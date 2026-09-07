# Guia de reprodução

## Ambiente
- R ≥ 4.4 (desenvolvido em 4.4.3, Windows 11). `Rscript` em `C:\Program Files\R\R-4.4.3\bin`.
- Dependências travadas por `renv` (`renv.lock`). Primeira sessão: `renv::restore()`.
- Artigo em LaTeX no Overleaf: `article/main.tex` é só esqueleto; tabelas, figuras e
  `numbers.tex` vêm de `scripts/09_export_overleaf.R` (`outputs/overleaf/`).
- Sem Python, sem Docker, sem serviços externos além das APIs públicas listadas.
- Runbook numerado com entradas, saídas e duração: `docs/RUNBOOK.md`.

## Ordem de execução
1. `source("scripts/00_check_environment.R")` — Console.
2. `source("scripts/01_test_data_access.R")` — Console (~2 min; rede).
3. `source("scripts/02_pilot_tjdft_month.R")` — Background Job (piloto, 1 mês, ~2–5 min).
4. `source("scripts/03_pilot_extract_values.R")` — Console/Background Job.
5. `testthat::test_dir("tests/testthat")`.
6. Fase 1 (após aprovação de D1–D8): `cfg$project$stage <- "phase1"` em `config/config.yml`
   e `targets::tar_make()` em Background Job.

## Linhagem e integridade
- Toda página baixada do JurisDF fica em `data/raw/tjdft/<janela>/page_NNNN.json` e é
  registrada em `collection_log` (URL, corpo da requisição, n, SHA-256).
- Íntegras/CSVs do STJ ficam em `data/raw/stj/<dataset>/` (download idempotente).
- O banco `data/processed/pnph.duckdb` é regenerável a partir de `data/raw`.
- Fora do Git: `data/`, `*.duckdb`, `renv/library`.

## Convenções de log
`outputs/logs/NN_<script>.log` com carimbo de tempo por linha; diagnósticos em
`outputs/diagnostics/NN_*.csv`.
