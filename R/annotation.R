# Human validation of the extractor (decision D5, ratified 2026-10-03) ----------------------
# Pure functions used by scripts/05_annotation_sample.R (seeded stratified sample, blind
# worksheets) and scripts/06_annotation_validity.R (precision/recall/F1 per field and
# intra-rater kappa). Design parameters live in config/config.yml -> `annotation`.
# Nothing here reads or writes decision texts to versioned folders: worksheets, text
# sheets ("fichas") and the key file go to `annotation$dir` (under data/, git-ignored).

# Codes accepted in the worksheets (documented in docs/COMO_ANOTAR.md) -----------------
ANNOT_CODES <- list(
  decide_dano_moral = c("S", "N"),
  papel_valor = c("FIXADO", "MANTIDO", "MAJORADO", "REDUZIDO", "AFASTADO", "SEM_VALOR"),
  resultado = c("PROVIDO", "PARCIAL", "DESPROVIDO", "NAO_CONHECIDO", "OUTRO"),
  multiplos_valores = c("S", "N"),
  confianca = c("1", "2", "3")
)
# Human role -> extractor role (the extractor's "fixed" covers fixed AND upheld).
ROLE_MAP <- c(FIXADO = "fixed", MANTIDO = "fixed", MAJORADO = "increased", REDUZIDO = "reduced")

WORKSHEET_COLS <- c("item_id", "rodada", "ficha", "decide_dano_moral", "valor_final", "papel_valor",
                    "multiplos_valores", "valor_origem", "tipo_lesao", "resultado", "confianca",
                    "minutos", "observacoes")

# Stratum of the panel (D8): Turmas Recursais vs Turmas/Câmaras Cíveis vs other panels.
annotation_stratum <- function(orgao_julgador, subbase = NA_character_, turma_recursal = NA) {
  org <- stringi::stri_trans_general(toupper(ifelse(is.na(orgao_julgador), "", orgao_julgador)), "Latin-ASCII")
  rec <- grepl("RECURSA", org) | (!is.na(subbase) & subbase == "acordaos-tr") | (!is.na(turma_recursal) & turma_recursal)
  civ <- grepl("CIVE(L|IS)", org)
  ifelse(rec, "recursal", ifelse(civ, "civel", "outro"))
}

# Allocation of n units over strata of sizes N (named): at least `min_per` in every
# non-empty stratum, remainder proportional to N by largest remainders, capped at N.
allocate_sample <- function(N, n, min_per = 1L) {
  stopifnot(!is.null(names(N)), n >= 0)
  N <- N[N > 0]
  if (sum(N) < n) stop(sprintf("sampling frame has %d units, fewer than n = %d", sum(N), n))
  if (length(N) * min_per > n) stop(sprintf("%d non-empty strata x min %d exceed n = %d", length(N), min_per, n))
  a <- pmin(N, min_per)
  repeat {
    left <- n - sum(a); if (left == 0) break
    open <- a < N
    share <- left * N[open] / sum(N[open])
    add <- floor(share)
    if (sum(add) == 0) {                               # distribute by largest remainder
      ord <- order(-(share - add), names(share))
      add[ord[seq_len(min(left, length(ord)))]] <- 1
    }
    a[open] <- pmin(N[open], a[open] + add)
  }
  a
}

# Opaque item identifiers (no information about stratum, round or extractor output).
make_item_ids <- function(n, existing = character()) {
  alphabet <- c(LETTERS[!LETTERS %in% c("I", "O")], 2:9)
  ids <- character()
  while (length(ids) < n) {
    cand <- vapply(seq_len(n - length(ids)), function(i) paste(sample(alphabet, 6, TRUE), collapse = ""), character(1))
    ids <- unique(c(ids, setdiff(paste0("P-", cand), existing)))
  }
  ids[seq_len(n)]
}

