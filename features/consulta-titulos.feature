# language: pt
# Referências: SPEC.md RF33, RF34, RF35, RN25

Funcionalidade: Consulta de títulos e avisos de lançamento
  Como aprovador
  Quero ver todos os títulos lançados, pelo app ou direto no Sienge, e saber o número de cada título assim que ele é lançado
  Para encontrar qualquer título rapidamente no Sienge e dar a baixa

  Contexto:
    Dado que estou autenticado como "camilla@sencoengenharia.com.br" com permissão de aprovador

  Regra: O número do título aparece assim que o lançamento termina

    Cenário: Lançamento com sucesso
      Dado que lancei a despesa da "FN TAG MATERIAIS EIRELI" de "R$ 490,80"
      Quando o Sienge cria o título "17171"
      Então vejo no canto inferior direito o aviso verde "Título 17171 lançado com sucesso"
      E posso copiar o número "17171" pelo ícone de copiar do próprio aviso

    Cenário: Erro no lançamento
      Quando o Sienge recusa o lançamento de uma despesa que aprovei
      Então vejo o aviso vermelho "Erro ao lançar" com o link "Ver em Erros"

    Cenário: Lançamento em nova tentativa
      Quando o envio de uma despesa que aprovei falha temporariamente e vai ser tentado de novo
      Então vejo o aviso amarelo "Enviando ao Sienge"

    Cenário: Vários lançamentos seguidos
      Quando três despesas que aprovei são lançadas em sequência
      Então os três avisos aparecem empilhados

  Regra: Aprovadores também cadastram despesas

    Cenário: Nova despesa pelo financeiro
      Quando eu toco em "Nova despesa" no cabeçalho do financeiro
      Então abre o mesmo cadastro de despesa usado pelos colaboradores
      E o botão de envio se chama "Lançar no Sienge"

    Cenário: Despesa do aprovador vai direto para o lançamento
      Quando eu preencho uma despesa válida e toco em "Lançar no Sienge"
      Então ela é registrada como aprovada por mim no histórico
      E entra direto na fila de lançamento, sem passar pela lista de pendentes

  Regra: A consulta mostra todos os títulos, do mais recente para o mais antigo

    Cenário: Abrir a consulta sem filtros
      Quando eu abro a tela "Títulos"
      Então vejo os títulos de todos os colaboradores e os lançados direto no Sienge
      E eles estão ordenados do mais recente para o mais antigo

    Esquema do Cenário: Filtrar títulos
      Quando eu filtro por "<filtro>" com "<valor>"
      Então vejo só os títulos que atendem ao filtro

      Exemplos:
        | filtro           | valor                        |
        | credor           | FN TAG                       |
        | credor           | 28.070.499/0001-22           |
        | colaborador      | Matheus Souza                |
        | colaborador      | Lançados direto no Sienge    |
        | número do título | 17171                        |
        | período          | de 01/10/2026 até 26/10/2026 |

    Cenário: Filtrar por centro de custo e período
      Quando eu filtro pelo centro de custo "1062 · KML8D31 · Caminhão GMC" e emissão de "01/10/2026" a "31/10/2026"
      Então vejo os títulos com apropriação no centro de custo "1062" nesse período
      E cada título mostra o valor do título e o valor no centro de custo

    Cenário: Valor no centro de custo considera o rateio
      Dado que o título "17170" de R$ 900,00 está rateado 50% no "1062" e 50% no "1066"
      Quando eu filtro pelo centro de custo "1062"
      Então o título "17170" mostra R$ 450,00 no centro de custo

    Cenário: Total no fim da lista
      Dado que o filtro retornou 6 títulos
      Então no fim da lista vejo o total do valor dos 6 títulos
      E com o filtro de centro de custo também vejo o total gasto nesse centro de custo

    Cenário: Copiar o número na lista
      Quando eu toco no ícone de copiar ao lado do título "17168"
      Então o número "17168" é copiado

  Regra: A consulta não gasta a cota da API

    Cenário: Consultar usa os títulos guardados no app
      Quando eu abro ou filtro a tela "Títulos"
      Então nenhuma requisição é feita ao Sienge

    Cenário: Título lançado pelo app entra na hora
      Quando o app lança o título "17171"
      Então ele já aparece na consulta, sem esperar a atualização de domingo

    Cenário: Atualizar agora busca os títulos novos
      Dado que o banco já tem os títulos até o 17171
      Quando eu toco em "Atualizar agora"
      Então o app busca no Sienge a última página de 200 títulos
      E grava só os títulos que ainda não estão no banco

    Cenário: Mais de 200 títulos novos
      Dado que todos os 200 títulos da última página são novos
      Quando a atualização roda
      Então o app busca também a página anterior, até encontrar títulos que já estão no banco

    Cenário: Intervalo mínimo de 5 minutos
      Dado que alguém tocou em "Atualizar agora" às 11:00
      Quando eu abro a tela "Títulos" às 11:02
      Então o botão "Atualizar agora" está desativado com "Disponível em 3 min"
      E nenhuma requisição é feita ao Sienge

    Cenário: Título lançado direto no Sienge
      Dado que a Camilla lançou um título direto no Sienge
      Quando a rotina de domingo roda ou eu toco em "Atualizar agora"
      Então o título passa a aparecer na consulta com "Direto no Sienge"

    Cenário: Título antigo alterado no Sienge
      Dado que a Camilla alterou no Sienge o valor do título "16720"
      Quando a rotina de domingo roda
      Então o app busca os títulos alterados desde a última rotina, em 1 requisição
      E o título "16720" aparece com o valor novo

    Cenário: Carga inicial desde 2022
      Dado que o app acabou de ser instalado
      Quando a carga inicial dos títulos roda
      Então os títulos com emissão desde 01/01/2022 são guardados aos poucos, sem passar do teto das rotinas na cota do dia, e a carga continua no dia seguinte de onde parou
