# ADR-0007 — Autenticação, sessões e recuperação de senha

- Situação: Aceita (06/11/2026)

## Contexto

Login por e-mail e senha definida pelo administrador, sem autocadastro (RF01). A sessão dura enquanto houver uso, com expiração após 30 dias de inatividade, e há bloqueio depois de 5 tentativas erradas por 15 minutos (`login.feature`). Trocar a senha encerra as outras sessões (RN19). A RNF03 pede cookie httpOnly. A Senco já tem SMTP na Locaweb.

## Decisão

- **Sessão opaca:** token aleatório de 32 bytes num cookie `httpOnly`, `Secure`, `SameSite=Lax`. O banco guarda só o hash (`sessoes.token_hash`). A expiração desliza com o uso (30 dias de inatividade), e a sessão é revogada na troca de senha, na desativação do usuário e no "Sair".
- **Senhas:** Argon2id, com as regras da RN19 em `packages/shared`.
- **CSRF:** `SameSite=Lax`, verificação do cabeçalho `Origin` nas rotas de escrita e corpo JSON obrigatório.
- **Bloqueio por tentativas:** contador por e-mail e IP, conforme `login.feature`.
- **Autorização** no backend em toda rota: perfil, marcação de administrador, empresa e centro de custo (RNF03).
- **Recuperação de senha:** token de uso único com validade de 1 hora (`tokens_senha`), enviado por e-mail pelo **SMTP da Locaweb** (nodemailer) atrás da porta `EnviadorEmail`. Em desenvolvimento, uma implementação que só escreve no log; em produção, nunca.

## Consequências

- Variáveis novas: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` e `APP_URL` (base do link).
- A hospedagem precisa liberar a saída para a porta SMTP da Locaweb (alguns provedores bloqueiam).
