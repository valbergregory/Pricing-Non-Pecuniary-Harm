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
| 04 | `scripts/04_collect_tjdft_full.R` | Background Job (idempotent; re-run to resume) | network (JurisDF, 1 req/s, identifying User-Agent — D6) | `data/raw/tjdft/<month>/page_NNNN.json` for every month 2015–2025, `acordaos` + `collection_log` in DuckDB, `outputs/diagnostics/04_collection_status.csv`, log | ~2,100 pages, 1.5–2 h |
| 05 | `scripts/05_annotation_sample.R` (only after D5 is ratified; run once) | Background Job | `pnph.duckdb` (read-only), `config.yml` → `annotation` | git-ignored `data/interim/annotation/`: `planilhas/rodada_{1,2,3}.csv`, `planilhas/rodada_R_reanotacao.csv`, `fichas/*.txt`, `chave_NAO_ABRIR.csv`, `extractor_snapshot.rds`; versioned `outputs/diagnostics/05_annotation_design.csv`, log | 20–60 min first run (extractor over ~78k decisions), then seconds |
| 06 | `scripts/06_annotation_validity.R` (after each annotation round) | Console | filled worksheets + key; `pnph.duckdb` if present (re-runs the current extractor) | `outputs/diagnostics/06_validity_report.md`, `06_validity_metrics.csv`, `06_validity_by_class.csv`, `06_intrarater_kappa.csv`; git-ignored `divergencias.csv` | seconds |
| T | `testthat::test_dir("tests/testthat")` | Console | `R/`, `config/` | console report (131 tests, synthetic fixtures) | 15 s |
| 09 | `scripts/09_export_overleaf.R` | Console | `outputs/diagnostics/*.csv`, `pnph.duckdb` | `outputs/overleaf/numbers.tex`, `outputs/overleaf/tables/*.tex`, `outputs/overleaf/figures/*.{pdf,png}`, `outputs/logs/sessionInfo.txt` | 10 s |
| P1 | `targets::tar_make()` (phase 1, after `stage: phase1` in `config/config.yml`) | Background Job | network (BCB; one JurisDF count request per month) | IPCA and minimum-wage series (D4 switches in `config.yml`), skips months already collected by 04, then `value_mentions` for the whole corpus (chunked extractor) | 30–90 min (extractor) |

## Where the project stands (2026-10-02) and next steps

1. **Done:** pilot (02–03) and full collection 2015–2025 (04): 78,506 decisions,
   132/132 months, finished 2026-09-12 on the author's machine (data not in Git).
2. **Waiting on the author:** D4 (deflator base month, SM multiples), ratification of
   D2/D3/D5/D7, sending the TJDFT SIC/CODJU request — see `docs/decisoes_pendentes.md`.
3. **Then annotation (D5):** run 05 once; annotate rounds 1–3 following
   `docs/COMO_ANOTAR.md`, running 06 after each round; blind re-annotation of 60 items
   ≥ 4 weeks after round 1; final 06 report (F1 threshold 0.90 on the final value).
4. **Then phase 1:** `stage: phase1` in `config/config.yml` and `targets::tar_make()`.

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

- Seed: `config/config.yml` → `project.seed` (used for the annotation sample; scripts
  05/06 also log the extractor version hash).
- Every API page saved verbatim with SHA-256 in `collection_log`; every STJ/BCB file in
  `data/metadata/download_manifest.csv`.
- Raw data are never modified and never committed; the scripts re-download them.
- `outputs/logs/sessionInfo.txt` records package versions at export time.

## Personal-data check before any push

`git grep -n -i -E "autor[a]?:|apelante|apelado|requerente" -- outputs docs` must return
nothing that names a party; decision texts live only in `data/` (ignored by Git) —
including the annotation text sheets and worksheets (`data/interim/annotation/`).
