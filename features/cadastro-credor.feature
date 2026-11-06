# language: pt
# Referências: SPEC.md RF16–RF19, RN13, RN14, RN17, RN18
# Códigos de município: data/municipios-sienge.csv (5.570 municípios)

Funcionalidade: Cadastro de credor
  Como colaborador
  Quero encontrar ou cadastrar o fornecedor da compra
  Para que o título vá para o Sienge com o credor correto

  Contexto:
    Dado que estou autenticado como "maria@sencoengenharia.com.br"

  Regra: O credor é buscado por documento ou nome

    Cenário: Buscar credor por CNPJ
      Dado que o credor "FN do Brasil Ltda" de CNPJ "28.070.499/0001-22" está cadastrado
      Quando eu busco pelo CNPJ "28070499000122"
      Então vejo o credor "FN do Brasil Ltda"

    Cenário: Buscar credor por nome
      Dado que o credor "Morelate Distribuidora de Auto Pecas Ltda" está cadastrado
      Quando eu busco por "morelate"
      Então vejo o credor "Morelate Distribuidora de Auto Pecas Ltda" com o CNPJ

    Cenário: Credor não encontrado
      Quando eu busco pelo CNPJ "55.932.700/0001-06" e não há resultado
      Então vejo a mensagem "Credor não cadastrado"
      E o botão "Cadastrar credor"

  Regra: O cadastro com CNPJ é preenchido pela consulta pública

    Cenário: Dados preenchidos pela consulta pública
      Quando eu toco em "Cadastrar credor" e informo o CNPJ "55.932.700/0001-06"
      Então razão social, nome fantasia, endereço, número, complemento, bairro, município, UF e CEP são preenchidos pela consulta pública de CNPJ
      E posso conferir e corrigir os dados antes de salvar

    Cenário: Salvar o credor pessoa jurídica
      Dado que conferi os dados do CNPJ "55.932.700/0001-06"
      Quando eu toco em "Salvar"
      Então o credor é criado no Sienge com:
        | campo              | valor                                   |
        | tipo de credor     | Fornecedor                              |
        | tipo de pessoa     | Jurídica                                |
        | CNPJ               | 55.932.700/0001-06                      |
        | inscrição estadual | Não contribuinte                        |
        | município          | código do Sienge do município informado |
      E volto para o cadastro do título com o credor preenchido

    Cenário: CNPJ não encontrado na consulta pública
      Quando eu informo um CNPJ válido que a consulta pública não retorna
      Então vejo a mensagem "Não encontramos este CNPJ. Preencha os dados manualmente."
      E os campos ficam liberados para digitação

    Cenário: Recibo sem CNPJ
      Dado que o comprovante é um recibo sem CNPJ ou CPF
      Quando eu toco em "Cadastrar credor"
      Então vejo a orientação "Pesquise o CNPJ ou CPF do fornecedor e informe aqui"
      E não consigo salvar sem informar o CNPJ ou CPF

    Cenário: Cadastrar credor pessoa física
      Quando eu informo o CPF de um prestador
      Então preencho nome, endereço e município manualmente
      E o credor é criado como pessoa física

    Esquema do Cenário: Documento inválido
      Quando eu informo o documento "<documento>"
      Então vejo a mensagem "<mensagem>"

      Exemplos:
        | documento          | mensagem                        |
        | 55.932.700/0001-07 | CNPJ inválido                   |
        | 111.111.111-11     | CPF inválido                    |
        | 1234               | Informe um CNPJ ou CPF completo |

  Regra: Credores não são duplicados

    Cenário: CNPJ já cadastrado no Sienge
      Dado que o CNPJ "28.070.499/0001-22" já existe no Sienge
      Quando eu tento cadastrá-lo de novo
      Então vejo a mensagem "Este credor já está cadastrado"
      E o credor existente é usado no título

  Regra: Os dados são ajustados ao formato aceito pelo Sienge

    Esquema do Cenário: Limpeza de caracteres
      Quando o nome informado é "<informado>"
      Então o nome enviado ao Sienge é "<enviado>"

      Exemplos:
        | informado                     | enviado                   |
        | Auto Peças São João           | Auto Pecas Sao Joao       |
        | Silva & Filhos Ltda.          | Silva e Filhos Ltda       |
        | Ferragens "Nova Era" - Filial | Ferragens Nova Era Filial |
        | Construção  Ltda              | Construcao Ltda           |

  Regra: Todo credor é cadastrado como "Não contribuinte"

    Esquema do Cenário: Inscrição estadual fixa
      Quando eu cadastro um credor "<tipo>"
      Então a inscrição estadual enviada ao Sienge é "Não contribuinte"
      E o campo de inscrição estadual não aparece para edição

      Exemplos:
        | tipo                                   |
        | pessoa jurídica pela consulta pública  |
        | pessoa jurídica preenchido manualmente |
        | pessoa física                          |

  Regra: O município é enviado com o código do Sienge

    Esquema do Cenário: Município vindo da consulta pública
      Dado que a consulta pública de CNPJ retornou o município "<retornado>" e a UF "<uf>"
      Quando eu salvo o credor
      Então o município enviado ao Sienge é o código "<codigo>"

      Exemplos:
        | retornado      | uf | codigo |
        | RIO DAS OSTRAS | RJ | 3669   |
        | NOVA FRIBURGO  | RJ | 3651   |
        | MACAE          | RJ | 3639   |
        | SAO PAULO      | SP | 3      |

    Cenário: Escolher o município ao preencher manualmente
      Dado que estou preenchendo o credor manualmente
      Quando eu digito "rio das" no campo município
      Então vejo as opções com nome e UF, como "Rio das Ostras - RJ"
      E ao escolher "Rio das Ostras - RJ" o código "3669" é usado no cadastro

    Cenário: Municípios com o mesmo nome em estados diferentes
      Quando eu digito "Belém" no campo município
      Então vejo "Belém - PA" e "Belém - AL" como opções separadas
      E cada uma usa o seu próprio código do Sienge

    Cenário: Município da consulta pública sem correspondência
      Dado que a consulta pública retornou um município que não foi encontrado na lista do Sienge
      Quando eu salvo o credor
      Então preciso escolher o município na lista antes de concluir

    Cenário: Município obrigatório
      Quando eu tento salvar um credor sem município
      Então vejo a mensagem "Informe o município"

  Regra: O cadastro não se perde se o Sienge estiver indisponível

    Cenário: Sienge fora do ar ou cota diária esgotada
      Dado que o Sienge não pode receber chamadas agora
      Quando eu salvo um credor novo
      Então o credor fica como "Aguardando cadastro no Sienge"
      E é criado automaticamente assim que possível
      E as despesas que o usam continuam podendo ser enviadas
