# Pricing Non-Pecuniary Harm

Research compendium (R-only) do working paper:

> **Pricing Non-Pecuniary Harm: A Jurimetric Analysis of Moral Damages
> Awards in Brazilian Appellate Courts**
> (alternativas: *How Much Is Suffering Worth? Judge Effects, Precedents and
> the Dispersion of Moral Damages in Brazil*; *Anchors, Precedents and
> Inflation: The Pricing of Non-Pecuniary Harm by Brazilian Courts*)

Infraestrutura **100 % em R** (coleta, tratamento, banco local DuckDB,
modelagem, artigo Quarto), auditável e reproduzível, que extrai dos
acórdãos públicos os valores arbitrados a título de dano moral e estima
(i) a distribuição e a dispersão dos valores por tipo de lesão, (ii) a parcela
da variância atribuível a relator/órgão julgador ("judge effects"),
(iii) o efeito do reexame recursal (majoração/redução) e (iv) o efeito de
precedentes qualificados do STJ e da inflação sobre o "preço" do dano moral.

**Status (2026-09-05): primeira entrega** — auditoria do ambiente, estrutura,
protocolo, inventário de fontes com teste real de acesso, piloto diagnóstico
com acórdãos reais do TJDFT (1 mês), extrator de valores testado,
relatório de viabilidade. **Nenhum download de universo completo e nenhuma
estimação definitiva.** Ver [docs/feasibility_report.md](docs/feasibility_report.md).

## Fonte principal (verificada em 2026-09-05)

API pública do **JurisDF/TJDFT** (`https://jurisdf.tjdft.jus.br/api/v1/pesquisa`,
POST JSON, sem chave, sem cota conhecida): devolve ementa, dispositivo,
relator, órgão julgador, classe CNJ, datas e — com `retornaInteiroTeor: true` —
o **inteiro teor** do acórdão. Fontes secundárias: Dados Abertos do STJ
(íntegras diárias, espelhos, precedentes qualificados), DataJud (volume),
BCB/SGS (IPCA para deflacionar).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `config/` | Configuração central, inventário de fontes, dicionário de tipos de lesão |
| `R/` | Funções do pipeline (clientes de API, extrator de valores, deflator, banco) |
| `sql/` | DDL DuckDB (acórdãos, menções de valor, anotação humana) |
| `scripts/` | Executáveis numerados (Console / Background Jobs / Terminal) |
| `data/raw` … `processed/` | Dados (fora do Git) |
| `data/metadata/` | Checksums, linhagem, logs de coleta |
| `outputs/diagnostics/` | Relatórios do piloto |
| `docs/` | Protocolo, inventário, estimandos, decisões, viabilidade |
| `article/` | Manuscrito Quarto (EN) |
| `tests/testthat/` | Testes do extrator e dos clientes |

## Como reproduzir (estado atual)

```r
# RStudio, projeto aberto na raiz:
source("scripts/00_check_environment.R")   # auditoria do ambiente
source("scripts/01_test_data_access.R")    # sondagem real das fontes (grava outputs/logs)
# Background Job:
source("scripts/02_pilot_tjdft_month.R")   # piloto: 1 mês de acórdãos do TJDFT -> DuckDB
source("scripts/03_pilot_extract_values.R")# extrator de valores + diagnóstico
testthat::test_dir("tests/testthat")
```

`renv` gerencia as dependências (`renv::restore()` na primeira sessão).

## Ética e uso de dados

Somente documentos públicos, obtidos por API oficial. Nomes de partes não
são extraídos nem armazenados em campos próprios; o inteiro teor fica fora
do Git. Publicação apenas agregada. Nenhum dado do trabalho do pesquisador
no Judiciário é utilizado.