# Draw the D5 design from a frame with columns uuid, stratum, year, found (logical).
# Returns one row per worksheet item: the main sample (rounds 1..n_rounds) plus the blind
# re-annotation subset (round = n_rounds + 1, with new item ids and `orig_item_id`).
draw_annotation_design <- function(frame, n_total = 300L, n_rounds = 3L, n_reannot = 60L,
                                   reannot_from_rounds = 1L, seed = 1L) {
  stopifnot(all(c("uuid", "stratum", "year", "found") %in% names(frame)), !anyDuplicated(frame$uuid))
  set.seed(seed)
  frame$cell <- paste(frame$stratum, frame$year, ifelse(frame$found, "com_valor", "sem_valor"), sep = "|")
  N <- table(frame$cell); N <- setNames(as.integer(N), names(N))
  a <- allocate_sample(N, n_total)
  picked <- do.call(rbind, lapply(names(a), function(h) {
    f <- frame[frame$cell == h, , drop = FALSE]
    f <- f[sample.int(nrow(f), a[[h]]), , drop = FALSE]
    f$N_h <- N[[h]]; f$n_h <- a[[h]]; f
  }))
  picked$weight <- picked$N_h / picked$n_h
  # Rounds: deal the stratum-sorted list round-robin, so each round mirrors the design.
  picked <- picked[order(picked$cell, stats::runif(nrow(picked))), ]
  picked$round <- ((seq_len(nrow(picked)) - 1L) %% n_rounds) + 1L
  picked <- picked[order(picked$round, stats::runif(nrow(picked))), ]   # random order within round
  picked$item_id <- make_item_ids(nrow(picked))
  picked$is_reannot <- FALSE; picked$orig_item_id <- NA_character_
  # Blind re-annotation: stratified by stratum x found within the eligible rounds.
  pool <- picked[picked$round %in% reannot_from_rounds, , drop = FALSE]
  pool$cell2 <- paste(pool$stratum, pool$found, sep = "|")
  N2 <- table(pool$cell2); N2 <- setNames(as.integer(N2), names(N2))
  a2 <- allocate_sample(N2, min(n_reannot, nrow(pool)))
  re <- do.call(rbind, lapply(names(a2), function(h) {
    f <- pool[pool$cell2 == h, , drop = FALSE]; f[sample.int(nrow(f), a2[[h]]), , drop = FALSE]
  }))
  re$cell2 <- NULL
  re <- re[sample.int(nrow(re)), ]
  re$orig_item_id <- re$item_id
  re$item_id <- make_item_ids(nrow(re), existing = picked$item_id)
  re$round <- n_rounds + 1L; re$is_reannot <- TRUE
  out <- rbind(picked, re)
  rownames(out) <- NULL
  out
}

# Plain-text sheet shown to the annotator: no extractor output, no rapporteur name.
format_ficha <- function(item_id, orgao_julgador, data_julgamento, decisao, ementa, inteiro_teor) {
  na <- function(x) if (is.null(x) || is.na(x) || !nzchar(x)) "(vazio)" else x
  c(sprintf("FICHA %s", item_id),
    sprintf("Órgão julgador: %s | Data de julgamento: %s", na(orgao_julgador), na(as.character(data_julgamento))),
    "", "=== DECISÃO (dispositivo resumido) ===", na(decisao),
    "", "=== EMENTA ===", na(ementa),
    "", "=== INTEIRO TEOR ===", na(inteiro_teor))
}

# Blank worksheet for a set of items (one row per item, codes filled by the annotator).
blank_worksheet <- function(items, ficha_dir) {
  ws <- as.data.frame(setNames(replicate(length(WORKSHEET_COLS), rep("", nrow(items)), simplify = FALSE),
                               WORKSHEET_COLS), stringsAsFactors = FALSE)
  ws$item_id <- items$item_id; ws$rodada <- items$round
  ws$ficha <- file.path(ficha_dir, paste0(items$item_id, ".txt"))
  ws
}

