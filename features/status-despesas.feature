# language: pt
# Referências: SPEC.md RF23, RF24, §3 (Colaborador)

Funcionalidade: Status das despesas
  Como colaborador
  Quero acompanhar o que aconteceu com cada despesa que enviei
  Para corrigir rapidamente o que for devolvido, sem precisar perguntar ao financeiro

  Contexto:
    Dado que estou autenticado como "maria@sencoengenharia.com.br"

  Regra: A tela agrupa as despesas por situação

    Cenário: Grupos e ordem
      Dado que tenho despesas em várias situações
      Quando eu abro a tela "Status despesas"
      Então vejo os grupos nesta ordem:
        | grupo              |
        | Devolvidas         |
        | Aguardando envio   |
        | Em análise         |
        | Aprovadas          |
        | Enviando ao Sienge |
        | Erro no lançamento |
        | Lançadas           |
      E grupos vazios não aparecem

    Esquema do Cenário: Situação mostrada ao colaborador
      Dado que tenho uma despesa no estado interno "<estado>"
      Quando eu abro a tela "Status despesas"
      Então ela aparece no grupo "<grupo>"

      Exemplos:
        | estado              | grupo              |
        | na fila do aparelho | Aguardando envio   |
        | PENDENTE            | Em análise         |
        | DEVOLVIDA           | Devolvidas         |
        | APROVADA            | Aprovadas          |
        | ENVIANDO            | Enviando ao Sienge |
        | ERRO                | Erro no lançamento |
        | LANCADA             | Lançadas           |

    Cenário: Despesa aprovada aguardando a cota do dia seguinte
      Dado que tenho uma despesa aprovada que não foi enviada por causa do limite diário do Sienge
      Quando eu abro a tela "Status despesas"
      Então ela aparece no grupo "Aprovadas" com a informação "Será lançada amanhã (limite diário do Sienge atingido)"

    Cenário: Despesa com erro no lançamento
      Dado que tenho uma despesa no grupo "Erro no lançamento"
      Quando eu toco nela
      Então vejo a mensagem "Houve um problema ao lançar no Sienge. O financeiro já foi avisado e vai resolver."
      E não preciso fazer nada

    Cenário: Ver só as minhas despesas
      Quando eu abro a tela "Status despesas"
      Então não vejo despesas de outros colaboradores

    Cenário: Filtrar por mês
      Quando eu escolho o mês "setembro de 2026"
      Então vejo só as despesas com emissão em setembro de 2026

  Regra: Despesas devolvidas podem ser corrigidas e reenviadas

    Cenário: Notificação de devolução
      Dado que um aprovador devolveu uma despesa minha com o motivo "Foto ilegível, envie outra"
      Quando eu abro o app
      Então vejo um aviso de 1 despesa devolvida
      E o grupo "Devolvidas" mostra o motivo "Foto ilegível, envie outra"

    Cenário: Abrir uma despesa devolvida
      Dado que tenho uma despesa devolvida
      Quando eu toco nela
      Então ela abre direto no formulário de edição

    Cenário: Corrigir e reenviar
      Dado que estou editando uma despesa devolvida
      Quando eu troco a foto e toco em "Reenviar"
      Então ela vai para o grupo "Em análise"
      E o aviso de devolução desaparece

  Regra: O colaborador só edita despesas devolvidas

    Esquema do Cenário: Despesas que não podem ser editadas
      Dado que tenho uma despesa no grupo "<grupo>"
      Quando eu toco nela
      Então vejo os detalhes apenas para leitura
      E não existem as opções "Editar" ou "Excluir"

      Exemplos:
        | grupo              |
        | Em análise         |
        | Aprovadas          |
        | Enviando ao Sienge |
        | Erro no lançamento |
        | Lançadas           |

    Cenário: Descartar uma despesa que ainda não foi enviada
      Dado que tenho uma despesa no grupo "Aguardando envio"
      Quando eu toco em "Descartar" e confirmo
      Então ela é removida do aparelho

  Regra: Os comprovantes ficam no app só até o lançamento

    Cenário: Comprovante de uma despesa ainda não lançada
      Dado que tenho uma despesa no grupo "Em análise"
      Quando eu abro a despesa
      Então vejo a prévia dos comprovantes

    Cenário: Comprovante de uma despesa lançada
      Dado que tenho uma despesa no grupo "Lançadas"
      Quando eu abro a despesa
      Então vejo "Comprovante enviado ao Sienge" com o nome e a descrição de cada anexo
      Mas não vejo mais a prévia do arquivo

  Regra: Despesas de rua passam pelo centro de custo

    Cenário: Grupo Aguardando centro de custo
      Dado que sou colaborador de rua e enviei uma despesa
      Quando eu abro a tela Status
      Então ela aparece no grupo "Aguardando centro de custo"
      E depois que o centro de custo é definido ela passa para "Em análise"

  Regra: Despesas descartadas ficam na lixeira por 30 dias

    Cenário: Descartar uma despesa devolvida
      Dado que tenho uma despesa no grupo "Devolvidas"
      Quando eu escolho "Descartar" e confirmo
      Então ela sai do grupo "Devolvidas" e aparece na "Lixeira"
      E vejo a data em que ela será excluída definitivamente

    Cenário: Recuperar da lixeira
      Dado que descartei uma despesa há 3 dias
      Quando eu abro a "Lixeira" e escolho "Recuperar"
      Então a despesa volta para o grupo em que estava

    Cenário: Recuperar uma despesa que ficaria duplicada
      Dado que a despesa da lixeira tem a mesma chave de acesso de outra despesa enviada depois
      Quando eu escolho "Recuperar"
      Então vejo a mensagem "Já existe uma despesa ativa para esta nota"
      E a despesa continua na lixeira

    Cenário: Excluir definitivamente
      Quando eu escolho "Excluir definitivamente" numa despesa da lixeira e confirmo
      Então a despesa e os arquivos dela são apagados
      E não é possível recuperá-la

    Cenário: Exclusão automática depois de 30 dias
      Dado que uma despesa está na lixeira há 30 dias
      Quando a rotina diária é executada
      Então a despesa e os arquivos dela são apagados

  Regra: O detalhe mostra o histórico da despesa

    Cenário: Ver o histórico
      Quando eu abro uma despesa lançada
      Então vejo o histórico com data e responsável:
        | evento               |
        | Enviada por mim      |
        | Aprovada por Camilla |
        | Lançada no Sienge    |
      E vejo o número do título no Sienge
