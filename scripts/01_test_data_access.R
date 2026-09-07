# 01 — Real access test of every source (Console; ~2 min). Writes
# outputs/logs/01_test_data_access.log and outputs/diagnostics/01_source_checks.csv
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
log <- make_logger("outputs/logs/01_test_data_access.log")
checks <- list()
note <- function(id, ok, detail) {
  checks[[length(checks) + 1]] <<- data.frame(id = id, ok = ok, detail = detail, checked_at = Sys.time())
  log(sprintf("%-16s %s  %s", id, if (isTRUE(ok)) "OK  " else "FAIL", detail))
}
try_note <- function(id, expr) {
  r <- tryCatch(expr, error = function(e) e)
  if (inherits(r, "error")) note(id, FALSE, conditionMessage(r)) else note(id, TRUE, r)
}

# 1. TJDFT JurisDF: counts per year + one page with full text
try_note("tjdft_count", {
  yrs <- c(2015, 2020, 2024, 2025)
  cts <- vapply(yrs, function(y) tjdft_count(cfg, sprintf("%d-01-01", y), sprintf("%d-12-31", y))$hits, numeric(1))
  paste(sprintf("%d=%s", yrs, format(cts, big.mark = ".")), collapse = " ")
})
try_note("tjdft_fulltext", {
  pg <- tjdft_fetch_page(cfg, cfg$pilot$window[1], cfg$pilot$window[2], 0)
  df <- tjdft_parse_registros(pg$registros)
  sprintf("hits=%d page0=%d with_fulltext=%d mean_chars=%.0f", pg$hits, nrow(df),
          sum(!is.na(df$inteiro_teor)), mean(df$inteiro_teor_chars, na.rm = TRUE))
})

# 2. STJ CKAN
try_note("stj_ckan", { pl <- stj_package_list(cfg); sprintf("%d datasets", length(pl)) })
try_note("stj_integras", {
  res <- stj_resources(cfg, cfg$sources$stj_ckan$datasets$integras)
  sprintf("%d resources; zips=%d; total=%.1f GB", nrow(res), sum(res$format == "ZIP"),
          sum(res$size[res$format == "ZIP"], na.rm = TRUE) / 1e9)
})
try_note("stj_temas", {
  t <- stj_temas(cfg)
  dm <- grepl("dano(s)? mora(l|is)", paste(t$teseFirmada, t$questaoSubmetidaAJulgamento), ignore.case = TRUE)
  sprintf("%d precedentes; %d mention dano moral", nrow(t), sum(dm))
})

# 3. DataJud (public key)
try_note("datajud_key", { k <- datajud_key(); if (is.na(k)) stop("key not found") else "key resolved" })
for (tb in c("tjdft", "tjsp", "tjrs", "tjal")) {
  try_note(paste0("datajud_", tb), {
    r <- datajud_count_subjects(cfg, tb)
    sprintf("total=%s grau=[%s]", format(r$total, big.mark = "."),
            paste(names(r$grau), r$grau, sep = ":", collapse = " "))
  })
}

# 4. BCB IPCA
try_note("bcb_ipca", { ip <- bcb_ipca(cfg, from = "01/01/2015"); sprintf("%d months, last=%s", nrow(ip), max(ip$ref_month)) })

# 5. Reachability of web-only portals (informational; no scraping)
portals <- c(tjsp = "https://esaj.tjsp.jus.br/cjsg/consultaCompleta.do",
             tjrs = "https://www.tjrs.jus.br/novo/buscas-solr/?aba=jurisprudencia",
             tjmg = "https://www5.tjmg.jus.br/jurisprudencia/pesquisaPalavrasEspelhoAcordao.do",
             tjal = "https://www2.tjal.jus.br/cjosg/",
             stj_scon = "https://scon.stj.jus.br/SCON/")
for (nm in names(portals)) {
  st <- tryCatch(httr2::request(portals[[nm]]) |> httr2::req_user_agent("Mozilla/5.0") |>
                   httr2::req_timeout(40) |> httr2::req_error(is_error = function(r) FALSE) |>
                   httr2::req_perform() |> httr2::resp_status(),
                 error = function(e) NA_integer_)
  note(paste0("web_", nm), !is.na(st) && st == 200, paste("HTTP", st))
}

out <- do.call(rbind, checks)
utils::write.csv(out, "outputs/diagnostics/01_source_checks.csv", row.names = FALSE)
log(sprintf("done: %d checks, %d OK", nrow(out), sum(out$ok)))
