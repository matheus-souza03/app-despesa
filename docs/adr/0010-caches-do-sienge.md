# ADR-0010 — Caches do Sienge e suas rotinas

- Situação: Aceita (06/11/2026)

## Contexto

As consultas (Títulos, conferência de notas, duplicidade com títulos lançados direto no Sienge) não podem gastar cota a cada abertura de tela (invariante 6.7). O `GET /bills` não traz o rateio, e o título só traz o `creditorId`.

## Decisão

- **Títulos (`titulos_sienge`, RN25):**
  - carga inicial pela API (ADR-0009, item 6);
  - lançados pelo app entram na hora, com o id do `Location` (0 requisição);
  - títulos novos pela última página do `GET /bills`, no domingo e no "Atualizar agora" (trava de 5 minutos para todo o app);
  - **títulos alterados:** 1 chamada a `GET /bills/by-change-date` por semana, na rotina de domingo, desde a última execução. Serve para atualizar valores e exclusões no cache, não para detectar baixa.
- **Credores (`credores`):** carga pelo relatório detalhado em PDF enviado pelo administrador (0 requisição; `docs/importacao-credores.md`), mais os criados pelo app e os desconhecidos buscados sob demanda (`GET /creditors/{id}`).
- **Rateio (`titulos_sienge_apropriacoes`, RN28):**
  - títulos do app gravam o rateio no lançamento;
  - o histórico vem do Excel "Contas pagas com apropriações" (0 requisição; `docs/importacao-apropriacoes.md`);
  - títulos novos lançados direto no Sienge são buscados no domingo com o que sobrar da cota.
- Toda tela lê só o banco; a API do Sienge é chamada só para atualizar o cache.

## Consequências

- A tela Títulos pode ficar até uma semana atrasada em alterações de títulos antigos, ou até o próximo "Atualizar agora" para títulos novos.
- A skill `sienge-api` deixa de proibir o `by-change-date` e passa a restringir o uso à rotina de domingo.
