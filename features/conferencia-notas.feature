# language: pt
# Referências: SPEC.md RF30, RF31, RN23
# Caso real: o comprovante do pagamento chega primeiro e é lançado; dias depois chega a nota do mesmo pagamento.

Funcionalidade: Conferência de notas
  Como aprovador
  Quero conferir se a nota que chegou depois do pagamento já tem um lançamento
  Para anexar a nota ao título existente em vez de lançar a mesma compra duas vezes

  Contexto:
    Dado que estou autenticado como "camilla@sencoengenharia.com.br" com permissão de aprovador

  Regra: Somente aprovadores acessam a conferência

    Cenário: Usuário sem permissão de aprovador
      Dado que estou autenticado como "maria@sencoengenharia.com.br" sem permissão de aprovador
      Então não vejo a opção "Conferência de notas" no menu

  Regra: A nota enviada preenche os dados da busca

    Cenário: Nota com chave de acesso
      Quando eu envio o arquivo da nota com a chave de acesso
      Então o credor é preenchido pelo CNPJ do emitente
      E informo o valor pago, a data de emissão e a data do pagamento

    Cenário: Comprovante sem chave
      Quando eu envio um recibo sem chave de acesso
      Então informo credor, valor, data de emissão e data do pagamento

  Regra: A busca usa credor, valor e período

    Cenário: Período entre a emissão e o pagamento
      Dado que a nota foi emitida em "12/09/2026" e o pagamento foi em "14/09/2026"
      Quando eu toco em "Procurar lançamentos"
      Então o app procura títulos do credor com emissão entre "09/09/2026" e "17/09/2026"
      E considera apenas os de valor igual ao valor pago

    Cenário: Nota emitida depois do pagamento
      Dado que o pagamento foi em "14/09/2026" e a nota foi emitida em "20/09/2026"
      Quando eu toco em "Procurar lançamentos"
      Então o período vai de "11/09/2026" a "23/09/2026"

    Cenário: Despesas do app ainda não lançadas também entram
      Dado que existe uma despesa pendente no app do mesmo credor e valor
      Quando eu toco em "Procurar lançamentos"
      Então ela aparece em "Despesas no app ainda não lançadas"

  Regra: Quando encontra, a nota é anexada ao título existente

    Cenário: Anexar a nota ao título encontrado
      Dado que a busca encontrou o título "16711" · PAG 14/09 · R$ 35,20
      Quando eu escolho o tipo "DANFe" e toco em "Anexar a nota ao título 16711"
      Então a nota é enviada ao Sienge como anexo do título "16711"
      E nenhum título novo é criado
      E vejo a mensagem "Nota anexada ao título 16711"

    Cenário: Mais de um lançamento parecido
      Dado que a busca encontrou 2 títulos do credor com o mesmo valor no período
      Então vejo os 2 títulos com número, documento, emissão e anexos atuais
      E escolho em qual anexar a nota

    Cenário: Arquivo apagado do app depois de anexado
      Quando o Sienge confirma o anexo
      Então o arquivo da nota é apagado do servidor do app

  Regra: Quando não encontra, o cadastro abre preenchido

    Cenário: Nenhum lançamento encontrado
      Dado que a busca não encontrou título nem despesa no app
      Então vejo "Nenhum lançamento encontrado"
      E o botão "Cadastrar título com esta nota"

    Cenário: Cadastrar a partir da conferência
      Quando eu toco em "Cadastrar título com esta nota"
      Então a tela de cadastro abre com credor, número, emissão, valor e o arquivo da nota já preenchidos

    Cenário: Ampliar o período
      Dado que a busca não encontrou nada
      Quando eu toco em "Ampliar o período"
      Então posso alterar as datas e procurar de novo

  Regra: O cadastro do colaborador também avisa sobre pagamento já lançado

    Cenário: Aviso no cadastro de uma nota já paga
      Dado que um colaborador cadastra uma nota do credor "FN TAG MATERIAIS EIRELI" de "R$ 490,80"
      E já existe o título "16701" · PAG 14/09 do mesmo credor e valor no período
      Quando ele informa credor, valor e datas
      Então vê o aviso "Este pagamento pode já estar lançado" com o título "16701"
      E pode escolher entre "Anexar a nota ao título 16701" e "É outra compra"
