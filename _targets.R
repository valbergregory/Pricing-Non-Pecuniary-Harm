# targets pipeline for phase 1 (the pilot runs through scripts/02-03).
# Run: targets::tar_make()  (Background Job), after `stage: phase1` in config/config.yml.
# The full 2015-2025 collection already exists (scripts/04, 2026-09-12): the `collected`
# branches only send one count request per month and skip months whose pages are all in
# `collection_log`, so tar_make() does not re-download the corpus.
library(targets)
tar_option_set(packages = c("httr2", "jsonlite", "yaml", "digest", "stringi", "duckdb", "DBI"),
               format = "rds")
for (f in list.files("R", full.names = TRUE)) source(f)

list(
  tar_target(config_file, "config/config.yml", format = "file"),
  tar_target(cfg, load_config(config_file)),
  tar_target(harm_types_file, "config/harm_types.yml", format = "file"),
  tar_target(ipca, bcb_ipca(cfg, from = "01/01/2010")),
  # D4 (pending): minimum-wage series only if temporal$report_sm_multiples is TRUE
  tar_target(minimum_wage, if (isTRUE(cfg$temporal$report_sm_multiples)) bcb_minimum_wage(cfg) else NULL),
  tar_target(windows, monthly_windows(cfg$temporal$study_window)),
  # Not a "file" target: the DuckDB file changes during collection, and hashing it would
  # invalidate every downstream target on each run.
  tar_target(db_ready, {
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE)); db_init(con); cfg$paths$db
  }),
  tar_target(collected, {
    if (cfg$project$stage == "feasibility") return(NULL)   # pilot only via scripts/02
    force(db_ready)
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    tjdft_collect_if_missing(cfg, con, windows$from, windows$to)
  }, pattern = map(windows), iteration = "list"),
  tar_target(mentions, {
    if (cfg$project$stage == "feasibility") return(NULL)
    force(collected); force(harm_types_file)
    con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    per <- extract_decisions_db(con, write_mentions = TRUE, log = message)
    list(extractor = extractor_version(), decisions = nrow(per),
         n_mentions = DBI::dbGetQuery(con, "SELECT count(*) n FROM value_mentions")$n)
  })
)
