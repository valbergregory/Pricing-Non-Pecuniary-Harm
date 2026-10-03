# Decisões pendentes do autor (checklist, 2026-10-02)

**Atualização 2026-10-03:** D2, D3, D4, D5, D7 e a moldura foram aprovados pelo pesquisador (ver `decisions_log.md`). Pendente só o envio do pedido SIC.

Texto original: nada abaixo foi decidido. Cada item traz uma **recomendação** (preparada pelo Claude
Code) e o que muda no repositório quando o autor decidir. Registrar a decisão em
`docs/decisions_log.md` (status → fechada, com data) e marcar aqui.

| ✓ | Item | Recomendação | Como aplicar a decisão |
|---|---|---|---|
| [x] | **D4** — mês-base do deflacionamento e múltiplos de salário-mínimo | **IPCA com base dez/2025** (último mês do período; valores em "reais de dez/2025") **e** reportar também **múltiplos do SM vigente no mês do julgamento** (âncora usada pelos juízes; relevante para RQ5 e para o teto de 40 SM das Recursais, D8) | `config/config.yml` → `temporal: price_base: "2025-12"` e `report_sm_multiples: true` (já são os valores atuais; trocar = editar uma linha). Funções: `price_base_date()`, `deflate_brl()`, `bcb_minimum_wage()` (SGS 1619, conferir no 1º uso), `add_real_values()` em `R/bcb_ipca.R`; alvo `minimum_wage` em `_targets.R` |
| [x] | **D5** — validação humana cega (300 acórdãos, 3 rodadas, reanotação de 60, F1 ≥ 0,90) | Ratificar como está; confirmar as **[regras propostas]** de `docs/COMO_ANOTAR.md` §3 (sobretudo vários beneficiários e acórdãos sem dano moral) e a exclusão de órgãos não cíveis da moldura | Parâmetros em `config/config.yml` → `annotation`. Depois: `source("scripts/05_annotation_sample.R")` uma única vez |
| [x] | **D2** — descarte de TJSP/TJMG/TJAL/SCON como fonte primária; TJRS como replicação | Ratificar (coerente com D1, D6 e D11, já fechadas) | Só `decisions_log.md` |
| [x] | **D3** — STJ como fonte secundária e `temas.csv` como calendário (RQ4) | Ratificar no alcance de D10 (aqui o STJ entra só como calendário de precedentes) | Só `decisions_log.md`; se o uso de íntegras/espelhos sair do escopo, ajustar a redação de D3 |
| [x] | **D7** — inteiro teor só em `data/raw` e DuckDB local; publicação agregada | Ratificar (já é a prática do pipeline; as fichas de anotação também ficam em `data/interim/`, git-ignorado) | Só `decisions_log.md` |
| [ ] | **Pedido SIC/CODJU ao TJDFT** (D6) | Enviar o texto pronto pelo SIC (gera protocolo) e cópia curta à CODJU | Texto em `docs/requests/tjdft_terms_request.md`; o pesquisador envia — o pipeline não envia nada. Registrar protocolo e data no próprio arquivo |
| [x] | Moldura da anotação: órgãos fora dos estratos D8 (ex.: Turmas Criminais que arbitram reparação mínima) | Manter fora (protocolo §3: dois estratos, Cíveis e Recursais) e reportar quantos são | `annotation$strata_include` |

## Depois das decisões (ordem)

1. Registrar D2–D5, D7 em `decisions_log.md`; enviar o pedido SIC.
2. `source("scripts/05_annotation_sample.R")` → anotar rodadas 1–3 (`docs/COMO_ANOTAR.md`),
   rodando `scripts/06_annotation_validity.R` ao fim de cada uma.
3. Reanotação (≥ 4 semanas após a rodada 1) → relatório final de validade.
4. Congelar o protocolo (`prereg-v1`), `stage: phase1` em `config/config.yml` e
   `targets::tar_make()`.
