# Tabela de estimandos (v0.1)

| ID | Estimando | População | Variável | Modelo/estimador | Inferência | RQ |
|---|---|---|---|---|---|---|
| E1 | Quantis (p10, p25, p50, p75, p90) do valor real de dano moral por tipo de lesão e ano | acórdãos TJDFT 2015–2025 com valor extraído validado | log(valor IPCA-2025) | regressão quantílica com dummies de tipo × ano | bootstrap por cluster (órgão) | RQ1 |
| E2 | ICC do relator e do órgão julgador, condicionado ao tipo de lesão, classe e ano | idem | log(valor real) | modelo multinível com efeitos cruzados (relator, órgão) | IC por bootstrap paramétrico | RQ2 |
| E3 | Efeito do reexame: E[log(v2/v1) \| quantil de v1] | acórdãos que mencionam valor de origem | log(v2) − log(v1) | regressão por quantil de v1; sinal e magnitude | EP agrupado por relator | RQ3 |
| E4 | Variação no valor mediano e na probabilidade de condenação após tema repetitivo *in re ipsa* nos tipos afetados vs não afetados | tipos afetados (bancário/plano de saúde) vs controle | log(valor); indicador de condenação | estudo de eventos / DiD com tendências por tipo | EP agrupado; correção Romano-Wolf | RQ4 |
| E5 | Fração de valores "redondos" (múltiplos de R$ 1.000/5.000/10.000) e deriva real anual | idem E1 | indicador; log(valor real) | frequências; tendência linear com quebras | IC bootstrap | RQ5 |

Regras de decisão pré-registradas: E2 é "relevante" se ICC(relator) ≥ 0,10;
E3 indica compressão se a inclinação de log(v2/v1) em v1 for negativa com IC 95 %
excluindo zero; E4 é reportado independentemente do sinal.
