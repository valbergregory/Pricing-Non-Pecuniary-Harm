# Inventário de dados (sondagem real em 2026-09-05)

Fonte de verdade legível por máquina: `config/data_sources.yml`. Log da sondagem:
`outputs/logs/01_test_data_access.log` e `outputs/diagnostics/01_source_checks.csv`.

## JurisDF — TJDFT (principal)

- Endpoint `POST https://jurisdf.tjdft.jus.br/api/v1/pesquisa`; sem chave; `tamanho ≤ 40`;
  propriedades desconhecidas são rejeitadas. Corpo capturado do próprio front-end:
  `query`, `termosAcessorios[{campo, valor}]`, `pagina`, `tamanho`, `sinonimos`, `espelho`,
  `inteiroTeor` (buscar também no inteiro teor), `retornaInteiroTeor`, `retornaTotalizacao`.
- Filtro de data: `{"campo":"dataJulgamento","valor":"entre 2024-01-01 e 2024-12-31"}`.
  A interface avançada também expõe número do acórdão/processo, relator, revisor,
  relator designado, órgão, classe, precedente qualificado, data de publicação
  (nomes dos campos ainda não capturados — próximo passo).
- Resposta: `hits.value`, `agregacoes` (relator, órgão, base, classe…), `paginacao`,
  `registros[]` com `uuid`, `identificador`, `base`/`subbase`, `processo`,
  `codigoClasseCnj`, `descricaoOrgaoJulgador`, `nomeRelator`, `dataJulgamento`,
  `dataPublicacao`, `decisao`, `ementa`, `turmaRecursal`, `segredoJustica`,
  `possuiInteiroTeor`, `marcadores` e, se pedido, `inteiroTeor` (média 38 mil caracteres).
- Volume "dano moral" (espelho, sem sinônimos, só acórdãos): 2015 5.502 · 2017 6.320 ·
  2019 6.361 · 2021 6.269 · 2023 7.979 · 2024 9.697 · 2025 11.374. Março/2024: 820.
- Amostra de 40 acórdãos (mar/2024): 11 ementas com R$; 39 inteiros teores com R$;
  classes CNJ 198 (Apelação Cível) 32, 460 (Recurso Inominado) 5.

## STJ Dados Abertos (secundária)

- 21 datasets no CKAN. Íntegras DJe: 1.285 dias (2021-01-04 → 2026-09-04), 1.288 ZIPs,
  11,2 GB; metadados incluem `assuntos` (códigos CNJ) e `teor`. Em 26/08/2026: 2.285
  registros, 412 textos (18 %), 92 com assunto de dano moral (todos monocráticos; 58 "Não
  Conhecendo"), 11 textos citam dano moral, 6 com Súmula 7, 2 com valor R$.
- Espelhos 3ª Turma maio/2026: 737; 92 com dano moral; 12 com R$. Campos ricos (tema,
  teseJuridica, referenciasLegislativas, jurisprudenciaCitada).
- Precedentes qualificados: 2.400 linhas; 58 citam dano moral na questão/tese.

## DataJud (contexto)

Só capa/movimentos. Assuntos 10433/7779/9992 (Indenização por Dano Moral — civil,
consumidor, administrativo), ajuizados 2015–2026: TJSP 282.464 · TJAL 65.093 ·
TJRS 48.957 · TJDFT 39.097 · TJMG 378 (carga incompleta). Distribuição por grau no
TJDFT: JE 21.197 · G1 12.017 · G2 4.132 · TR 1.751. **Quirk:** em TJDFT/TJAL o campo
`dataAjuizamento` é lido como `epoch_millis`; usar limites numéricos.

## Códigos CNJ de assunto (SGT)

10433 (Direito Civil > Responsabilidade Civil), 7779 (Consumidor > Responsabilidade do
Fornecedor), 9992 (Adm. > Responsabilidade da Administração), 14010/14033/1855/13195
(Trabalho — fora do escopo).

## Deflator

BCB/SGS 433 (IPCA mensal, %), JSON, sem chave.
