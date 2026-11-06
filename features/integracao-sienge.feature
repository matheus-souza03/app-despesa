# language: pt
# Referências: SPEC.md §8, RN02, RN05, RN09, RN10, RN11, RN16, RNF06, RNF07, RNF10
# Skill: .claude/skills/sienge-api/SKILL.md
# Esta funcionalidade não tem tela: descreve o comportamento do worker.
# A API não permite baixa: todo título termina "Lançado"; a baixa é feita no Sienge.

Funcionalidade: Integração com o Sienge
  Como aprovador
  Quero que cada despesa aprovada seja lançada no Sienge exatamente uma vez
  Para não redigitar nada e não correr o risco de títulos duplicados

  Regra: Fora de produção nada é enviado ao Sienge

    Cenário: Modo dry-run
      Dado que o modo dry-run está ligado
      Quando uma despesa aprovada é processada
      Então o título é montado e validado
      E fica registrado no log de integração como "dry-run"
      Mas nenhuma chamada é feita ao Sienge

  Regra: O título é montado a partir da despesa

    Cenário: Nota fiscal a prazo da FN do Brasil
      Dado uma despesa aprovada com:
        | campo           | valor                                        |
        | empresa         | 1                                            |
        | credor          | FN do Brasil Ltda (28.070.499/0001-22)       |
        | chave de acesso | 33260928070499000122550010000030871000059038 |
        | emissão         | 14/09/2026                                   |
        | valor total     | 490,80                                       |
        | parcela 1       | 490,80 com vencimento em 12/10/2026          |
        | apropriação     | 107 / 2.01.01.06 / 490,80                    |
        | descrição       | Auto transformador e materiais elétricos     |
      Quando o worker processa a despesa
      Então o título é criado no Sienge com:
        | campo               | valor                                    |
        | documento           | DANF                                     |
        | número do documento | 003.087                                  |
        | data de emissão     | 14/09/2026                               |
        | data contábil       | 14/09/2026                               |
        | indexador           | 0                                        |
        | data base           | 01/09/2026                               |
        | data 1º vencimento  | 12/10/2026                               |
        | valor do desconto   | 0,00                                     |
        | observação          | Auto transformador e materiais elétricos |
      E a chave de acesso fica registrada só no app, porque o lançamento comum de título não a recebe
      E a despesa fica "Lançada"

    Cenário: Rateio com percentuais
      Dado uma despesa de "365,55" com apropriações "1062" de "182,78" e "1066" de "182,77"
      Quando o título é montado
      Então as apropriações são enviadas em percentual, calculado a partir dos valores
      E os percentuais somam exatamente 100%
      E o valor que o Sienge calcula para cada linha é "182,78" e "182,77"

  Regra: A observação nunca vai vazia

    Esquema do Cenário: Conteúdo da observação
      Dado uma despesa com a observação "<digitada>"
      Quando o título é montado
      Então o campo de observação enviado é "<enviada>"

      Exemplos:
        | digitada                          | enviada                           |
        | Faixas refletivas - GMC e EFO7F00 | Faixas refletivas - GMC e EFO7F00 |
        |                                   | um espaço em branco               |

  Regra: Títulos criados pela API chegam não autorizados

    Cenário: Parcelas não autorizadas
      Quando o worker lança um título no Sienge
      Então as parcelas ficam com "Autorizado: Não"
      E a autorização é feita pela Camilla no Sienge, fora do app

  Regra: O lançamento segue sempre a mesma ordem

    Cenário: Lançamento completo com dois anexos
      Dado uma despesa aprovada da empresa "1" com 2 anexos
      Quando o worker processa a despesa
      Então o credor é confirmado pelo cache local
      E o título é criado com as apropriações na mesma chamada
      E o número do título é gravado na despesa antes de qualquer outro passo
      E os 2 anexos são enviados, um por chamada, com as descrições "DANFe" e "COMP"
      E a despesa fica "Lançada"
      E são consumidas 3 requisições da cota

    Cenário: Credor ainda não existe no Sienge
      Dado uma despesa aprovada cujo credor não foi encontrado nem no cache nem no Sienge
      Quando o worker processa a despesa
      Então nenhum título é criado
      E a despesa fica com erro "Credor não cadastrado"

  Regra: Títulos criados pela API não são alterados pela API

    Cenário: Título com parcelas iguais
      Dado uma despesa aprovada de "17.214,96" em 3 parcelas com 1º vencimento "19/11/2026"
      Quando o worker processa a despesa
      Então o título é criado com 3 parcelas e 1º vencimento "19/11/2026"
      E o Sienge gera 3 parcelas de "5.738,32" em 19/11/2026, 19/12/2026 e 19/01/2027
      E nenhuma chamada de alteração é feita

    Cenário: Despesa com parcelas diferentes
      Dado uma despesa aprovada de "900,00" marcada com "As parcelas são diferentes"
      Quando o worker processa a despesa
      Então o título é criado com 3 parcelas iguais
      E a despesa fica marcada "Ajustar parcelas no Sienge" com os valores reais
      E nenhuma chamada de alteração é feita

    Cenário: Nenhuma correção pela API depois do lançamento
      Dado que um título já foi criado pelo app
      Quando for preciso corrigir qualquer dado dele
      Então a correção é feita pela Camilla na tela do Sienge
      E o app não tenta nenhuma chamada de alteração, porque o Sienge recusa alterações pela API em títulos de origem "SE"

  Regra: O comprovante só fica no app até chegar ao Sienge

    Cenário: Arquivo apagado depois do envio
      Dado uma despesa aprovada com 2 anexos guardados no servidor do app
      Quando o Sienge confirma o recebimento dos 2 anexos
      Então os 2 arquivos são apagados do servidor do app
      E a despesa continua registrando nome, descrição e data de envio de cada anexo

    Cenário: Envio de anexo que falhou
      Dado que o envio do 2º anexo ao Sienge falhou
      Então o 2º arquivo continua no servidor do app para a nova tentativa
      E só o 1º arquivo, já confirmado pelo Sienge, é apagado

    Cenário: Despesa na lixeira
      Quando uma despesa que nunca foi lançada é descartada
      Então os arquivos dela continuam no servidor do app enquanto ela estiver na lixeira

    Cenário: Despesa excluída definitivamente
      Quando uma despesa da lixeira é excluída definitivamente ou completa 30 dias na lixeira
      Então os arquivos dela são apagados do servidor do app

    Cenário: Exclusão que falhou
      Dado que a exclusão de um arquivo já enviado ao Sienge falhou
      Quando a rotina diária de limpeza é executada
      Então o arquivo é apagado

  Regra: Uma despesa nunca gera dois títulos

    Cenário: Resposta perdida depois de criar o título
      Dado que o Sienge criou o título mas a resposta não chegou por timeout
      Quando o worker tenta de novo
      Então ele procura no Sienge um título do mesmo credor, número e valor
      E ao encontrar grava o número do título na despesa
      E não cria um segundo título

    Cenário: Falha ao enviar o anexo
      Dado que o título foi criado e o envio do anexo falhou
      Quando o worker tenta de novo
      Então só o anexo é reenviado
      E o título não é criado novamente

    Cenário: Despesa já lançada é processada de novo
      Dado uma despesa que já tem número de título e anexos enviados
      Quando ela entra na fila por engano
      Então nenhuma chamada de criação é feita

  Regra: Falhas temporárias são repetidas; erros de dados não

    Esquema do Cenário: Tratamento por tipo de resposta
      Quando o Sienge responde "<resposta>"
      Então o worker "<acao>"

      Exemplos:
        | resposta                 | acao                                                   |
        | 429 (limite por minuto)  | espera e tenta de novo, até 5 vezes                    |
        | 500, 502, 503 ou timeout | espera e tenta de novo, até 5 vezes                    |
        | 400 com mensagem de erro | marca a despesa com erro e mostra a mensagem do Sienge |
        | 401 ou 403               | pausa a fila e avisa os administradores                |

    Cenário: Tentativas esgotadas
      Dado que o Sienge ficou fora do ar durante as 5 tentativas
      Quando a última tentativa falha
      Então a despesa fica com erro "Sienge indisponível"
      E pode ser reenviada pelo aprovador

  Regra: A cota diária nunca é ultrapassada e segue a prioridade por tipo

    Cenário: Fila pausada ao atingir o teto dos lançamentos
      Dado que o limite diário é 100 requisições e a reserva para ações de pessoas é 10
      E já foram usadas 87 hoje
      Quando a próxima despesa precisaria de 4 requisições
      Então ela não é processada hoje
      E a fila é pausada até o dia seguinte
      E os aprovadores veem o aviso "Limite diário do Sienge atingido"

    Cenário: A reserva atende quem está esperando na tela
      Dado que a fila de lançamentos parou no teto de 90 requisições
      Quando um colaborador cadastra um credor novo
      Então o credor é criado no Sienge usando a reserva do dia

    Cenário: Retomada no dia seguinte
      Dado que a fila foi pausada por cota
      Quando começa um novo dia
      Então as despesas são processadas na ordem em que foram aprovadas
      E antes das despesas aprovadas no novo dia

    Cenário: Ordem no domingo
      Dado que é domingo e há despesas aprovadas aguardando cota
      Quando começa o dia
      Então primeiro rodam a sincronização dos cadastros e a atualização dos títulos novos e alterados
      E em seguida a fila de lançamentos é liberada
      E só com o que sobrar o app busca o rateio dos títulos lançados direto no Sienge

  Regra: O Sienge também barra número repetido

    Cenário: Sienge recusa o título por número duplicado
      Dado que o tipo de documento "DANF" bloqueia número repetido para o mesmo credor no Sienge
      Quando o Sienge recusa a criação do título por número duplicado
      Então o worker procura o título existente do mesmo credor, número e emissão
      E se o valor também for igual, grava o número desse título na despesa em vez de marcar erro
      Mas se o valor for diferente, a despesa fica com erro "Já existe outro título com este número para o credor"

  Regra: Nada sensível fica no log

    Cenário: Registro de cada chamada
      Quando o worker faz qualquer chamada ao Sienge
      Então o log registra data, recurso, resultado e tempo de resposta
      E não registra senha, cabeçalho de autenticação, CPF completo nem chave Pix
