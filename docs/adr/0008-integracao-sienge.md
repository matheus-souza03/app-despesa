# ADR-0008 — Integração com o Sienge

- Situação: Aceita (06/11/2026)

## Contexto

Não existe homologação do Sienge, e toda escrita vai para produção. Títulos criados pela API (origem `SE`) não aceitam alteração pela API. O detalhe de endpoints e corpos está na skill `sienge-api`.

## Decisão

- Porta `SiengeApi` (`04-classes.md` §3) **sem nenhum método de alteração de título**: não há `PATCH` nem `PUT` em `/bills` (invariante 6.6). A única implementação HTTP é a `SiengeHttp`, que faz autenticação Basic, timeout, `trim()` dos textos, conversão de datas do Sienge (sem fuso) para São Paulo e conversão de centavos para reais só na borda.
- **Quem chama o Sienge:**
  - o worker: lançamentos, credores pendentes e rotinas;
  - a API, só em ações em que uma pessoa espera na tela: buscar ou criar credor, conferência de notas, "Atualizar agora", "Parcelas ajustadas", "Sincronizar agora" e abrir um comprovante já enviado.
  - Os dois passam pela reserva de cota (ADR-0009) e gravam `chamadas_api`.
- **Dry-run por padrão** (`SIENGE_DRY_RUN=true`): o corpo é validado com Zod e gravado, e a resposta é simulada (ids negativos). Chamadas reais exigem `SIENGE_DRY_RUN=false` explícito. Os testes usam mock HTTP e nunca desligam o dry-run.
- **Erros:**
  - `400`: recusa por dados, sem nova tentativa; número duplicado leva a buscar o título existente;
  - `401` e `403`: a fila inteira pausa e os administradores são avisados;
  - `429`, `5xx` e tempo esgotado: nova tentativa com espera crescente, seguindo a idempotência de `03-sequencias.md` S5.
- As credenciais ficam só nas variáveis de ambiente da API e do worker e nunca são logadas, assim como CPF completo e chave Pix.

## Consequências

- O bloqueio de alteração de títulos `SE` fica garantido pelo próprio tipo da porta.
- Os primeiros lançamentos reais são acompanhados pela Camilla (RNF07).
