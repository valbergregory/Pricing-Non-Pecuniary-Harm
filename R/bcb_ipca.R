# IPCA deflator from BCB/SGS series 433 (monthly % change) ---------------------

bcb_ipca <- function(cfg, from = "01/01/2000", to = format(Sys.Date(), "%d/%m/%Y")) {
  r <- httr2::request(cfg$sources$bcb_sgs$url) |>
    httr2::req_url_query(formato = "json", dataInicial = from, dataFinal = to) |>
    httr2::req_timeout(60) |> httr2::req_retry(max_tries = 3) |> httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  df <- data.frame(ref_month = as.Date(r$data, format = "%d/%m/%Y"),
                   pct = as.numeric(r$valor), stringsAsFactors = FALSE)
  df <- df[order(df$ref_month), ]
  df$index_value <- cumprod(1 + df$pct / 100)
  df
}

# Deflate nominal BRL observed in `month` to prices of `base_month` (both Date, day 1)
deflate_brl <- function(amount, month, ipca, base_month) {
  idx <- setNames(ipca$index_value, format(ipca$ref_month, "%Y-%m"))
  m <- format(as.Date(month), "%Y-%m"); b <- format(as.Date(base_month), "%Y-%m")
  amount * unname(idx[b]) / unname(idx[m])
}
