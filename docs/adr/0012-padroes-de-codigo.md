# ADR-0012 — Padrões de código: idioma, dinheiro e datas

- Situação: Aceita (06/11/2026)

## Decisão

- **Idioma:** o domínio fica em português sem acento, como em `docs/modelagem/`: tabelas, colunas, entidades, regras, eventos e rotas da API (`/api/despesas/{id}/envio`). Termos técnicos genéricos podem ficar em inglês (`handler`, `repository`, `client`, `config`). A interface e as mensagens são em português do Brasil, com os textos das features.
- **Dinheiro:**
  - centavos como `number` **inteiro** no código (todo valor de `numeric(14,2)` cabe num inteiro seguro de JavaScript), validado com `Number.isSafeInteger`;
  - conversão de texto para centavos na borda do banco, e de centavos para reais com ponto decimal na borda do Sienge;
  - nunca `parseFloat` em valor de dinheiro;
  - percentuais de rateio com aritmética decimal exata (biblioteca decimal), 12 casas (RN05). Isso substitui o `bigint` citado em `04-classes.md`.
- **Datas:** datas de negócio são texto `YYYY-MM-DD` (data civil, sem fuso), calculadas sem `Date` local. O "hoje" vem sempre da porta `Relogio`, no fuso America/Sao_Paulo. Instantes técnicos são `timestamptz` em UTC.
- **TDD** em `packages/shared`: o teste vem antes da regra, com os casos reais da SPEC §13 e das features.
- **Auditoria:** toda transição grava `eventos_despesa`; a função de transição devolve o evento e a camada de aplicação grava os dois na mesma transação.
