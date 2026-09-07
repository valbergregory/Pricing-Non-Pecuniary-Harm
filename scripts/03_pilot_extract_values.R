# 03 — Pilot extraction diagnostics (Background Job or Console). Reads the
# DuckDB filled by 02, runs the rule-based extractor + harm classifier, and
# writes coverage diagnostics. NOT a result: it measures whether extraction is
# feasible and where it fails, to design the annotation round (D5).
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
log <- make_logger("outputs/logs/03_pilot_extract_values.log")
con <- db_connect(cfg); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ac <- DBI::dbGetQuery(con, "SELECT uuid, base, subbase, classe_cnj, orgao_julgador, relator,
                             data_julgamento, decisao, ementa, inteiro_teor FROM acordaos")
log(sprintf("acordaos loaded: %d", nrow(ac)))

men <- extract_from_acordaos(ac)
log(sprintf("amount mentions: %d (ementa %d, full text %d)", nrow(men),
            sum(men$section == "ementa"), sum(men$section == "inteiro_teor")))
DBI::dbExecute(con, "DELETE FROM value_mentions")
db_upsert(con, "value_mentions", men)

# Per-decision diagnostics -------------------------------------------------------
per <- do.call(rbind, lapply(split(men, men$uuid), function(m) {
  data.frame(uuid = m$uuid[1],
             n_mentions = nrow(m),
             n_ementa = sum(m$section == "ementa"),
             n_moral = sum(m$is_moral),
             award_ementa = pick_award(m[m$section == "ementa", ]),
             award_any = pick_award(m), stringsAsFactors = FALSE)
}))
diag <- merge(ac[, c("uuid", "base", "subbase", "classe_cnj", "orgao_julgador", "relator",
                     "data_julgamento", "ementa")], per, by = "uuid", all.x = TRUE)
diag$n_mentions[is.na(diag$n_mentions)] <- 0L
diag$harm_type <- classify_harm_vec(diag$ementa)
diag$ementa <- NULL

cov <- data.frame(
  metric = c("decisions", "with any R$ mention", "with R$ in ementa", "with moral-context mention",
             "award picked from ementa", "award picked from any section"),
  n = c(nrow(diag), sum(diag$n_mentions > 0), sum(diag$n_ementa > 0, na.rm = TRUE),
        sum(diag$n_moral > 0, na.rm = TRUE), sum(!is.na(diag$award_ementa)), sum(!is.na(diag$award_any))))
cov$share <- round(cov$n / nrow(diag), 3)
print(cov); for (i in seq_len(nrow(cov))) log(sprintf("%-32s %5d  %.1f%%", cov$metric[i], cov$n[i], 100 * cov$share[i]))
utils::write.csv(cov, "outputs/diagnostics/03_extraction_coverage.csv", row.names = FALSE)

roles <- as.data.frame(table(section = men$section, role = men$role, moral = men$is_moral))
utils::write.csv(roles[roles$Freq > 0, ], "outputs/diagnostics/03_role_distribution.csv", row.names = FALSE)

ht <- as.data.frame(table(harm_type = diag$harm_type)); ht <- ht[order(-ht$Freq), ]
utils::write.csv(ht, "outputs/diagnostics/03_harm_type_distribution.csv", row.names = FALSE)
log(paste("harm types:", paste(ht$harm_type, ht$Freq, sep = "=", collapse = ", ")))

# Distribution of picked awards (diagnostic only; unvalidated extractor)
a <- diag$award_any[!is.na(diag$award_any)]
if (length(a)) {
  qs <- stats::quantile(a, c(.1, .25, .5, .75, .9))
  log(sprintf("picked awards (UNVALIDATED): n=%d median=%.0f p10=%.0f p90=%.0f", length(a), qs[3], qs[1], qs[5]))
  utils::write.csv(data.frame(q = names(qs), brl = unname(qs)), "outputs/diagnostics/03_award_quantiles_unvalidated.csv", row.names = FALSE)
}

# Annotation sample for round 1 (D5): 60 decisions stratified by whether an award was picked
set.seed(cfg$project$seed)
strata <- split(diag$uuid, !is.na(diag$award_any))
samp <- unlist(lapply(strata, function(u) sample(u, min(30, length(u)))))
ann <- diag[diag$uuid %in% samp, c("uuid", "base", "orgao_julgador", "data_julgamento", "harm_type", "award_ementa", "award_any")]
ann$award_brl_human <- NA; ann$award_role_human <- NA; ann$harm_type_human <- NA; ann$notes <- NA
utils::write.csv(ann, "outputs/diagnostics/03_annotation_sample_round1.csv", row.names = FALSE)
utils::write.csv(diag, "outputs/diagnostics/03_per_decision_diagnostics.csv", row.names = FALSE)
log(sprintf("annotation sample written: %d decisions", nrow(ann)))
log("done")
