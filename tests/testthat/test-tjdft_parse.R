test_that("tjdft_body builds the schema the API accepts", {
  b <- tjdft_body("dano moral", "2024-01-01", "2024-12-31", 2, 40)
  expect_equal(b$pagina, 2L); expect_equal(b$tamanho, 40L)
  expect_equal(b$termosAcessorios[[1]]$campo, "dataJulgamento")
  expect_equal(b$termosAcessorios[[1]]$valor, "entre 2024-01-01 e 2024-12-31")
  expect_true(b$retornaTotalizacao)
})

test_that("tjdft_parse_registros maps fields and tolerates missing ones", {
  regs <- list(
    list(uuid = "u1", identificador = 1L, base = "acordaos", subbase = "acordaos",
         processo = "0700000-00.2024.8.07.0001", codigoClasseCnj = 198,
         descricaoOrgaoJulgador = "1ª TURMA CÍVEL", codigoSistjOrgaoJulgador = 10,
         nomeRelator = "X", dataJulgamento = "2024-03-13T03:00:00.000Z",
         dataPublicacao = "2024-03-20T03:00:00.000Z", decisao = "NEGAR PROVIMENTO",
         ementa = "Dano moral. R$ 5.000,00.", uf = "DF", turmaRecursal = FALSE,
         segredoJustica = FALSE, possuiInteiroTeor = TRUE, inteiroTeor = "texto completo"),
    list(uuid = "u2", base = "decisoes")   # sparse record
  )
  df <- tjdft_parse_registros(regs, raw_file = "x.json")
  expect_equal(nrow(df), 2)
  expect_equal(df$classe_cnj[1], 198L)
  expect_equal(df$data_julgamento[1], as.Date("2024-03-13"))
  expect_true(is.na(df$data_julgamento[2]))
  expect_equal(df$inteiro_teor_chars[1], nchar("texto completo"))
  expect_true(is.na(df$inteiro_teor[2]))
})

test_that("harm classifier follows dictionary priority", {
  ht <- load_harm_types(file.path(root, "config/harm_types.yml"))
  expect_equal(classify_harm("PLANO DE SAÚDE. NEGATIVA DE COBERTURA. DANO MORAL.", ht), "medical")
  expect_equal(classify_harm("INSCRIÇÃO INDEVIDA EM CADASTRO DE INADIMPLENTES.", ht), "credit_listing")
  expect_equal(classify_harm("ATRASO DE VOO. DANO MORAL.", ht), "air_travel")
  expect_equal(classify_harm("Texto sem pistas.", ht), "other")
})