# Worksheets are written with ';' and UTF-8 BOM so that Excel/LibreOffice in pt-BR open
# them directly; the reader accepts ';' or ',' (whatever the spreadsheet saved).
write_worksheet <- function(ws, path) {
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  utils::write.table(ws, con, sep = ";", row.names = FALSE, na = "", fileEncoding = "UTF-8", qmethod = "double")
}

read_worksheet <- function(path) {
  first <- readLines(path, n = 1, warn = FALSE, encoding = "UTF-8")
  sep <- if (grepl(";", first)) ";" else ","
  ws <- utils::read.table(path, sep = sep, header = TRUE, quote = "\"", colClasses = "character",
                          na.strings = character(), fileEncoding = "UTF-8-BOM", comment.char = "",
                          check.names = FALSE, fill = TRUE)
  names(ws) <- sub("^﻿", "", names(ws))
  missing <- setdiff(WORKSHEET_COLS, names(ws))
  if (length(missing)) stop(path, ": missing columns ", paste(missing, collapse = ", "))
  ws
}

# "R$ 10.000,00", "10.000,00", "10000", "10000.5", "10 mil" are NOT all accepted: the
# annotator writes the number as it appears (Brazilian format) or plain digits.
parse_annot_value <- function(x) {
  x <- trimws(gsub("R\\$|\\s| ", "", x, perl = TRUE))
  out <- rep(NA_real_, length(x))
  ok <- nzchar(x)
  br <- ok & grepl(",", x)                                  # Brazilian: 1.234,56
  out[br] <- suppressWarnings(as.numeric(gsub(",", ".", gsub("\\.", "", x[br]))))
  thou <- ok & !br & grepl("^\\d{1,3}(\\.\\d{3})+$", x)       # 10.000 -> thousands
  out[thou] <- suppressWarnings(as.numeric(gsub("\\.", "", x[thou])))
  plain <- ok & !br & !thou
  out[plain] <- suppressWarnings(as.numeric(x[plain]))
  bad <- ok & is.na(out)
  if (any(bad)) warning("unparseable values: ", paste(unique(x[bad]), collapse = ", "))
  out
}

# Validate codes; returns a data.frame of problems (item_id, column, value).
check_worksheet <- function(ws, harm_ids) {
  probs <- list()
  chk <- function(col, allowed) {
    v <- toupper(trimws(ws[[col]])); bad <- nzchar(v) & !(v %in% allowed)
    if (any(bad)) probs[[length(probs) + 1]] <<- data.frame(item_id = ws$item_id[bad], column = col, value = ws[[col]][bad])
  }
  for (col in names(ANNOT_CODES)) chk(col, ANNOT_CODES[[col]])
  chk("tipo_lesao", toupper(harm_ids))
  for (col in c("valor_final", "valor_origem")) {
    v <- suppressWarnings(parse_annot_value(ws[[col]])); bad <- nzchar(trimws(ws[[col]])) & is.na(v)
    if (any(bad)) probs[[length(probs) + 1]] <- data.frame(item_id = ws$item_id[bad], column = col, value = ws[[col]][bad])
  }
  done <- nzchar(trimws(ws$decide_dano_moral))
  incoh <- done & toupper(trimws(ws$papel_valor)) %in% names(ROLE_MAP) & !nzchar(trimws(ws$valor_final))
  if (any(incoh)) probs[[length(probs) + 1]] <- data.frame(item_id = ws$item_id[incoh], column = "valor_final",
                                                           value = "papel com valor, mas valor_final vazio")
  if (length(probs)) do.call(rbind, probs) else data.frame(item_id = character(), column = character(), value = character())
}

