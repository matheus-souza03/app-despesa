# language: pt
# Referências: SPEC.md §3, RF36, RN27; docs/modelagem/01-estados.md (T22–T26)

Funcionalidade: Definir centro de custo das despesas de rua
  Como aprovador de centro de custo
  Quero indicar a qual centro de custo pertence cada compra enviada pelo pessoal de rua
  Para que o colaborador de rua lance rápido e a despesa chegue completa à aprovação

  Contexto:
    Dado que estou autenticado como "marcos.bento@sencoengenharia.com.br" com o perfil "aprovador de centro de custo"

  Regra: Despesas de rua chegam sem apropriação

    Cenário: Cadastro do colaborador de rua
      Dado que estou autenticado como "pedro@sencoengenharia.com.br" com o perfil "colaborador de rua"
      Quando eu abro o cadastro de uma nova despesa
      Então não vejo a seção "Apropriação"
      E vejo o aviso "Centro de custo definido pelo financeiro"

    Cenário: Envio do colaborador de rua
      Dado que "pedro@sencoengenharia.com.br" enviou uma despesa válida sem apropriação
      Então ela fica "Aguardando centro de custo"
      E aparece na minha tela "Definir centro de custo"
      E para ele aparece no grupo "Aguardando centro de custo" da tela Status

    Cenário: Planilha importada por colaborador de rua
      Dado que "pedro@sencoengenharia.com.br" importou uma planilha com a coluna "Centro de custo" preenchida
      Então as despesas importadas ficam "Aguardando centro de custo"
      E o texto da coluna "Centro de custo" é ignorado

  Regra: O aprovador de centro de custo só altera as apropriações

    Cenário: Fila de despesas aguardando centro de custo
      Quando eu abro "Definir centro de custo"
      Então vejo as despesas aguardando centro de custo, das mais antigas para as mais novas
      E cada despesa abre com o comprovante ao lado dos dados

    Cenário: Campos só para leitura
      Quando eu abro uma despesa aguardando centro de custo
      Então documento, credor, valores, parcelas e observação aparecem só para leitura
      E só a seção "Apropriação" pode ser editada

    Cenário: Enviar para aprovação
      Dado que preenchi a apropriação com "1062 · KML8D31 · Caminhão GMC" e "1066 · EFO7F00 · Volkswagen 9.150E", R$ 450,00 cada
      E o saldo restante é "R$ 0,00"
      Quando eu toco em "Enviar para aprovação"
      Então a despesa vai para a aprovação do financeiro
      E o histórico registra que eu defini as apropriações

    Cenário: Apropriação que não fecha o total
      Dado que o saldo restante é "R$ 100,00"
      Quando eu toco em "Enviar para aprovação"
      Então vejo "Faltam R$ 100,00 na apropriação"
      E a despesa continua aguardando centro de custo

    Cenário: Qualquer centro de custo da empresa
      Quando eu escolho o centro de custo de uma despesa da empresa "1"
      Então vejo todos os centros de custo da empresa "1" que não estão ocultos

    Cenário: Deixar para depois
      Quando eu toco em "Deixar para depois"
      Então a despesa vai para o fim da fila

    Cenário: Sem opção de devolver ou lançar
      Quando eu abro uma despesa aguardando centro de custo
      Então não vejo as opções "Devolver", "Editar" e "Lançar no Sienge"

  Regra: Correções depois da aprovação

    Cenário: Devolvida e corrigida sem mudar o valor
      Dado que a aprovadora devolveu uma despesa de rua já com apropriação
      Quando o colaborador de rua corrige a foto e reenvia sem mudar o valor
      Então a despesa volta direto para a aprovação

    Cenário: Devolvida e corrigida com outro valor
      Dado que a aprovadora devolveu uma despesa de rua de R$ 900,00 já com apropriação
      Quando o colaborador de rua corrige o valor para R$ 950,00 e reenvia
      Então a despesa volta para "Aguardando centro de custo"
