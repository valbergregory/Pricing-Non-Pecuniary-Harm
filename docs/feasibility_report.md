# Relatório de viabilidade — primeira entrega (2026-09-05)

Escopo: artigo 1 do portfólio jurídico, **somente em R**. Nenhum resultado
científico é apresentado; o que segue é inventário de fontes com teste real de
acesso, matriz de seleção, desenho proposto, piloto diagnóstico e critérios de
continuidade.

## 1. O problema de dados que define o desenho

O STJ quase não revisa o *quantum* do dano moral (Súmula 7), salvo valor
"irrisório ou exorbitante". A sondagem confirmou: em 26/08/2026, das 2.285
decisões publicadas pelo STJ, 92 tinham assunto CNJ de dano moral (todas
monocráticas, 58 de "não conhecimento"); dos 412 textos disponíveis, 11 citavam
dano moral e **apenas 2 traziam valor em R$**. O STJ, portanto, não serve como
fonte principal de valores; a massa está nos tribunais de 2º grau.

Entre os tribunais estaduais, só um oferece API pública com inteiro teor: o
**TJDFT (JurisDF)**. Esse achado orienta todo o desenho.

## 2. Matriz de seleção de fontes

Notas 0–3 (3 = melhor), com base em acessos REALMENTE testados em 2026-09-05.

| Critério | (A) TJDFT JurisDF API | (B) STJ íntegras DJe | (C) STJ espelhos | (D) TJSP e-SAJ | (E) TJRS Solr | (F) TJMG | (G) TJAL | (H) DataJud |
|---|---|---|---|---|---|---|---|---|
| Acesso programático | 3 (POST JSON, sem chave) | 3 (CKAN) | 3 (CKAN) | 0 (formulário) | 1 (Solr não documentado) | 0 (401) | 0 (503) | 3 (chave pública) |
| Traz o valor arbitrado | 3 (39/40 inteiros teores) | 1 (2/412) | 1 (12/737) | 2 (ementa) | 2 (ementa) | — | — | 0 |
| Inteiro teor | 3 | 3 | 0 | 1 (PDF) | 1 | — | — | 0 |
| Metadados (relator, órgão, classe, datas) | 3 | 2 | 3 | 2 | 2 | — | — | 3 |
| Volume anual "dano moral" | 3 (5,5k–11,4k acórdãos) | 1 | 1 | 3 | 2 | — | — | 3 (capa) |
| Série temporal (≥ 10 anos) | 3 (2015–2025 verificado) | 1 (2021+) | 2 (2022+) | 3 | 2 | — | — | 2 |
| Licença/termos claros | 2 (a confirmar, D6) | 3 (CC-BY) | 3 (CC-BY) | 1 | 1 | — | — | 3 |
| Risco de bloqueio/CAPTCHA | 3 | 3 | 3 | 0 | 1 | — | — | 3 |
| Dados sensíveis | 2 (nomes de partes no texto) | 2 | 3 | 2 | 2 | — | — | 3 (partes suprimidas) |
| Viabilidade individual (1 pesquisador) | 3 | 2 | 3 | 0 | 1 | 0 | 0 | 3 |
| **Total** | **28** | **21** | **22** | **14** | **15** | — | — | **23** |

**Decisão proposta (D1–D3):** fonte principal **(A)**; **(B)+(C)** como
contraste (valores revisados no STJ) e calendário de temas repetitivos (RQ4);
**(H)** apenas para volume por grau/tribunal e como base do artigo 2
(duração). **(E)** fica como replicação futura. **(D)**, **(F)**, **(G)** descartadas.

## 3. Resultados da sondagem (checklist)

