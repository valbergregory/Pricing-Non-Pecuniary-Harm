# D5 annotation design and validity metrics — synthetic fixtures only (no decision text).

synthetic_frame <- function(n_civ = 400, n_rec = 300, years = 2015:2025, seed = 1) {
  set.seed(seed)
  n <- n_civ + n_rec
  data.frame(uuid = sprintf("u%05d", seq_len(n)),
             stratum = rep(c("civel", "recursal"), c(n_civ, n_rec)),
             year = as.character(sample(years, n, TRUE)),
             found = stats::runif(n) < 0.5, stringsAsFactors = FALSE)
}

test_that("annotation_stratum follows D8 (Recursais vs Cíveis vs others)", {
  s <- annotation_stratum(c("PRIMEIRA TURMA RECURSAL", "1ª TURMA CÍVEL", "1ª CÂMARA CÍVEL", "1ª TURMA CRIMINAL", "X", NA),
                          subbase = c("acordaos", "acordaos", "acordaos", "acordaos", "acordaos-tr", "acordaos"))
  expect_equal(s, c("recursal", "civel", "civel", "outro", "recursal", "outro"))
  expect_equal(annotation_stratum("2ª TURMA CIVEL", turma_recursal = TRUE), "recursal")
})

test_that("allocate_sample sums to n, respects minimum and caps", {
  N <- c(a = 1000, b = 10, c = 1, d = 0)
  a <- allocate_sample(N, 50)
  expect_equal(sum(a), 50)
  expect_false("d" %in% names(a))
  expect_true(all(a >= 1)); expect_true(all(a <= N[names(a)]))
  expect_equal(a[["c"]], 1)
  expect_error(allocate_sample(c(a = 3, b = 2), 10), "fewer than")
  expect_error(allocate_sample(setNames(rep(5, 5), letters[1:5]), 4), "exceed")
  expect_equal(sum(allocate_sample(c(a = 7, b = 3), 10)), 10)    # census of a tiny frame
})

test_that("draw_annotation_design is seeded, stratified, balanced and blind", {
  fr <- synthetic_frame()
  d1 <- draw_annotation_design(fr, 300, 3, 60, 1, seed = 20260905)
  d2 <- draw_annotation_design(fr, 300, 3, 60, 1, seed = 20260905)
  expect_identical(d1, d2)                                        # reproducible
  main <- d1[!d1$is_reannot, ]; re <- d1[d1$is_reannot, ]
  expect_equal(nrow(main), 300); expect_equal(nrow(re), 60)
  expect_false(anyDuplicated(main$uuid) > 0)
  expect_equal(as.vector(table(main$round)), c(100, 100, 100))
  expect_equal(unique(re$round), 4L)
  expect_true(all(re$uuid %in% main$uuid[main$round == 1]))       # re-annotation from round 1
  expect_true(all(re$orig_item_id %in% main$item_id))
  expect_length(intersect(re$item_id, main$item_id), 0)          # new opaque ids
  expect_true(all(grepl("^P-[A-Z2-9]{6}$", d1$item_id)))
  # every non-empty cell represented; weights reconstruct the frame size
  cells <- unique(paste(fr$stratum, fr$year, fr$found))
  expect_setequal(unique(paste(main$stratum, main$year, main$found)), cells)
  expect_equal(sum(main$weight), nrow(fr))
  # each round mirrors the stratum composition (within one item per stratum)
  tab <- table(main$round, main$stratum)
  expect_true(all(apply(tab, 2, function(x) diff(range(x))) <= 1))
  expect_false(identical(d1, draw_annotation_design(fr, 300, 3, 60, 1, seed = 1)))
})

test_that("worksheets round-trip with ';' and Brazilian number formats", {
  items <- data.frame(item_id = c("P-AAAAAA", "P-BBBBBB"), round = 1L)
  ws <- blank_worksheet(items, "fichas")
  expect_equal(names(ws), WORKSHEET_COLS)
  ws$decide_dano_moral <- c("S", "s"); ws$valor_final <- c("R$ 10.000,00", "")
  ws$papel_valor <- c("majorado", "SEM_VALOR"); ws$tipo_lesao <- c("air_travel", "other")
  ws$observacoes <- c("texto; com ponto e vírgula", "ação")
  p <- tempfile(fileext = ".csv"); write_worksheet(ws, p)
  back <- read_worksheet(p)
  expect_equal(back$observacoes, ws$observacoes)
  expect_equal(nrow(check_worksheet(back, c("air_travel", "other"))), 0)
  a <- normalise_annotations(back)
  expect_equal(a$award_brl, c(10000, NA)); expect_equal(a$award_role, c("increased", NA))
  expect_equal(a$harm_type, c("air_travel", "other"))
  # comma-separated file saved by a spreadsheet is also accepted
  utils::write.csv(ws, p, row.names = FALSE); expect_equal(read_worksheet(p)$valor_final, ws$valor_final)
})

test_that("parse_annot_value accepts the formats in COMO_ANOTAR.md", {
  expect_equal(parse_annot_value(c("R$ 10.000,00", "10.000,00", "10000", "10.000", "1.500,5", "500,50", "", "8000.5")),
               c(10000, 10000, 10000, 10000, 1500.5, 500.5, NA, 8000.5))
  expect_warning(parse_annot_value("dez mil"), "unparseable")
})

