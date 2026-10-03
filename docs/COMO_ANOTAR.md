# Como anotar — validação humana cega do extrator (D5)

> **Status:** D5 está **proposta**. Este guia e os scripts 05/06 ficam prontos para uso,
> mas a amostra só deve ser sorteada depois que o autor ratificar D5 em
> `docs/decisions_log.md`. As regras marcadas **[regra proposta]** são sugestões de
> operacionalização; o autor confirma ou altera antes da rodada 1 (e registra aqui).

## 1. O que é e por que é cego

O extrator por regras (`R/value_extractor.R`) e o classificador de tipo de lesão
(`R/harm_classifier.R`) são instrumentos de medida. Antes de qualquer resultado,
mede-se o erro deles contra a leitura humana de 300 acórdãos (3 rodadas de 100), com
reanotação cega de 60 itens para medir a concordância do anotador consigo mesmo
(`research_protocol.md` §5). Limiar: **F1 ≥ 0,90 no valor final** (config
`annotation$f1_threshold`).

"Cego" significa: a planilha e a ficha **não mostram** o que o extrator encontrou, nem
o estrato, nem o relator. As previsões ficam em `chave_NAO_ABRIR.csv` — **não abra esse
arquivo** até terminar as três rodadas e a reanotação.

## 2. Arquivos (todos fora do Git, em `data/interim/annotation/`)

| Arquivo | Conteúdo | Quem mexe |
|---|---|---|
| `planilhas/rodada_1.csv`, `rodada_2.csv`, `rodada_3.csv` | uma linha por acórdão, colunas em branco | **você preenche** |
| `planilhas/rodada_R_reanotacao.csv` | 60 itens já anotados na rodada 1, com **novos códigos** | você preenche, ≥ 4 semanas depois de terminar a rodada 1 |
| `fichas/P-XXXXXX.txt` | texto do acórdão: órgão, data, dispositivo, ementa, inteiro teor | só leitura |
| `chave_NAO_ABRIR.csv` | item → uuid, estrato, peso, saída congelada do extrator | ninguém (lido pelo script 06) |
| `extractor_snapshot.rds` | cache do extrator sobre o corpus inteiro | script 05 |
| `divergencias.csv` | itens em que extrator e anotação divergem (gerado pelo 06) | depois das rodadas, para corrigir regras |

As planilhas usam `;` como separador e UTF-8 — abrem direto no Excel/LibreOffice em
português. Salve no mesmo formato (CSV). O script 06 aceita `;` ou `,`.

## 3. Colunas e códigos

| Coluna | O que escrever | Códigos / formato |
|---|---|---|
| `item_id`, `rodada`, `ficha` | **não alterar** | — |
| `decide_dano_moral` | O acórdão decide (concede, mantém, altera ou nega) pedido de dano moral? **Preencher esta coluna marca a linha como anotada.** | `S` / `N` |
| `valor_final` | Valor de dano moral que vale **depois** do acórdão (fixado, mantido, majorado ou reduzido). Em branco se não há condenação em dano moral ao final. | número como no texto: `10.000,00`, `10000` ou `R$ 10.000,00` |
| `papel_valor` | O que o acórdão fez com o valor | `FIXADO` (fixado pela 1ª vez no 2º grau), `MANTIDO`, `MAJORADO`, `REDUZIDO`, `AFASTADO` (condenação excluída), `SEM_VALOR` (não há valor de dano moral em jogo) |
| `multiplos_valores` | Há valores de dano moral distintos para beneficiários diferentes? | `S` / `N` |
| `valor_origem` | Valor de dano moral da sentença, se o acórdão o menciona | número; em branco se não mencionado |
| `tipo_lesao` | Tipo de lesão (dicionário `config/harm_types.yml`) | `wrongful_death`, `medical`, `credit_listing`, `air_travel`, `banking_fraud`, `consumer_service`, `honor_privacy`, `state_liability`, `other` |
| `resultado` | Resultado do recurso | `PROVIDO`, `PARCIAL`, `DESPROVIDO`, `NAO_CONHECIDO`, `OUTRO` |
| `confianca` | Sua confiança na anotação | `1` baixa, `2` média, `3` alta |
| `minutos` | Tempo gasto no item (para medir o custo real) | número |
| `observacoes` | Livre. **Não copie nomes de partes, advogados ou magistrados.** | texto curto |

### Regras de preenchimento **[regra proposta]**

1. **Valor final = o que prevalece após o acórdão.** Se a sentença fixou R$ 5.000,00 e o
   acórdão majorou para R$ 8.000,00: `valor_final = 8.000,00`, `papel_valor = MAJORADO`,
   `valor_origem = 5.000,00`.
2. **Recurso desprovido que mantém a sentença:** `valor_final` = valor da sentença,
   `papel_valor = MANTIDO`.
3. **Condenação afastada** (o acórdão exclui o dano moral): `valor_final` em branco,
   `papel_valor = AFASTADO`, `valor_origem` = valor excluído, se citado.
4. **Pedido negado nas duas instâncias:** `valor_final` em branco, `papel_valor = SEM_VALOR`.
5. **Vários beneficiários com valores diferentes:** `multiplos_valores = S`; em
   `valor_final`, o **maior** valor por beneficiário; os demais em `observacoes` (só os
   números). O script 06 reporta as métricas também sem esses itens.
