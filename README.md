# Pricing Non-Pecuniary Harm

Research compendium (R-only) for the working paper

> **Pricing Non-Pecuniary Harm: A Jurimetric Analysis of Moral Damages Awards in a
> Brazilian Appellate Court (Federal District, 2015–2025)** — Valber Gregory

Scope decisions (2026-09-07): single jurisdiction (TJDFT) with a planned replication in
TJRS; civil panels and small-claims appellate panels analysed as explicit strata; the
STJ's review of awards under *Súmula 7* is the object of a separate paper
([STJ-Moral-Damages-Jurimetrics](https://github.com/valbergregory/STJ-Moral-Damages-Jurimetrics)).

Brazilian law leaves the monetary valuation of moral damages (*dano moral*) to judicial
discretion. This repository builds a reproducible pipeline that extracts the amounts
awarded in the full text of public appellate decisions and estimates (i) the distribution
of awards by type of harm, (ii) the share of variance attributable to judges and panels,
(iii) the compression effect of appellate review, (iv) the response of awards to binding
STJ precedents, and (v) the role of anchors and inflation.

**Status (2026-09-07): feasibility stage.** Sources audited with live access tests,
one-month pilot collection (TJDFT, March 2024), rule-based extractor with tests,
pre-registration protocol drafted. **No scientific result is reported yet**; the
pilot numbers are diagnostics of extraction feasibility.
See [docs/feasibility_report.md](docs/feasibility_report.md) (pt-BR).

## Data sources (all public, verified 2026-09-05)

| Source | Role | Access |
|---|---|---|
| [JurisDF — TJDFT jurisprudence API](https://jurisdf.tjdft.jus.br/) | **Primary**: ementa, dispositivo, panel, rapporteur, dates and full text of appellate decisions, 2015–2025 | `POST /api/v1/pesquisa`, no key |
| [STJ open data](https://dadosabertos.web.stj.jus.br/) | Secondary: decisions reviewed despite *Súmula 7*; qualified precedents (`temas.csv`) as event calendar | CKAN, CC-BY |
| [DataJud public API (CNJ)](https://datajud-wiki.cnj.jus.br/api-publica/) | Context: case volumes by court and instance (no award values) | public key |
| [BCB/SGS series 433](https://api.bcb.gov.br/) | IPCA deflator | JSON |

Raw judicial texts are **not redistributed**; the scripts re-download them and record
URL, date, size and SHA-256 in `data/metadata/download_manifest.csv` and in the
`collection_log` table.

## Reproduce (R 4.4.3; packages pinned in `renv.lock`)

```r
renv::restore()
source("scripts/00_check_environment.R")   # environment audit
source("scripts/01_test_data_access.R")    # live source checks (network, ~2 min)
source("scripts/02_pilot_tjdft_month.R")   # pilot: one month of TJDFT decisions -> DuckDB
source("scripts/03_pilot_extract_values.R")# extractor diagnostics + annotation sample
testthat::test_dir("tests/testthat")       # 33 tests
source("scripts/09_export_overleaf.R")     # numbers.tex, tables, figures for Overleaf
```

Step-by-step runbook with inputs, outputs and durations: [docs/RUNBOOK.md](docs/RUNBOOK.md).
Phase 1 (full 2015–2025 collection) runs through `targets::tar_make()` after the
protocol is approved.

## Repository layout

| Path | Content |
|---|---|
| `config/` | central config, source inventory, harm-type dictionary |
| `R/` | pipeline functions: API clients (TJDFT, STJ, DataJud, BCB), value extractor, harm classifier, DuckDB helpers |
| `sql/` | DuckDB schema |
| `scripts/` | numbered, executable steps (see runbook) |
| `tests/testthat/` | unit tests for the extractor, parsers and classifier |
| `docs/` | research protocol, estimand table, decision log, data inventory and dictionary, feasibility report, AI-use policy, LaTeX snippets |
| `article/` | Overleaf skeleton only (`main.tex`, `references.bib`); prose is written by the author |
| `outputs/` | logs, diagnostics, `overleaf/` exports (generated) |
| `data/` | raw and processed data (git-ignored) |

## AI use and authorship

Code, tests and repository documentation were written with the assistance of Claude Code
(Anthropic), as disclosed in `docs/latex_snippets/ai_disclosure.tex`. The study design,
every methodological decision, the execution of all code and the article text are the
author's. Claude Code does not write the article's prose. Policy and journal requirements:
[docs/AI_POLICY_AND_REPRODUCIBILITY.md](docs/AI_POLICY_AND_REPRODUCIBILITY.md).

## Ethics

Only public documents obtained from official portals; no names of parties, lawyers or
individual judges are stored in dedicated fields or published; judge-level analysis is
reported at court/panel level. Full texts stay outside Git.

## Licence

Code: MIT. Text and figures: CC BY 4.0. See `LICENSE` and `CITATION.cff`.
