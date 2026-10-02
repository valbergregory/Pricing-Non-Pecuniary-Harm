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
  if (is.na(idx[b])) stop("IPCA not available for base month ", b, " (series ends ", max(names(idx)), ")")
  amount * unname(idx[b]) / unname(idx[m])
}

# D4 helpers: the base month and the SM option come only from config/config.yml
# (temporal$price_base, temporal$report_sm_multiples), so the author's decision is a
# one-line edit there.
price_base_date <- function(cfg) {
  b <- cfg$temporal$price_base
  if (is.null(b) || !grepl("^\\d{4}-\\d{2}$", b)) stop("config temporal$price_base must be 'YYYY-MM'")
  as.Date(paste0(b, "-01"))
}

# Generic BCB/SGS monthly series -> data.frame(ref_month, value)
bcb_sgs_monthly <- function(code, from = "01/01/2000", to = format(Sys.Date(), "%d/%m/%Y")) {
  r <- httr2::request(sprintf("https://api.bcb.gov.br/dados/serie/bcdata.sgs.%s/dados", code)) |>
    httr2::req_url_query(formato = "json", dataInicial = from, dataFinal = to) |>
    httr2::req_timeout(60) |> httr2::req_retry(max_tries = 3) |> httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  if (!all(c("data", "valor") %in% names(r))) stop("unexpected SGS response for series ", code)
  df <- data.frame(ref_month = as.Date(r$data, format = "%d/%m/%Y"), value = as.numeric(r$valor))
  df[order(df$ref_month), ]
}

# Nominal minimum wage (R$) by month, SGS series in config (default 1619).
bcb_minimum_wage <- function(cfg, from = "01/01/2010") {
  code <- cfg$sources$bcb_sgs$minimum_wage_series %||% 1619
  sm <- bcb_sgs_monthly(code, from = from)
  # Sanity check: the Brazilian minimum wage was between R$ 500 and R$ 5,000 in 2010-2030.
  if (any(sm$value < 500 | sm$value > 5000, na.rm = TRUE)) stop("series ", code, " does not look like the minimum wage")
  names(sm)[2] <- "sm_brl"
  sm
}

# Amount in multiples of the minimum wage in force in the month of the decision.
to_sm_multiples <- function(amount, month, sm) {
  v <- setNames(sm$sm_brl, format(sm$ref_month, "%Y-%m"))
  amount / unname(v[format(as.Date(month), "%Y-%m")])
}

# Adds award_real (IPCA, base month from config) and, if configured, award_sm.
add_real_values <- function(df, cfg, ipca, sm = NULL, amount = "award_brl", date = "data_julgamento") {
  df$award_real <- deflate_brl(df[[amount]], df[[date]], ipca, price_base_date(cfg))
  if (isTRUE(cfg$temporal$report_sm_multiples)) {
    if (is.null(sm)) stop("report_sm_multiples is TRUE but no minimum-wage series was supplied")
    df$award_sm <- to_sm_multiples(df[[amount]], df[[date]], sm)
  }
  df
}
