# Registro de decisões

| ID | Data | Decisão | Justificativa | Status |
|---|---|---|---|---|
| D0 | 2026-09-04 | Projeto **somente em R** (coleta, banco DuckDB, modelagem, artigo Quarto) | decisão do pesquisador (divisão do portfólio) | fechada |
| D1 | 2026-09-05 | Fonte principal = API JurisDF/TJDFT com inteiro teor; jurisdição única (DF), 2015–2025 | única fonte pública com API, sem chave/cota, que devolve ementa + inteiro teor; ~5,5k–11,4k acórdãos/ano; 39/40 inteiros teores com R$ no piloto | proposta — aguarda aprovação |
| D2 | 2026-09-05 | TJSP (e-SAJ), TJMG (401), TJAL (503), SCON/STJ (403) descartados como fonte primária; TJRS (Solr) fica como replicação futura | sem API; scraping sensível a sessão/CAPTCHA; regra de não usar portais que exigem sessão | proposta |
| D3 | 2026-09-05 | STJ entra como fonte secundária (íntegras + espelhos das 3ª/4ª Turmas) para a subamostra de valores revisados apesar da Súmula 7, e temas.csv como calendário de eventos (RQ4) | STJ raramente revisa quantum (11/412 textos com dano moral, 2 com R$ em 26/08/2026) — insuficiente como fonte principal, útil como contraste | proposta |
| D4 | — | Mês-base do deflacionamento (dez/2025) e uso adicional de múltiplos de salário-mínimo | comparabilidade intertemporal; SM é âncora usada por juízes | pendente |
| D5 | 2026-09-05 | Validação do extrator por anotação humana cega (300 acórdãos, 3 rodadas; reanotação de 60) com limiar F1 ≥ 0,90 para o valor final | evita que erro de extração vire "resultado"; um único anotador exige concordância intra-avaliador | proposta |
| D6 | — | Confirmar termos de uso/limites de requisição do JurisDF (não localizados) e definir cadência (1 req/s, janelas mensais, retomada idempotente) | cortesia com serviço público; 80k+ acórdãos ≈ 2.100 páginas com inteiro teor (~4 GB de JSON) | pendente — Valber |
| D7 | 2026-09-05 | Inteiro teor armazenado só em `data/raw` (fora do Git) e no DuckDB local; nenhum campo com nome de parte; publicação agregada | LGPD art. 7º §3º (dado tornado público) + finalidade acadêmica | proposta |
| D8 | — | Inclusão das Turmas Recursais (`acordaos-tr`) na amostra principal ou como estrato separado | ampliam cobertura de causas de menor valor, mas rito e composição diferem | pendente |
| D9 | 2026-09-05 | Piloto = março/2024 (820 acórdãos), diagnóstico de extração; nenhuma estatística do piloto entra no artigo | separar viabilidade de resultado | fechada |
