# ADR-0002 — PostgreSQL 16 com Drizzle (no lugar do Prisma)

- Situação: Aceita (06/11/2026). Substitui a proposta de Prisma do CLAUDE.md.

## Contexto

O modelo (`docs/modelagem/02-modelo-er.md`) depende de recursos do PostgreSQL que o Prisma não expressa no schema: índices únicos **parciais** com expressão (duplicidade RN09: `coalesce(credor_id::text, credor_documento)` onde o status não é rascunho nem descartada), coluna **gerada** (`planos_financeiros.selecionavel`), `CHECK`s, `citext`, `unaccent` e `pg_trgm`, além de `SELECT … FOR UPDATE` nas transições. O job de lançamento precisa nascer na **mesma transação** da aprovação (ADR-0003), o que é difícil quando o ORM controla a própria conexão e o pg-boss usa outra.

## Decisão

- **PostgreSQL 16** com as extensões `citext`, `unaccent` e `pg_trgm`.
- **Drizzle ORM** sobre `node-postgres` (`pg`). O schema fica em TypeScript em `packages/db/src/schema`, e as migrações são geradas pelo `drizzle-kit` e versionadas em SQL (`packages/db/migrations`). O que o Drizzle não gera (extensões, funções auxiliares) vai em migrações SQL escritas à mão (`drizzle-kit generate --custom`).
- Mapeamento de tipos:
  - `numeric(14,2)` é lido como texto e convertido para centavos inteiros no repositório (nunca `parseFloat`);
  - `date` em modo texto (`YYYY-MM-DD`, data civil);
  - `timestamptz` como instante em UTC.
- O índice trigram de busca por nome sem acento usa uma função `unaccent` imutável criada por migração (o `unaccent()` do PostgreSQL não é `IMMUTABLE` e não pode aparecer direto num índice).

## Consequências

- As restrições do modelo ficam no banco, revisáveis no SQL das migrações.
- Transações explícitas e compartilháveis com o pg-boss.
- O CLAUDE.md passa a citar Drizzle; o comando `pnpm db:migrate` aplica as migrações.
