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
- **Git:** repositório público em github.com/valbergregory/Pricing-Non-Pecuniary-Harm;
  commits e push autorizados (07/09/2026) desde que a checagem de dados pessoais passe.
- **Não instalar pacotes globalmente:** usar `renv` (`renv.lock` versionado).
- **Idioma:** documentação interna em pt-BR; README, artigo e código em inglês.
- **Política de IA e reprodutibilidade** (`docs/AI_POLICY_AND_REPRODUCIBILITY.md`):
  Claude Code escreve código, testes, configuração, runbook e documentação do repositório;
  **nunca escreve prosa do artigo** — `article/main.tex` é só esqueleto com `% AUTHOR WRITES`.
  Todo número do artigo sai de `scripts/09_export_overleaf.R` (`outputs/overleaf/numbers.tex`).
- **Dados pessoais:** nenhum nome de parte, advogado ou juiz em arquivo versionado ou
  output; relator só como hash salgado fora do banco; análise por órgão/painel.

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
