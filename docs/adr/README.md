# Decisões de arquitetura (ADRs)

Um arquivo por decisão: contexto, decisão e consequências. Decisão nova ou mudança de decisão = ADR novo (o antigo fica com a situação "Substituída por ADR-NNNN"). As decisões de 06/11/2026 vieram da revisão do projeto antes do início do código.

| ADR | Decisão | Situação |
|---|---|---|
| [0001](0001-monorepo-e-stack.md) | Monorepo pnpm e stack | Aceita |
| [0002](0002-banco-postgres-e-drizzle.md) | PostgreSQL 16 com Drizzle (no lugar do Prisma) | Aceita |
| [0003](0003-fila-pg-boss.md) | Fila de jobs no Postgres (pg-boss), com o job criado na transação da aprovação | Aceita |
| [0004](0004-pwa-offline-e-idempotencia.md) | PWA com fila offline (Dexie) e idempotência pelo id gerado no cliente | Aceita |
| [0005](0005-avisos-em-tempo-real-sse.md) | Avisos em tempo real por Server-Sent Events | Aceita |
| [0006](0006-storage-temporario-dos-anexos.md) | Storage temporário dos anexos atrás de uma porta (disco local por enquanto) | Aceita |
| [0007](0007-autenticacao-e-senhas.md) | Sessão em cookie httpOnly, Argon2id e recuperação por e-mail (SMTP da Locaweb) | Aceita |
| [0008](0008-integracao-sienge.md) | Integração com o Sienge: porta sem alteração de títulos, dry-run padrão, idempotência | Aceita |
| [0009](0009-cota-da-api.md) | Cota da API: prioridade por tipo, lançamentos no dia seguinte, rotinas aos domingos, baixa manual na v1 | Aceita |
| [0010](0010-caches-do-sienge.md) | Caches do Sienge (títulos, credores, rateio) e suas rotinas | Aceita |
| [0011](0011-hospedagem.md) | Hospedagem e ambientes | Proposta |
| [0012](0012-padroes-de-codigo.md) | Padrões de código: idioma, dinheiro e datas | Aceita |

Visão geral (C4 níveis 1 e 2): [`docs/arquitetura/c4.md`](../arquitetura/c4.md).
