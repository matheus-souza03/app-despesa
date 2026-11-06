# App de Despesas → Sienge

Web app (PWA, mobile-first) para colaboradores enviarem compras pelo celular ou pelo computador. Um aprovador revisa e, com um clique, o sistema cria o título no **Contas a Pagar do Sienge** (ERP) via API e anexa os comprovantes. A baixa continua sendo feita no Sienge (a API não permite baixa).

Objetivo de negócio: hoje a única pessoa do financeiro (Camilla) lança manualmente ~66 compras/dia (~40% do dia dela), recebidas por WhatsApp e planilha. O app descentraliza a digitação e deixa para o financeiro apenas a conferência.

- Especificação completa (requisitos, regras de negócio, leitura de códigos, estados): `docs/SPEC.md` — leia antes de implementar qualquer regra de negócio.
- O que está em aberto: `PENDENCIAS.md`. Não implemente por suposição um item que esteja lá: pergunte.
- Telas aprovadas: `docs/telas/` (imagens e índice por perfil); visual e componentes: `docs/design-system.md`.
- Importações de arquivos do Sienge: credores (`docs/importacao-credores.md`) e rateio dos títulos (`docs/importacao-apropriacoes.md`); amostras para testes em `data/fixtures/`.
- Modelagem: `docs/modelagem/` — estados e transições (01), modelo ER e dicionário de dados (02), sequências dos fluxos com o Sienge (03), classes do domínio e portas (04). O schema do banco e a máquina de estados seguem esses documentos.
- Integração com o Sienge: use a skill `sienge-api` (`.claude/skills/sienge-api/SKILL.md`) sempre que tocar em código que chama a API do Sienge.

## Stack (decidida nos ADRs em `docs/adr/`)

- Monorepo pnpm: `apps/web` (React + TS + Vite, PWA), `apps/api` (Node + TS, Fastify), `apps/worker` (fila de integração), `packages/shared` (schemas Zod, tipos, regras puras, parsers de código; sem I/O), `packages/db` (schema Drizzle, migrações e cliente do banco).
- Front: Tailwind, shadcn/ui, React Hook Form + Zod, TanStack Query, Dexie (fila offline em IndexedDB), leitura de código via `BarcodeDetector` com fallback `@zxing/browser`.
- Back: PostgreSQL 16, Drizzle (ADR-0002), pg-boss (fila sobre o Postgres, job criado na transação da aprovação, ADR-0003), storage para os comprovantes **temporário** (só até o envio ao Sienge, ADR-0006), avisos por SSE (ADR-0005), sessão em cookie httpOnly e e-mail pelo SMTP da Locaweb (ADR-0007).

## Comandos

