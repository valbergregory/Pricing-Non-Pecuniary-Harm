# 02 — Pilot collection (RStudio Background Job): one month of TJDFT acórdãos on
# "dano moral", with full text, into DuckDB. Diagnostic only — not the study sample.
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
log <- make_logger("outputs/logs/02_pilot_tjdft_month.log")
con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
db_init(con)

w <- cfg$pilot$window
res <- tjdft_collect_window(cfg, con, w[1], w[2], max_pages = cfg$pilot$max_pages, log = log)

n <- DBI::dbGetQuery(con, "SELECT count(*) AS n, count(inteiro_teor) AS n_ft,
                            min(data_julgamento) AS d0, max(data_julgamento) AS d1 FROM acordaos")
log(sprintf("acordaos in DB: %d (full text: %d), %s..%s", n$n, n$n_ft, n$d0, n$d1))
by_base <- DBI::dbGetQuery(con, "SELECT base, subbase, count(*) n FROM acordaos GROUP BY 1,2 ORDER BY n DESC")
print(by_base)
utils::write.csv(by_base, "outputs/diagnostics/02_pilot_by_base.csv", row.names = FALSE)

# IPCA into DB (for later deflation)
ip <- bcb_ipca(cfg, from = "01/01/2010")
db_upsert(con, "ipca", ip)
log(sprintf("ipca rows: %d", nrow(ip)))
log("done")
