# 04 — Full collection 2015–2025 from JurisDF (RStudio Background Job). Decision D12.
# Courtesy rules (D6): 1 request/second, identifying User-Agent, monthly windows,
# idempotent resume (a window whose pages are all logged is skipped), raw JSON kept
# with SHA-256. Re-run any time: it only fetches what is missing.
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
log <- make_logger("outputs/logs/04_collect_tjdft_full.log")
con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
db_init(con)

w <- as.Date(cfg$temporal$study_window)
starts <- seq(as.Date(format(w[1], "%Y-%m-01")), w[2], by = "month")
ends <- pmin(c(starts[-1] - 1, w[2]), w[2])
windows <- data.frame(from = format(starts), to = format(ends), stringsAsFactors = FALSE)
log(sprintf("study window %s..%s: %d monthly windows", w[1], w[2], nrow(windows)))

done_pages <- function(from, to) {
  DBI::dbGetQuery(con, "SELECT count(DISTINCT page) n FROM collection_log WHERE source='tjdft' AND request_body LIKE ?",
                  params = list(sprintf("%%entre %s e %s%%", from, to)))$n
}
status_file <- "outputs/diagnostics/04_collection_status.csv"
status <- if (file.exists(status_file)) utils::read.csv(status_file, stringsAsFactors = FALSE) else
  data.frame(from = character(), to = character(), hits = integer(), pages = integer(),
             pages_done = integer(), checked_at = character(), stringsAsFactors = FALSE)

for (i in seq_len(nrow(windows))) {
  from <- windows$from[i]; to <- windows$to[i]
  cnt <- tryCatch(tjdft_count(cfg, from, to), error = function(e) NULL)
  if (is.null(cnt)) { log(sprintf("%s..%s: count FAILED, skipping for now", from, to)); next }
  n_pages <- ceiling(cnt$hits / cfg$sources$tjdft$page_size)
  have <- done_pages(from, to)
  if (cnt$hits == 0 || have >= n_pages) {
    log(sprintf("%s..%s: %d hits, %d/%d pages already collected — skip", from, to, cnt$hits, have, n_pages))
  } else {
    log(sprintf("%s..%s: %d hits, %d pages (%d done) — collecting", from, to, cnt$hits, n_pages, have))
    res <- tryCatch(tjdft_collect_window(cfg, con, from, to, log = log), error = function(e) { log("ERROR: ", conditionMessage(e)); NULL })
  }
  st <- data.frame(from = from, to = to, hits = cnt$hits, pages = n_pages, pages_done = done_pages(from, to),
                   checked_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  status <- rbind(status[!(status$from %in% from), ], st)
  utils::write.csv(status, "outputs/diagnostics/04_collection_status.csv", row.names = FALSE)
  Sys.sleep(cfg$sources$tjdft$sleep_seconds)
}
tot <- DBI::dbGetQuery(con, "SELECT count(*) n, count(inteiro_teor) nft, min(data_julgamento) d0, max(data_julgamento) d1 FROM acordaos")
log(sprintf("acordaos in DB: %d (full text %d), %s..%s", tot$n, tot$nft, tot$d0, tot$d1))
log("done")
