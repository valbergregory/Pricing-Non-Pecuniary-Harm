# 06 — D5 validity report (Console; run after each annotation round).
# Compares the human annotations (filled worksheets) with the extractor and computes
# precision / recall / F1 per field, by round and by stratum, and the intra-rater kappa
# on the blind re-annotation subset. Only rows already annotated (decide_dano_moral
# filled) are used; partial rounds are reported as such.
#
# Predictions: "frozen" = extractor output stored in the key at sampling time (05);
# "current" = the extractor in R/ now, re-run on the annotated decisions (needs the
# DuckDB file). Both are reported when the DB is available; the threshold check
# (annotation$f1_threshold, research_protocol.md §5) is printed for both.
#
# Reads : annotation$dir/{chave_NAO_ABRIR.csv, planilhas/*.csv}, pnph.duckdb (optional)
# Writes (versioned, aggregate only): outputs/diagnostics/06_validity_metrics.csv,
#   06_validity_by_class.csv, 06_intrarater_kappa.csv, 06_validity_report.md, log
# Writes (git-ignored): annotation$dir/divergencias.csv (item-level errors, for debugging)
for (f in list.files("R", full.names = TRUE)) source(f)
cfg <- load_config(); ensure_dirs(cfg)
A <- cfg$annotation
log <- make_logger("outputs/logs/06_annotation_validity.log")
adir <- A$dir; tol <- A$value_tolerance_brl; thr <- A$f1_threshold
set.seed(cfg$project$seed)

key <- utils::read.csv(file.path(adir, "chave_NAO_ABRIR.csv"), stringsAsFactors = FALSE, fileEncoding = "UTF-8")
files <- list.files(file.path(adir, "planilhas"), pattern = "\\.csv$", full.names = TRUE)
ws <- do.call(rbind, lapply(files, function(p) read_worksheet(p)[, WORKSHEET_COLS]))
ht_ids <- vapply(load_harm_types(), function(t) t$id, character(1))
probs <- check_worksheet(ws, ht_ids)
if (nrow(probs)) {
  print(probs)
  stop(nrow(probs), " invalid cells in the worksheets (see above and docs/COMO_ANOTAR.md); fix and re-run")
}
ann <- normalise_annotations(ws)
ann <- merge(ann, key[, c("item_id", "uuid", "stratum", "year", "found", "weight", "is_reannot", "orig_item_id",
                          "award_any", "award_role", "harm_type")],
             by = "item_id", suffixes = c("", "_frozen"))
names(ann)[names(ann) == "award_any"] <- "award_frozen"
names(ann)[names(ann) == "award_role_frozen"] <- "role_frozen"
log(sprintf("annotated items: %d main (of %d), %d re-annotation (of %d)",
            sum(!ann$is_reannot), sum(!key$is_reannot), sum(ann$is_reannot), sum(key$is_reannot)))
main <- ann[!ann$is_reannot, ]
if (nrow(main) == 0) stop("no annotated items yet")

# Current extractor on the annotated decisions (if the DB is reachable) --------------------
preds <- list(frozen = data.frame(uuid = main$uuid, award = main$award_frozen, role = main$role_frozen,
                                  harm = main$harm_type_frozen, stringsAsFactors = FALSE))
if (file.exists(cfg$paths$db) && requireNamespace("duckdb", quietly = TRUE)) {
  con <- db_connect(cfg, read_only = TRUE); on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  cur <- extract_decisions_db(con, uuids = main$uuid)
  em <- DBI::dbGetQuery(con, sprintf("SELECT uuid, ementa FROM acordaos WHERE uuid IN (%s)",
                                     paste(rep("?", nrow(main)), collapse = ", ")), params = as.list(main$uuid))
  cur$harm <- classify_harm_vec(em$ementa[match(cur$uuid, em$uuid)])
  preds$current <- data.frame(uuid = cur$uuid, award = cur$award_any, role = cur$award_role, harm = cur$harm)
  log(sprintf("current extractor %s re-run on %d decisions", extractor_version(), nrow(cur)))
} else log("DuckDB not available: reporting frozen predictions only")

