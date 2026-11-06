# language: pt
# Referências: SPEC.md §1 (Empresas), RF26, RF27, §8 (Cota)

Funcionalidade: Configurações
  Como administrador
  Quero manter as configurações da integração e os cadastros vindos do Sienge
  Para que os lançamentos usem sempre dados atualizados e respeitem os limites da API

  Contexto:
    Dado que estou autenticado como "ronald@sencoengenharia.com.br" com o papel "administrador"

  Regra: Somente administradores acessam as configurações

    Cenário: Colaborador tenta abrir as configurações
      Dado que estou autenticado como "maria@sencoengenharia.com.br" com o papel "colaborador"
      Quando eu tento abrir a tela "Configurações"
      Então vejo a mensagem "Você não tem permissão para acessar as configurações"

  Regra: O administrador pode ocultar centros de custo encerrados

    Cenário: Ocultar um centro de custo
      Dado que a API do Sienge não informa se um centro de custo está encerrado
      Quando eu marco o centro de custo "1045" como oculto
      Então ele não aparece mais para novas despesas
      Mas as despesas antigas continuam mostrando o "1045"

    Cenário: Voltar a exibir um centro de custo
      Dado que o centro de custo "1045" está oculto
      Quando eu desmarco a opção de ocultar
      Então ele volta a aparecer para quem tem permissão nele

  Regra: Os cadastros do Sienge são sincronizados periodicamente e sob demanda

    Cenário: Sincronização automática aos domingos
      Quando chega o horário das rotinas de domingo
      Então empresas, centros de custo, planos financeiros, credores e tipos de documento são atualizados
      E só depois a fila de lançamentos aguardando cota é liberada
      E a data da última sincronização é registrada

    Cenário: Nenhuma rotina automática chama o Sienge de segunda a sábado
      Dado que hoje é quarta-feira
      Então nenhuma sincronização automática é feita
      Mas "Sincronizar agora" continua disponível para o administrador

    Cenário: Sincronizar agora
      Quando eu toco em "Sincronizar agora"
      Então vejo uma estimativa de quantas requisições da cota diária serão usadas
      E ao confirmar a sincronização começa
      E vejo o resultado: itens novos, alterados e desativados

    Cenário: Centro de custo removido do Sienge
      Dado que o centro de custo "1045" não vem mais do Sienge
      Quando a sincronização termina
      Então o "1045" fica inativo no app
      E não aparece em novas despesas
      Mas as despesas antigas continuam mostrando o "1045"

    Cenário: Falha na sincronização
      Quando a sincronização falha no meio
      Então os dados anteriores continuam valendo
      E vejo a mensagem de erro e o botão "Tentar novamente"

    Cenário: Sincronização bloqueada pela cota
      Dado que restam 5 requisições na cota de hoje
      Quando eu toco em "Sincronizar agora" e a estimativa é de 12 requisições
      Então vejo o aviso "Cota insuficiente hoje. Tente amanhã ou aguarde a sincronização de domingo."

  Regra: O consumo da API fica visível

    Cenário: Ver o consumo de hoje
      Quando eu abro "Integração com o Sienge"
      Então vejo as requisições usadas hoje e o limite diário, por exemplo "37 de 100"
      E vejo quantas despesas aprovadas aguardam envio

    Cenário: Ajustar o limite diário
      Dado que a empresa contratou um pacote maior
      Quando eu altero o limite diário para "1000"
      Então o worker passa a respeitar o novo limite
      E a alteração fica registrada no histórico

  Regra: Os credores são carregados pelo arquivo exportado do Sienge

    Cenário: Importar o arquivo de credores
      Dado que exportei do Sienge o arquivo com todos os credores cadastrados
      Quando eu envio o arquivo em "Credores do Sienge"
      Então os credores são gravados no app sem usar requisições da API
      E vejo quantos credores foram incluídos e atualizados

    Cenário: Credor desconhecido num título
      Dado que um título lançado direto no Sienge tem um credor que o app não conhece
      Quando a atualização dos títulos é executada
      Então o app busca só esse credor no Sienge

  Regra: O rateio dos títulos antigos vem do relatório de contas pagas

    Cenário: Importar o relatório de contas pagas com apropriações
      Dado que exportei do Sienge o relatório "Contas pagas com apropriações" em Excel
      Quando eu envio o arquivo em "Rateio dos títulos"
      Então o centro de custo e o percentual de cada título são gravados sem usar requisições da API
      E vejo quantos títulos receberam rateio

    Cenário: Título rateado em dois centros de custo
      Dado que o arquivo traz o título 16913 com 30% no centro de custo 34 e 70% no 3
      Quando eu importo o arquivo
      Então o título 16913 fica com essas duas apropriações

    Cenário: Rateio do app não é sobrescrito
      Dado que o título 17170 foi lançado pelo app com o rateio que o app enviou
      Quando eu importo um arquivo que também traz o título 17170
      Então o rateio gravado pelo app é mantido

