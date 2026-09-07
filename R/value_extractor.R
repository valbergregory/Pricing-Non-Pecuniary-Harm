# Rule-based extraction of monetary amounts and their role in the decision ------
# Design: (1) find every "R$ <amount>" mention; (2) parse to numeric BRL;
# (3) classify the ROLE of the mention from a context window (fixed/upheld,
# increased, reduced, first-instance value, claimed, excluded: fees/fines/
# material damages/value of the case); (4) flag whether the mention refers to
# MORAL damages (window mentions dano moral / compensação / danos morais).
# Everything is transparent and testable; human annotation validates it (D5).

AMOUNT_RX <- "R\\$\\s?\\d{1,3}(?:\\.\\d{3})*(?:,\\d{2})?|R\\$\\s?\\d+(?:,\\d{2})?"

parse_brl <- function(txt) {
  x <- gsub("R\\$\\s?", "", txt)
  x <- gsub("\\.", "", x); x <- gsub(",", ".", x)
  suppressWarnings(as.numeric(x))
}

norm_text <- function(x) {
  x <- gsub("\\s+", " ", x)
  tolower(stringi::stri_trans_general(x, "Latin-ASCII"))
}

ROLE_RULES <- list(
  # order matters: first match wins within the same distance tier
  exclude_fees     = "honorari|sucumb|custas",
  exclude_fine     = "multa|astreinte|dias-multa",
  exclude_case_val = "valor da causa|valor atribuido a causa",
  exclude_material = "danos? materia|dano emergente|lucros cessantes|repeticao|restitui|devolu|ressarci",
  increased        = "major|elev|aument|arbitr[a-z]* em patamar superior",
  reduced          = "reduz|minor|diminu|decot",
  first_instance   = "sentenca|juizo a quo|primeiro grau|magistrad[oa] (sentenciante|de origem)|fixad[oa] na origem|arbitrad[oa] na origem|condenou",
  claimed          = "pleite|requer|postul|pedid|pretens",
  fixed            = "fix|arbitr|mant|condena|quantum|montante|compensa|indeniz"
)

# Clause containing positions [from, to]: bounded by ';' or '.' followed by space/end,
# limited to `max_span` characters on each side.
clause_around <- function(text, from, to, max_span = 220L) {
  left <- substr(text, max(1, from - max_span), from - 1)
  right <- substr(text, to + 1, min(nchar(text), to + max_span))
  lb <- gregexpr("[;.](?=\\s|$)", left, perl = TRUE)[[1]]
  if (lb[1] != -1) left <- substr(left, max(lb) + 1, nchar(left))
  rb <- regexpr("[;.](?=\\s|$)", right, perl = TRUE)
  if (rb != -1) right <- substr(right, 1, rb)
  paste0(left, substr(text, from, to), right)
}

classify_role <- function(ctx) {
  ctx <- norm_text(ctx)
  for (nm in names(ROLE_RULES)) if (grepl(ROLE_RULES[[nm]], ctx, perl = TRUE)) return(nm)
  "unknown"
}

is_moral_ctx <- function(ctx) grepl("dano[s]? mora|danos morais|compensa|abalo|sofrimento|extrapatrimon", norm_text(ctx), perl = TRUE)

# Extract all mentions from one text. `window` = chars on each side for context.
extract_amounts <- function(text, window = 160L, section = "ementa") {
  if (is.null(text) || is.na(text) || !nzchar(text)) return(empty_mentions())
  m <- gregexpr(AMOUNT_RX, text, perl = TRUE)[[1]]
  if (m[1] == -1) return(empty_mentions())
  starts <- as.integer(m); lens <- attr(m, "match.length")
  rows <- lapply(seq_along(starts), function(i) {
    amt_txt <- substr(text, starts[i], starts[i] + lens[i] - 1)
    ctx <- substr(text, max(1, starts[i] - window), min(nchar(text), starts[i] + lens[i] + window))
    # Role is decided on the CLAUSE containing the amount (between ; or . boundaries),
    # so that "danos materiais de R$ X; danos morais em R$ Y" is split correctly.
    role <- classify_role(clause_around(text, starts[i], starts[i] + lens[i] - 1))
    data.frame(section = section, idx = i, amount_brl = parse_brl(amt_txt), amount_text = amt_txt,
               role = role, role_conf = if (role == "unknown") 0.3 else 0.7,
               is_moral = is_moral_ctx(ctx), context = gsub("\\s+", " ", ctx),
               position = starts[i], stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

empty_mentions <- function() data.frame(section = character(), idx = integer(), amount_brl = numeric(),
                                        amount_text = character(), role = character(), role_conf = numeric(),
                                        is_moral = logical(), context = character(), position = integer(),
                                        stringsAsFactors = FALSE)

# Heuristic "final award" for a decision: prefer ementa mentions with role fixed/
# increased/reduced that are moral; if none, fall back to full text. Returns one row
# or NA. This is a DIAGNOSTIC heuristic; the paper's measure comes from validated rules.
pick_award <- function(mentions) {
  if (nrow(mentions) == 0) return(NA_real_)
  cand <- mentions[mentions$is_moral & mentions$role %in% c("fixed", "increased", "reduced"), ]
  if (nrow(cand) == 0) return(NA_real_)
  # For increased/reduced, the LAST amount in the context tends to be the new value
  cand$amount_brl[nrow(cand)]
}

# Apply to a data.frame of acórdãos (columns uuid, ementa, inteiro_teor) -> long table
extract_from_acordaos <- function(df, sections = c("ementa", "inteiro_teor")) {
  out <- lapply(seq_len(nrow(df)), function(i) {
    parts <- lapply(sections, function(s) {
      m <- extract_amounts(df[[s]][i], section = s)
      if (nrow(m)) m$uuid <- df$uuid[i]
      m
    })
    do.call(rbind, parts)
  })
  res <- do.call(rbind, out)
  if (is.null(res) || nrow(res) == 0) { e <- empty_mentions(); e$uuid <- character(); return(e) }
  res[, c("uuid", setdiff(names(res), "uuid"))]
}
