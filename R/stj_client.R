# STJ open-data (CKAN) client ---------------------------------------------------

stj_ckan <- function(cfg, action, ...) {
  httr2::request(paste0(cfg$sources$stj_ckan$base, "/", action)) |>
    httr2::req_url_query(...) |> httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 3) |> httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
}

stj_package_list <- function(cfg) stj_ckan(cfg, "package_list")$result

# Resources of a dataset as a data.frame (name, format, size, url, last_modified)
stj_resources <- function(cfg, dataset_id) {
  r <- stj_ckan(cfg, "package_show", id = dataset_id)$result$resources
  data.frame(name = r$name, format = r$format, size = r$size, url = r$url,
             last_modified = r$last_modified %||% NA, stringsAsFactors = FALSE)
}

# Download a resource to data/raw/stj/<dataset>/ (skips if present), returns path
stj_download <- function(cfg, url, dataset_id, name = basename(url)) {
  dir <- file.path(cfg$paths$raw, "stj", dataset_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dir, name)
  if (!file.exists(dest)) {
    httr2::request(url) |> httr2::req_timeout(600) |> httr2::req_retry(max_tries = 3) |>
      httr2::req_perform(path = dest)
    manifest_add(cfg, paste0("stj/", dataset_id), url, dest, licence = "CC-BY (STJ Dados Abertos)")
  } else {
    mf <- file.path(cfg$paths$metadata, "download_manifest.csv")
    known <- if (file.exists(mf)) utils::read.csv(mf, stringsAsFactors = FALSE)$file else character()
    if (!dest %in% known) manifest_add(cfg, paste0("stj/", dataset_id), url, dest, licence = "CC-BY (STJ Dados Abertos)")
  }
  dest
}

# Íntegras: one day = metadados<yyyymmdd>.json + textos<yyyymmdd>.zip
stj_integras_day <- function(cfg, day, resources = NULL) {
  ds <- cfg$sources$stj_ckan$datasets$integras
  if (is.null(resources)) resources <- stj_resources(cfg, ds)
  key <- format(as.Date(day), "%Y%m%d")
  meta <- resources[grepl(paste0("^metadados", key, "$"), resources$name), ][1, ]
  zip  <- resources[grepl(paste0("^", key, "\\.zip$"), resources$name), ][1, ]
  if (is.na(meta$url) || is.na(zip$url)) return(NULL)
  meta_path <- stj_download(cfg, meta$url, ds, paste0("metadados", key, ".json"))
  zip_path  <- stj_download(cfg, zip$url, ds, paste0("textos", key, ".zip"))
  m <- jsonlite::fromJSON(meta_path, simplifyVector = TRUE)
  names(m) <- iconv(names(m), to = "ASCII//TRANSLIT")
  files <- utils::unzip(zip_path, list = TRUE)$Name
  list(metadata = m, zip = zip_path, n_meta = nrow(m), n_text = length(files))
}

stj_read_text <- function(zip_path, seq_documento) {
  con <- unz(zip_path, paste0(seq_documento, ".txt"), encoding = "UTF-8")
  on.exit(close(con))
  paste(readLines(con, warn = FALSE), collapse = "\n")
}

# Precedentes qualificados: temas.csv — COMMA-separated, quoted multiline fields
# (verified 2026-09-07); data.table::fread parses it correctly (2.400 rows).
stj_temas <- function(cfg) {
  ds <- cfg$sources$stj_ckan$datasets$precedentes
  res <- stj_resources(cfg, ds)
  url <- res$url[tolower(res$name) == "temas.csv"][1]
  path <- stj_download(cfg, url, ds, "temas.csv")
  as.data.frame(data.table::fread(path, encoding = "UTF-8", colClasses = "character"))
}

# Download manifest (policy §4): one row per raw file with URL, date, size, SHA-256, licence
manifest_add <- function(cfg, source, url, path, licence = NA_character_, filters = NA_character_) {
  mf <- file.path(cfg$paths$metadata, "download_manifest.csv")
  row <- data.frame(source = source, url = url, file = path, downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                    size_bytes = file.info(path)$size, sha256 = sha256_file(path),
                    licence = licence, filters = filters, stringsAsFactors = FALSE)
  utils::write.table(row, mf, sep = ",", row.names = FALSE, col.names = !file.exists(mf), append = file.exists(mf))
  invisible(row)
}
