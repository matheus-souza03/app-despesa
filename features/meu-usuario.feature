# language: pt
# Referências: SPEC.md §3, RF01, RF28

Funcionalidade: Meu usuário
  Como usuário do app de despesas
  Quero ver meus dados e minhas permissões e trocar minha senha
  Para saber o que posso fazer no app e manter meu acesso seguro

  Contexto:
    Dado que estou autenticado como "maria@sencoengenharia.com.br"

  Regra: A tela é aberta pelo ícone do usuário

    Cenário: Abrir a tela Meu usuário
      Quando eu toco no ícone do meu usuário em qualquer tela
      Então sou levado à tela "Meu usuário"

  Regra: O usuário vê seus dados, mas não os altera

    Cenário: Ver meus dados
      Quando eu abro a tela "Meu usuário"
      Então vejo meu nome e meu e-mail
      E vejo os meus papéis
      E vejo o botão "Redefinir senha"
      E vejo o botão "Sair"

    Esquema do Cenário: Papéis exibidos
      Dado que tenho o papel "<papel>" e aprovador "<aprovador>"
      Quando eu abro a tela "Meu usuário"
      Então vejo os papéis "<papeis>"

      Exemplos:
        | papel         | aprovador | papeis                   |
        | colaborador   | não       | Colaborador              |
        | colaborador   | sim       | Colaborador, Aprovador   |
        | administrador | não       | Administrador            |
        | administrador | sim       | Administrador, Aprovador |

    Cenário: Dados não editáveis pelo próprio usuário
      Quando eu abro a tela "Meu usuário"
      Então nome, e-mail e papéis aparecem apenas para leitura
      E vejo a orientação "Para alterar seus dados, fale com um administrador"

  Regra: O usuário pode trocar a senha quando quiser

    Cenário: Trocar a senha
      Quando eu toco em "Redefinir senha"
      E informo a senha atual "Obra2026!"
      E defino a nova senha "Frota#2026" e confirmo a mesma senha
      Então minha senha é alterada
      E continuo autenticado neste aparelho
      E minhas sessões em outros aparelhos são encerradas

    Cenário: Senha atual incorreta
      Quando eu toco em "Redefinir senha"
      E informo a senha atual "errada123"
      E defino a nova senha "Frota#2026" e confirmo a mesma senha
      Então vejo a mensagem "Senha atual incorreta"
      E minha senha não é alterada

    Esquema do Cenário: Nova senha que não atende aos requisitos
      Dado que toquei em "Redefinir senha" e informei a senha atual correta
      Quando eu defino a nova senha "<senha>" e confirmo "<confirmacao>"
      Então vejo a mensagem "<mensagem>"
      E minha senha não é alterada

      Exemplos:
        | senha      | confirmacao | mensagem                                    |
        | abc12      | abc12       | A senha precisa ter pelo menos 8 caracteres |
        | abcdefgh   | abcdefgh    | A senha precisa ter letras e números        |
        | Frota#2026 | Frota#2027  | As senhas não conferem                      |
        | Obra2026!  | Obra2026!   | A nova senha deve ser diferente da atual    |

  Regra: O usuário sai do app por esta tela

    Cenário: Sair do app
      Dado que não tenho despesas aguardando envio no aparelho
      Quando eu toco em "Sair"
      Então minha sessão é encerrada
      E sou levado à tela de login

    Cenário: Sair com despesas ainda não enviadas
      Dado que tenho 1 despesa na fila offline do aparelho
      Quando eu toco em "Sair"
      Então vejo o aviso "Você tem 1 despesa ainda não enviada. Conecte-se à internet antes de sair para não perdê-la."
      E posso escolher entre "Cancelar" e "Sair mesmo assim"
