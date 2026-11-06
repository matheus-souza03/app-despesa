# language: pt
# Referências: SPEC.md RF06–RF15, RF25, RN01–RN13, RN21, §7, §9

Funcionalidade: Cadastro de título
  Como colaborador
  Quero registrar uma compra pelo celular, lendo os códigos do comprovante, digitando manualmente ou importando uma planilha
  Para que ela chegue ao financeiro completa, sem precisar mandar pelo WhatsApp

  Contexto:
    Dado que estou autenticado como "maria@sencoengenharia.com.br"
    E tenho permissão nos centros de custo:
      | empresa | centro de custo                         |
      | 1       | 107 - Emissário - Rio das Ostras        |
      | 1       | 1062 - KML8D31 - Caminhão GMC           |
      | 1       | 1066 - EFO7F00 - Volkswagen 9.150E      |
      | 4       | 4033 - LSZ4J89 - Caminhão Leve VW 8.160 |
    E o credor de CNPJ "28.070.499/0001-22" (FN do Brasil Ltda) está cadastrado no Sienge

  Regra: A leitura da chave de acesso preenche os dados da nota

    Cenário: Ler o código de barras de um DANFE
      Quando eu escaneio o código de barras "33260928070499000122550010000030871000059038"
      Então o credor "FN do Brasil Ltda" é preenchido
      E o número do documento é preenchido com "003.087"
      E o tipo de documento é definido como "DANF"
      E a chave de acesso fica registrada no título
      E a data de emissão precisa estar em setembro de 2026
      E os campos preenchidos aparecem marcados como "lido do código"

    Cenário: Ler o QR code de um cupom fiscal (NFC-e)
      Quando eu escaneio o QR code de uma NFC-e
      Então a chave de acesso é extraída da URL do QR code
      E o tipo de documento é definido como "DANF"

    Cenário: Código com dígito verificador inválido
      Quando eu escaneio o código "33260928070499000122550010000030871000059030"
      Então vejo a mensagem "Código não reconhecido. Confira o comprovante ou preencha manualmente."
      E nenhum campo é alterado

    Cenário: Data de emissão fora do mês indicado pela chave
      Dado que escaneei a chave de uma nota emitida em setembro de 2026
      Quando eu informo a data de emissão "05/10/2026"
      Então vejo o aviso "A data não confere com a nota (setembro de 2026)"

    Cenário: Campos lidos continuam editáveis
      Dado que o número do documento foi preenchido pela leitura com "003.087"
      Quando eu altero o número para "003.088"
      Então o novo valor é aceito
      E o valor lido "003.087" fica guardado para a revisão do aprovador

  Regra: A leitura do boleto preenche valor e vencimento da parcela

    Cenário: Ler a linha digitável de um boleto
      Quando eu informo a linha digitável "34191.09107 07142.916902 69952.760002 9 16090000036555"
      Então a parcela é preenchida com valor "365,55" e vencimento "24/10/2026"
      E a linha digitável fica registrada na despesa
      Mas não é incluída automaticamente na observação

    Cenário: Um boleto por parcela
      Dado que escaneei a nota de "900,00"
      Quando eu escaneio os boletos:
        | boleto | valor  | vencimento |
        | 1      | 300,00 | 10/11/2026 |
        | 2      | 350,00 | 10/12/2026 |
        | 3      | 250,00 | 15/01/2027 |
      Então "A nota já está paga?" fica como "Não"
      E a despesa tem 3 parcelas com esses valores e vencimentos
      E vejo a confirmação "Boleto 3 de 3 lido"

    Cenário: Boletos diferentes da regra do Sienge
      Dado que as parcelas montadas pelos boletos são 300,00, 350,00 e 250,00
      Então "As parcelas são diferentes" é marcado automaticamente
      E vejo o aviso "O título será lançado com parcelas iguais e mensais; o financeiro ajusta as parcelas no Sienge"

    Cenário: Boletos iguais à regra do Sienge
      Dado que escaneei 3 boletos de "300,00" com vencimentos em 10/11/2026, 10/12/2026 e 10/01/2027
      Então "As parcelas são diferentes" não é marcado

    Cenário: Menos boletos que parcelas
      Dado que escaneei só o boleto da 1ª parcela
      Quando eu informo que são 3 parcelas
      Então a parcela 1 vem do boleto
      E preencho valor e vencimento das parcelas 2 e 3

    Cenário: Remover um boleto lido por engano
      Dado que escaneei 3 boletos
      Quando eu removo o boleto 2
      Então a despesa fica com 2 parcelas

    Cenário: Soma dos boletos diferente do total da nota
      Dado que o valor total da nota é "900,00"
      Quando a soma dos boletos escaneados é "850,00"
      Então vejo o aviso "A soma dos boletos (850,00) é diferente do total (900,00)"

    Cenário: Boleto com valor em branco
      Quando eu escaneio um boleto cujo código não traz valor
      Então o vencimento é preenchido
      E vejo a mensagem "Este boleto não informa o valor. Digite o valor da parcela."

    Cenário: Valor do boleto diferente do total da nota
      Dado que o valor total do título é "490,80"
      Quando eu escaneio um boleto de valor "450,00"
      Então vejo o aviso "O valor do boleto (450,00) é diferente do total (490,80)"
      Mas consigo continuar o cadastro

  Regra: Tipo de documento, credor e número seguem o comprovante e a forma de pagamento

    Esquema do Cenário: Tipo de documento calculado
      Quando eu informo a forma de pagamento "<forma>" e o comprovante "<comprovante>"
      Então o tipo de documento é "<tipo>"
      E o credor esperado é "<credor>"

      Exemplos:
        | forma              | comprovante     | tipo | credor                |
        | reembolso          | nota fiscal     | DANF | emitente da nota      |
        | reembolso          | nenhum          | REMB | o próprio colaborador |
        | cartão corporativo | nota fiscal     | DANF | emitente da nota      |
        | cartão corporativo | nenhum          | PAG  | fornecedor            |
        | Pix da empresa     | nenhum          | PAG  | fornecedor            |
        | Pix da empresa     | recibo          | REC  | emitente do recibo    |
        | boleto a prazo     | nota fiscal     | DANF | emitente da nota      |
        | boleto a prazo     | nenhum          | PAG  | fornecedor            |
        | cartão corporativo | nota de serviço | NFSE | emitente da nota      |

    Cenário: Reembolso sem nota e sem credor indicado usa o colaborador
      Quando eu informo a forma de pagamento "reembolso" e o comprovante "nenhum"
      E não indico nenhum credor
      Então o credor do título é o meu cadastro de colaborador

    Cenário: Reembolso sem nota com credor indicado
      Dado que informei a forma de pagamento "reembolso" e o comprovante "nenhum"
      Quando eu indico o credor "ACQUA LUZ MATERIAIS ELETRICOS LTDA"
      Então o credor do título é "ACQUA LUZ MATERIAIS ELETRICOS LTDA"
      E o tipo de documento continua "REMB"

    Cenário: Boleto a prazo sem nota nem recibo
      Dado que informei a forma de pagamento "boleto a prazo" e o comprovante "nenhum"
      E o 1º vencimento do boleto é "10/11/2026"
      Então o tipo de documento é "PAG"
      E o número do documento é "10/11"

    Esquema do Cenário: Número do documento quando não há número no comprovante
      Dado que o tipo de documento é "<tipo>"
      E o comprovante não tem número
      Quando eu informo a data do pagamento "14/09/2026"
      Então o número do documento é "14/09"

      Exemplos:
        | tipo |
        | PAG  |
        | REMB |
        | REC  |

    Cenário: Recibo com número usa o número do recibo
      Dado que o tipo de documento é "REC"
      Quando eu informo o número do recibo "17758"
      Então o número do documento é "17758"

  Regra: O colaborador informa se a nota já está paga

    Esquema do Cenário: Sugestão inicial pela forma de pagamento
      Quando eu escolho a forma de pagamento "<forma>"
      Então a opção "A nota já está paga?" vem marcada como "<paga>"
      E posso trocar a resposta

      Exemplos:
        | forma              | paga |
        | cartão corporativo | Sim  |
        | Pix da empresa     | Sim  |
        | boleto a prazo     | Não  |

    Cenário: Reembolso não tem sugestão
      Quando eu escolho a forma de pagamento "reembolso"
      Então a opção "A nota já está paga?" fica sem resposta
      E preciso escolher "Sim" ou "Não" antes de enviar

    Cenário: Nota paga exige a data do pagamento
      Dado que marquei "A nota já está paga?" como "Sim"
      Quando eu tento enviar sem a data do pagamento
      Então vejo a mensagem "Informe a data do pagamento"

    Cenário: Nota paga tem uma única parcela
      Dado que marquei "A nota já está paga?" como "Sim"
      Então o título terá 1 parcela com o valor total
      E a opção de parcelar não aparece

    Cenário: Nota não paga pede os vencimentos
      Dado que marquei "A nota já está paga?" como "Não"
      Então não é pedida a data do pagamento
      E informo o vencimento de cada parcela

  Regra: As datas do título são calculadas

    Cenário: Nota paga
      Dado que marquei "A nota já está paga?" como "Sim"
      Quando eu informo a data de emissão "14/09/2026" e a data do pagamento "14/09/2026"
      Então a data contábil é "14/09/2026"
      E a data base é "01/09/2026"
      E o vencimento da parcela é "14/09/2026"

    Cenário: Nota não paga
      Dado que marquei "A nota já está paga?" como "Não"
      Quando eu informo a data de emissão "14/09/2026" e o vencimento "12/10/2026"
      Então a data contábil é "14/09/2026"
      E a data base é "01/09/2026"
      E o vencimento da parcela é "12/10/2026"

  Regra: A empresa define quais centros de custo podem ser usados

    Cenário: Só aparecem centros de custo da empresa escolhida e permitidos ao usuário
      Quando eu escolho a empresa "1"
      Então posso escolher os centros de custo "107", "1062" e "1066"
      E não vejo o centro de custo "4033"

    Cenário: Trocar a empresa depois de preencher apropriações
      Dado que escolhi a empresa "1" e o centro de custo "1062"
      Quando eu troco a empresa para "4"
      Então vejo o aviso "As apropriações serão apagadas porque os centros de custo são de outra empresa"
      E posso confirmar ou cancelar a troca

  Regra: As apropriações somam exatamente o valor total

    Cenário: Uma apropriação com o valor total
      Dado que o valor total é "147,29"
      Quando eu adiciono o centro de custo "107" com o plano financeiro "2.01.01.06" e valor "147,29"
      Então o saldo restante é "0,00"
      E consigo enviar

    Cenário: Rateio entre dois veículos
      Dado que o valor total é "365,55"
      Quando eu adiciono o centro de custo "1062" com o plano financeiro "2.01.04.02" e valor "182,78"
      E adiciono o centro de custo "1066" com o plano financeiro "2.01.04.02" e valor "182,77"
      Então o saldo restante é "0,00"
      E consigo enviar

    Cenário: Mais de um plano financeiro no mesmo centro de custo
      Dado que o valor total é "490,80"
      Quando eu adiciono ao centro de custo "107" o plano "2.01.01.06" com "390,80" e o plano "2.01.04.02" com "100,00"
      Então o saldo restante é "0,00"

    Esquema do Cenário: Soma diferente do total bloqueia o envio
      Dado que o valor total é "365,55"
      Quando a soma das apropriações é "<soma>"
      Então vejo "<mensagem>"
      E não consigo enviar

      Exemplos:
        | soma   | mensagem                         |
        | 300,00 | Faltam 65,55 para fechar o total |
        | 400,00 | Excedeu o total em 34,45         |

  Regra: O plano financeiro mostra só contas que recebem despesas

    Cenário: Buscar plano financeiro com nome repetido
      Quando eu busco o plano financeiro por "Seguros"
      Então vejo os resultados com código e grupo, por exemplo:
        | código     | nome    | grupo                   |
        | 2.01.04.06 | Seguros | Veículos e equipamentos |
        | 2.01.06.03 | Seguros | Localização             |
      E não vejo contas totalizadoras, redutoras ou de receitas

    Cenário: Navegar pela lista completa
      Quando eu toco em "Ver todos os planos"
      Então vejo os planos organizados por grupo

  Regra: As parcelas seguem a regra do Sienge, e diferenças ficam para ajuste no Sienge

    Cenário: Nota paga tem uma parcela com o valor total
      Dado que marquei "A nota já está paga?" como "Sim"
      Quando eu informo o valor total "490,80"
      Então existe 1 parcela de "490,80"

    Cenário: Prévia das parcelas geradas pelo Sienge
      Dado que marquei "A nota já está paga?" como "Não"
      E o valor total é "17.214,96"
      Quando eu informo 3 parcelas com 1º vencimento "19/11/2026"
      Então vejo a prévia:
        | parcela | valor    | vencimento |
        | 1       | 5.738,32 | 19/11/2026 |
        | 2       | 5.738,32 | 19/12/2026 |
        | 3       | 5.738,32 | 19/01/2027 |

    Cenário: Prévia com vencimento no fim do mês
      Dado que o valor total é "900,00"
      Quando eu informo 3 parcelas com 1º vencimento "31/01/2027"
      Então vejo a prévia com vencimentos "31/01/2027", "28/02/2027" e "31/03/2027"

    Cenário: Parcelas reais diferentes da prévia
      Dado que o valor total é "900,00"
      Quando eu marco "As parcelas são diferentes"
      E informo as parcelas:
        | parcela | valor  | vencimento |
        | 1       | 300,00 | 10/11/2026 |
        | 2       | 350,00 | 10/12/2026 |
        | 3       | 250,00 | 15/01/2027 |
      Então consigo enviar
      E vejo o aviso "O título será lançado com parcelas iguais e mensais; o financeiro ajusta as parcelas no Sienge"

    Cenário: Parcelas diferentes que não fecham o total
      Dado que marquei "As parcelas são diferentes" e o valor total é "900,00"
      Quando a soma das parcelas é "850,00"
      Então vejo "Faltam 50,00 nas parcelas"
      E não consigo enviar

  Regra: O credor não cadastrado não impede o envio

    Cenário: CNPJ lido de um credor que não existe no Sienge
      Quando eu escaneio a chave de uma nota de um emitente não cadastrado
      Então o CNPJ do credor fica preenchido
      E vejo o aviso "Credor não cadastrado" com o botão "Cadastrar credor"
      E consigo enviar a despesa mesmo assim

  Regra: Toda despesa tem ao menos um anexo, e todo anexo tem a descrição do tipo de documento

    Cenário: Enviar sem anexo
      Quando eu tento enviar uma despesa sem anexo
      Então vejo a mensagem "Anexe pelo menos um comprovante"

    Cenário: Opções de descrição do anexo
      Quando eu anexo um arquivo
      Então escolho a descrição numa lista com as opções:
        | descrição | uso                                    |
        | DANFe     | Nota fiscal eletrônica ou cupom fiscal |
        | NFSE      | Nota fiscal de serviço                 |
        | REC       | Recibo                                 |
        | PAG       | Comprovante de pagamento sem nota      |
        | REMB      | Comprovante de reembolso               |
        | COMP      | Comprovante de pagamento               |

    Esquema do Cenário: Descrição sugerida pelo tipo de documento
      Dado que o tipo de documento é "<tipo>"
      Quando eu anexo o "<arquivo>"
      Então a descrição sugerida do anexo é "<descricao>"
      E posso trocar a descrição por outra opção da lista

      Exemplos:
        | tipo | arquivo            | descricao |
        | DANF | documento da nota  | DANFe     |
        | NFSE | documento da nota  | NFSE      |
        | REC  | foto do recibo     | REC       |
        | PAG  | comprovante do Pix | COMP      |
        | REMB | comprovante do Pix | COMP      |

    Cenário: Anexo sem descrição
      Dado que anexei um arquivo antes de definir o tipo de documento
      Quando eu tento enviar a despesa sem escolher a descrição do anexo
      Então vejo a mensagem "Escolha o tipo de documento de cada anexo"
      E não consigo enviar

    Cenário: Mais de um anexo
      Quando eu anexo a nota fiscal e o comprovante do Pix
      Então a despesa tem 2 anexos, sugeridos como "DANFe" e "COMP"
      Mas posso trocar a descrição de cada anexo, se quiser

    Cenário: Arquivo acima do limite
      Quando eu anexo um arquivo de 80 MB
      Então vejo a mensagem "O arquivo passa de 70 MB"

    Cenário: Foto comprimida antes do envio
      Quando eu tiro uma foto do comprovante pela câmera
      Então vejo a prévia da foto
      E a imagem é comprimida antes de subir

  Regra: A mesma despesa não pode ser enviada duas vezes

    Cenário: Nota já enviada
      Dado que já existe uma despesa com a chave "33260928070499000122550010000030871000059038"
      Quando eu escaneio a mesma chave
      Então vejo a mensagem "Esta nota já foi enviada" com o link para a despesa existente
      E não consigo enviar

    Cenário: Mesmo documento digitado com zeros diferentes
      Dado que já existe uma despesa do credor "FN do Brasil Ltda" com número "003.087", emissão "14/09/2026" e valor "490,80"
      Quando eu digito o número "3087" para o mesmo credor, data e valor
      Então vejo a mensagem "Esta despesa parece já ter sido enviada" com o link para a existente

  Regra: A observação é opcional

    Cenário: Enviar sem observação
      Quando eu envio uma despesa válida sem preencher a observação
      Então a despesa é enviada
      E a observação do título no Sienge fica em branco

    Cenário: Escrever uma observação
      Quando eu escrevo a observação "Faixas refletivas - GMC e EFO7F00"
      Então ela vai para o campo Observação do título no Sienge exatamente como escrevi

    Cenário: Observação longa demais
      Quando eu escrevo uma observação com mais de 500 caracteres
      Então vejo o contador "500/500" e não consigo digitar mais

  Regra: O cadastro funciona sem internet

    Cenário: Enviar sem conexão
      Dado que meu aparelho está sem conexão
      Quando eu envio uma despesa válida
      Então ela fica guardada no aparelho como "Aguardando envio"
      E é enviada automaticamente quando a conexão voltar

    Cenário: Verificação de duplicidade adiada
      Dado que enviei uma despesa sem conexão
      Quando a conexão volta e o servidor encontra uma duplicata
      Então a despesa não é registrada
      E vejo o aviso "Esta despesa já tinha sido enviada" na tela de status

  Regra: É possível importar várias despesas por planilha

    Cenário: Baixar o modelo
      Quando eu toco em "Importar planilha" abaixo do formulário
      Então posso baixar o modelo de planilha com as colunas esperadas

    Cenário: Importar planilha válida com rateio
      Dado uma planilha com as linhas:
        | Código | Documento | Nº doc.     | Empresa | Credor             | Emissão    | Valor total | Desconto | Parcelas | 1º vencimento | Centro de custo | Plano financeiro | Valor CC | Arquivo do comprovante |
        | 1      | DANF      | 003.072.580 | 1       | 04.617.659/0001-42 | 02/10/2026 | 147,29      | 0,00     | 1        | 02/10/2026    | 107             | 2.01.01.06       | 147,29   | nota-3072580.pdf       |
        | 2      | DANF      | 085.414     | 1       | 04.125.812/0005-48 | 26/09/2026 | 365,55      | 0,00     | 1        | 26/09/2026    | 1062            | 2.01.04.02       | 182,78   | nota-85414.pdf         |
        | 2      |           |             |         |                    |            |             |          |          |               | 1066            | 2.01.04.02       | 182,77   |                        |
      E envio junto os arquivos "nota-3072580.pdf" e "nota-85414.pdf"
      Quando eu importo a planilha
      Então são criadas 2 despesas pendentes
      E a despesa de código "2" tem 2 apropriações
      E cada despesa recebe o comprovante indicado na coluna "Arquivo do comprovante"

    Esquema do Cenário: Linhas inválidas são recusadas com o motivo
      Dado uma planilha em que a despesa de código "5" tem "<problema>"
      Quando eu importo a planilha
      Então a despesa "5" não é importada
      E vejo o motivo "<motivo>"
      E as demais despesas válidas são importadas

      Exemplos:
        | problema                                     | motivo                                        |
        | centro de custo de outra empresa             | Centro de custo 4033 não pertence à empresa 1 |
        | soma dos valores de centro de custo ≠ total  | Rateio soma 300,00, mas o total é 365,55      |
        | documento "XYZ"                              | Tipo de documento inválido: XYZ               |
        | CNPJ com dígito errado                       | CNPJ/CPF do credor inválido                   |
        | arquivo do comprovante não enviado           | Arquivo nota-123.pdf não foi enviado          |
        | nota já enviada                              | Despesa duplicada                             |
        | centro de custo sem permissão para o usuário | Sem permissão no centro de custo 1062         |

    Esquema do Cenário: Centro de custo escrito de forma aproximada
      Dado uma planilha da empresa "1" com o texto "<texto>" na coluna "Centro de custo"
      Quando eu importo a planilha
      Então o centro de custo escolhido é "<escolhido>"
      E aparece como "<origem>" numa lista suspensa que posso trocar

      Exemplos:
        | texto                    | escolhido                          | origem                |
        | 1062                     | 1062 · KML8D31 · Caminhão GMC      | Encontrado pelo texto |
        | KML8D31                  | 1062 · KML8D31 · Caminhão GMC      | Encontrado pelo texto |
        | emissario rio das ostras | 107 · Emissário – Rio das Ostras   | Encontrado pelo texto |
        | volkswagen 9150          | 1066 · EFO7F00 · Volkswagen 9.150E | Encontrado pelo texto |

    Cenário: Placa que existe em mais de uma empresa
      Dado que a placa "LSZ4J89" existe nos centros de custo 1000 (empresa 1), 2008 (empresa 2) e 4033 (empresa 4)
      Quando uma linha da empresa "1" traz "LSZ4J89" na coluna "Centro de custo"
      Então o centro de custo escolhido é "1000 · LSZ4J89 · Caminhão Leve VW 8.160"

    Cenário: Centro de custo não encontrado
      Dado uma linha com o texto "galpão novo" na coluna "Centro de custo"
      Quando nenhum centro de custo da empresa corresponde ao texto
      Então a linha aparece como "Não encontrado · escolha na lista"
      E ela só é importada depois que eu escolher o centro de custo

    Cenário: Credor da planilha não cadastrado
      Dado uma planilha com um credor que não existe no Sienge
      Quando eu importo a planilha
      Então a despesa é importada com o aviso "Credor não cadastrado"
      E as demais despesas da planilha são importadas normalmente

    Cenário: Descrição dos anexos importados
      Dado uma planilha com uma despesa do tipo "DANF" e o arquivo do comprovante enviado junto
      Quando eu importo a planilha
      Então o anexo recebe a descrição "DANFe"

    Cenário: Arquivo enviado e não citado na planilha
      Dado que enviei o arquivo "extra.pdf" junto com a planilha
      E nenhuma linha cita "extra.pdf"
      Quando eu importo a planilha
      Então vejo o aviso "O arquivo extra.pdf não foi usado em nenhuma despesa"
      E ele não é guardado