| # | Exigência | Resultado |
|---|---|---|
| 1 | API oficial responde a consulta com filtro de data | **SIM** — corpo da requisição capturado do front-end; `termosAcessorios[{campo:"dataJulgamento", valor:"entre A e B"}]`; erro explícito para propriedades desconhecidas |
| 2 | Inteiro teor recuperável por API | **SIM** — `retornaInteiroTeor: true`; 40/40 registros com texto (média 38 mil caracteres) |
| 3 | Valor em R$ presente | **SIM** — 39/40 inteiros teores; 11/40 ementas (março/2024) |
| 4 | Volume suficiente | **SIM** — 5.502 (2015) a 11.374 (2025) acórdãos/ano com "dano moral"; março/2024 = 820 |
| 5 | Metadados para efeitos de julgador | **SIM** — relator, órgão julgador (código e nome), classe CNJ, datas, dispositivo |
| 6 | Deflator oficial | **SIM** — BCB/SGS 433 via JSON |
| 7 | Precedentes qualificados como eventos | **SIM** — temas.csv (2.400 linhas; 58 citam dano moral; Temas 1078, 1156, 1365 sobre *in re ipsa*) |
| 8 | Volume por tribunal/grau para contexto | **SIM** — DataJud: TJSP 282k, TJAL 65k, TJRS 49k, TJDFT 39k (2015–2026); quirk `epoch_millis` documentado |
| 9 | Termos de uso da API do TJDFT | **PENDENTE** (D6) — não localizados na sondagem; solicitar/confirmar antes da coleta do universo |
| 10 | Paginação até o fim do universo | **PARCIAL** — `pagina` 2100 × 40 respondeu 200; limite de profundidade a testar na fase 1 |

## 4. Piloto diagnóstico (março/2024)

[preenchido automaticamente após scripts/02 e 03 — ver seção 4 abaixo]

## 5. Arquitetura R-only

```
JurisDF API ──httr2──▶ data/raw/tjdft/<mês>/page_NNNN.json (SHA-256 em collection_log)
                          │ tjdft_parse_registros()
                          ▼
                 DuckDB data/processed/pnph.duckdb
                   acordaos ─▶ value_extractor.R ─▶ value_mentions ─▶ pick_award()
                             ─▶ harm_classifier.R ─▶ harm_type
                   ipca (BCB/SGS) ─▶ deflate_brl()
                   annotations (anotação humana cega, D5)
                          │ targets::tar_make()  (fase 1)
                          ▼
             lme4 / quantreg / fixest ─▶ outputs/tables, outputs/figures ─▶ article/manuscript.qmd
```

Custo computacional estimado do universo 2015–2025: ~85 mil acórdãos ≈ 2.100
requisições de 40 registros com inteiro teor (~1,5 MB cada) ≈ 3–4 GB de JSON
bruto, 1–2 h de coleta a 1 req/s; DuckDB local (< 5 GB); estimação em minutos.
Sem custo monetário. Hardware atual (64 GB RAM) é mais que suficiente.

## 6. Riscos e limitações

- **Termos de uso/limite de requisições do JurisDF** não confirmados (D6).
- **Seleção**: só litígios recorridos; DataJud mostra que no TJDFT os JE (21k)
  e o 1º grau (12k) concentram os ajuizamentos — o 2º grau vê 4k. Turmas
  Recursais (`acordaos-tr`) mitigam parte disso (D8).
- **Uma jurisdição** (DF): validade interna alta, externa limitada.
- **Extração**: regras sobre texto livre; o valor "final" exige distinguir
  fixado/majorado/reduzido/sentença/pleiteado/honorários. Só entra no artigo
  após validação humana com F1 ≥ 0,90 (D5).
- **Dados pessoais** nos inteiros teores (nomes de partes): tratamento D7.

## 7. Critérios de continuidade (gate para a fase 1)

1. D6 resolvido (termos de uso/cadência confirmados ou ausência documentada).
2. Piloto: ≥ 70 % dos acórdãos com pelo menos uma menção de valor em contexto
   de dano moral e ≥ 50 % com valor final escolhido pela heurística.
3. Primeira rodada de anotação (60 acórdãos) com F1 ≥ 0,80 do extrator
   (meta 0,90 após ajuste de regras).
4. Aprovação de D1–D5, D7–D8 pelo pesquisador.

Se (2) ou (3) falharem, a alternativa é restringir a amostra às ementas
estruturadas (padrão CNJ 2024+) ou incluir extração assistida por revisão
humana integral em uma subamostra aleatória.
