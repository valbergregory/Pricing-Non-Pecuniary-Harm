# Protocolo da pré-anotação por IA da validação D5 (decisão D5b, 2026-10-03)

Registro de proveniência exigido por `docs/AI_POLICY_AND_REPRODUCIBILITY.md` §2.3. Nenhum texto de
acórdão é versionado.

| Campo | Valor |
|---|---|
| Ferramenta | assistente de IA em nuvem (Claude Code, Anthropic), autorizado por escrito pelo pesquisador em 03/10/2026 |
| Versão exata do modelo | **a registrar pelo pesquisador** (consultar a interface no dia da pré-anotação) |
| Temperatura / semente | não controláveis pelo usuário na ferramenta; registrado como limitação |
| Data(s) | a preencher quando a pré-anotação for feita |
| Entrada | `planilhas/rodada_1..3.csv` em branco + fichas dos 300 itens. **Sem** `chave_NAO_ABRIR.csv` e sem a planilha de reanotação |
| Saída | `ia/rodada_<k>_IA.csv` (mesmo formato; `observacoes` = `IA[confiança]: motivo`) |
| Instruções | abaixo (versão 1) |
| Validação | o pesquisador revisa 100 % das linhas; o script 06 reporta a taxa de alteração por campo; a reanotação cega (60) mede a concordância sem sugestões |

## Instruções dadas à IA (versão 1)
1. Ler `docs/COMO_ANOTAR.md` §3 (colunas, códigos e regras 1–10) e segui-lo à risca; usar só os códigos
   permitidos e o dicionário `config/harm_types.yml` para `tipo_lesao`.
2. Ler cada ficha (dispositivo e ementa primeiro; inteiro teor quando necessário).
3. Preencher todas as colunas exceto `minutos`; valores no formato brasileiro (`10.000,00`).
4. `observacoes`: `IA[1|2|3]:` (confiança baixa/média/alta) + motivo curto; nas dúvidas, o que conferir e
   onde. Nunca nomes de partes, advogados ou magistrados.
5. Não alterar `item_id`, `rodada`, `ficha`.
