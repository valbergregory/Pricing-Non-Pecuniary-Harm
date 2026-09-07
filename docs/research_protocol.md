# Protocolo de pesquisa — Pricing Non-Pecuniary Harm (v0.1, 2026-09-05)

## 1. Objeto e motivação

O dano moral não tem tabela legal no Brasil (o art. 944 do CC manda medir a
indenização pela extensão do dano; a tarifação do art. 223-G da CLT foi
objeto da ADI 6.050, julgada em 2023 com interpretação conforme). O valor é
arbitrado caso a caso pelo juiz, sob os vetores "razoabilidade e
proporcionalidade" e o método bifásico do STJ (REsp 1.152.541/RS, 2011). A
pergunta empírica é **como esse arbitramento se comporta em escala**: quanto
vale cada tipo de lesão, quanto da variação é atribuível ao julgador, se o
reexame recursal comprime a dispersão, e se precedentes qualificados e a
inflação alteram o "preço" do sofrimento.

## 2. Perguntas de pesquisa

| RQ | Pergunta | Estimando (ver estimand_table.md) |
|---|---|---|
| RQ1 | Qual é a distribuição (nível e dispersão) dos valores de dano moral por tipo de lesão? | quantis condicionais de log(valor real) por tipo |
| RQ2 | Que parcela da variância é atribuível ao relator/órgão julgador, mantido o tipo de lesão? | ICC e efeitos aleatórios (relator, órgão), modelo multinível |
| RQ3 | O reexame de 2º grau comprime a dispersão (majora valores baixos, reduz altos)? | razão valor 2º grau / valor 1º grau por quantil do valor de origem |
| RQ4 | Precedentes qualificados do STJ (ex.: Temas 1078, 1156, 1365 — dano moral *in re ipsa*) deslocam valores/probabilidade de condenação nos tipos afetados? | estudo de eventos em torno da data de julgamento/publicação do tema |
| RQ5 | Há âncoras: números redondos, múltiplos de salário-mínimo, rigidez nominal sob inflação? | frequência de valores redondos; deriva real vs nominal ao longo do tempo |

## 3. Desenho empírico

- **Unidade de análise:** acórdão (decisão colegiada de 2º grau ou Turma
  Recursal) do TJDFT que decide pedido de dano moral, 2015–2025.
- **Variável dependente:** valor arbitrado/mantido a título de dano moral
  (R$ nominais e deflacionados pelo IPCA), extraído da ementa/dispositivo e
  validado por anotação humana; variável auxiliar: valor da sentença de origem
  quando mencionado (majoração/redução).
- **Covariáveis:** tipo de lesão (dicionário `config/harm_types.yml`), classe
  processual CNJ, órgão julgador, relator, data, base (Turma Cível vs Turma
  Recursal), resultado (provido/desprovido), presença de tema repetitivo.
- **Modelos:** regressão quantílica e modelos multinível (efeitos cruzados
  relator × tipo × ano) sobre log(valor); decomposição de variância; estudo de
  eventos com controle por tipos não afetados; testes de números redondos.
- **Inferência:** erros-padrão agrupados por relator/órgão; bootstrap por
  cluster; correção para múltiplas comparações nos estudos de eventos.

## 4. Fontes (todas verificadas em 2026-09-05)

Principal: API JurisDF/TJDFT (ementa + inteiro teor). Secundárias: STJ Dados
Abertos (íntegras e espelhos: valores excepcionalmente revisados sob a
Súmula 7; temas.csv: eventos), DataJud (volume por tribunal), BCB/SGS (IPCA).
Ver `config/data_sources.yml` e `docs/data_inventory.md`.

## 5. Validação da extração (D5)

1. Extrator por regras (R/value_extractor.R) sobre ementa e inteiro teor.
2. Anotação humana cega pelo pesquisador de 300 acórdãos (3 rodadas de 100),
   com reanotação de 60 após 4 semanas (concordância intra-avaliador).
3. Métricas: precisão/recall do valor final, do papel (fixado/majorado/
   reduzido) e do tipo de lesão; erro absoluto mediano.
4. Regras só entram na fase 2 se F1 ≥ 0,90 no valor final; caso contrário,
   a amostra analítica fica restrita aos acórdãos com extração de alta confiança
   e a limitação é reportada.

## 6. Ameaças à validade e mitigação

- **Seleção:** só chegam ao 2º grau casos recorridos; comparar com volume
  do DataJud por grau e reportar como limitação; Turmas Recursais ampliam
  a cobertura de causas de menor valor.
- **Uma jurisdição:** o DF é um ente único (sem heterogeneidade estadual);
  ganho de validade interna; validade externa via replicação futura no TJRS
  (Solr) se viável.
- **Erro de extração:** medido e reportado (seção 5); análises de
  sensibilidade excluindo extrações de baixa confiança.
- **Mudança de padrão de ementa (2024, Rec. CNJ 154):** ementas estruturadas
  ("I. CASO EM EXAME… IV. DISPOSITIVO E TESE") facilitam extração no período
  recente; testar estabilidade do extrator por ano.

## 7. Ética e dados pessoais

Documentos públicos obtidos por API oficial; nomes de partes não são
extraídos nem armazenados em campos próprios; inteiro teor fora do Git;
publicação apenas agregada. Nenhum dado do trabalho do pesquisador é usado.

## 8. Pré-registro

Este protocolo, com os estimandos e regras de decisão, será congelado
(commit etiquetado `prereg-v1`) antes da coleta do universo 2015–2025.
