# DataJud public API (CNJ) — counts only; no award values exist there ---------
# Quirk verified 2026-09-05: in api_publica_tjdft and api_publica_tjal the field
# dataAjuizamento is stored as "yyyyMMddHHmmss" but mapped so that Elasticsearch
# reads it as epoch_millis; ISO ranges return 0. Use numeric bounds with
# format = "epoch_millis" (e.g. 20150101000000) for those courts.

datajud_search <- function(cfg, tribunal, body, key = datajud_key()) {
  stopifnot(!is.na(key), nzchar(key))
  url <- sprintf("%s/api_publica_%s/_search", cfg$sources$datajud$base, tribunal)
  httr2::request(url) |>
    httr2::req_headers(Authorization = paste("APIKey", key), `Content-Type` = "application/json") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |> httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 3) |> httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = FALSE)
}

datajud_count_subjects <- function(cfg, tribunal, from = "2015-01-01", to = "2026-12-31",
                                   epoch_quirk = tribunal %in% c("tjdft", "tjal")) {
  codes <- cfg$sources$datajud$subject_codes
  rng <- if (epoch_quirk) {
    list(gte = as.numeric(paste0(gsub("-", "", from), "000000")),
         lte = as.numeric(paste0(gsub("-", "", to), "235959")), format = "epoch_millis")
  } else list(gte = from, lte = to)
  body <- list(size = 0, track_total_hits = TRUE,
               query = list(bool = list(filter = list(
                 list(terms = list(assuntos.codigo = codes)),
                 list(range = list(dataAjuizamento = rng))))),
               aggs = list(grau = list(terms = list(field = "grau.keyword", size = 6))))
  r <- datajud_search(cfg, tribunal, body)
  grau <- vapply(r$aggregations$grau$buckets, function(b) b$doc_count, numeric(1))
  names(grau) <- vapply(r$aggregations$grau$buckets, function(b) b$key, character(1))
  list(total = r$hits$total$value, grau = grau)
}
