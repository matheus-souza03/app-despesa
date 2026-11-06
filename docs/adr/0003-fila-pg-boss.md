# ADR-0003 — Fila de jobs no Postgres (pg-boss)

- Situação: Aceita (06/11/2026)

## Contexto

Aprovar uma despesa (T3, T7) precisa enfileirar o lançamento de forma atômica: não pode existir despesa `APROVADA` sem job, nem job sem aprovação. O volume é pequeno, e o projeto não tem outra infraestrutura além do PostgreSQL.

## Decisão

- **pg-boss** no mesmo banco (schema `pgboss`, fora do modelo de dados do app).
- O job é criado **dentro da transação** que muda o estado da despesa, usando o adaptador de banco do pg-boss no `send` (o SQL roda no mesmo `client` da transação do Drizzle).
- Filas previstas:
  - `lancar-despesa`: uma por despesa, com `singletonKey` = id da despesa, concorrência 1 e ordem de aprovação;
  - `apagar-anexo`: só depois do `201`, RN22;
  - `criar-credor-pendente`;
  - `rotinas-domingo`: agendada, ADR-0009;
  - `limpeza-diaria`: lixeira de 30 dias e arquivos órfãos, sem chamadas ao Sienge;
  - `carga-titulos`, `importar-credores` e `importar-rateio`.
- O worker é o único consumidor. Espera por cota **não** conta como tentativa: o job é reagendado (`startAfter`) para o próximo dia de cota (ADR-0009). Falhas temporárias seguem T14 (até 5 tentativas, espera crescente).

## Consequências

- Sem Redis nem serviço de fila extra; a fila entra no backup do banco.
- A retomada após queda do worker depende da idempotência descrita em `03-sequencias.md` S5.
