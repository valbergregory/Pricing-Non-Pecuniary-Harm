# 05 — D5 annotation design (Background Job; run ONCE, after the author ratifies D5).
# Draws the seeded stratified sample of acórdãos for blind human validation of the
# extractor: n_total items in n_rounds rounds + a blind re-annotation subset, with
# strata = panel type (D8: Turmas Cíveis vs Turmas Recursais) x year x extractor-found-value.
#
# Reads : data/processed/pnph.duckdb (table `acordaos`, read-only), config `annotation`.
# Writes (git-ignored, under annotation$dir = data/interim/annotation/):
#   planilhas/rodada_<k>.csv        blank worksheets (';', UTF-8) — the annotator fills these
#   fichas/<item_id>.txt            decision text per item (ementa + dispositivo + inteiro teor)
#   chave_NAO_ABRIR.csv             key: item -> uuid, stratum, weight, frozen extractor output
#   extractor_snapshot.rds          per-decision extractor output on the whole frame (cache)
# Writes (versioned, aggregate only): outputs/diagnostics/05_annotation_design.csv,
#   outputs/logs/05_annotation_sample.log
# Duration: extractor over ~78k decisions ~20-60 min the first time (cached afterwards).
# Safety: refuses to run if worksheets already exist (they may hold annotations), unless
#   Sys.setenv(PNPH_OVERWRITE_ANNOTATION = "1") is set explicitly.
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
A <- cfg$annotation
log <- make_logger("outputs/logs/05_annotation_sample.log")
adir <- A$dir
ws_dir <- file.path(adir, "planilhas"); fi_dir <- file.path(adir, "fichas")
if (length(list.files(ws_dir, pattern = "\\.csv$")) > 0 && Sys.getenv("PNPH_OVERWRITE_ANNOTATION") != "1")
  stop("Worksheets already exist in ", ws_dir, ". They may contain annotations; not overwriting. ",
       "Set PNPH_OVERWRITE_ANNOTATION=1 only if you really want a new draw.")
for (d in c(adir, ws_dir, fi_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stopifnot(grepl("^data/", adir))   # must stay under the git-ignored data/ tree

con <- db_connect(cfg, read_only = TRUE); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
meta <- DBI::dbGetQuery(con, "SELECT uuid, base, subbase, orgao_julgador, turma_recursal, data_julgamento
                               FROM acordaos WHERE base = 'acordaos'")
log(sprintf("acordaos (base = acordaos): %d", nrow(meta)))

# Extractor snapshot (frozen predictions; cache keyed by the extractor version) ---------
ver <- extractor_version()
snap_file <- file.path(adir, "extractor_snapshot.rds")
snap <- if (file.exists(snap_file)) readRDS(snap_file) else NULL
if (is.null(snap) || !identical(attr(snap, "extractor"), ver) || !all(meta$uuid %in% snap$uuid)) {
  log(sprintf("running extractor %s over %d decisions (chunks of 2000)", ver, nrow(meta)))
  snap <- extract_decisions_db(con, uuids = sort(meta$uuid), log = log)
  ht <- load_harm_types()
  em <- DBI::dbGetQuery(con, "SELECT uuid, ementa FROM acordaos WHERE base = 'acordaos'")
  snap$harm_type <- classify_harm_vec(em$ementa[match(snap$uuid, em$uuid)], ht)
  attr(snap, "extractor") <- ver
  saveRDS(snap, snap_file)
} else log(sprintf("using cached extractor snapshot %s", ver))

# Sampling frame ------------------------------------------------------------------------
frame <- merge(meta, snap, by = "uuid")
frame$stratum <- annotation_stratum(frame$orgao_julgador, frame$subbase, frame$turma_recursal)
frame$year <- format(as.Date(frame$data_julgamento), "%Y")
frame$found <- !is.na(frame$award_any)
log(paste("strata in DB:", paste(names(table(frame$stratum)), table(frame$stratum), sep = "=", collapse = ", ")))
frame <- frame[frame$stratum %in% unlist(A$strata_include), ]
log(sprintf("sampling frame (%s): %d decisions", paste(unlist(A$strata_include), collapse = "+"), nrow(frame)))

design <- draw_annotation_design(frame[, c("uuid", "stratum", "year", "found")],
                                 n_total = A$n_total, n_rounds = A$n_rounds, n_reannot = A$n_reannot,
                                 reannot_from_rounds = unlist(A$reannot_from_rounds), seed = cfg$project$seed)
key <- merge(design, frame[, c("uuid", "orgao_julgador", "data_julgamento", "award_ementa", "award_any",
                               "award_role", "harm_type")], by = "uuid")
key$extractor <- ver; key$seed <- cfg$project$seed; key$created_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
key <- key[order(key$round, match(key$item_id, design$item_id)), ]
utils::write.csv(key, file.path(adir, "chave_NAO_ABRIR.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# Text sheets and worksheets ----------------------------------------------------------------
u <- unique(key$uuid)
txt <- DBI::dbGetQuery(con, sprintf("SELECT uuid, decisao, ementa, inteiro_teor FROM acordaos WHERE uuid IN (%s)",
                                    paste(rep("?", length(u)), collapse = ", ")), params = as.list(u))
for (i in seq_len(nrow(key))) {
  t <- txt[txt$uuid == key$uuid[i], ]
  writeLines(format_ficha(key$item_id[i], key$orgao_julgador[i], key$data_julgamento[i], t$decisao, t$ementa, t$inteiro_teor),
             file.path(fi_dir, paste0(key$item_id[i], ".txt")), useBytes = TRUE)
}
for (r in sort(unique(key$round))) {
  items <- key[key$round == r, ]
  name <- if (r > A$n_rounds) "rodada_R_reanotacao.csv" else sprintf("rodada_%d.csv", r)
  write_worksheet(blank_worksheet(items, fi_dir), file.path(ws_dir, name))
  log(sprintf("worksheet %s: %d items", name, nrow(items)))
}

# Aggregate design table (no uuids, no text) -----------------------------------------------
cells <- unique(design[!design$is_reannot, c("stratum", "year", "found", "N_h", "n_h")])
cells <- cells[order(cells$stratum, cells$year, cells$found), ]
utils::write.csv(cells, "outputs/diagnostics/05_annotation_design.csv", row.names = FALSE)
log(sprintf("design: %d cells, n = %d (+%d re-annotation), seed %s, extractor %s",
            nrow(cells), sum(!design$is_reannot), sum(design$is_reannot), cfg$project$seed, ver))
log("done — see docs/COMO_ANOTAR.md")
