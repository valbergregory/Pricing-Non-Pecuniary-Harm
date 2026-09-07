# CLAUDE.md — Pricing Non-Pecuniary Harm

## Regras do projeto
- **R-only.** Coleta, tratamento, banco (DuckDB via pacote `duckdb`), modelagem e
  artigo (Quarto) em R. Não introduzir Python nem serviços externos.
- **Nunca inventar dados ou resultados.** Toda tabela/figura nasce de script
  reproduzível sobre dados baixados; o piloto é diagnóstico, não resultado.
- **Fontes:** só APIs/portais públicos e oficiais (JurisDF/TJDFT, Dados Abertos
  STJ, DataJud, BCB/SGS). Sem scraping de portais que exigem sessão/CAPTCHA.
- **Dados pessoais:** não extrair nomes de partes; inteiro teor fica em
  `data/raw` (fora do Git); publicação apenas agregada (LGPD art. 7º §3º).
- **Git:** commits locais permitidos; push só com autorização do pesquisador.
- **Não instalar pacotes globalmente:** usar `renv`.
- **Idioma:** documentação interna em pt-BR; artigo e código (nomes, comentários
  curtos) em inglês.

## Fluxo de trabalho no RStudio
- Console: verificações curtas (`source("scripts/00_check_environment.R")`).
- Background Jobs: coleta e estimações (`scripts/02_*`, `04_*`, `05_*`).
- Terminal: Git, `renv::restore()`, `quarto render`.

## Convenções
- Scripts numerados em `scripts/`; funções puras em `R/` (uma família por arquivo).
- Cada coleta grava `data/metadata/collection_log.csv` com URL, corpo da
  requisição, data/hora, n de registros e SHA-256 do arquivo bruto.
- Chave de acórdão = `uuid` do JurisDF; chave de menção de valor = `uuid` + índice.
- Decisões de desenho vão para `docs/decisions_log.md` (D1, D2, …) com status.
