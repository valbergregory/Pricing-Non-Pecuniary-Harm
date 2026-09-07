# JurisDF (TJDFT) public API client --------------------------------------------
# Endpoint discovered and verified on 2026-09-05 by capturing the front-end request:
#   POST https://jurisdf.tjdft.jus.br/api/v1/pesquisa
#   {"query": "...", "termosAcessorios": [{"campo": "dataJulgamento",
#     "valor": "entre 2024-01-01 e 2024-12-31"}], "pagina": 0, "tamanho": 40,
#     "sinonimos": false, "espelho": true, "inteiroTeor": false,
#     "retornaInteiroTeor": true, "retornaTotalizacao": true}
# The API rejects unknown properties ("property X should not exist") and caps
# tamanho at 40.

tjdft_body <- function(query, date_from, date_to, page, size = 40,
                       sinonimos = FALSE, espelho = TRUE, inteiro_teor_search = FALSE,
                       return_full_text = TRUE, extra_terms = list()) {
  terms <- list(list(campo = "dataJulgamento",
                     valor = sprintf("entre %s e %s", date_from, date_to)))
  terms <- c(terms, extra_terms)
  list(query = query, termosAcessorios = terms, pagina = as.integer(page),
       tamanho = as.integer(size), sinonimos = sinonimos, espelho = espelho,
       inteiroTeor = inteiro_teor_search, retornaInteiroTeor = return_full_text,
       retornaTotalizacao = TRUE)
}

tjdft_request <- function(endpoint, body, timeout = 120) {
  httr2::request(endpoint) |>
    httr2::req_headers(`Content-Type` = "application/json",
                       `User-Agent` = "Pricing-Non-Pecuniary-Harm/0.1 (+https://github.com/valbergregory/Pricing-Non-Pecuniary-Harm; academic research; 1 req/s; R httr2)") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(timeout) |>
    httr2::req_retry(max_tries = 4, backoff = ~ 2 ^ .x) |>
    httr2::req_perform()
}

# One page -> list(hits, registros (list), raw_json (string))
tjdft_fetch_page <- function(cfg, date_from, date_to, page, return_full_text = NULL) {
  s <- cfg$sources$tjdft
  if (is.null(return_full_text)) return_full_text <- isTRUE(s$return_full_text)
  body <- tjdft_body(s$query, date_from, date_to, page, s$page_size,
                     sinonimos = isTRUE(s$sinonimos), espelho = isTRUE(s$espelho),
                     inteiro_teor_search = isTRUE(s$inteiro_teor_search),
                     return_full_text = return_full_text)
  resp <- tjdft_request(s$endpoint, body)
  raw <- httr2::resp_body_string(resp)
  parsed <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  if (is.null(parsed$hits)) stop("Unexpected response: ", substr(raw, 1, 300))
  list(hits = parsed$hits$value, registros = parsed$registros,
       agregacoes = parsed$agregacoes, raw_json = raw,
       body_json = jsonlite::toJSON(body, auto_unbox = TRUE))
}

# Count only (tamanho = 1, no full text) --------------------------------------
tjdft_count <- function(cfg, date_from, date_to) {
  s <- cfg$sources$tjdft
  body <- tjdft_body(s$query, date_from, date_to, 0, 1, sinonimos = isTRUE(s$sinonimos),
                     espelho = isTRUE(s$espelho), return_full_text = FALSE)
  parsed <- jsonlite::fromJSON(httr2::resp_body_string(tjdft_request(s$endpoint, body)),
                               simplifyVector = FALSE)
  bases <- vapply(parsed$agregacoes$base, function(b) b$total, numeric(1))
  names(bases) <- vapply(parsed$agregacoes$base, function(b) b$nome, character(1))
  list(hits = parsed$hits$value, bases = bases)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

as_date_safe <- function(x) {
  if (is.null(x) || !nzchar(x)) return(as.Date(NA))
  as.Date(substr(x, 1, 10))
}

# Registros (list of lists) -> data.frame matching table `acordaos`
tjdft_parse_registros <- function(registros, raw_file = NA_character_) {
  if (length(registros) == 0) return(data.frame())
  rows <- lapply(registros, function(r) {
    it <- r$inteiroTeor %||% NA_character_
    data.frame(
      uuid = r$uuid %||% NA_character_,
      identificador = as.character(r$identificador %||% NA),
      base = r$base %||% NA_character_, subbase = r$subbase %||% NA_character_,
      processo = r$processo %||% NA_character_,
      classe_cnj = as.integer(r$codigoClasseCnj %||% NA),
      orgao_julgador = r$descricaoOrgaoJulgador %||% NA_character_,
      cod_orgao = as.integer(r$codigoSistjOrgaoJulgador %||% NA),
      relator = r$nomeRelator %||% NA_character_,
      data_julgamento = as_date_safe(r$dataJulgamento),
      data_publicacao = as_date_safe(r$dataPublicacao),
      decisao = r$decisao %||% NA_character_, ementa = r$ementa %||% NA_character_,
      uf = r$uf %||% NA_character_,
      turma_recursal = isTRUE(r$turmaRecursal), segredo_justica = isTRUE(r$segredoJustica),
      possui_inteiro_teor = isTRUE(r$possuiInteiroTeor),
      inteiro_teor = it, inteiro_teor_chars = if (is.na(it)) NA_integer_ else nchar(it),
      raw_file = raw_file, collected_at = Sys.time(),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

# Collect a date window into DuckDB, page by page, saving raw JSON + log.
tjdft_collect_window <- function(cfg, con, date_from, date_to, max_pages = Inf, log = message) {
  s <- cfg$sources$tjdft
  out_dir <- file.path(cfg$paths$raw, "tjdft", paste0(date_from, "_", date_to))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  first <- tjdft_fetch_page(cfg, date_from, date_to, 0)
  n_pages <- ceiling(first$hits / s$page_size)
  log(sprintf("TJDFT %s..%s: %d hits, %d pages (max %s)", date_from, date_to,
              first$hits, n_pages, format(max_pages)))
  total <- 0L
  for (p in seq_len(min(n_pages, max_pages)) - 1L) {
    pg <- if (p == 0) first else tjdft_fetch_page(cfg, date_from, date_to, p)
    raw_file <- file.path(out_dir, sprintf("page_%04d.json", p))
    writeLines(pg$raw_json, raw_file, useBytes = TRUE)
    df <- tjdft_parse_registros(pg$registros, raw_file)
    if (nrow(df)) db_upsert(con, "acordaos", df)
    db_log_collection(con, "tjdft", s$endpoint, as.character(pg$body_json), p, nrow(df), raw_file)
    total <- total + nrow(df)
    log(sprintf("  page %d/%d: %d records (cum %d)", p + 1, min(n_pages, max_pages), nrow(df), total))
    Sys.sleep(s$sleep_seconds)
  }
  invisible(list(hits = first$hits, collected = total, dir = out_dir))
}
