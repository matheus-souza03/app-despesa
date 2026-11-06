# ADR-0004 — PWA com fila offline e idempotência pelo id do cliente

- Situação: Aceita (06/11/2026)

## Contexto

Quem compra na rua pode estar sem sinal (RF14, RNF02). A despesa e os arquivos precisam sobreviver no aparelho até a conexão voltar, sem criar duplicatas quando o envio é repetido.

## Decisão

- Service worker gerado pelo `vite-plugin-pwa` (Workbox) para o *app shell*; os dados vêm da API pelo TanStack Query.
- **Fila local em IndexedDB com Dexie:** despesa, anexos (`Blob`) e o pedido de envio. "Aguardando envio" é um estado só do aparelho (`01-estados.md` §1.1).
- O id da despesa e de cada anexo é gerado no aparelho (`crypto.randomUUID()`). O servidor trata como upsert `PUT /api/despesas/{id}` e `PUT /api/despesas/{id}/anexos/{anexoId}`, e repetir `POST /api/despesas/{id}/envio` numa despesa já enviada devolve o estado atual (S1).
- Reenvio quando a conexão volta (evento `online`), quando o app abre e periodicamente enquanto houver itens na fila. A Background Sync API não é usada como mecanismo principal, porque o Safari não a oferece.
- As validações V1–V8 rodam no aparelho com `packages/shared` e de novo no servidor.

## Consequências

- O servidor precisa ser idempotente em todas as rotas de escrita da despesa.
- No iPhone, o IndexedDB de sites não instalados pode ser apagado depois de dias sem uso: o app orienta a instalar na tela inicial.
- A sessão expirada com itens na fila não perde os itens (`login.feature`, "Sessão expirada com despesas aguardando envio").
