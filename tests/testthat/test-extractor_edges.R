# Edge cases of the value extractor, harm classifier, deflator and phase-1 helpers
# (synthetic snippets written for the tests; no real decision text, no names).

test_that("plain-digit amounts are not truncated (fix 2026-10-02)", {
  m <- extract_amounts("Danos morais fixados em R$ 10000,00.")
  expect_equal(m$amount_brl, 10000)
  expect_equal(extract_amounts("compensação por danos morais de R$ 5000")$amount_brl, 5000)
})

test_that("non-breaking or repeated spaces after R$ are accepted", {
  expect_equal(extract_amounts("danos morais fixados em R$ 5.000,00.")$amount_brl, 5000)
  expect_equal(extract_amounts("danos morais fixados em R$  7.500,00.")$amount_brl, 7500)
  expect_equal(parse_brl("R$ 1.234,56"), 1234.56)
})

test_that("large amounts and amounts at the end of text parse", {
  expect_equal(parse_brl("R$ 1.000.000,00"), 1e6)
  m <- extract_amounts("Indenização por dano moral mantida em R$ 1.000.000,00")
  expect_equal(m$amount_brl, 1e6); expect_equal(m$role, "fixed")
})

test_that("decimal points inside amounts do not split clauses", {
  txt <- "Danos materiais de R$ 1.200,00. Danos morais reduzidos para R$ 3.000,00."
  m <- extract_amounts(txt)
  expect_equal(m$role, c("exclude_material", "reduced"))
  expect_equal(pick_award(m), 3000); expect_equal(pick_award_role(m), "reduced")
})

test_that("value of the case is excluded and claimed amounts are not awards", {
  m <- extract_amounts("Atribuído à causa o valor da causa de R$ 40.000,00. A autora pleiteia danos morais de R$ 20.000,00.")
  expect_equal(m$role, c("exclude_case_val", "claimed"))
  expect_true(is.na(pick_award(m))); expect_true(is.na(pick_award_role(m)))
})

test_that("summarise_mentions keeps decisions without mentions", {
  df <- data.frame(uuid = c("a", "b"), ementa = c("Danos morais arbitrados em R$ 2.000,00.", "Sem valor."),
                   inteiro_teor = c(NA, NA), stringsAsFactors = FALSE)
  s <- summarise_mentions(extract_from_acordaos(df), df$uuid)
  expect_equal(s$uuid, c("a", "b")); expect_equal(s$n_mentions, c(1L, 0L))
  expect_equal(s$award_any, c(2000, NA)); expect_equal(s$award_role, c("fixed", NA))
  e <- summarise_mentions(extract_from_acordaos(df[2, ]), "b")
  expect_equal(nrow(e), 1)
})

test_that("harm classifier: priority, accents, case and empty input", {
  ht <- load_harm_types(file.path(root, "config/harm_types.yml"))
  expect_equal(classify_harm("ÓBITO DO PACIENTE. PLANO DE SAÚDE.", ht), "wrongful_death")   # first in dictionary wins
  expect_equal(classify_harm("Negativação indevida no SERASA", ht), "credit_listing")
  expect_equal(classify_harm("COBRANÇA INDEVIDA. FALHA NA PRESTAÇÃO DO SERVIÇO.", ht), "consumer_service")
  expect_equal(classify_harm("golpeado", ht), "other")                                       # word boundary
  expect_equal(classify_harm(NA, ht), "other"); expect_equal(classify_harm(character(), ht), "other")
  expect_equal(classify_harm_vec(c("ATRASO DE VOO", NA), ht), c("air_travel", "other"))
})

test_that("deflator and minimum-wage multiples use the configured base month (D4)", {
  ipca <- data.frame(ref_month = as.Date(c("2025-01-01", "2025-02-01", "2025-03-01")), pct = c(1, 1, 1))
  ipca$index_value <- cumprod(1 + ipca$pct / 100)
  expect_equal(deflate_brl(100, as.Date("2025-01-15"), ipca, as.Date("2025-03-01")), 100 * 1.01^2)
  expect_error(deflate_brl(100, as.Date("2025-01-01"), ipca, as.Date("2025-12-01")), "base month")
  cfg <- list(temporal = list(price_base = "2025-03", report_sm_multiples = TRUE))
  expect_equal(price_base_date(cfg), as.Date("2025-03-01"))
  expect_error(price_base_date(list(temporal = list(price_base = "dez/2025"))), "YYYY-MM")
  sm <- data.frame(ref_month = as.Date(c("2025-01-01", "2025-02-01", "2025-03-01")), sm_brl = 1500)
  df <- data.frame(award_brl = c(3000, 1500), data_julgamento = as.Date(c("2025-01-10", "2025-03-20")))
  out <- add_real_values(df, cfg, ipca, sm)
  expect_equal(out$award_sm, c(2, 1)); expect_equal(out$award_real[2], 1500)
  expect_false("award_sm" %in% names(add_real_values(df, list(temporal = list(price_base = "2025-03")), ipca)))
  expect_error(add_real_values(df, cfg, ipca, NULL), "minimum-wage")
})

test_that("monthly_windows covers the study period without gaps", {
  w <- monthly_windows(c("2015-01-01", "2025-12-31"))
  expect_equal(nrow(w), 132)
  expect_equal(w$to[w$from == "2016-02-01"], "2016-02-29")
  expect_equal(tail(w$to, 1), "2025-12-31")
  expect_true(all(as.Date(w$from[-1]) == as.Date(w$to[-nrow(w)]) + 1))
})

test_that("config carries the pending-decision switches", {
  cfg <- load_config(file.path(root, "config/config.yml"))
  expect_match(cfg$temporal$price_base, "^\\d{4}-\\d{2}$")
  expect_true(is.logical(cfg$temporal$report_sm_multiples))
  expect_equal(cfg$annotation$n_total, 300); expect_equal(cfg$annotation$n_reannot, 60)
  expect_equal(cfg$annotation$f1_threshold, 0.9)
  expect_match(cfg$annotation$dir, "^data/")   # git-ignored tree
})
