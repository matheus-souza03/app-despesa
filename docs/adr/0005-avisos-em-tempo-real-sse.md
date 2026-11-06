# ADR-0005 — Avisos em tempo real por Server-Sent Events

- Situação: Aceita (06/11/2026)

## Contexto

O aprovador precisa ver "Título N lançado", "Erro ao lançar" e "Enviando ao Sienge" em qualquer tela do financeiro assim que o worker termina (RF33), e o colaborador precisa saber que uma despesa foi devolvida (RF24). O worker e a API são processos separados.

## Decisão

- Os avisos ficam gravados em `notificacoes` (decisão 5 da modelagem) e são a fonte da verdade.
- A API expõe `GET /api/eventos` como **Server-Sent Events**, autenticado pelo cookie de sessão, com um canal por usuário.
- O worker grava a notificação e chama `pg_notify('notificacoes', usuario_id)`; a API faz `LISTEN` e repassa aos clientes conectados.
- Ao (re)conectar, o PWA busca as notificações ainda não fechadas. Se a conexão cair, o próprio `EventSource` reconecta.

## Consequências

- Nada além do PostgreSQL. Comunicação de mão única, que basta para avisos, sem WebSocket.
- O proxy da hospedagem (ADR-0011) precisa deixar conexões longas abertas, sem buffer.
