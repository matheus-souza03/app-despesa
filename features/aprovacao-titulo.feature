# language: pt
# Referências: SPEC.md §4, RF20–RF22, RN02, RN15
# A API do Sienge não permite baixa: o app só lança; a baixa é feita no Sienge.

Funcionalidade: Aprovação de título
  Como aprovador
  Quero revisar cada despesa com o comprovante ao lado e decidir com um clique
  Para lançar no Sienge sem redigitar nada

  Contexto:
    Dado que estou autenticado como "camilla@sencoengenharia.com.br" com permissão de aprovador

  Regra: Somente aprovadores acessam a aprovação

    Cenário: Usuário sem permissão de aprovador
      Dado que estou autenticado como "maria@sencoengenharia.com.br" sem permissão de aprovador
      Quando eu tento abrir a tela "Aprovação"
      Então vejo a mensagem "Você não tem permissão para aprovar despesas"

  Regra: O painel mostra as despesas pendentes e permite filtrar

    Cenário: Lista de pendentes
      Dado que existem 12 despesas pendentes
      Quando eu abro a tela "Aprovação"
      Então vejo as 12 despesas, das mais antigas para as mais recentes
      E cada uma mostra colaborador, credor, valor, empresa e data de envio

    Esquema do Cenário: Filtros
      Quando eu filtro por "<filtro>" igual a "<valor>"
      Então vejo apenas as despesas com "<filtro>" igual a "<valor>"

      Exemplos:
        | filtro          | valor                        |
        | status          | Erro                         |
        | empresa         | 4                            |
        | centro de custo | 1062                         |
        | colaborador     | maria@sencoengenharia.com.br |
        | credor          | FN do Brasil Ltda            |
        | período         | outubro de 2026              |

    Cenário: Faturas a vencer
      Dado que existem títulos lançados com vencimento futuro
      Quando eu abro a visão "Faturas a vencer"
      Então vejo esses títulos ordenados pelo vencimento mais próximo
      E vejo a orientação "A baixa é feita no Sienge"

    Cenário: Títulos com parcelas a ajustar
      Dado que o título "17150" foi lançado com a marca "Ajustar parcelas no Sienge"
      Quando eu abro a visão "Faturas a vencer"
      Então o título "17150" aparece com o aviso "Ajustar parcelas no Sienge"
      E vejo os valores e vencimentos reais de cada parcela
      E posso tocar em "Parcelas ajustadas" depois de corrigir no Sienge

    Cenário: Confirmar o ajuste das parcelas no Sienge
      Dado que ajustei no Sienge as parcelas do título "17150" para os valores e vencimentos reais
      Quando eu toco em "Parcelas ajustadas"
      Então o app consulta as parcelas do título "17150" no Sienge
      E como elas batem com os valores reais, o aviso "Ajustar parcelas no Sienge" sai do título

    Cenário: Ajuste ainda não feito no Sienge
      Dado que as parcelas do título "17150" no Sienge ainda são as iguais geradas no lançamento
      Quando eu toco em "Parcelas ajustadas"
      Então vejo a mensagem "O Sienge ainda mostra as parcelas antigas"
      E o aviso continua no título

  Regra: A revisão mostra os dados e os comprovantes lado a lado

    Cenário: Abrir uma despesa
      Quando eu abro uma despesa pendente
      Então vejo os comprovantes ao lado dos dados
      E os campos que foram lidos de código aparecem marcados
      E os campos alterados pelo colaborador mostram o valor lido originalmente

    Cenário: Ver o comprovante de uma despesa já lançada
      Dado que a despesa já foi lançada no Sienge como título "17120"
      Quando eu abro a despesa
      Então vejo "Comprovante no Sienge — título 17120" no lugar da prévia
      E posso tocar em "Abrir do Sienge" para ver o arquivo, sem que ele seja guardado no app

  Regra: O aprovador decide o destino da despesa

    Esquema do Cenário: Lançar a despesa
      Dado que estou revisando uma despesa com forma de pagamento "<forma>"
      Quando eu toco em "Lançar"
      Então a despesa fica "Aprovada" e entra na fila de envio ao Sienge
      E a baixa continua sendo feita no Sienge, fora do app

      Exemplos:
        | forma          |
        | Pix da empresa |
        | boleto a prazo |

    Cenário: Editar antes de aprovar
      Quando eu altero o plano financeiro de "2.01.01.06" para "2.01.04.02" e salvo
      Então a despesa continua pendente com a alteração
      E a alteração fica registrada no histórico com meu nome, data, valor anterior e novo

    Cenário: Devolver ao colaborador
      Quando eu toco em "Devolver" e escrevo o motivo "Foto ilegível, envie outra"
      Então a despesa fica "Devolvida"
      E o colaborador é notificado com o motivo

    Cenário: Devolver sem motivo
      Quando eu toco em "Devolver" sem escrever o motivo
      Então vejo a mensagem "Informe o motivo da devolução"

    Cenário: Deixar para depois
      Quando eu toco em "Deixar para depois"
      Então a despesa continua pendente
      E fica marcada para eu revisar depois

    Cenário: Aprovar a própria despesa
      Dado que a despesa foi enviada por mim
      Quando eu toco em "Lançar"
      Então a aprovação é aceita

    Cenário: A revisão é a última chance de corrigir pelo app
      Dado que estou revisando uma despesa pendente
      Então vejo o aviso "Depois de lançado, o título só pode ser corrigido no Sienge"

  Regra: A edição acontece na própria tela de revisão

    Cenário: Entrar no modo de edição
      Dado que estou revisando uma despesa pendente
      Quando eu toco em "Editar"
      Então continuo na mesma tela, com o comprovante visível
      E os campos de documento, pagamento, apropriação e observação ficam editáveis
      E as ações passam a ser "Salvar alterações" e "Cancelar edição"

    Cenário: Campo alterado mostra o valor anterior
      Dado que estou editando a despesa
      Quando eu troco o centro de custo "1066 · EFO7F00 · Volkswagen 9.150E" por "1069 · LTB5H21 · Caminhão VW Constellation"
      Então vejo "Alterado · antes: 1066 · EFO7F00 · Volkswagen 9.150E" abaixo do campo

    Cenário: Cancelar a edição
      Dado que alterei campos durante a edição
      Quando eu toco em "Cancelar edição"
      Então os valores voltam a ser os anteriores e a tela volta ao modo de revisão

  Regra: Despesas com pendências não podem ser aprovadas

    Cenário: Credor ainda não cadastrado
      Dado que a despesa tem o aviso "Credor não cadastrado"
      Quando eu abro a despesa
      Então o sistema busca o credor de novo no Sienge
      E enquanto ele não estiver cadastrado, o botão "Lançar" fica desativado com o aviso "Cadastre o credor antes de lançar"
      E posso cadastrar o credor dali mesmo

  Regra: Dois aprovadores não decidem a mesma despesa

    Cenário: Despesa aprovada por outra pessoa enquanto eu revisava
      Dado que eu e outro aprovador abrimos a mesma despesa
      E ele aprovou primeiro
      Quando eu tento aprovar ou devolver
      Então vejo a mensagem "Esta despesa já foi aprovada por outro aprovador"

  Regra: Os erros de integração ficam visíveis e podem ser corrigidos

    Cenário: Despesa com erro no envio
      Dado que uma despesa aprovada falhou com a mensagem do Sienge "Centro de custo inativo"
      Quando eu abro a lista de erros
      Então vejo a despesa com a mensagem "Centro de custo inativo"
      E posso escolher "Tentar novamente" ou "Editar"

    Cenário: Editar uma despesa com erro
      Dado uma despesa com erro cujo título não chegou a ser criado no Sienge
      Quando eu escolho "Editar"
      Então ela volta para pendente
      E posso corrigir e aprovar de novo

    Cenário: Erro com título já criado não pode ser editado
      Dado uma despesa com erro cujo título 17160 já foi criado no Sienge e falta um anexo
      Então não vejo as opções "Editar" e "Descartar"
      E vejo "Tentar de novo", "Anexar outro arquivo" e "Resolvido no Sienge"

    Cenário: Resolvido no Sienge
      Dado uma despesa com erro cujo título 17160 já foi criado no Sienge
      Quando eu anexo o arquivo direto no Sienge e escolho "Resolvido no Sienge"
      Então a despesa passa a lançada
      E o arquivo é apagado do servidor do app

    Cenário: Descartar uma despesa com erro sem título criado
      Dado uma despesa com erro "Já existe documento com este número para este credor" e sem título criado
      Quando eu escolho "Descartar" e informo o motivo "Nota já lançada no Sienge"
      Então a despesa vai para a lixeira e não vai ao Sienge
      E pode ser recuperada por 30 dias

    Cenário: Cota diária esgotada
      Dado que a cota diária da API do Sienge foi atingida
      Quando eu aprovo uma despesa
      Então a aprovação é registrada
      E vejo o aviso "Limite diário do Sienge atingido. Esta despesa será lançada amanhã."
