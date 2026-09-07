test_that("parse_brl handles Brazilian formats", {
  expect_equal(parse_brl("R$ 10.000,00"), 10000)
  expect_equal(parse_brl("R$10.000,00"), 10000)
  expect_equal(parse_brl("R$ 1.500"), 1500)
  expect_equal(parse_brl("R$ 500,50"), 500.5)
  expect_equal(parse_brl("R$ 100.000,00"), 1e5)
})

test_that("extract_amounts finds every mention and classifies role", {
  txt <- "Majora-se de R$ 6.000,00 para R$ 10.000,00 o valor da compensação por dano moral, em atenção à proporcionalidade."
  m <- extract_amounts(txt)
  expect_equal(nrow(m), 2)
  expect_equal(m$amount_brl, c(6000, 10000))
  expect_true(all(m$is_moral))
  expect_true(all(m$role == "increased"))
  expect_equal(pick_award(m), 10000)
})

test_that("fees and fines are excluded from award roles", {
  txt <- "Honorários advocatícios fixados em R$ 2.000,00. Multa de R$ 500,00 por litigância."
  m <- extract_amounts(txt)
  expect_equal(m$role, c("exclude_fees", "exclude_fine"))
  expect_true(is.na(pick_award(m)))
})

test_that("first-instance value is distinguished from the fixed award", {
  txt <- "A sentença condenou a ré ao pagamento de R$ 5.000,00 a título de danos morais. Recurso não provido."
  m <- extract_amounts(txt)
  expect_equal(m$role, "first_instance")
})

test_that("empty and NA inputs return empty frame", {
  expect_equal(nrow(extract_amounts(NA)), 0)
  expect_equal(nrow(extract_amounts("")), 0)
  expect_equal(nrow(extract_amounts("sem valores aqui")), 0)
})

test_that("material damages are excluded", {
  txt <- "Danos materiais de R$ 3.200,00 comprovados; danos morais arbitrados em R$ 8.000,00."
  m <- extract_amounts(txt)
  expect_equal(m$role, c("exclude_material", "fixed"))
  expect_equal(pick_award(m), 8000)
})
