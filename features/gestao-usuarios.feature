# language: pt
# Referências: SPEC.md §3, RF02–RF05, RN14, RNF04

Funcionalidade: Gestão de usuários
  Como administrador
  Quero cadastrar as pessoas que usam o app e definir o que cada uma pode fazer
  Para que cada colaborador lance só nos centros de custo dele e só quem deve aprove

  Contexto:
    Dado que estou autenticado como "ronald@sencoengenharia.com.br" com o papel "administrador"

  Regra: Somente administradores gerenciam usuários

    Cenário: Colaborador tenta abrir a gestão de usuários
      Dado que estou autenticado como "maria@sencoengenharia.com.br" com o papel "colaborador"
      Então não vejo a opção "Usuários" no menu
      E se eu acessar o endereço da tela diretamente, vejo a mensagem "Você não tem permissão para gerenciar usuários"

  Regra: O administrador cadastra usuários com uma senha provisória

    Cenário: Cadastrar um colaborador
      Quando eu cadastro o usuário:
        | campo            | valor                       |
        | nome             | João Pereira                |
        | e-mail           | joao@sencoengenharia.com.br |
        | senha provisória | Provisoria2026              |
        | perfil           | colaborador de escritório   |
        | administrador    | não                         |
        | CPF              | 529.982.247-25              |
        | chave Pix        | joao.pereira@mail.com       |
        | município        | Rio das Ostras - RJ         |
      E escolho os centros de custo "1062" e "1066"
      Então o usuário é criado
      E ele já pode entrar no app com a senha provisória
      E a senha provisória não fica visível depois de salva

    Cenário: E-mail já usado
      Dado que existe o usuário "maria@sencoengenharia.com.br"
      Quando eu tento cadastrar outro usuário com o e-mail "maria@sencoengenharia.com.br"
      Então vejo a mensagem "Já existe um usuário com este e-mail"

    Esquema do Cenário: Senha provisória fora dos requisitos
      Quando eu cadastro um usuário com a senha provisória "<senha>"
      Então vejo a mensagem "<mensagem>"
      E o usuário não é criado

      Exemplos:
        | senha    | mensagem                                    |
        | abc12    | A senha precisa ter pelo menos 8 caracteres |
        | abcdefgh | A senha precisa ter letras e números        |

    Cenário: Definir uma nova senha provisória para um usuário
      Dado que "joao@sencoengenharia.com.br" esqueceu a senha
      Quando eu defino para ele a nova senha provisória "Provisoria2027"
      Então a senha dele é alterada
      E as sessões abertas dele são encerradas

  Regra: Os dados de reembolso viram o credor do colaborador no Sienge

    Cenário: Criar o credor do colaborador
      Quando eu salvo um usuário com CPF "529.982.247-25"
      Então um credor pessoa física do tipo "Colaborador" é criado ou atualizado no Sienge
      E a inscrição estadual do credor é "Não contribuinte"
      E o município é enviado com o código do Sienge "3669"
      E esse credor passa a ser usado nos reembolsos dele

    Cenário: Município obrigatório para o credor do colaborador
      Quando eu salvo um usuário com CPF e sem município
      Então vejo a mensagem "Informe o município do colaborador (obrigatório no cadastro de credor do Sienge)"

    Cenário: CPF inválido
      Quando eu informo o CPF "529.982.247-26"
      Então vejo a mensagem "CPF inválido"

    Cenário: Dados sensíveis mascarados na listagem
      Quando eu abro a lista de usuários
      Então o CPF aparece como "***.982.247-**"
      E a chave Pix não aparece na lista

  Regra: Permissões de centro de custo são definidas por usuário

    Cenário: Lista de centros de custo para permissão
      Quando eu edito as permissões de um colaborador
      Então vejo apenas centros de custo vinculados a alguma empresa, agrupados por empresa
      E posso marcar todos os centros de custo de uma empresa de uma vez

    Cenário: Remover a permissão de um centro de custo
      Dado que "joao@sencoengenharia.com.br" tem permissão no centro de custo "1062"
      Quando eu removo essa permissão
      Então ele não consegue mais escolher o "1062" em novas despesas
      E as despesas que ele já enviou com o "1062" não são alteradas

    Cenário: Aprovadores veem todos os centros de custo
      Dado que "camilla@sencoengenharia.com.br" tem o perfil "aprovador"
      E "marcos.bento@sencoengenharia.com.br" tem o perfil "aprovador de centro de custo"
      Então os dois podem usar qualquer centro de custo, sem lista de permissões

    Cenário: Administradores veem todos os centros de custo
      Dado que "pedro@sencoengenharia.com.br" tem o perfil "colaborador de escritório" e é administrador
      Então ele pode usar qualquer centro de custo da empresa da despesa, sem lista de permissões

    Cenário: Colaborador de rua não tem centros de custo
      Quando eu defino o perfil "colaborador de rua" para um usuário
      Então a lista de centros de custo não aparece no cadastro dele

  Regra: Cada usuário tem um perfil, e a marcação de administrador é à parte

    Esquema do Cenário: O que cada perfil faz
      Quando eu defino o perfil "<perfil>" para um usuário
      Então ao cadastrar ele informa centro de custo: "<informa_cc>"
      E a despesa enviada por ele vai para "<destino>"
      E ele define centro de custo de despesas de rua: "<define_cc>"
      E ele aprova e lança no Sienge: "<aprova>"

      Exemplos:
        | perfil                       | informa_cc        | destino                    | define_cc | aprova |
        | colaborador de rua           | não               | aguardando centro de custo | não       | não    |
        | colaborador de escritório    | sim, os liberados | aprovação                  | não       | não    |
        | aprovador de centro de custo | sim, todos        | aprovação                  | sim       | não    |
        | aprovador                    | sim, todos        | lançamento                 | sim       | sim    |

    Cenário: Administrador em qualquer perfil
      Quando eu marco "Administrador" para um usuário com o perfil "colaborador de escritório"
      Então ele passa a gerenciar usuários e configurações
      E continua com o que o perfil "colaborador de escritório" permite
      Mas pode usar qualquer centro de custo, sem lista de permissões

  Regra: Sempre existe ao menos um administrador e um aprovador ativos

    Cenário: Remover o último administrador
      Dado que sou o único administrador ativo
      Quando eu tento desmarcar "Administrador" no meu usuário
      Então vejo a mensagem "É preciso manter pelo menos um administrador ativo"

    Cenário: Remover o último aprovador
      Dado que "camilla@sencoengenharia.com.br" é a única aprovadora ativa
      Quando eu tento mudar o perfil dela ou desativá-la
      Então vejo a mensagem "É preciso manter pelo menos um aprovador ativo"

  Regra: Usuários são desativados, nunca apagados

    Cenário: Desativar um usuário
      Quando eu desativo "joao@sencoengenharia.com.br"
      Então ele não consegue mais entrar
      E as sessões dele são encerradas
      E as despesas que ele enviou continuam no histórico com o nome dele

    Cenário: Reativar um usuário
      Dado que "joao@sencoengenharia.com.br" está desativado
      Quando eu o reativo
      Então ele volta a conseguir entrar com a senha que já tinha

  Regra: Toda alteração de usuário fica registrada

    Cenário: Histórico de alterações
      Quando eu altero o perfil, a marcação de administrador, os centros de custo ou o status de um usuário
      Então a alteração fica registrada com meu nome, data, valor anterior e novo