# Normalised annotation table from a worksheet (only rows already annotated).
normalise_annotations <- function(ws) {
  ws <- ws[nzchar(trimws(ws$decide_dano_moral)), , drop = FALSE]
  up <- function(x) { x <- toupper(trimws(x)); x[!nzchar(x)] <- NA_character_; x }
  data.frame(item_id = ws$item_id, round = as.integer(ws$rodada),
             decide_dano_moral = up(ws$decide_dano_moral),
             award_brl = parse_annot_value(ws$valor_final),
             papel_valor = up(ws$papel_valor),
             award_role = unname(ROLE_MAP[up(ws$papel_valor)]),
             multiplos_valores = up(ws$multiplos_valores),
             first_instance_brl = parse_annot_value(ws$valor_origem),
             harm_type = tolower(up(ws$tipo_lesao)),
             outcome = up(ws$resultado), confianca = up(ws$confianca),
             minutos = suppressWarnings(as.numeric(sub(",", ".", ws$minutos))),
             stringsAsFactors = FALSE)
}

# Precision / recall / F1 of an extracted value against the human value.
# TP: both present and |pred - gold| <= tol; a wrong value counts as FP and FN.
value_prf <- function(pred, gold, tol = 0.01, w = rep(1, length(pred))) {
  hp <- !is.na(pred); hg <- !is.na(gold)
  tp <- hp & hg & abs(pred - gold) <= tol
  TP <- sum(w[tp]); FP <- sum(w[hp & !tp]); FN <- sum(w[hg & !tp]); TN <- sum(w[!hp & !hg])
  P <- if (TP + FP > 0) TP / (TP + FP) else NA_real_
  R <- if (TP + FN > 0) TP / (TP + FN) else NA_real_
  F1 <- if (isTRUE(P + R > 0)) 2 * P * R / (P + R) else NA_real_
  c(n = sum(w), tp = TP, fp = FP, fn = FN, tn = TN, precision = P, recall = R, f1 = F1)
}

# Per-class precision/recall/F1 for a categorical field, plus macro-F1 and accuracy.
class_prf <- function(pred, gold) {
  ok <- !is.na(pred) & !is.na(gold); pred <- pred[ok]; gold <- gold[ok]
  cls <- sort(unique(c(pred, gold)))
  per <- do.call(rbind, lapply(cls, function(k) {
    tp <- sum(pred == k & gold == k); fp <- sum(pred == k & gold != k); fn <- sum(pred != k & gold == k)
    P <- if (tp + fp > 0) tp / (tp + fp) else NA_real_; R <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
    data.frame(class = k, support = sum(gold == k), precision = P, recall = R,
               f1 = if (isTRUE(P + R > 0)) 2 * P * R / (P + R) else if (tp + fp + fn > 0) 0 else NA_real_)
  }))
  list(per_class = per, n = length(gold), accuracy = if (length(gold)) mean(pred == gold) else NA_real_,
       macro_f1 = if (length(cls)) mean(per$f1, na.rm = TRUE) else NA_real_)
}

# Cohen's kappa for two codings of the same items (NA treated as its own category
# "<vazio>", because "no value" is itself an annotation decision).
cohen_kappa <- function(a, b) {
  a <- ifelse(is.na(a), "<vazio>", as.character(a)); b <- ifelse(is.na(b), "<vazio>", as.character(b))
  n <- length(a); if (n == 0) return(c(n = 0, agreement = NA, kappa = NA))
  lv <- union(a, b); tab <- table(factor(a, lv), factor(b, lv))
  po <- sum(diag(tab)) / n; pe <- sum(rowSums(tab) * colSums(tab)) / n^2
  c(n = n, agreement = po, kappa = if (pe < 1) (po - pe) / (1 - pe) else NA_real_)
}

# Percentile bootstrap CI for the value F1 (resampling items; seed fixed by caller).
bootstrap_f1 <- function(pred, gold, tol = 0.01, reps = 2000L, level = 0.95) {
  n <- length(pred); if (n < 2) return(c(lo = NA_real_, hi = NA_real_))
  f <- replicate(reps, { i <- sample.int(n, n, TRUE); value_prf(pred[i], gold[i], tol)[["f1"]] })
  q <- stats::quantile(f, c((1 - level) / 2, 1 - (1 - level) / 2), na.rm = TRUE, names = FALSE)
  c(lo = q[1], hi = q[2])
}
