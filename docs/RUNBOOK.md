# RUNBOOK — execution order, inputs, outputs, duration

All steps run from the project root in R 4.4.3 (Windows tested). First session:
`renv::restore()` (installs the pinned packages into `renv/library`). Network is
required for steps 01, 02 and 04. Nothing here needs Python, Docker or API keys
(the DataJud key is public and fetched automatically from the CNJ wiki; you may pin it in
`.Renviron` as `DATAJUD_APIKEY`).

| # | Script | Where to run | Reads | Writes | Duration |
|---|---|---|---|---|---|
| 00 | `scripts/00_check_environment.R` | Console | — | `outputs/logs/00_environment.log` | 5 s |
| 01 | `scripts/01_test_data_access.R` | Console | network (JurisDF, STJ CKAN, DataJud, BCB) | `outputs/logs/01_test_data_access.log`, `outputs/diagnostics/01_source_checks.csv`, `data/raw/stj/precedentes-qualificados/temas.csv`, `data/metadata/download_manifest.csv` | 1–2 min |
| 02 | `scripts/02_pilot_tjdft_month.R` | Background Job | network (JurisDF, BCB) | `data/raw/tjdft/<window>/page_NNNN.json`, `data/processed/pnph.duckdb` (tables `acordaos`, `ipca`, `collection_log`), `outputs/diagnostics/02_pilot_by_base.csv`, log | 2–5 min (820 decisions, 21 pages) |
| 03 | `scripts/03_pilot_extract_values.R` | Console / Background Job | `pnph.duckdb` | `value_mentions` table; `outputs/diagnostics/03_*.csv` (coverage, roles, harm types, unvalidated quantiles, annotation sample) | 1–2 min |
| T | `testthat::test_dir("tests/testthat")` | Console | `R/`, `config/harm_types.yml` | console report (33 tests) | 10 s |
| 09 | `scripts/09_export_overleaf.R` | Console | `outputs/diagnostics/*.csv`, `pnph.duckdb` | `outputs/overleaf/numbers.tex`, `outputs/overleaf/tables/*.tex`, `outputs/overleaf/figures/*.{pdf,png}`, `outputs/logs/sessionInfo.txt` | 10 s |
| P1 | `targets::tar_make()` (phase 1, after `stage: phase1` in `config/config.yml`) | Background Job | network | full 2015–2025 collection into DuckDB (~2,100 pages, 3–4 GB raw JSON, 1–2 h at 1 req/s) | hours |

## One-command reproduction (current stage: feasibility)

```r
renv::restore()
source("scripts/00_check_environment.R")
source("scripts/01_test_data_access.R")
source("scripts/02_pilot_tjdft_month.R")
source("scripts/03_pilot_extract_values.R")
testthat::test_dir("tests/testthat")
source("scripts/09_export_overleaf.R")
```

## Determinism and provenance

- Seed: `config/config.yml` → `project.seed` (used for the annotation sample).
- Every API page saved verbatim with SHA-256 in `collection_log`; every STJ/BCB file in
  `data/metadata/download_manifest.csv`.
- Raw data are never modified and never committed; the scripts re-download them.
- `outputs/logs/sessionInfo.txt` records package versions at export time.

## Personal-data check before any push

`git grep -n -i -E "autor[a]?:|apelante|apelado|requerente" -- outputs docs` must return
nothing that names a party; decision texts live only in `data/` (ignored by Git).