- `pnpm install`: dependências (Node 24 e pnpm 9; `.nvmrc`). Copie `.env.example` para `.env`.
- `pnpm db:up` / `pnpm db:down`: PostgreSQL 16 local (Docker Compose). `pnpm db:generate` gera a migração a partir do schema Drizzle; `pnpm db:migrate` aplica.
- `pnpm dev`: web (Vite em http://localhost:5173, com proxy de `/api`), API (http://localhost:3000) e worker, lendo o `.env` da raiz. O worker precisa do banco no ar.
- `pnpm test` (Vitest em todos os pacotes), `pnpm typecheck`, `pnpm lint`, `pnpm format:check` e `pnpm build`: o mesmo que o CI roda (`.github/workflows/ci.yml`).
- O TypeScript fica na série 6.0: o typescript-eslint ainda não aceita o TypeScript 7 (ADR-0001).

Testes manuais da API do Sienge (fora do app): `scripts/sienge-probe.mjs` (Node 18+, credenciais por variável de ambiente; respostas salvas em `respostas/`, fora do git). Variáveis de ambiente do projeto: `.env.example`.

## Invariantes de negócio (nunca violar)

1. Nada vai ao Sienge sem aprovação de um usuário com o perfil **aprovador** (hoje só a Camilla). Colaboradores e aprovador de centro de custo nunca disparam integração. Perfis: colaborador de rua, colaborador de escritório, aprovador de centro de custo, aprovador; administrador é uma marcação à parte (SPEC §3).
2. Soma das apropriações (centro de custo × plano financeiro) = valor total do título. Soma das parcelas = valor total. Validar no front **e** no back.
3. Tipo de documento e credor seguem a matriz da SPEC (RN01): o comprovante decide (NF-e/NFC-e → DANF, NFS-e → NFSE, recibo → REC, credor = emitente); sem comprovante, decide a forma de pagamento: reembolso → REMB (credor indicado pelo usuário ou, sem indicação, o colaborador); cartão, Pix ou boleto → PAG (fornecedor).
3.1. Um título só usa centros de custo da própria empresa; só aparecem CCs vinculados a alguma empresa.
4. Data contábil = data de emissão. Data base/competência = dia 1 do mês da emissão. Compra já paga: vencimento = data do pagamento. Esses campos são calculados, não digitados.
5. Nunca lançar duplicado: chave de acesso é única; sem chave, checar credor + número + data + valor.
6. O sistema nunca pode ficar sem pelo menos um administrador e um aprovador ativos.
6.1. Colaborador não edita nem exclui despesa pendente; só edita despesa DEVOLVIDA.
6.2. Cota da API: 100 requisições/dia. Toda chamada ao Sienge passa pelo contador diário; não adicione chamadas extras (consultas de conferência, sync frequente) sem justificar o custo. Prioridade `PESSOA` > `LANCAMENTO` > `ROTINA`; rotinas automáticas que chamam o Sienge só aos domingos; lançamento sem cota sai no dia seguinte (ADR-0009).
6.3. `notes` (observação) = texto livre do usuário; sem texto, enviar `" "` (um espaço). Nada é acrescentado automaticamente.
6.4. Títulos criados pela API nascem com parcelas não autorizadas; a autorização e a baixa são feitas no Sienge. O app só acompanha (tela "Baixas pendentes"); na v1, "Já dei baixa" só marca no app, sem consultar o Sienge (ADR-0009).
6.5. Anexo só é apagado do storage depois do `201` do Sienge para aquele anexo; nunca antes. Depois do lançamento o app não guarda o arquivo (SPEC RN22).
6.6. Título criado pela API não pode ser alterado pela API (origem `SE`): nada de `PATCH`/`PUT` em `/bills`. Correções depois do lançamento são feitas no Sienge.
6.7. Consultas de títulos leem o cache local (`titulos_sienge`, SPEC RN25); a API do Sienge só é chamada para atualizar o cache, nunca a cada abertura de tela.
7. Campos de credor enviados ao Sienge passam por sanitização (o Sienge rejeita caracteres especiais).

## Regras de engenharia

- TypeScript `strict`. Schemas Zod em `packages/shared` são a fonte única de validação (front e back).
- Lógica pura (parsers de chave/boleto, cálculo de datas, validação de rateio) vive em `packages/shared` com testes unitários — escreva o teste primeiro.
- Dinheiro em centavos (`integer`) no código; `numeric(14,2)` no banco; percentual de rateio `numeric(15,12)`. Nunca `float`.
- Datas de negócio são datas civis (`YYYY-MM-DD`, fuso America/Sao_Paulo), não timestamps.
- **Não existe ambiente de homologação do Sienge.** Toda chamada real exige `SIENGE_DRY_RUN=false` explícito; o padrão é dry-run (loga o payload e não envia). Testes usam mock da API.
- Nunca logar credenciais, CPF completo ou chave Pix. Credenciais do Sienge só no backend/worker, via env.
- UI e mensagens em português do Brasil. Nomes do domínio (tabelas, colunas, entidades, regras) em português, sem acento, como em `docs/modelagem/`; termos técnicos genéricos podem ficar em inglês. (ADR-0012.)
- Toda mudança de status de despesa gera registro de auditoria (quem, quando, de → para).
