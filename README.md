# Pricing Non-Pecuniary Harm

Research compendium for the working paper *Pricing Non-Pecuniary Harm: A
Jurimetric Analysis of Moral Damages Awards in a Brazilian Appellate Court
(Federal District, 2015–2025)*.

Brazilian law leaves the monetary valuation of moral damages (*dano moral*) to
judicial discretion. This repository collects public appellate decisions of
the Federal District court (TJDFT), extracts the amounts awarded from their
full text, and treats them as data. Civil panels (Turmas Cíveis) and
small-claims appellate panels (Turmas Recursais) are analysed as explicit
strata. The review of awards by the Superior Court of Justice (STJ) under
*Súmula 7* is the object of a separate repository
([STJ-Moral-Damages-Jurimetrics](https://github.com/valbergregory/STJ-Moral-Damages-Jurimetrics)).

**Research questions** (`docs/research_protocol.md`, estimands in
`docs/estimand_table.md`):

1. Distribution (level and dispersion) of awards by type of harm.
2. Share of variance attributable to the rapporteur and the panel, holding the
   type of harm fixed.
3. Whether appellate review compresses dispersion relative to first-instance
   values.
4. Whether qualified STJ precedents shift awards in the affected types of harm.
5. Anchors: round numbers, minimum-wage multiples and nominal rigidity under
   inflation.

## Data sources

Machine-readable inventory, with access details and status per source, in
`config/data_sources.yml` (narrative version in `docs/data_inventory.md`).

| Source | Institution | Role | Period |
|---|---|---|---|
| [JurisDF](https://jurisdf.tjdft.jus.br/) — jurisprudence API | TJDFT | Primary: ementa, dispositivo, panel, rapporteur, dates and full text of appellate decisions | 2015–2025 |
| [STJ open data](https://dadosabertos.web.stj.jus.br/) — full texts, panel summaries (3rd and 4th Panels), qualified precedents (`temas.csv`) | STJ | Secondary: decisions reviewed despite *Súmula 7*; precedents as event calendar | 2021 onwards (full texts) |
| [DataJud public API](https://datajud-wiki.cnj.jus.br/api-publica/) | CNJ | Context: case volumes by court (no award values) | 2015–2026 |
| SGS series 433 (IPCA) and 1619 (minimum wage) | Banco Central do Brasil | Deflator; minimum-wage multiples | monthly |

Judicial texts are not redistributed. The scripts re-download them and record
URL, request body, page count and SHA-256 in the `collection_log` table and
in `data/metadata/download_manifest.csv`.

## Repository layout

| Path | Content |
|---|---|
| `config/` | `config.yml` (sources, study window, deflator base, annotation design), `data_sources.yml`, `harm_types.yml` (rule-based harm-type dictionary) |
| `R/` | API clients (JurisDF, STJ CKAN, DataJud, BCB/SGS), value extractor, harm classifier, annotation tooling, DuckDB helpers |
| `sql/schema.sql` | DuckDB DDL (see below) |
| `scripts/` | Numbered steps: environment check, source access tests, one-month pilot, extractor diagnostics, full collection, annotation sample, annotation validity report, export |
| `_targets.R` | `targets` pipeline for the full corpus (collection by monthly windows, deflator series, extraction) |
| `tests/testthat/` | Unit tests for the extractor, parsers, classifier and annotation tooling (synthetic fixtures only) |
| `docs/` | Research protocol, estimand table, decision log, data inventory, data dictionary, reproducibility guide, runbook, annotation guide |
| `data/` | Raw pages, DuckDB file and annotation worksheets (git-ignored); `data/metadata/` with the download manifest |
| `outputs/` | Logs and diagnostics CSVs; figures, tables and models are generated locally |

### Database schema (`data/processed/pnph.duckdb`)

| Table | Content |
|---|---|
| `acordaos` | one row per decision: identifiers, base, panel, rapporteur, dates, dispositivo, ementa, full text and length, lineage |
| `value_mentions` | one row per "R$" mention in ementa or full text: amount, role (fixed, increased, reduced, first instance, claimed, excluded categories, unknown), confidence, moral-damages flag, context |
| `annotations` | human annotation rounds: final award, role, first-instance value, harm type, outcome |
| `ipca` | monthly IPCA and cumulative index |
| `collection_log` | every API page: timestamp, URL, request body, record count, raw file, SHA-256 |

Field-level dictionary in `docs/data_dictionary.md`.

## Reproduce

R 4.4.3; packages pinned in `renv.lock`. No Python, Docker or services other than the public APIs listed above.

```r
renv::restore()
source("scripts/00_check_environment.R")
source("scripts/01_test_data_access.R")    # live source checks (network)
source("scripts/02_pilot_tjdft_month.R")   # one month of TJDFT decisions -> DuckDB
source("scripts/03_pilot_extract_values.R")
source("scripts/04_collect_tjdft_full.R")  # 2015-2025 collection (idempotent, 1 req/s)
testthat::test_dir("tests/testthat")
source("scripts/05_annotation_sample.R")   # blind annotation sample (worksheets git-ignored)
source("scripts/06_annotation_validity.R") # precision/recall/F1 and intra-rater kappa
```

Full-corpus extraction: set `stage: phase1` in `config/config.yml`, then
`targets::tar_make()`. Inputs, outputs and durations of each step are in
`docs/RUNBOOK.md`; environment notes in `docs/reproducibility_guide.md`.

Optional environment variable (`.Renviron`, git-ignored): `DATAJUD_APIKEY`.
The DataJud key is public; when absent, the scripts fetch it from the CNJ page.

## Ethics and personal data

Only public documents obtained from official portals. Names of parties are
not extracted or stored in dedicated fields; full texts stay outside Git;
results are published in aggregate, with judge-level analysis reported at
court/panel level (decision D7, `docs/decisions_log.md`). Collection runs at
one request per second with a User-Agent identifying the repository
(decision D6).

## Licence and citation

Code: MIT ([LICENSE](LICENSE)). Text, documentation and figures: CC BY 4.0
([LICENSING.md](LICENSING.md)). Judicial documents are not redistributed.

Citation: [CITATION.cff](CITATION.cff).