metrics <- list(); by_class <- list(); diverg <- list()
groups <- c(list(todos = rep(TRUE, nrow(main))),
            setNames(lapply(sort(unique(main$round)), function(r) main$round == r), paste0("rodada_", sort(unique(main$round)))),
            setNames(lapply(sort(unique(main$stratum)), function(s) main$stratum == s), paste0("estrato_", sort(unique(main$stratum)))),
            list(sem_multiplos_valores = is.na(main$multiplos_valores) | main$multiplos_valores != "S"))
for (pn in names(preds)) {
  p <- preds[[pn]][match(main$uuid, preds[[pn]]$uuid), ]
  for (g in names(groups)) {
    i <- groups[[g]]
    v <- value_prf(p$award[i], main$award_brl[i], tol)
    ci <- if (g == "todos") bootstrap_f1(p$award[i], main$award_brl[i], tol, A$bootstrap_reps) else c(lo = NA, hi = NA)
    both <- i & !is.na(p$award) & !is.na(main$award_brl)
    ae <- abs(p$award[both] - main$award_brl[both])
    metrics[[length(metrics) + 1]] <- data.frame(predictions = pn, group = g, field = "valor_final",
      n = v[["n"]], tp = v[["tp"]], fp = v[["fp"]], fn = v[["fn"]], tn = v[["tn"]],
      precision = v[["precision"]], recall = v[["recall"]], f1 = v[["f1"]], f1_lo95 = ci[["lo"]], f1_hi95 = ci[["hi"]],
      median_abs_error = if (length(ae)) stats::median(ae) else NA_real_, accuracy = NA_real_)
    if (g == "todos") {
      vw <- value_prf(p$award[i], main$award_brl[i], tol, w = main$weight[i])
      metrics[[length(metrics) + 1]] <- data.frame(predictions = pn, group = "todos_ponderado_desenho", field = "valor_final",
        n = vw[["n"]], tp = vw[["tp"]], fp = vw[["fp"]], fn = vw[["fn"]], tn = vw[["tn"]],
        precision = vw[["precision"]], recall = vw[["recall"]], f1 = vw[["f1"]], f1_lo95 = NA, f1_hi95 = NA,
        median_abs_error = NA, accuracy = NA)
    }
    for (fld in c("papel_valor", "tipo_lesao")) {
      cp <- if (fld == "papel_valor") class_prf(p$role[i & both], main$award_role[i & both]) else class_prf(p$harm[i], main$harm_type[i])
      metrics[[length(metrics) + 1]] <- data.frame(predictions = pn, group = g, field = fld, n = cp$n,
        tp = NA, fp = NA, fn = NA, tn = NA, precision = NA, recall = NA, f1 = cp$macro_f1, f1_lo95 = NA, f1_hi95 = NA,
        median_abs_error = NA, accuracy = cp$accuracy)
      if (g == "todos" && nrow(cp$per_class %||% data.frame())) by_class[[length(by_class) + 1]] <- cbind(predictions = pn, field = fld, cp$per_class)
    }
  }
  wrong <- !(!is.na(p$award) & !is.na(main$award_brl) & abs(p$award - main$award_brl) <= tol) & !(is.na(p$award) & is.na(main$award_brl))
  if (any(wrong)) diverg[[pn]] <- data.frame(predictions = pn, item_id = main$item_id[wrong], uuid = main$uuid[wrong],
                                               human = main$award_brl[wrong], extractor = p$award[wrong],
                                               human_role = main$papel_valor[wrong], extractor_role = p$role[wrong])
}
metrics <- do.call(rbind, metrics)
utils::write.csv(metrics, "outputs/diagnostics/06_validity_metrics.csv", row.names = FALSE)
if (length(by_class)) utils::write.csv(do.call(rbind, by_class), "outputs/diagnostics/06_validity_by_class.csv", row.names = FALSE)
if (length(diverg)) utils::write.csv(do.call(rbind, diverg), file.path(adir, "divergencias.csv"), row.names = FALSE)

