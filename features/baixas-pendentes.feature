# language: pt
# Referências: SPEC.md RF29, RN20, RN21
# v1 (ADR-0009): "Já dei baixa" só marca no app, sem consultar o Sienge. A conferência pelas parcelas (RN20 original) fica para uma versão futura.
# A API não dá baixa nem autoriza parcelas: esta tela só ajuda a Camilla a encontrar no Sienge os títulos pagos que faltam baixar.

Funcionalidade: Baixas pendentes
  Como aprovador
  Quero ver os títulos que o colaborador marcou como pagos e que ainda não tiveram baixa no Sienge
  Para encontrar cada um rapidamente na tela de baixa do Sienge, autorizar e dar a baixa

  Contexto:
    Dado que estou autenticado como "camilla@sencoengenharia.com.br" com permissão de aprovador

  Regra: Somente aprovadores acessam a tela

    Cenário: Usuário sem permissão de aprovador
      Dado que estou autenticado como "maria@sencoengenharia.com.br" sem permissão de aprovador
      Então não vejo a opção "Baixas pendentes" no menu
      E se eu acessar o endereço da tela diretamente, vejo a mensagem "Você não tem permissão para acessar esta tela"

  Regra: A lista mostra os títulos pagos ainda sem baixa

    Cenário: Quais títulos entram na lista
      Dado que existem estas despesas lançadas no Sienge:
        | título | paga | já dei baixa |
        | 17120  | Não  | —            |
        | 17121  | Sim  | não          |
        | 17122  | Sim  | sim          |
      Quando eu abro a tela "Baixas pendentes"
      Então vejo somente o título "17121"

    Cenário: Despesas aprovadas ainda não lançadas não aparecem
      Dado que uma despesa marcada como paga ainda está na fila de envio ao Sienge
      Quando eu abro a tela "Baixas pendentes"
      Então ela não aparece na lista
      E vejo a informação "Aguardando lançamento no Sienge" na tela "Aprovação"

  Regra: Os dados usados nos filtros do Sienge ficam em destaque

    Cenário: Informações de cada título
      Quando eu abro a tela "Baixas pendentes"
      Então cada título mostra em destaque:
        | informação         | exemplo                                |
        | número do título   | 17121                                  |
        | credor             | FN TAG MATERIAIS EIRELI (FN DO BRASIL) |
        | CNPJ/CPF do credor | 28.070.499/0001-22                     |
        | data do pagamento  | 14/09/2026                             |
      E também mostra empresa, tipo e número do documento, valor e colaborador que enviou

    Cenário: Copiar o número do título
      Quando eu toco no ícone de copiar ao lado do número "17121"
      Então o número "17121" é copiado para colar no filtro "Título" do Sienge

    Cenário: Lembrete de autorização
      Quando eu abro a tela "Baixas pendentes"
      Então vejo o aviso "Títulos criados pelo app chegam ao Sienge não autorizados: autorize antes de dar baixa."

    Esquema do Cenário: Ordenar e filtrar
      Quando eu filtro ou ordeno a lista por "<campo>"
      Então a lista é organizada por "<campo>"

      Exemplos:
        | campo             |
        | data do pagamento |
        | credor            |
        | número do título  |
        | empresa           |

  Regra: Na v1, a baixa é confirmada pelo aprovador no app, sem consultar o Sienge

    Cenário: Confirmação antes de tirar o título da lista
      Quando eu toco em "Já dei baixa" no título "17121"
      Então vejo a pergunta "Confirmar que a baixa do título 17121 já foi feita no Sienge?" com os botões "Confirmar" e "Cancelar"
      E o título continua na lista até eu confirmar

    Cenário: Avisar que a baixa foi feita
      Dado que acabei de dar baixa no título "17121" no Sienge
      Quando eu toco em "Já dei baixa" no título "17121" e confirmo
      Então o título "17121" sai da lista
      E fica registrado na despesa quem confirmou a baixa e quando
      E nenhuma requisição é feita ao Sienge

    Cenário: Desistir de confirmar a baixa
      Quando eu toco em "Já dei baixa" no título "17121" e depois em "Cancelar"
      Então o título "17121" continua na lista
      E nada é registrado na despesa

    Cenário: Título com baixa confirmada não volta à lista
      Dado que confirmei a baixa do título "17122"
      Quando eu abro a tela "Baixas pendentes"
      Então o título "17122" não aparece

    Cenário: Abrir a tela não gasta a cota
      Quando eu abro ou filtro a tela "Baixas pendentes"
      Então nenhuma requisição é feita ao Sienge
