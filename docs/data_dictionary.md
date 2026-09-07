# Dicionário de dados (DuckDB `data/processed/pnph.duckdb`)

## `acordaos` (1 linha por decisão do JurisDF)
| campo | tipo | origem | descrição |
|---|---|---|---|
| uuid | VARCHAR PK | `uuid` | identificador estável do documento no JurisDF |
| identificador | VARCHAR | `identificador` | número do acórdão/decisão |
| base / subbase | VARCHAR | `base`, `subbase` | acordaos, acordaos-tr, decisoes-monocraticas, decisoes-presidencia… |
| processo | VARCHAR | `processo` | número CNJ |
| classe_cnj | INTEGER | `codigoClasseCnj` | classe (198 Apelação Cível, 460 Recurso Inominado…) |
| orgao_julgador / cod_orgao | VARCHAR / INTEGER | `descricaoOrgaoJulgador`, `codigoSistjOrgaoJulgador` | órgão colegiado |
| relator | VARCHAR | `nomeRelator` | relator (nome público do magistrado) |
| data_julgamento / data_publicacao | DATE | idem | datas |
| decisao | VARCHAR | `decisao` | dispositivo resumido (ex.: "NEGAR PROVIMENTO. UNÂNIME") |
| ementa | VARCHAR | `ementa` | ementa |
| turma_recursal, segredo_justica, possui_inteiro_teor | BOOLEAN | idem | flags |
| inteiro_teor / inteiro_teor_chars | VARCHAR / INTEGER | `inteiroTeor` | texto integral (fora do Git) e tamanho |
| raw_file, collected_at | VARCHAR, TIMESTAMP | pipeline | linhagem |

## `value_mentions` (1 linha por menção "R$" em ementa ou inteiro teor)
| campo | descrição |
|---|---|
| uuid, section, idx | chave (seção = ementa \| inteiro_teor) |
| amount_brl, amount_text | valor numérico e texto original |
| role | fixed, increased, reduced, first_instance, claimed, exclude_fees, exclude_fine, exclude_case_val, exclude_material, unknown |
| role_conf | confiança heurística (0,3 desconhecido; 0,7 regra) |
| is_moral | contexto (±160 caracteres) menciona dano moral/compensação |
| context, position | janela de contexto e posição no texto |

## `annotations` (anotação humana; D5)
uuid, annotator, round, award_brl, award_role, first_instance_brl, harm_type, outcome, notes, annotated_at.

## `ipca`
ref_month (1º dia do mês), pct (variação mensal %), index_value (índice acumulado desde a 1ª observação).

## `collection_log`
collected_at, source, request_url, request_body, page, n_records, raw_file, sha256.

## Variáveis derivadas (fase 1)
award_brl (valor final validado), award_real (IPCA mês-base D4), award_sm (múltiplos do salário-mínimo vigente), harm_type (dicionário), outcome (provido/desprovido a partir de `decisao`), tema_event (indicador pós-tema para tipos afetados).
