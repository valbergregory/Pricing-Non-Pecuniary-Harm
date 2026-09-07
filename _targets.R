# targets pipeline (skeleton for phase 1; the pilot runs through scripts/02-03).
# Run: targets::tar_make()  (Background Job)
library(targets)
tar_option_set(packages = c("httr2", "jsonlite", "yaml", "digest", "stringi", "duckdb", "DBI"),
               format = "rds")
for (f in list.files("R", full.names = TRUE)) source(f)

list(
  tar_target(config_file, "config/config.yml", format = "file"),
  tar_target(cfg, load_config(config_file)),
  tar_target(harm_types_file, "config/harm_types.yml", format = "file"),
  tar_target(ipca, bcb_ipca(cfg, from = "01/01/2010")),
  # Phase 1 (after D1–D6 approval): monthly windows over the study period
  tar_target(windows, {
    w <- as.Date(cfg$temporal$study_window)
    starts <- seq(w[1], w[2], by = "month")
    data.frame(from = format(starts), to = format(pmin(starts + 31 - as.integer(format(starts + 31, "%d")), w[2])))
  }),
  tar_target(db_path, {
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); db_init(con); cfg$paths$db
  }, format = "file"),
  tar_target(collected, {
    if (cfg$project$stage == "feasibility") return(NULL)   # pilot only via scripts/02
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    tjdft_collect_window(cfg, con, windows$from, windows$to)
  }, pattern = map(windows), iteration = "list"),
  tar_target(mentions, {
    if (is.null(collected)) return(NULL)
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    ac <- DBI::dbGetQuery(con, "SELECT uuid, ementa, inteiro_teor FROM acordaos")
    m <- extract_from_acordaos(ac); DBI::dbExecute(con, "DELETE FROM value_mentions"); db_upsert(con, "value_mentions", m); nrow(m)
  })
)
