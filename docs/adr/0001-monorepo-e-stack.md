# ADR-0001 — Monorepo pnpm e stack

- Situação: Aceita (06/11/2026)

## Contexto

O app tem três partes que rodam separadas: o PWA (celular e computador), a API e o worker que fala com o Sienge. As mesmas regras (leitura de chave e boleto, rateio, datas, validações V1–V8) precisam valer no front e no back (CLAUDE.md, "Regras de engenharia"). Escala pequena: de 4 a 30 usuários.

## Decisão

- **Monorepo pnpm workspaces:**
  - `apps/web`: PWA (React + Vite);
  - `apps/api`: API HTTP (Fastify);
  - `apps/worker`: fila de integração e rotinas (pg-boss);
  - `packages/shared`: regras puras, schemas Zod e tipos, **sem** acesso a banco, rede ou relógio real (as portas de `docs/modelagem/04-classes.md` §3 recebem essas dependências);
  - `packages/db`: schema Drizzle, migrações e cliente do banco, usado pela API e pelo worker (ADR-0002).
- **Node.js 24 LTS** e **TypeScript `strict`** (com `noUncheckedIndexedAccess`), ESM em todos os pacotes.
- **Front:** React, Vite, `vite-plugin-pwa`, Tailwind CSS 4 com os tokens de `docs/design-system.md`, shadcn/ui, React Router, React Hook Form + Zod, TanStack Query, Dexie (ADR-0004), leitura de código com `BarcodeDetector` e fallback `@zxing/browser`. A fonte Barlow é servida pelo próprio app (`@fontsource/barlow`), para funcionar offline.
- **Back:** Fastify; entradas validadas com os mesmos schemas Zod de `packages/shared`.
- **Testes:** Vitest (unitários e integração), Playwright (E2E dos fluxos críticos), mock HTTP da API do Sienge com as respostas reais anonimizadas.
- **Qualidade:** ESLint (typescript-eslint) e Prettier; CI no GitHub Actions (lint, typecheck, testes e build) no repositório `github.com/matheus-souza03/app-despesa`.
- **Execução:** em desenvolvimento, `tsx` para a API e o worker e PostgreSQL pelo Docker Compose; em produção, build com `tsup`, que empacota os pacotes do workspace.

## Consequências

- Uma linguagem só, e as regras de negócio testáveis sem banco, sem Sienge e sem relógio.
- `packages/shared` não pode importar nada de Node, do banco ou do navegador; o lint e o typecheck do pacote garantem isso.
- Os pacotes internos são consumidos pelo código-fonte (`exports` apontando para `src`), sem etapa de build própria.
- **TypeScript fixado na série 6.0** (06/11/2026). O TypeScript 7 (compilador nativo) não traz mais a API JavaScript que o typescript-eslint usa, e o typescript-eslint 8.72 exige `typescript < 6.1`. Revisar quando o typescript-eslint aceitar o 7.
- Versões na criação do esqueleto: Vite 8, Vitest 5, ESLint 10, React 19, Tailwind 4, Fastify 5, Drizzle 0.45, pg-boss 12, Zod 4.