6. **Mesmo valor para cada um de vários autores** ("R$ 5.000,00 para cada autor"):
   `valor_final = 5.000,00`, `multiplos_valores = N`.
7. **Valor por extenso ou em salários-mínimos sem R$:** anote o valor em reais se o texto
   o permitir; caso contrário deixe em branco e explique em `observacoes`.
8. **Ignore** honorários, multas/astreintes, danos materiais, valor da causa e correção
   monetária/juros — só o principal de dano moral.
9. **Acórdão que não trata de dano moral** (a busca "dano moral" traz falsos positivos):
   `decide_dano_moral = N`, `papel_valor = SEM_VALOR`, resto em branco (exceto `resultado`).
10. **Tipo de lesão:** escolha um único código, o do fato principal; em caso de dúvida
    entre dois, use o que aparece primeiro na lista acima (mesma prioridade do
    classificador) e anote a dúvida em `observacoes`.

### Exemplos (textos sintéticos, sem partes)

| Trecho (resumido) | decide | valor_final | papel | origem | tipo |
|---|---|---|---|---|---|
| "Atraso de voo superior a 8 horas. Danos morais fixados na sentença em R$ 3.000,00 mantidos. Recurso desprovido." | S | 3.000,00 | MANTIDO | 3.000,00 | air_travel |
| "Inscrição indevida em cadastro de inadimplentes. Quantum majorado de R$ 4.000,00 para R$ 8.000,00." | S | 8.000,00 | MAJORADO | 4.000,00 | credit_listing |
| "Negativa de cobertura pelo plano de saúde. Mero inadimplemento contratual. Dano moral afastado." | S | (vazio) | AFASTADO | (se citado) | medical |
| "Honorários fixados em R$ 2.000,00. Dano moral não configurado." | S | (vazio) | SEM_VALOR | (vazio) | conforme o fato |
| "Ação de cobrança de aluguéis" (sem pedido de dano moral) | N | (vazio) | SEM_VALOR | (vazio) | other |

## 4. Ordem de trabalho e tempo

1. **Rodada 1** (100 itens): abra `rodada_1.csv`; para cada linha, abra a ficha indicada
   em `ficha`, leia **dispositivo e ementa primeiro** e o inteiro teor só se necessário
   (voto do relator, parte final). Preencha e salve com frequência.
2. Rode o script 06 (abaixo) para conferir códigos e ver as métricas parciais — o
   relatório mostra só números agregados, sem revelar item a item (o detalhe vai para
   `divergencias.csv`, que você **não** deve abrir antes do fim da rodada 3 e da
   reanotação, para não contaminar a anotação).
3. **Rodadas 2 e 3** (100 + 100). A ordem dos itens já é aleatória; cada rodada tem a
   mesma composição de estratos.
4. **Reanotação**: no mínimo **4 semanas** depois de terminar a rodada 1, preencha
   `rodada_R_reanotacao.csv` sem consultar a rodada 1.
5. Rode o 06 de novo: métricas finais + kappa intra-avaliador.

**Tempo estimado (não medido):** 3 a 6 minutos por acórdão, ou seja, 5 a 10 horas por
rodada de 100 e 3 a 6 horas na reanotação. A coluna `minutos` mede o tempo real.

## 5. Comandos (RStudio, na raiz do projeto)

```r
# 0) Só depois de ratificar D5. Sorteio (uma única vez; Background Job, ~20-60 min
#    na primeira execução por causa do extrator sobre ~78 mil acórdãos):
source("scripts/05_annotation_sample.R")

# 1) Após cada rodada (Console, segundos): valida códigos e gera o relatório
source("scripts/06_annotation_validity.R")
# -> outputs/diagnostics/06_validity_report.md (+ 06_validity_metrics.csv,
#    06_validity_by_class.csv, 06_intrarater_kappa.csv)
```

O script 05 **recusa sobrescrever** planilhas existentes. Um novo sorteio exige
`Sys.setenv(PNPH_OVERWRITE_ANNOTATION = "1")` e apaga o trabalho anterior — não faça
isso depois de começar a anotar.

## 6. Desenho da amostra (para o texto de métodos, que o autor escreve)

- Moldura: acórdãos (`base = acordaos`) dos estratos D8 — Turmas/Câmaras Cíveis e
  Turmas Recursais; órgãos de outros tipos (criminais etc.) ficam fora
  (`annotation$strata_include`).
- Células: estrato × ano de julgamento × extrator-achou-valor (sim/não).
- Alocação: mínimo de 1 por célula não vazia e o restante proporcional ao tamanho da
  célula (maiores restos); peso = N_célula / n_célula (guardado na chave).
- Rodadas: lista ordenada por célula distribuída em rodízio entre as 3 rodadas (cada
  rodada espelha o desenho); ordem aleatória dentro da rodada.
- Reanotação: 60 itens da rodada 1, estratificados por estrato × achou-valor, com
  novos códigos de item.
- Semente: `project.seed` em `config/config.yml`; a versão do extrator (hash) e a
  semente ficam gravadas na chave e no log `outputs/logs/05_annotation_sample.log`.
- Métricas (06): valor final — VP quando |extrator − humano| ≤ R$ 0,01; valor errado
  conta como FP e FN; precisão, recall, F1 com IC 95 % por bootstrap; versão ponderada
  pelo desenho como complemento. Papel do valor e tipo de lesão — F1 por classe e
  macro-F1. Reanotação — concordância e kappa de Cohen por campo.
