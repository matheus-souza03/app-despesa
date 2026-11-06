# language: pt
# Referências: SPEC.md RN08, RF37; data/planos-financeiros-liberados.json

Funcionalidade: Planos financeiros liberados no app
  Como aprovador ou aprovador de centro de custo
  Quero escolher quais planos financeiros do Sienge aparecem no app
  Para que as despesas usem só os planos que a empresa definiu

  Contexto:
    Dado que estou autenticado como "camilla@sencoengenharia.com.br" com o perfil "aprovador"

  Regra: Só os planos liberados aparecem nas despesas

    Cenário: Lista inicial
      Dado que o app foi instalado com a lista inicial de planos liberados
      Quando um colaborador de escritório escolhe o plano financeiro de uma apropriação
      Então ele vê só os planos liberados que são de resultado, não redutores e ativos
      E os planos totalizadores liberados aparecem só como título de grupo

    Cenário: Plano do Sienge que não foi liberado
      Dado que o plano "2.01.08.01" existe no Sienge mas não foi liberado no app
      Quando alguém escolhe o plano financeiro de uma apropriação
      Então o plano "2.01.08.01" não aparece na lista

    Cenário: Planilha com plano não liberado
      Dado uma planilha com o plano financeiro "2.01.08.01" numa linha
      Quando a planilha é importada
      Então a linha aparece com o problema "Plano financeiro não liberado no app"

    Cenário: Plano desativado no Sienge
      Dado que o plano liberado "2.01.04.05" foi desativado no Sienge
      Quando a sincronização dos cadastros roda
      Então o plano "2.01.04.05" deixa de aparecer em despesas novas
      E as despesas antigas continuam mostrando o nome dele

  Regra: Aprovadores e aprovadores de centro de custo mantêm a lista

    Cenário: Adicionar um plano esquecido
      Quando eu abro "Planos financeiros" e escolho "Adicionar do Sienge"
      E procuro "Licenciamento" e libero o plano "2.01.04.05"
      Então o plano passa a aparecer nas despesas novas
      E fica registrado quem liberou e quando

    Cenário: Importar uma lista
      Quando eu importo um arquivo JSON no formato da lista de planos do Sienge
      Então os planos do arquivo são liberados no app
      E vejo quantos foram liberados e quantos já estavam liberados

    Cenário: Tirar um plano do app
      Quando eu escolho "Tirar do app" no plano "2.01.07.03"
      Então ele deixa de aparecer em despesas novas
      E as despesas que já usam esse plano não mudam

    Cenário: Plano novo criado no Sienge
      Dado que a Camilla criou um plano financeiro novo direto no Sienge
      Quando eu toco em "Atualizar do Sienge"
      Então o plano novo aparece em "Adicionar do Sienge"
      E posso liberá-lo no app

    Cenário: O app não cria planos financeiros
      Quando eu abro "Planos financeiros"
      Então não existe a opção de criar plano
      E vejo a orientação de que planos novos são criados no Sienge

    Cenário: Só planos de despesa podem ser liberados
      Quando eu procuro um plano em "Adicionar do Sienge"
      Então só aparecem planos do grupo 2, de resultado e ativos

    Cenário: Aprovador de centro de custo também mantém a lista
      Dado que estou autenticado como "marcos.bento@sencoengenharia.com.br" com o perfil "aprovador de centro de custo"
      Então vejo a tela "Planos financeiros" com as mesmas ações

    Esquema do Cenário: Outros perfis não mantêm a lista
      Dado que estou autenticado com o perfil "<perfil>"
      Então não vejo a tela "Planos financeiros"

      Exemplos:
        | perfil                    |
        | colaborador de rua        |
        | colaborador de escritório |

    Cenário: Sincronização não muda o que foi liberado
      Dado que tirei do app o plano "2.01.07.03"
      Quando a sincronização dos cadastros roda
      Então o plano "2.01.07.03" continua fora do app
