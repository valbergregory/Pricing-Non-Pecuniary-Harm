# DuckDB helpers ------------------------------------------------------------

db_connect <- function(cfg, read_only = FALSE) {
  dir.create(dirname(cfg$paths$db), showWarnings = FALSE, recursive = TRUE)
  DBI::dbConnect(duckdb::duckdb(), dbdir = cfg$paths$db, read_only = read_only)
}

db_init <- function(con, schema = "sql/schema.sql") {
  stmts <- strsplit(paste(readLines(schema, warn = FALSE), collapse = "\n"), ";")[[1]]
  stmts <- trimws(gsub("--[^\n]*", "", stmts))
  for (s in stmts[nzchar(stmts)]) DBI::dbExecute(con, s)
  invisible(TRUE)
}

# Upsert helper: DuckDB supports INSERT OR REPLACE for tables with a primary key
db_upsert <- function(con, table, df) {
  if (nrow(df) == 0) return(invisible(0L))
  tmp <- paste0("tmp_", table, "_", as.integer(Sys.time()))
  duckdb::duckdb_register(con, tmp, df)
  on.exit(duckdb::duckdb_unregister(con, tmp), add = TRUE)
  cols <- paste(DBI::dbQuoteIdentifier(con, names(df)), collapse = ", ")
  DBI::dbExecute(con, sprintf("INSERT OR REPLACE INTO %s (%s) SELECT %s FROM %s",
                              table, cols, cols, tmp))
}

db_log_collection <- function(con, source, url, body, page, n, raw_file) {
  df <- data.frame(collected_at = Sys.time(), source = source, request_url = url,
                   request_body = body, page = as.integer(page), n_records = as.integer(n),
                   raw_file = raw_file, sha256 = sha256_file(raw_file),
                   stringsAsFactors = FALSE)
  DBI::dbAppendTable(con, "collection_log", df)
  invisible(df)
}
