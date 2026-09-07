# 00 — Environment audit (Console). Writes outputs/logs/00_environment.log
source("R/01_config.R")
cfg <- load_config(); ensure_dirs(cfg)
log <- make_logger("outputs/logs/00_environment.log")

log("R ", getRversion(), " | platform ", R.version$platform)
log("libPaths: ", paste(.libPaths(), collapse = " ; "))
log("renv active: ", file.exists("renv/activate.R"), " | lockfile: ", file.exists("renv.lock"))

pkgs <- c("httr2", "jsonlite", "yaml", "digest", "stringi", "duckdb", "DBI", "data.table",
          "testthat", "targets", "tarchetypes", "lme4", "fixest", "sandwich", "quantreg",
          "boot", "modelsummary", "ggplot2", "quarto", "knitr", "rmarkdown")
have <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
log("packages present: ", paste(names(have)[have], collapse = ", "))
log("packages MISSING: ", if (any(!have)) paste(names(have)[!have], collapse = ", ") else "none")

q <- Sys.which("quarto"); log("quarto CLI: ", if (nzchar(q)) q else "NOT FOUND")
g <- Sys.which("git");    log("git: ", if (nzchar(g)) g else "NOT FOUND")
log("DATAJUD_APIKEY in .Renviron: ", nzchar(Sys.getenv("DATAJUD_APIKEY")))
log("done")
