# ADR-0011 — Hospedagem e ambientes

- Situação: **Proposta** (06/11/2026). Decidir antes do piloto.

## Contexto

Em avaliação: uma VPS com Docker Compose ou AWS (ou outro serviço em nuvem). O desenvolvimento começa local.

## Decisão (até agora)

- **Local:** Docker Compose com PostgreSQL 16 (`docker-compose.yml`). A API, o worker e o web rodam com `pnpm dev`, e os anexos ficam em disco (`STORAGE_PATH`).
- **Requisitos que a opção escolhida precisa cumprir:**
  - HTTPS com domínio próprio;
  - PostgreSQL 16 com `citext`, `unaccent` e `pg_trgm`, backup diário (RNF09) e restauração testada;
  - disco persistente (ou S3 compatível, ADR-0006) para os anexos temporários;
  - agendamento das rotinas no fuso America/Sao_Paulo;
  - segredos fora do git;
  - saída liberada para o SMTP da Locaweb;
  - proxy que mantenha conexões SSE abertas (ADR-0005).
- **Ambientes:** local; homologação sempre em dry-run; produção, a única com `SIENGE_DRY_RUN=false`.

## Pendente

Escolher o provedor, o domínio, onde ficam os backups e quem administra o servidor.