test_that("check_worksheet flags invalid codes and incoherent rows", {
  ws <- blank_worksheet(data.frame(item_id = c("P-1", "P-2", "P-3"), round = 1L), "f")
  ws$decide_dano_moral <- c("S", "X", "S"); ws$papel_valor <- c("FIXADO", "", "MAJORADO")
  ws$valor_final <- c("5.000,00", "", ""); ws$tipo_lesao <- c("medical", "nope", "")
  pr <- check_worksheet(ws, c("medical", "other"))
  expect_setequal(paste(pr$item_id, pr$column), c("P-2 decide_dano_moral", "P-2 tipo_lesao", "P-3 valor_final"))
})

test_that("value_prf counts a wrong value as FP and FN", {
  pred <- c(1000, 2000, NA, 500, NA); gold <- c(1000, 3000, 700, NA, NA)
  v <- value_prf(pred, gold)
  expect_equal(unname(v[c("tp", "fp", "fn", "tn")]), c(1, 2, 2, 1))
  expect_equal(v[["precision"]], 1 / 3); expect_equal(v[["recall"]], 1 / 3)
  expect_equal(v[["f1"]], 1 / 3)
  expect_equal(value_prf(c(1000.004), c(1000))[["tp"]], 1)            # within 1 cent
  expect_equal(value_prf(c(1, 1), c(1, NA), w = c(2, 3))[["fp"]], 3)   # design weights
  expect_true(is.na(value_prf(NA_real_, NA_real_)[["f1"]]))
})

test_that("class_prf gives per-class and macro F1", {
  cp <- class_prf(c("fixed", "fixed", "reduced", "increased"), c("fixed", "reduced", "reduced", "increased"))
  expect_equal(cp$n, 4); expect_equal(cp$accuracy, 0.75)
  f <- setNames(cp$per_class$f1, cp$per_class$class)
  expect_equal(f[["increased"]], 1); expect_equal(f[["fixed"]], 2 / 3); expect_equal(f[["reduced"]], 2 / 3)
  expect_equal(cp$macro_f1, mean(c(1, 2 / 3, 2 / 3)))
})

test_that("cohen_kappa matches hand computation and treats NA as a category", {
  a <- c("S", "S", "N", "N", "S", "N"); b <- c("S", "N", "N", "N", "S", "S")
  # po = 4/6; pe = (3*3 + 3*3)/36 = 0.5; kappa = (2/3 - 1/2) / (1/2) = 1/3
  expect_equal(cohen_kappa(a, b)[["kappa"]], 1 / 3)
  expect_equal(cohen_kappa(c(1, NA, 3), c(1, NA, 3))[["kappa"]], 1)
  expect_true(is.na(cohen_kappa(c("x", "x"), c("x", "x"))[["kappa"]]))   # no variation
})

test_that("bootstrap_f1 brackets the point estimate", {
  set.seed(1)
  gold <- c(rep(1000, 40), rep(NA, 10)); pred <- gold; pred[1:5] <- 999
  ci <- bootstrap_f1(pred, gold, reps = 300)
  f1 <- value_prf(pred, gold)[["f1"]]
  expect_true(ci[["lo"]] <= f1 && f1 <= ci[["hi"]])
})

test_that("format_ficha hides extractor output and rapporteur", {
  f <- format_ficha("P-AAAAAA", "1ª TURMA CÍVEL", as.Date("2024-03-01"), "NEGAR PROVIMENTO", "Ementa.", NA)
  expect_true(any(grepl("P-AAAAAA", f))); expect_true(any(grepl("(vazio)", f, fixed = TRUE)))
  expect_false(any(grepl("relator|award|extrator", f, ignore.case = TRUE)))
})

test_that("ia_change_rate counts researcher changes to the AI pre-annotation (D5b)", {
  mk <- function(ids, decide, valor, papel, tipo) {
    ws <- as.data.frame(setNames(replicate(length(WORKSHEET_COLS), rep("", length(ids)), simplify = FALSE),
                                 WORKSHEET_COLS), stringsAsFactors = FALSE)
    ws$item_id <- ids; ws$rodada <- "1"; ws$decide_dano_moral <- decide; ws$valor_final <- valor
    ws$papel_valor <- papel; ws$tipo_lesao <- tipo; ws$resultado <- "DESPROVIDO"; ws
  }
  ia <- mk(c("P-1", "P-2", "P-3"), c("S", "S", "N"), c("10.000,00", "5000", ""), c("MANTIDO", "MAJORADO", "SEM_VALOR"),
           c("medical", "air_travel", "other"))
  fin <- mk(c("P-1", "P-2", "P-3"), c("S", "S", ""), c("10000", "6.000,00", ""), c("MANTIDO", "MAJORADO", ""),
            c("medical", "consumer_service", ""))
  r <- ia_change_rate(ia, fin)
  expect_equal(r$n[1], 2)                                            # P-3 not yet annotated
  expect_equal(r$changed[r$field == "award_brl"], 1)                 # 10.000,00 = 10000; 5000 -> 6000
  expect_equal(r$changed[r$field == "harm_type"], 1)
  expect_equal(r$changed[r$field == "papel_valor"], 0)
  expect_equal(r$rate[r$field == "award_brl"], 0.5)
})
