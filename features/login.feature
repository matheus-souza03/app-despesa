# language: pt
# Referências: SPEC.md RF01, RF02, RNF03, RNF04
# Troca de senha e saída do app: meu-usuario.feature

Funcionalidade: Login
  Como usuário do app de despesas
  Quero entrar com meu e-mail e senha
  Para enviar e acompanhar minhas despesas, ou aprová-las, com segurança

  Não existe autocadastro: somente administradores criam usuários.

  Contexto:
    Dado que existe o usuário ativo "maria@sencoengenharia.com.br" com a senha "Obra2026!"

  Regra: O usuário entra com e-mail e senha

    Cenário: Login com credenciais válidas
      Quando eu informo o e-mail "maria@sencoengenharia.com.br" e a senha "Obra2026!"
      E toco em "Entrar"
      Então estou autenticado
      E sou levado à minha tela inicial

    Cenário: E-mail com maiúsculas e espaços é aceito
      Quando eu informo o e-mail " Maria@Senco.com.br " e a senha "Obra2026!"
      E toco em "Entrar"
      Então estou autenticado

    Esquema do Cenário: Credenciais inválidas não revelam se o e-mail existe
      Quando eu informo o e-mail "<email>" e a senha "<senha>"
      E toco em "Entrar"
      Então vejo a mensagem "E-mail ou senha inválidos"
      E não estou autenticado

      Exemplos:
        | email                        | senha     |
        | maria@sencoengenharia.com.br | errada123 |
        | joao@sencoengenharia.com.br  | Obra2026! |

    Esquema do Cenário: Campos obrigatórios
      Quando eu informo o e-mail "<email>" e a senha "<senha>"
      E toco em "Entrar"
      Então vejo a mensagem "<mensagem>" junto ao campo "<campo>"
      E nenhuma tentativa de login é registrada

      Exemplos:
        | email                        | senha     | campo  | mensagem         |
        |                              | Obra2026! | e-mail | Informe o e-mail |
        | maria@senco                  | Obra2026! | e-mail | E-mail inválido  |
        | maria@sencoengenharia.com.br |           | senha  | Informe a senha  |

    Cenário: Usuário desativado não consegue entrar
      Dado que o usuário "maria@sencoengenharia.com.br" foi desativado por um administrador
      Quando eu informo o e-mail "maria@sencoengenharia.com.br" e a senha "Obra2026!"
      E toco em "Entrar"
      Então vejo a mensagem "Seu acesso está desativado. Fale com um administrador."
      E não estou autenticado

  Regra: O primeiro acesso é feito com usuário e senha definidos pelo administrador

    Cenário: Entrar com a senha definida pelo administrador
      Dado que um administrador cadastrou o usuário "joao@sencoengenharia.com.br" com a senha "Provisoria2026"
      Quando eu informo o e-mail "joao@sencoengenharia.com.br" e a senha "Provisoria2026"
      E toco em "Entrar"
      Então estou autenticado
      E sou levado à minha tela inicial

    Cenário: A troca da senha definida pelo administrador é opcional
      Dado que entrei com a senha definida pelo administrador
      Então não sou obrigado a trocar a senha
      E posso trocá-la quando quiser na tela "Meu usuário"

  Regra: O usuário pode redefinir a senha esquecida

    Esquema do Cenário: Solicitar redefinição de senha
      Quando eu toco em "Esqueci minha senha"
      E informo o e-mail "<email>"
      Então vejo a mensagem "Se o e-mail estiver cadastrado, você receberá um link para criar uma nova senha."

      Exemplos:
        | email                        |
        | maria@sencoengenharia.com.br |
        | joao@sencoengenharia.com.br  |

    Cenário: Redefinir a senha com um link válido
      Dado que solicitei a redefinição de senha há menos de 1 hora
      Quando eu abro o link recebido por e-mail
      E defino a senha "NovaSenha26" e confirmo a mesma senha
      Então minha senha é alterada
      E todas as minhas outras sessões são encerradas
      E o link deixa de funcionar

    Cenário: Link de redefinição expirado ou já usado
      Dado que meu link de redefinição tem mais de 1 hora ou já foi usado
      Quando eu abro o link
      Então vejo a mensagem "Este link não é mais válido. Solicite uma nova redefinição."

  Regra: Tentativas repetidas bloqueiam o acesso temporariamente

    Cenário: Bloqueio após 5 tentativas erradas
      Dado que errei a senha de "maria@sencoengenharia.com.br" 5 vezes nos últimos 15 minutos
      Quando eu tento entrar novamente, mesmo com a senha correta
      Então vejo a mensagem "Muitas tentativas. Tente novamente em 15 minutos."
      E não estou autenticado

    Cenário: Acesso liberado após o tempo de bloqueio
      Dado que meu acesso foi bloqueado por tentativas erradas há mais de 15 minutos
      Quando eu informo o e-mail "maria@sencoengenharia.com.br" e a senha "Obra2026!"
      E toco em "Entrar"
      Então estou autenticado

  Regra: A tela inicial depende da permissão do usuário

    Esquema do Cenário: Redirecionamento após o login
      Dado que "maria@sencoengenharia.com.br" tem o papel "<papel>" e aprovador "<aprovador>"
      Quando eu entro com credenciais válidas
      Então sou levado à tela "<tela>"

      Exemplos:
        | papel         | aprovador | tela            |
        | colaborador   | não       | Status despesas |
        | administrador | não       | Status despesas |
        | administrador | sim       | Aprovação       |

  Regra: A sessão permanece ativa no celular e respeita a fila offline

    Cenário: Continuar conectado entre usos
      Dado que entrei no app há 10 dias
      E usei o app pela última vez há 2 dias
      Quando eu abro o app
      Então continuo autenticado

    Cenário: Sessão expirada por inatividade
      Dado que não uso o app há mais de 30 dias
      Quando eu abro o app
      Então sou levado à tela de login

    Cenário: Sessão expirada com despesas aguardando envio
      Dado que tenho 2 despesas na fila offline do aparelho
      E minha sessão expirou
      Quando eu entro novamente com o mesmo usuário
      Então as 2 despesas são enviadas automaticamente

    Cenário: Outro usuário entra no aparelho com despesas pendentes
      Dado que "maria@sencoengenharia.com.br" tem 2 despesas na fila offline do aparelho
      E a sessão de "maria@sencoengenharia.com.br" expirou
      Quando "joao@sencoengenharia.com.br" entra no mesmo aparelho
      Então as despesas de "maria@sencoengenharia.com.br" não são enviadas nem exibidas para "joao@sencoengenharia.com.br"
      E permanecem guardadas até "maria@sencoengenharia.com.br" entrar novamente

    Cenário: Usuário desativado durante a sessão
      Dado que estou autenticado
      Quando um administrador desativa meu usuário
      E eu faço qualquer ação no app
      Então minha sessão é encerrada
      E vejo a mensagem "Seu acesso está desativado. Fale com um administrador."

    Cenário: Tentar entrar sem internet
      Dado que meu aparelho está sem conexão
      E não tenho sessão ativa
      Quando eu toco em "Entrar"
      Então vejo a mensagem "Sem conexão. Para entrar, é preciso estar conectado à internet."
