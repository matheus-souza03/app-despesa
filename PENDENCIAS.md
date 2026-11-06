# Pendências — App de Despesas → Sienge

Situação em 06/11/2026 (atualizada com as decisões de arquitetura). Fase atual: **wireframes em verificação pela equipe; modelagem e ADRs concluídos; esqueleto do monorepo criado; próxima etapa: regras puras (`packages/shared`)**. Marque `[x]` ao resolver e registre a decisão no documento indicado.

## 1. Com a equipe e a Camilla

- [ ] **Verificação dos wireframes:** a equipe está com uma cópia da apresentação para apontar ajustes. Atenção: a apresentação (`extras/apresentacao/`) é anterior aos perfis de rua e escritório; as telas atuais estão em `docs/telas/`.
- [ ] **Relatório de credores:** dá para exportar só os credores ativos? → `docs/importacao-credores.md`
- [ ] **Rateio dos títulos em aberto:** existe o relatório de contas a pagar **em aberto** com apropriações, no mesmo formato do de contas pagas? → SPEC RN28, `docs/importacao-apropriacoes.md`
- [ ] **Histórico do rateio:** exportar "Contas pagas com apropriações" do período inteiro (desde 2023, todas as empresas), num arquivo ou em um por ano.
- [ ] **Parâmetros provisórios:** margem de 3 dias da conferência de notas (`CONFERENCIA_MARGEM_DIAS`) e reserva de 10 requisições por dia para ações de pessoas (`COTA_RESERVA_PESSOAS`, ADR-0009). O intervalo de 12 horas das baixas saiu da v1 (baixa confirmada só no app).
- [x] **"Já dei baixa" por engano:** o app pede confirmação antes de tirar o título da lista (decidido em 06/11/2026). → ADR-0009, `baixas-pendentes.feature`
- [ ] **RF31:** confirmar o aviso "Este pagamento pode já estar lançado" no cadastro do colaborador (proposta que já está nos wireframes).

## 2. Softplan e serviços externos

- [ ] **Cota da API (principal risco do projeto):** 100 requisições por dia comportam cerca de 30 a 45 lançamentos; a demanda estimada é de cerca de 66 por dia. Pedir pacote maior ou preço do excedente. → SPEC §8
- [ ] (Opcional) Permissão para alterar pela API títulos de origem `SE`: permitiria enviar parcelas diferentes sem ajuste manual. → SPEC RF13
- [ ] (Baixa prioridade) A API aceita CNPJ alfanumérico? → SPEC §7.5
- [x] Provedor de e-mail para a recuperação de senha (RF01): SMTP da Locaweb (ADR-0007).
- [ ] **Caixa remetente dos e-mails do app:** a Senco usa a caixa de e-mail hospedada na Locaweb (`email-ssl.com.br`, porta 465, SSL/TLS). Falta escolher ou criar a caixa (sugestão: uma dedicada, como `naoresponda@sencoengenharia.com.br`). O endereço e a senha vão só no `.env` do servidor (`SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`), nunca no git. Só é necessário quando a recuperação de senha for implementada (etapa 6).
- [ ] **Cota:** em que horário (e fuso) o contador diário do Sienge reinicia, e qual resposta a API dá quando a cota acaba (`429`?). → ADR-0009

## 3. API do Sienge — confirmar no primeiro uso real ou em teste

Detalhes e contexto em `.claude/skills/sienge-api/SKILL.md`, seção "A confirmar no spike".

- [x] `stateRegistrationNumber: " "` direto no `POST /creditors`: aceito (confirmado em 06/11/2026). O plano B com `"ISENTO"` foi removido; o cadastro de credor custa 1 requisição.
- [ ] Onde fica o centavo de sobra na divisão automática das parcelas.
- [ ] Anexar arquivo em título lançado pela tela do Sienge (origem `CP`), usado na conferência de notas.
- [ ] Dar baixa altera o `changedDate` do título? (otimização da RN20; só interessa para a versão futura da conferência de baixa)
- [ ] Precisão aceita no `percentage` das apropriações.
- [ ] Limites de período do `GET /bills` e do `GET /bills/by-change-date`.
- [ ] Valores de `type` e `defaultFlag` da chave Pix do credor (só se o credor do colaborador receber Pix pelo cadastro).

## 4. Arquitetura (decisões em `docs/adr/`, 06/11/2026)

- [x] C4 níveis 1 e 2 (`docs/arquitetura/c4.md`).
- [x] ADRs 0001 a 0010 e 0012: stack e monorepo, Drizzle no lugar do Prisma, pg-boss na transação da aprovação, PWA offline, SSE, storage temporário, autenticação, integração com o Sienge, cota (prioridade por tipo, lançamentos no dia seguinte, rotinas aos domingos, baixa manual na v1), caches e padrões de código.
- [x] Idioma do código: domínio em português (ADR-0012).
- [x] Centros de custo do administrador: a marcação de administrador libera todos os CCs da empresa, qualquer que seja o perfil (V5).
- [ ] **Hospedagem** (ADR-0011, proposta): VPS com Docker Compose ou AWS; domínio, backups e quem administra o servidor.
- [ ] Modelagem de ameaças (STRIDE) e LGPD: acesso por centro de custo e por despesa, uploads, CPF e chave Pix, credenciais do Sienge.

## 5. Planejamento da implementação

- [ ] Backlog do MVP em ordem de dependência (sugestão no `README.md`).
- [ ] Definition of Done e estratégia de testes: TDD em `packages/shared`, integração com mock do Sienge, E2E (Playwright) nos fluxos críticos.
- [ ] CI (GitHub Actions): workflow criado (`.github/workflows/ci.yml`), falta o primeiro push para `github.com/matheus-souza03/app-despesa`. Ambientes: local, homologação em dry-run e produção (ADR-0011).
- [ ] Plano de implantação: carga inicial dos títulos (83 requisições num dia sem lançamentos), importação dos credores e do rateio, piloto com 2 ou 3 colaboradores, WhatsApp em paralelo.

## 6. Telas sem wireframe

Decidido em 06/11/2026: serão montadas direto no código, seguindo `docs/design-system.md` e as telas vizinhas, e revisadas com o app rodando.

- [ ] **Lixeira** (celular e computador): lista, recuperar, excluir definitivamente e data da exclusão automática (RN26).
- [ ] **Configurações:** área para enviar os arquivos do Sienge (credores e rateio dos títulos), com o resultado da importação.
- [ ] **Erros:** botão "Resolvido no Sienge" no erro com título já criado (T19).
- [ ] **Status:** grupo "Aguardando centro de custo" para o colaborador de rua.
- [ ] **Recuperação de senha** (link "Esqueci minha senha" do login).
- [ ] **Avisos de lançamento** vermelho (erro) e amarelo (enviando); só o verde foi desenhado.
- [ ] **Novo usuário:** formulário de criação (hoje só existe a edição).

## 7. Documentação

- [ ] Os exemplos das features usam nomes antigos (Maria Souza, João Pereira, Carlos Lima); os wireframes usam os novos (Matheus Souza, Victor Rodrigues, Claudio Marcos, Pedro, Gledson, Marcos Bento). Só cosmético.
- [x] Preencher a seção "Comandos" do CLAUDE.md quando o monorepo existir.
- [ ] Gerar de novo a apresentação com as telas atuais, se for apresentar outra vez.

## 8. Versões futuras (decididas fora da v1)

- Conferência da baixa no Sienge pelas parcelas (RN20 original: ao abrir a tela, no "Já dei baixa" e na rotina de domingo), se sobrar cota (ADR-0009).
