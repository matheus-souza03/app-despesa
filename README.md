# App de Despesas → Sienge

PWA para os colaboradores da Senco Engenharia registrarem compras pelo celular ou pelo computador. O financeiro revisa e, com um clique, o app cria o título no Contas a Pagar do Sienge pela API e anexa os comprovantes.

Situação (06/11/2026): requisitos, testes da API, histórias, fluxos, wireframes, modelagem e decisões de arquitetura (`docs/adr/`) concluídos; esqueleto do monorepo criado. Próxima etapa: regras puras em `packages/shared` (etapa 3). Tudo o que está em aberto: `PENDENCIAS.md`.

## Mapa dos arquivos

| Caminho | Conteúdo |
|---|---|
| `CLAUDE.md` | Contexto e invariantes que o Claude Code carrega em toda sessão |
| `PENDENCIAS.md` | Tudo o que falta decidir, testar ou desenhar |
| `docs/SPEC.md` | Especificação: perfis, requisitos (RF), regras de negócio (RN), leitura de códigos, limitações da API |
| `docs/modelagem/` | Estados (01), modelo ER e dicionário de dados (02), sequências com o Sienge (03), classes do domínio (04) |
| `docs/adr/` | Decisões de arquitetura (ADRs), uma por arquivo |
| `docs/arquitetura/c4.md` | Diagramas C4 níveis 1 e 2 (contexto e containers) |
| `docs/fluxos/` | Fluxos de usuário do cadastro e da aprovação (Mermaid) |
| `docs/telas/` | Imagens das 23 telas aprovadas, com índice por perfil e requisitos; `fonte/` tem o HTML dos wireframes |
| `docs/design-system.md` | Cores, tipografia, tamanhos e componentes |
| `docs/importacao-credores.md` | Leitura do relatório de credores (PDF) exportado do Sienge |
| `docs/importacao-apropriacoes.md` | Leitura do relatório "Contas pagas com apropriações" (Excel) |
| `features/` | 14 funcionalidades em Gherkin (cerca de 290 cenários): critérios de aceite e base dos testes |
| `.claude/skills/sienge-api/SKILL.md` | Como falar com a API do Sienge: endpoints, corpos, formatos reais das respostas, limitações e descobertas |
| `data/municipios-sienge.csv` | Códigos de município do Sienge (5.570) |
| `data/planos-financeiros-liberados.json` | Planos financeiros escolhidos pelos aprovadores para aparecer no app (carga inicial) |
| `data/fixtures/` | Amostras reais sem dados pessoais para testes (relatório de credores e de contas pagas) |
| `assets/marca/` | Logo da Senco |
| `scripts/sienge-probe.mjs` | Testes manuais da API (GET, POST, PATCH, anexos), com respostas anonimizadas |
| `scripts/exportar-planos.mjs` | Exporta todos os planos financeiros (CSV e JSON) em 1 requisição |
| `apps/`, `packages/` | Código: `web` (PWA), `api`, `worker`, `shared` (regras puras) e `db` (schema Drizzle) |
| `docker-compose.yml` | PostgreSQL 16 local para desenvolvimento |
| `.env.example` | Variáveis de ambiente (copie para `.env`, que não vai para o git) |
| `extras/` | Painel do Power BI (`dashboard-powerbi/`) e a apresentação dos wireframes (desatualizada) |

## Como continuar no Claude Code (VS Code)

1. Clone o repositório (`github.com/matheus-souza03/app-despesa`) e abra a pasta no VS Code. O `.gitignore` já deixa de fora `.env`, os anexos locais e as respostas dos testes da API.
2. Abra o Claude Code nessa pasta. Ele lê o `CLAUDE.md` automaticamente e encontra a skill `sienge-api` em `.claude/skills/`.
3. Nunca coloque usuário e senha da API do Sienge em arquivos versionados: use variáveis de ambiente ou o `.env`.
4. Trabalhe uma etapa por sessão, sempre pedindo para ler os documentos da etapa antes de escrever código.

### Ordem sugerida das sessões

| # | Etapa | O que pedir | Ler antes |
|---|---|---|---|
| 1 | Arquitetura (concluída) | C4 níveis 1 e 2 e um ADR por decisão da seção 4 do `PENDENCIAS.md`, em `docs/adr/` | `CLAUDE.md`, `docs/SPEC.md`, `docs/modelagem/` |
| 2 | Base do monorepo (esqueleto criado) | pnpm workspaces, TypeScript strict, Vitest, lint e CI | ADRs |
| 3 | Regras puras | `packages/shared` com TDD: dinheiro, chave de acesso, boleto, número da nota, rateio, datas, tipo de documento, parcelas, duplicidade, sanitização, busca de centro de custo, máquina de estados | `docs/modelagem/04-classes.md`, `01-estados.md`, features |
| 4 | Banco | Schema do Drizzle, migrações e carga dos municípios | `docs/modelagem/02-modelo-er.md` |
| 5 | Cliente do Sienge | Porta `SiengeApi`, implementação HTTP com dry-run e reserva de cota, mock para testes | skill `sienge-api`, `03-sequencias.md` |
| 6 | Acesso | Login, sessões, perfis e usuários | `login.feature`, `gestao-usuarios.feature`, `meu-usuario.feature` |
| 7 | Cadastros e caches | Sincronização (empresas, centros, planos, documentos), importação de credores e do rateio, carga e rotina de domingo dos títulos | `configuracoes.feature`, `docs/importacao-*.md` |
| 8 | Despesas | Cadastro (celular e computador), leitura de código, credor, envio offline, status, lixeira | `cadastro-titulo.feature`, `cadastro-credor.feature`, `status-despesas.feature`, `docs/telas/` |
| 9 | Aprovação e lançamento | Fila de centro de custo, aprovação, worker de lançamento, anexos, avisos, erros | `definir-centro-custo.feature`, `aprovacao-titulo.feature`, `integracao-sienge.feature` |
| 10 | Financeiro | Títulos, conferência de notas, baixas pendentes, faturas a vencer, planos financeiros | `consulta-titulos.feature`, `conferencia-notas.feature`, `baixas-pendentes.feature`, `planos-financeiros.feature` |

Ao fim de cada etapa: revisar o resultado contra as features da etapa e atualizar o `PENDENCIAS.md`.

### Testes da API do Sienge

```bash
export SIENGE_USER='usuario-de-api'
read -s SIENGE_PASS && export SIENGE_PASS
node scripts/sienge-probe.mjs gets
node scripts/exportar-planos.mjs
```

No Windows (PowerShell): `$env:SIENGE_USER='usuario-de-api'` e `$env:SIENGE_PASS='...'` no lugar do `export`. Cada chamada gasta 1 das 100 requisições do dia; os comandos de escrita (`post`, `patch`, `attach`) gravam no Sienge de produção e exigem `--confirmo`.