# Intra-rater agreement on the blind re-annotation ----------------------------------------
re <- ann[ann$is_reannot, ]
kap <- NULL
if (nrow(re)) {
  orig <- ann[match(re$orig_item_id, ann$item_id), ]
  ok <- !is.na(orig$item_id); re <- re[ok, ]; orig <- orig[ok, ]
  fields <- c(decide_dano_moral = "decide_dano_moral", tem_valor = NA, valor_final = "award_brl", papel_valor = "papel_valor",
              tipo_lesao = "harm_type", resultado = "outcome", valor_origem = "first_instance_brl")
  kap <- do.call(rbind, lapply(names(fields), function(nm) {
    a <- if (nm == "tem_valor") !is.na(orig$award_brl) else orig[[fields[[nm]]]]
    b <- if (nm == "tem_valor") !is.na(re$award_brl) else re[[fields[[nm]]]]
    k <- cohen_kappa(a, b); data.frame(field = nm, n = k[["n"]], agreement = k[["agreement"]], kappa = k[["kappa"]])
  }))
  utils::write.csv(kap, "outputs/diagnostics/06_intrarater_kappa.csv", row.names = FALSE)
  log(sprintf("re-annotated pairs: %d", nrow(re)))
}

# Report (generated; numbers only, no interpretation) -------------------------------------
fmt <- function(x) ifelse(is.na(x), "—", sprintf("%.3f", x))
tot <- metrics[metrics$group == "todos" & metrics$field == "valor_final", ]
rep <- c("# Relatório de validade do extrator (D5) — GERADO por scripts/06_annotation_validity.R",
         "", sprintf("Gerado em %s; extrator atual %s; semente %s; tolerância de valor R$ %s.",
                     format(Sys.time(), "%Y-%m-%d %H:%M"), extractor_version(), cfg$project$seed, format(tol)),
         sprintf("Itens anotados: %d de %d (amostra principal); reanotação: %d de %d.",
                 nrow(main), sum(!key$is_reannot), nrow(re), sum(key$is_reannot)),
         if (nrow(main) < sum(!key$is_reannot)) "**Amostra incompleta: métricas parciais.**" else "",
         "", "## Valor final de dano moral", "",
         "| predições | n | VP | FP | FN | precisão | recall | F1 | IC95% F1 | erro abs. mediano (R$) | limiar F1 |",
         "|---|---|---|---|---|---|---|---|---|---|---|",
         sprintf("| %s | %d | %d | %d | %d | %s | %s | %s | [%s; %s] | %s | %s |", tot$predictions, as.integer(tot$n), as.integer(tot$tp),
                 as.integer(tot$fp), as.integer(tot$fn), fmt(tot$precision), fmt(tot$recall), fmt(tot$f1), fmt(tot$f1_lo95),
                 fmt(tot$f1_hi95), ifelse(is.na(tot$median_abs_error), "—", format(round(tot$median_abs_error, 2))),
                 ifelse(is.na(tot$f1), "—", ifelse(tot$f1 >= thr, sprintf("atinge (>= %.2f)", thr), sprintf("não atinge (< %.2f)", thr)))),
         "", "## Todos os campos, por grupo", "",
         "| predições | grupo | campo | n | F1 (macro p/ categóricos) | acurácia |", "|---|---|---|---|---|---|",
         sprintf("| %s | %s | %s | %s | %s | %s |", metrics$predictions, metrics$group, metrics$field,
                 format(round(metrics$n, 1)), fmt(metrics$f1), fmt(metrics$accuracy)),
         "", "## Concordância intra-avaliador (reanotação cega)", "",
         if (is.null(kap)) "Reanotação ainda não preenchida." else
           c("| campo | n | concordância | kappa de Cohen |", "|---|---|---|---|",
             sprintf("| %s | %d | %s | %s |", kap$field, as.integer(kap$n), fmt(kap$agreement), fmt(kap$kappa))),
         "", "Definições: VP = valor do extrator igual ao humano (± tolerância); valor errado conta como FP e FN;",
         "papel_valor comparado só onde ambos têm valor (FIXADO e MANTIDO = `fixed`); tipo_lesao = classificador por regras;",
         "`todos_ponderado_desenho` pondera pelo inverso da fração amostral de cada célula (estrato × ano × achou-valor).")
writeLines(rep, "outputs/diagnostics/06_validity_report.md", useBytes = TRUE)
print(tot[, c("predictions", "n", "precision", "recall", "f1", "f1_lo95", "f1_hi95")])
log("done — outputs/diagnostics/06_validity_report.md")
