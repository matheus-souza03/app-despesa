# Fluxo de usuário — Aprovação de título (aprovador, desktop)

Referências: `features/aprovacao-titulo.feature`, `features/baixas-pendentes.feature`, `features/integracao-sienge.feature`, SPEC §4, RF20–RF22, RF29, RN15, RN20.

Legenda: retângulo = tela ou ação do usuário; losango = decisão; arredondado = início ou fim; tracejado = acontece fora do app.

## 1. Revisão e decisão

```mermaid
flowchart TD
  inicio(["Abre a tela Aprovação"]) --> painel["Painel de pendentes: mais antigas primeiro; filtros por status, empresa, centro de custo, colaborador, credor e período"]
  painel --> abre["Abre uma despesa: comprovantes ao lado; campos lidos de código marcados; valores alterados pelo colaborador com o valor original"]
  abre --> outro{"Outro aprovador já decidiu?"}
  outro -->|Sim| avisoOutro["Aviso: já aprovada ou devolvida por outro aprovador"] --> painel
  outro -->|Não| credor{"Credor cadastrado no Sienge? (app busca de novo)"}
  credor -->|Não| bloqueio["Botão Lançar desativado: cadastre o credor antes de lançar"]
  bloqueio --> cadCredor(["Fluxo de cadastro de credor, sem sair da revisão"]) --> decisao
  credor -->|Sim| decisao{"O que fazer? (aviso: depois de lançado, só se corrige no Sienge)"}
  decisao -->|Lançar| lancar["Despesa Aprovada: entra na fila de envio"]
  decisao -->|Editar| editar["Corrige campos; histórico registra quem, quando, antes e depois"] --> abre
  decisao -->|Devolver| motivo{"Motivo preenchido?"}
  motivo -->|Não| pedeMotivo["Mensagem: informe o motivo da devolução"] --> motivo
  motivo -->|Sim| devolvida(["Despesa Devolvida: colaborador é notificado"])
  decisao -->|Deixar para depois| depois(["Continua pendente, marcada para revisar depois"])
  lancar --> envio(["Segue para o fluxo 2"])
```

## 2. Depois de lançar

```mermaid
flowchart TD
  fila["Fila de envio: ordem de aprovação, contador da cota diária"] --> cota{"Cota do dia suficiente?"}
  cota -->|Não| amanha["Aviso: limite diário do Sienge atingido; envia amanhã"] --> fila
  cota -->|Sim| envio["Worker cria o título, grava o número e envia os anexos"]
  envio --> resultado{"Resultado"}
  resultado -->|Falha temporária| retry["Até 5 tentativas com espera"] --> resultado
  resultado -->|Erro de dados| erro["Despesa com Erro: mensagem do Sienge na lista de erros"]
  erro --> acaoErro{"Tentar de novo ou editar?"}
  acaoErro -->|Tentar de novo| fila
  acaoErro -->|Editar| pendente(["Volta para pendente: fluxo 1"])
  resultado -->|Sucesso| lancada["Despesa Lançada; anexos apagados do app"]
  lancada --> autorizar["No Sienge: autorizar as parcelas (todo título da API nasce não autorizado)"]
  lancada --> paga{"Nota marcada como paga?"}
  paga -->|Sim| baixas["Aparece em Baixas pendentes: número do título, credor e data do pagamento em destaque"]
  baixas --> baixaSienge["No Sienge: dar a baixa"] --> confere["App confere no Sienge e tira da lista"]
  paga -->|Não| ajuste{"Parcelas diferentes?"}
  ajuste -->|Sim| faturas["Faturas a vencer com aviso Ajustar parcelas no Sienge e os valores reais"]
  faturas --> ajustaSienge["No Sienge: ajustar as parcelas; no app, marcar Parcelas ajustadas"]
  ajuste -->|Não| fim(["Nada mais a fazer até o vencimento"])

  classDef sienge stroke-dasharray: 5 4
  class autorizar,baixaSienge,ajustaSienge sienge
```

## Observações para o wireframe

- Uso principal em desktop: lista de pendentes à esquerda e despesa aberta à direita (comprovante e dados lado a lado) evita abrir e fechar telas a cada uma das ~66 despesas do dia.
- Atalhos de teclado para as quatro decisões e para ir à próxima pendente aceleram a revisão em lote.
- O botão Lançar é a ação principal; Devolver pede o motivo num campo que já aparece aberto.
- Avisos que precisam estar visíveis na revisão: credor não cadastrado, parcelas diferentes, valor do boleto diferente do total, campos alterados pelo colaborador.
- Três listas apoiam o trabalho no Sienge depois do lançamento: erros de integração, Baixas pendentes e Faturas a vencer (com os ajustes de parcela).
