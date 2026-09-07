# Project configuration helpers ---------------------------------------------
# Usage: source("R/01_config.R"); cfg <- load_config()

load_config <- function(path = "config/config.yml") {
  stopifnot(file.exists(path))
  yaml::read_yaml(path)
}

# Absolute-safe path builder relative to project root
proj_path <- function(...) file.path(...)

ensure_dirs <- function(cfg) {
  dirs <- c(cfg$paths$raw, cfg$paths$interim, cfg$paths$processed,
            cfg$paths$metadata, "outputs/logs", "outputs/diagnostics",
            "outputs/tables", "outputs/figures")
  for (d in dirs) if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  invisible(dirs)
}

# Simple timestamped logger writing to console and to a file
make_logger <- function(file) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  function(...) {
    line <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(..., collapse = ""))
    cat(line, "\n")
    cat(line, "\n", file = file, append = TRUE)
    invisible(line)
  }
}

sha256_file <- function(path) digest::digest(path, algo = "sha256", file = TRUE)

# Public DataJud key: read from .Renviron, else fetch from the CNJ wiki page.
datajud_key <- function() {
  k <- Sys.getenv("DATAJUD_APIKEY", unset = "")
  if (nzchar(k)) return(k)
  page <- tryCatch(
    httr2::request("https://datajud-wiki.cnj.jus.br/api-publica/acesso") |>
      httr2::req_timeout(60) |> httr2::req_perform() |> httr2::resp_body_string(),
    error = function(e) "")
  txt <- gsub("<[^>]+>", " ", page)                 # strip HTML tags
  txt <- gsub("&nbsp;|\\s+", " ", txt)
  m <- regmatches(txt, regexpr("APIKey\\s*:?\\s*([A-Za-z0-9+/=]{40,})", txt, perl = TRUE))
  if (length(m) == 0) return(NA_character_)
  sub("^APIKey\\s*:?\\s*", "", m)
}
