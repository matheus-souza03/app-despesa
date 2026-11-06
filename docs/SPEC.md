# SPEC — App de Despesas → Sienge

Versão 1.5 — 06/11/2026 (decisões de arquitetura em `docs/adr/`: cota por prioridade e rotinas aos domingos, baixa confirmada só no app na v1, administrador usa todos os centros de custo). Versão 1.4: curadoria dos planos financeiros; perfis de rua, escritório e aprovador de centro de custo; filtro por centro de custo nos títulos. Fontes: levantamento com o financeiro (rodadas 1 a 3), prints e exportações do Sienge (centros de custo, plano financeiro, tipos de documento), comprovantes de exemplo e decisões do responsável pelo projeto (Ronald).
Itens **TODO** dependem de acesso à API ou de material ainda não coletado.

## Sumário

1. Contexto
2. Glossário
3. Atores e permissões
4. Fluxo e estados
5. Requisitos funcionais
6. Regras de negócio
7. Leitura de códigos
8. Integração com o Sienge
9. Importação de planilha
10. Requisitos não funcionais
11. Modelo conceitual de dados
12. Fora de escopo / próximas versões
13. Casos de teste reais
14. Pendências

---

## 1. Contexto

- A empresa usa o **Sienge (web)**, subdomínio `sencoeng`. Só existe um usuário de sistema, usado pela Camilla (financeiro/RH), que lança tudo há 5 anos.
- Volume: ~66 lançamentos/dia (~1.400/mês), ~2 min cada, ~40% do dia dela.
- Hoje as compras chegam por **WhatsApp** (foto/PDF) e por uma **planilha compartilhada** (compras online da administração). Duplicidade é controlada de memória.
- Quase todas as compras chegam **já pagas**. O dono autoriza toda compra antes, fora do sistema (sem limitador de valor no app).
- Lançamento em **Financeiro > Contas a pagar > Títulos**, sem pedido/nota de compra antes. A aba "Inf. Pagamento" do título não é usada.
- Veículos são centros de custo. Contabilidade aceita anexos em imagem ou PDF.
- **API:** contratado o pacote de **100 requisições/dia**. Usuário de API existe, mas a autenticação falha (401) — TODO.

### Empresas

| Código | Empresa |
|---|---|
| 1 | Soluções em Consultoria e Obras Ltda |
| 2 | Senco Soluções e Projetos Ltda |
| 3 | Bento Gastronomia |
| 4 | Senco Locações e Transportes Ltda |
| 5 | Locações Parceria |

**A API do Sienge não permite dar baixa nem autorizar parcelas.** O app só lança o título. Todo título criado pela API nasce com as parcelas **não autorizadas**; a Camilla autoriza e dá a baixa no Sienge. Para isso, o app mostra a tela "Baixas pendentes" (RF29) com os títulos que o colaborador marcou como pagos.

## 2. Glossário

| Termo | Significado |
|---|---|
| Título | Lançamento no contas a pagar do Sienge |
| Baixa | Registro de que o título/parcela foi pago |
| Credor | Quem recebe (fornecedor ou colaborador), identificado por CNPJ/CPF |
| Empresa | Empresa do grupo devedora do título |
| Centro de custo (CC) | Obra, setor ou veículo; cada CC pertence a uma empresa |
| Plano financeiro | Categoria da despesa (ex.: 2.01.04.02 Peças e Componentes; na API o código vai sem pontos, `2010402`) |
| Apropriação | Linha (CC + plano financeiro + valor + percentual) que distribui o título |
| Tipo de documento | DANF, NFSE, REC, PAG, REMB |
| Data base | Dia 1 do mês da emissão |
| Data contábil | Igual à emissão |
| Despesa | Registro no app antes de virar título |

## 3. Atores e permissões

Cada usuário tem **um perfil** e, independentemente dele, pode ser **administrador**. Perfis definidos depois da apresentação dos wireframes à equipe (29/10/2026).

| Perfil | Para quem | Centros de custo | Ao enviar uma despesa | Telas além das do colaborador |
|---|---|---|---|---|
| **Colaborador de rua** | Quem compra na rua e precisa lançar rápido | Nenhum: não informa apropriação | Vai para **Aguardando centro de custo** | — |
| **Colaborador de escritório** | O colaborador "normal" | Só os liberados pelo administrador | Vai para a aprovação (Pendente) | — |
| **Aprovador de centro de custo** | Quem sabe onde cada compra foi usada | Todos | Vai para a aprovação (Pendente) | **Definir centro de custo** (só as apropriações das despesas de rua) e **Planos financeiros** (RF37) |
| **Aprovador** | Camilla | Todos | Aprovada direto ("Lançar no Sienge", RF34) | Aprovação, Títulos, Conferência de notas, Baixas pendentes, Faturas a vencer, Erros, Planos financeiros (RF37); edita qualquer campo, inclusive apropriações |
| **Administrador** (marcação à parte) | Quem gerencia o app | Todos os da empresa do título, quando o perfil informa apropriação (V5) | Não muda o perfil | Usuários e Configurações |

### Todos os perfis
- Cadastram despesas e credores, veem a tela **Status despesas** com as próprias despesas e a tela **Meu usuário**, e trocam a própria senha.
- **Não** editam nem excluem despesa pendente; editam **apenas** despesas DEVOLVIDAS e reenviam.

### Colaborador de rua
- O cadastro **não tem** a seção de apropriação (RN27). Na importação por planilha, as colunas de centro de custo e plano financeiro são ignoradas.

### Aprovador de centro de custo
- Na tela **Definir centro de custo**, vê as despesas aguardando centro de custo (mesma tela da aprovação), mas **só altera as apropriações** (centro de custo, plano financeiro e valor). Não devolve, não edita outros campos e não lança.
- O aprovador não usa essa tela: as despesas de rua chegam a ele já com as apropriações, e ele pode alterá-las na própria tela de aprovação, como qualquer outro campo.

### Administrador
- Cadastra/desativa usuários (sem autocadastro) com **senha provisória**, define o perfil, a marcação de administrador e os CCs dos colaboradores de escritório, e pode definir nova senha provisória para quem esqueceu.
- Oculta centros de custo encerrados (a API não informa a situação do centro de custo).
- Usa qualquer centro de custo (não oculto) da empresa do título, qualquer que seja o perfil, sem lista de permissões (decidido em 06/11/2026). Um colaborador de rua que seja administrador continua enviando sem apropriação.
- Regra: sempre ≥ 1 administrador ativo e ≥ 1 aprovador ativo.

Escala: 4 a 30 usuários.

## 4. Fluxo e estados

1. Colaborador cria a despesa (leitura de código, upload ou digitação), anexa comprovante(s), define empresa, apropriações, parcelas e observação (opcional), e envia.
2. Despesa fica **PENDENTE** no painel dos aprovadores.
3. O aprovador escolhe:
   - **Lançar**: cria o título com apropriações e parcelas e envia os anexos. A baixa (de compra já paga ou das parcelas de um boleto) é feita depois no Sienge.
   - **Editar** e voltar à revisão.
   - **Devolver ao colaborador** com motivo obrigatório (ex.: foto ilegível).
   - **Deixar para depois** (permanece pendente).
4. O worker executa a integração e atualiza o status.

| Estado | Significado | Próximos |
|---|---|---|
| RASCUNHO | Salvo no servidor, não enviado | PENDENTE; AGUARDANDO_CC (autor de rua); APROVADA (autor aprovador, RF34); DESCARTADA |
| AGUARDANDO_CC | Despesa de rua esperando o aprovador de centro de custo (RN27) | PENDENTE; DESCARTADA |
| PENDENTE | Aguardando revisão | APROVADA, DEVOLVIDA, DESCARTADA |
| DEVOLVIDA | Colaborador precisa corrigir (motivo visível) | PENDENTE, AGUARDANDO_CC (rua, se as apropriações deixaram de fechar), DESCARTADA |
| APROVADA | Na fila de integração (inclui aguardando cota e nova tentativa) | ENVIANDO |
| ENVIANDO | Worker em execução | LANCADA, APROVADA (nova tentativa), ERRO |
| LANCADA | Título criado e anexado no Sienge | — |
| ERRO | Falha na integração | APROVADA (tentar de novo); PENDENTE ou DESCARTADA (só sem título criado); LANCADA (resolvido no Sienge, só com título criado) |
| DESCARTADA | Na lixeira por 30 dias, com motivo | Estado anterior (recuperar); excluída (definitivamente ou após 30 dias) |

"Aguardando envio" (sem conexão) não é estado do servidor: a despesa está só na fila do aparelho. Transições, condições e efeitos detalhados: `docs/modelagem/01-estados.md`. Descartar (aprovado): o autor descarta rascunho ou devolvida; o aprovador descarta pendente ou erro sem título criado. A despesa vai para a lixeira por 30 dias (RN26).

Só o worker muda o estado a partir de APROVADA. Toda transição gera auditoria.

## 5. Requisitos funcionais

### Usuários e acesso
- **RF01** Login individual (e-mail + senha definida pelo administrador; troca opcional a qualquer momento) com recuperação de senha por e-mail.
- **RF02** Gestão de usuários: perfil (colaborador de rua, colaborador de escritório, aprovador de centro de custo, aprovador) e marcação de administrador.
- **RF03** CCs permitidos por usuário, só para colaborador de escritório sem a marcação de administrador (rua não escolhe CC; aprovadores, aprovadores de centro de custo e administradores acessam todos).
- **RF04** Regras de mínimo de administradores/aprovadores ativos.
- **RF05** Cadastro do colaborador com nome, CPF, chave Pix e município; o sistema cria/atualiza o credor do colaborador no Sienge (usado no reembolso).

### Envio de despesa
- **RF06** Entrada combinável: QR code da NFC-e / código de barras do DANFE (chave de acesso); código de barras ou linha digitável do boleto; preenchimento manual.
- **RF07** A leitura preenche todos os campos possíveis (§7). Campos lidos ficam editáveis, marcados como "lido do código", com o valor original guardado.
- **RF08** Anexos: **1 ou mais** por despesa (o comum é 1), enviados por **upload** (foto da câmera ou arquivo do aparelho; imagem ou PDF, sem conversão). Prévia antes de enviar. Cada anexo tem uma descrição obrigatória, escolhida numa lista de tipos de documento (RN11). O arquivo fica no servidor do app só até ser enviado ao Sienge (RN22).
- **RF09** Campos: empresa; forma de pagamento (reembolso, cartão corporativo, Pix da empresa, boleto a prazo); tipo de comprovante (nota fiscal, nota de serviço, recibo, nenhum); credor; número do documento; data de emissão; data do pagamento (se paga); valor total; **a nota já está paga? (Sim/Não)**; observação (opcional, texto livre até 500 caracteres); apropriações; parcelas.
- **RF10** Campos calculados (não exibidos para digitação): tipo de documento, data contábil, data base, vencimento de nota paga, número de documento quando não há nota.
- **RF11** Apropriações (não aparecem para colaborador de rua): escolher CC (só CCs **da empresa do título** e permitidos ao usuário; aprovadores, aprovadores de centro de custo e administradores veem todos) e, dentro de cada CC, linhas de plano financeiro com valor. Mostrar saldo restante; bloquear se soma ≠ total.
- **RF12** Plano financeiro com autocomplete por nome/código e lista completa navegável por grupo. Exibir sempre código + nome + grupo pai (há nomes repetidos em grupos diferentes).
- **RF13** Parcelas: nota paga → 1 parcela. Nota não paga → quantidade de parcelas + 1º vencimento, e o app mostra a prévia das parcelas como o Sienge vai gerar (valores iguais, vencimentos mensais no mesmo dia; se o mês não tiver esse dia, o último dia do mesmo mês, nunca o mês seguinte). Se as parcelas reais do boleto forem diferentes, o usuário marca "As parcelas são diferentes" e informa valor e vencimento de cada uma (soma = total). Como a API não altera títulos que ela mesma criou, o título é lançado com as parcelas padrão e a despesa fica marcada **"Ajustar parcelas no Sienge"**, com os valores reais visíveis na revisão e em "Faturas a vencer" para a Camilla ajustar na tela do Sienge. Depois de ajustar, ela toca em "Parcelas ajustadas": o app consulta as parcelas do título no Sienge (1 requisição) e só tira a marca se valores e vencimentos baterem com os reais (tolerância de 1 centavo); se não baterem, avisa que o Sienge ainda mostra as parcelas antigas. "Faturas a vencer" continua listando todos os títulos lançados pelo app ainda não pagos, por vencimento (acompanhamento; dashboards ficam para a v2).
- **RF14** Fila offline com reenvio automático.
- **RF15** Verificação de duplicidade antes de enviar e antes de integrar (RN09).

### Credor
- **RF16** Busca por CNPJ/CPF ou nome no cache do Sienge.
- **RF17** Não encontrado: manter o documento preenchido com aviso "Credor não cadastrado" e botão para cadastrar.
- **RF18** Cadastro de credor por qualquer colaborador. O colaborador informa o CNPJ/CPF **manualmente** quando o comprovante não traz (recibos à mão); com CNPJ, o app preenche razão social, fantasia e endereço por API pública de CNPJ; o usuário confere; o sistema cria o credor no Sienge (inscrição estadual sempre "Não contribuinte" e município pelo código do Sienge) e atualiza o cache.
- **RF19** Antes de integrar, o worker refaz a busca do credor pendente.

### Revisão
- **RF20** Painel com filtros: status, empresa, CC, colaborador, credor, período; visão "faturas a vencer" (títulos lançados por vencimento; a situação de pagamento fica no Sienge).
- **RF21** Tela de revisão com comprovante(s) ao lado dos dados e as ações do §4. "Editar" não abre outra tela: os campos da própria revisão passam a ser editáveis (com o comprovante continuando visível), as ações viram "Salvar alterações" e "Cancelar edição", e cada campo alterado mostra o valor anterior até salvar; datas calculadas continuam só para leitura. Despesas já lançadas mostram "Comprovante no Sienge — título N" no lugar da prévia, com a opção de abrir o anexo direto do Sienge (1 requisição, RN22).
- **RF22** Erros de integração com mensagem legível e "tentar novamente".

### Status do colaborador
- **RF23** Tela "Status despesas" com um grupo por estado, nesta ordem: Devolvidas, Aguardando envio, Em análise, Aprovadas, Enviando ao Sienge, Erro no lançamento, Lançadas. Devolvidas mostram o motivo e abrem direto a edição; as demais são só leitura. Antes do lançamento o colaborador vê a prévia dos anexos; depois, a indicação de que estão no Sienge.
- **RF24** Notificação ao colaborador quando uma despesa for devolvida (no app; push é v2).
- **RF28** Tela "Meu usuário", aberta pelo ícone do usuário: nome, e-mail e papéis (só leitura), "Redefinir senha" (com senha atual) e "Sair".
- **RF29** Tela "Baixas pendentes" (aprovadores): lista os títulos já lançados no Sienge que o colaborador marcou como pagos e que ainda não tiveram baixa. Mostra em destaque os dados que a Camilla usa nos filtros da tela de baixa do Sienge: **número do título**, **credor** (razão social e CNPJ/CPF), **data do pagamento** (= vencimento), além de empresa, documento, número do documento, valor e parcela. Filtros e ordenação por data, credor e número do título; botão para copiar o número do título. O título sai da lista quando o aprovador toca em "Já dei baixa" e confirma; na v1, sem consultar o Sienge (RN20). Lembrete fixo: "Títulos criados pelo app chegam ao Sienge não autorizados: autorize antes de dar baixa."
- **RF30** Tela "Conferência de notas" (aprovadores): para a nota que chega depois do pagamento já lançado. O aprovador envia a nota; o app lê a chave (credor, número) e pede valor pago, data de emissão e data do pagamento. Procura no Sienge títulos do mesmo credor com o mesmo valor no período (RN23) e, no app, despesas ainda não lançadas com os mesmos dados. Encontrou → mostra cada título (número, documento, emissão, anexos atuais) e o botão "Anexar a nota ao título N" (escolhendo o tipo do anexo); o título não é alterado. Não encontrou → "Nenhum lançamento encontrado", com "Cadastrar título com esta nota" (cadastro já preenchido) e "Ampliar o período".
- **RF31** A mesma busca roda no cadastro de despesa quando o colaborador informa credor, valor e datas de uma nota: se houver lançamento parecido, mostra o aviso "Este pagamento pode já estar lançado" com as opções "Anexar a nota ao título N" e "É outra compra" (proposta incluída nos wireframes; confirmar).
- **RF32** O cadastro de despesa existe também no computador, para colaboradores: formulário em seções lado a lado com o painel de comprovantes (arrastar arquivos), leitura da chave de acesso a partir do PDF e campo para colar a chave de 44 dígitos ou a linha digitável.
- **RF33** Avisos de lançamento no canto inferior direito, para quem lançou (aprovador), em qualquer tela do financeiro, assim que o worker termina: **verde** "Título N lançado com sucesso", com credor e valor e um botão de ícone para copiar o número (some sozinho depois de 15 segundos ou ao fechar); **vermelho** "Erro ao lançar", com o link "Ver em Erros"; **amarelo** "Enviando ao Sienge", para despesas em nova tentativa ou aguardando cota. Vários avisos empilham. O número do título também fica na consulta de títulos (RF35).
- **RF34** Aprovadores também cadastram despesas: botão "Nova despesa" no cabeçalho do financeiro, abrindo as mesmas telas do colaborador. Quando quem cadastra é aprovador, "Enviar despesa" vira **"Lançar no Sienge"**: a despesa é aprovada no próprio envio (registrado no histórico) e vai direto para a fila de lançamento.
- **RF35** Tela "Títulos" (aprovadores): todos os títulos a pagar desde 2022, de todas as origens (lançados pelo app, direto no Sienge e os da folha de pagamento, `FP`), do mais recente para o mais antigo. Filtros: credor (nome ou CNPJ), colaborador (incluindo "Lançados direto no Sienge"), número do título e período de emissão. Cada linha mostra número (com botão de copiar), credor, documento, emissão, empresa, valor e quem lançou. Lê o cache local (RN25), sem gastar requisições. "Atualizar agora" consulta a API e grava os títulos novos desde a última atualização (RN25 c); depois de usado, fica desativado por **5 minutos** para todo o app, mostrando quanto falta (parâmetro `ATUALIZAR_TITULOS_INTERVALO_MIN`). **Filtro por centro de custo** (o motivo mais comum de consulta: quanto cada centro de custo gastou num período): com o filtro, cada título mostra também o **valor no centro de custo**, que considera só a parte rateada para ele. No fim da lista, o **total** dos títulos retornados (valor dos títulos e, com o filtro, valor no centro de custo).
- **RF36** Tela "Definir centro de custo" (aprovador de centro de custo): lista das despesas aguardando centro de custo, mais antigas primeiro, e a despesa aberta com o comprovante, os dados só para leitura e a apropriação editável (centro de custo, plano financeiro e valor, saldo restante). Ações: "Enviar para aprovação" (exige apropriação completa, V4 a V6) e "Deixar para depois".
- **RF37** Tela "Planos financeiros" (aprovador e aprovador de centro de custo): mostra os planos liberados no app, agrupados pelo grupo do Sienge (ex.: 2.01.04 Veículos e equipamentos). Ações: **Adicionar do Sienge** (procura na lista completa sincronizada, só planos do grupo 2 de resultado e ativos, e libera um plano esquecido), **Importar lista** (arquivo JSON no formato da API, como o enviado pelos aprovadores), **Tirar do app** (deixa de aparecer em despesas novas, sem afetar as antigas) e **Atualizar do Sienge** (sincroniza a lista de planos, 1 requisição). **O app não cria planos:** a API não tem endpoint para isso; planos novos são criados na tela do Sienge e depois liberados aqui. Toda mudança fica registrada (quem e quando).

### Importação e sincronização
- **RF25** Importação de planilha (§9).
- **RF26** Sync de cadastros (empresas, CCs, planos financeiros, credores, tipos de documento, indexador) aos domingos e sob demanda por administrador, respeitando a cota (ADR-0009).
- **RF27** Ocultar/exibir centros de custo encerrados (configuração do administrador).

## 6. Regras de negócio

- **RN01 — Tipo de documento e credor**

  | Comprovante / situação | Tipo | Credor | Número do documento |
  |---|---|---|---|
  | NF-e ou NFC-e (cupom fiscal) | DANF | Emitente | Número da nota |
  | NFS-e | NFSE | Emitente | Número da nota |
  | Recibo | REC | Emitente do recibo (PF/PJ) | Número do recibo; sem número → data do pagamento `dd/mm` |
  | Reembolso sem nota | REMB | O credor indicado pelo usuário; sem credor indicado, o colaborador (do cadastro dele) | Data do pagamento `dd/mm` |
  | Cartão ou Pix da empresa, sem nota | PAG | Fornecedor | Data do pagamento `dd/mm` |
  | Boleto a prazo com nota | DANF/NFSE | Fornecedor | Número da nota; com parcelas |
  | Boleto a prazo sem nota nem recibo (raro) | PAG | Fornecedor | Data do 1º vencimento do boleto `dd/mm`; com parcelas |

  Havendo nota, ela prevalece sobre a forma de pagamento. NFC-e usa DANF (o código NFCE do Sienge não é usado). Só DANF, NFSE, REC, PAG e REMB aparecem no app.
- **RN02 — Datas:** data contábil = emissão; data base = dia 1 do mês da emissão; nota paga → 1 parcela com vencimento = data do pagamento; nota não paga → vencimento(s) informado(s).
- **RN03 — Valor:** valor do título = valor efetivamente pago; "valor do desconto" = 0, salvo quando informado (importação). Desconto de boleto na baixa é feito no Sienge.
- **RN04 — Divergência:** se o valor informado divergir do valor da nota, prevalece o da nota.
- **RN05 — Apropriação:** N linhas de CC + plano financeiro + valor; percentual calculado (12 casas, como no Sienge); a diferença de arredondamento vai para a primeira linha (padrão observado: 182,78 + 182,77). Soma = total.
- **RN06 — Parcelas:** soma = total.
- **RN07 — Centros de custo:** só CCs vinculados a uma empresa e não encerrados; o título só usa CCs da própria empresa; colaborador de escritório vê só os permitidos, salvo se for administrador (V5).
- **RN08 — Plano financeiro:** só aparecem no app os planos **liberados pelos aprovadores** (curadoria, RF37) que sejam do **grupo 2** (saídas e despesas), do tipo "Resultado", não redutores e ativos no Sienge; os planos totalizadores liberados servem só como título de grupo na lista. Lista inicial: `data/planos-financeiros-liberados.json` (união das duas listas escolhidas pelos aprovadores em 06/11/2026: 100 planos, 84 selecionáveis em 16 grupos; os planos do grupo 1 e o grupo `2.04.03`, que não tinha planos dentro, ficaram de fora). Plano desativado no Sienge sai da lista sozinho na sincronização; despesas antigas continuam mostrando o nome.
- **RN09 — Duplicidade:** chave de acesso única. Sem chave: credor + número do documento normalizado (só dígitos, sem zeros à esquerda; `dd/mm` mantido como texto) + emissão + valor. Duplicata bloqueia o envio com link para a existente.
- **RN10 — Número do documento:** padrão da Camilla: grupos de 3 dígitos com ponto, sem os grupos iniciais zerados e com o primeiro grupo completado até 3 dígitos (NF 000.003.087 → `003.087`; 3072580 → `003.072.580`; 85414 → `085.414`). Vale para número lido da chave ou digitado. O DANF no Sienge considera zeros à esquerda, por isso o formato precisa ser sempre o mesmo.
- **RN11 — Anexos:** todo anexo tem descrição obrigatória, escolhida na lista DANFe, NFSE, REC, PAG, REMB, COMP. A sugestão segue o tipo do documento; comprovante de pagamento (ex.: Pix) = `COMP`. O usuário pode trocar por outra opção da lista. Anexos importados pela planilha recebem a descrição do tipo do documento. Nome do arquivo de DANFE: a chave de acesso.
- **RN12 — Observação do título:** é o texto que o usuário escreveu no campo "Observação" (opcional). O app não acrescenta nada automaticamente. A API recusa observação vazia: sem texto, enviar **um espaço** (`" "`), que na tela do Sienge aparece em branco.
- **RN13 — Credor:** sanitizar antes de enviar: remover acentos (ã→a, ç→c), trocar `&` por `e`, remover qualquer outro caractere que não seja letra, número ou espaço, colapsar espaços. Município pelo código interno do Sienge.
- **RN14 — Credor do colaborador:** criado/atualizado a partir do cadastro do usuário. Em reembolso sem nota, vale o credor que o usuário indicar; só se nenhum for indicado o credor é o próprio colaborador (o CPF mascarado em comprovantes de Pix não é usado).
- **RN15 — Aprovação:** só usuários com permissão de aprovador; toda despesa passa por aprovação.
- **RN16 — Indexador:** sempre 0 (REAL).
- **RN17 — Inscrição estadual:** todo credor criado pelo app é enviado como **"Não contribuinte"** (código `N` na API), com o número da inscrição preenchido com **um espaço** (a API recusa vazio; se recusar o espaço no cadastro, usa "ISENTO" e em seguida troca para espaço). O campo não é editável.
- **RN18 — Município do credor:** obrigatório e enviado pelo código do Sienge, conforme `data/municipios-sienge.csv` (5.570 municípios, chave única nome + UF). Da consulta pública, casar por nome normalizado (sem acentos, maiúsculas) + UF; sem correspondência, o usuário escolhe na lista.
- **RN19 — Senhas:** mínimo de 8 caracteres, com letras e números; a nova senha deve ser diferente da atual; trocar a senha encerra as sessões nos outros aparelhos.
- **RN20 — Confirmação de baixa:** um título marcado como pago entra em "Baixas pendentes" assim que é lançado e sai quando o aprovador toca em **"Já dei baixa"** e confirma na pergunta que o app mostra. Na v1, o app **não consulta o Sienge** para isso (0 requisição, ADR-0009): grava quem confirmou e quando (evento `BAIXA_CONFIRMADA`), e o título não volta à lista. **Versão futura, se sobrar cota:** conferir as parcelas no Sienge (`GET /bills/{billId}/installments`, campo `situation`): (a) ao abrir a tela, só para os títulos não verificados há mais de 12 horas; (b) no "Já dei baixa", antes de tirar da lista; (c) na rotina de domingo. Se ficar comprovado que a baixa altera o `changedDate` do título, a conferência pode se limitar aos títulos que aparecerem no `by-change-date` (RN25).
- **RN21 — Nota paga:** sugestão inicial pela forma de pagamento (cartão corporativo e Pix da empresa → Sim; boleto a prazo → Não; reembolso → sem sugestão, o usuário escolhe), sempre editável. Paga = Sim exige a data do pagamento e gera 1 parcela; paga = Não pede quantidade de parcelas e 1º vencimento (RF13).
- **RN22 — Retenção dos anexos:** (despesa na lixeira mantém os arquivos até a exclusão definitiva, RN26) o arquivo enviado pelo colaborador fica no storage do app apenas enquanto a despesa não foi lançada (rascunho no servidor, pendente, devolvida, aprovada, com erro). Depois que o Sienge confirma o recebimento de **cada** anexo (`201` do envio), o arquivo é apagado do storage; o registro do anexo continua (nome, descrição, tamanho, data de envio). Se a despesa for descartada, os arquivos também são apagados. Uma rotina diária apaga arquivos órfãos e tenta de novo exclusões que falharam. Depois do lançamento, o comprovante só existe no Sienge.
- **RN23 — Busca de lançamento existente:** credor = CNPJ/CPF do emitente; valor = valor pago (tolerância de 1 centavo); período = da menor à maior entre data de emissão da nota e data do pagamento, com margem de **3 dias** em cada ponta (parâmetro `CONFERENCIA_MARGEM_DIAS`, provisório). Busca no cache local de títulos (RN25), depois de buscar os títulos novos (RN25 c, 1 requisição); sem cache, `GET /bills` com `creditorId` e o período de emissão. Anexar ao título encontrado: `POST /bills/{billId}/attachments` (1 requisição).
- **RN24 — Centro de custo por texto na importação:** o app procura o texto da coluna "Centro de custo" só entre os centros de custo da empresa da linha (e permitidos ao usuário), por busca direta de código, placa ou nome, com correspondência aproximada (sem acentos, maiúsculas/minúsculas, palavras fora de ordem). Resultado claro → "Encontrado pelo texto"; sem resultado ou ambíguo → "Não encontrado · escolha na lista", e a linha só importa depois que o usuário escolher. Na conferência da importação, cada centro de custo aparece numa lista suspensa com o texto original da planilha e a origem, e o usuário pode trocar antes de importar. A sugestão por IA para descrições livres fica para uma versão futura (§12).
- **RN25 — Cache local de títulos:** os títulos do Sienge ficam guardados no banco do app (tabela `titulos_sienge`, com as colunas usadas em filtros e a resposta completa da API em `jsonb`), em vez de consultados na API a cada tela. Banco em vez de arquivo .json: permite filtrar e ordenar com índices, aguenta acessos simultâneos e entra no backup. (a) **Carga inicial:** todos os títulos, pela API REST (`GET /bills` paginado). Em 26/10/2026 eram **16.513 títulos** (os mais antigos com emissão em 2023); a API devolve no máximo **200 por chamada** (pedir mais é reduzido para 200), em ordem crescente de número do título: **83 chamadas** para tudo. Fazer no dia da implantação, antes de o app entrar em uso, quando a cota do dia está livre; se não couber, continua no dia seguinte de onde parou. (b) **Lançamentos do app:** entram no cache na hora, com os dados do próprio envio e o número vindo do `Location`, sem requisição extra. (c) **Atualização dos títulos novos:** uma rotina automática **aos domingos** (ADR-0009) e o botão "Atualizar agora" (no máximo uma vez a cada 5 minutos) buscam os títulos mais recentes pela própria API REST: `GET /bills` com `limit=200` e o `offset` da última página (a lista vem em ordem crescente de número do título, então os novos ficam no fim). Os que ainda não estão no banco são gravados. Se todos os 200 da página forem novos, a rotina busca também a página anterior, até encontrar títulos que o banco já tem. O custo costuma ser de 1 a 2 requisições por semana. Alterações feitas depois em títulos antigos (valor, exclusão) não aparecem nessa busca; por isso a rotina de domingo faz também 1 chamada a `GET /bills/by-change-date` desde a última execução (decidido em 06/11/2026, ADR-0010). Usam o cache: a tela Títulos, a conferência de notas (RN23, que antes de buscar faz a atualização incremental), a checagem de duplicidade com títulos lançados direto no Sienge e as listas de acompanhamento. Os **credores** também ficam no banco (tabela `credores`), porque o título só traz o `creditorId` e a tela Títulos filtra por nome e CNPJ. A carga é feita pelo **"Relatório de Credores" detalhado, exportado do Sienge em PDF** (uma página por credor; formato e regras em `docs/importacao-credores.md`), enviado pelo administrador em Configurações (sem gastar requisições, e pode ser reenviado para atualizar tudo); os credores criados pelo app entram na hora; e um credor desconhecido que aparecer num título é buscado sob demanda (`GET /creditors/{id}`, 1 requisição, raro). O cache não guarda situação de pagamento, que continua vindo da consulta de parcelas (RN20). Em 25 e 26/10/2026, o `by-change-date` trouxe 16 títulos alterados (1 chamada), incluindo títulos antigos alterados pela Camilla no dia, o que indica que dar baixa muda a data de alteração do título.
- **RN26 — Lixeira:** descartar não apaga na hora. A despesa fica na lixeira por **30 dias**, com quem descartou, quando e o motivo, e some das listas de trabalho. Nesse prazo, quem descartou ou um aprovador pode **recuperar** (volta ao estado em que estava, desde que não fique duplicada com outra despesa ativa) ou **excluir definitivamente**. Passados os 30 dias, a rotina diária exclui sozinha. A exclusão definitiva apaga a despesa, o histórico e os arquivos; os anexos ficam guardados enquanto a despesa está na lixeira.
- **RN27 — Despesa de colaborador de rua:** enviada sem apropriação, vai para **Aguardando centro de custo**. O aprovador de centro de custo completa as apropriações e envia para a aprovação (Pendente); a partir daí, segue o fluxo normal. Se o aprovador devolver e o colaborador de rua corrigir, a despesa volta para a aprovação quando as apropriações continuarem válidas (soma igual ao total); se o valor mudou e elas deixaram de fechar, volta para Aguardando centro de custo. A duplicidade (RN09) é checada no envio do colaborador, como nos outros perfis.
- **RN28 — Valor por centro de custo na consulta de títulos:** para cada título, o valor no centro de custo é `valor do título × percentual da apropriação`. O `GET /bills` traz só o cabeçalho do título (credor, número, datas, valor), **sem as apropriações**; elas vêm de `GET /bills/{id}/budget-categories`, uma requisição por título. Por isso: (a) títulos lançados **pelo app** já gravam as apropriações no banco no lançamento (sem custo); (b) títulos **novos lançados direto no Sienge** têm as apropriações buscadas na rotina de domingo com o que sobrar da cota, 1 requisição por título (ADR-0009); (c) o **histórico** vem do relatório **"Contas pagas com apropriações"** exportado do Sienge em Excel e enviado pelo administrador (sem gastar requisições; formato e regras em `docs/importacao-apropriacoes.md`). Esse relatório só traz títulos pagos; o rateio dos títulos em aberto lançados direto no Sienge vem por `GET /bills/{id}/budget-categories`, a menos que exista o mesmo relatório para contas em aberto.

## 7. Leitura de códigos

Funções puras em `packages/shared`, com testes unitários (exemplos reais em §13).

### 7.1 Chave de acesso NF-e/NFC-e (44 dígitos)
Fontes: código de barras do DANFE (Code 128C) = a chave; QR da NFC-e = URL cujo parâmetro `p` começa com a chave; texto/nome de arquivo de PDF de DANFE (44 dígitos com ou sem espaços).

| Posição | Tam. | Campo |
|---|---|---|
| 1–2 | 2 | cUF |
| 3–6 | 4 | AAMM da emissão |
| 7–20 | 14 | CNPJ do emitente |
| 21–22 | 2 | Modelo: 55 = NF-e, 65 = NFC-e |
| 23–25 | 3 | Série |
| 26–34 | 9 | Número |
| 35 | 1 | Tipo de emissão |
| 36–43 | 8 | Código numérico |
| 44 | 1 | DV módulo 11 |

DV: pesos 2→9 da direita para a esquerda sobre os 43 primeiros dígitos, repetindo; resto = soma % 11; DV = 0 se resto ∈ {0,1}, senão 11 − resto.

Preenche: credor (CNPJ), número (formatado `000.000.000`), série, mês/ano (valida a emissão), tipo DANF, campo "Chave de acesso NF-e" do título. Não contém valor nem data exata (no QR em contingência, o `p` traz dia e valor — aproveitar).

NFS-e: preenchimento manual na v1.

### 7.2 Boleto
- Código de barras (44): 1–3 banco; 4 moeda (9); 5 DV geral; 6–9 fator de vencimento; 10–19 valor; 20–44 campo livre.
- Linha digitável (47) → código de barras: `l[0..4) + l[32] + l[33..47) + l[4..9) + l[10..20) + l[21..31)`. Validar DVs dos campos (módulo 10) e o geral (módulo 11).
- Arrecadação/concessionária: começa com `8`; 44/48 dígitos; layout próprio.
- Fator de vencimento: dias desde 07/10/1997; chegou a 9999 em 21/02/2025 e reiniciou em 1000 em 22/02/2025. Calcular as duas datas candidatas e escolher a mais próxima de hoje. Fator `0000` = sem vencimento; valor zerado = digitação manual.
- **Um boleto por parcela:** cada boleto escaneado na mesma despesa vira uma parcela (valor e vencimento do próprio boleto), em ordem de vencimento. Ao ler o primeiro boleto, "A nota já está paga?" passa para Não e a quantidade de parcelas acompanha o número de boletos lidos. O colaborador pode remover um boleto lido por engano.
- Com as parcelas montadas pelos boletos, o app compara com a regra do Sienge (valores iguais com tolerância de 1 centavo e vencimentos mensais no mesmo dia do 1º). Se forem diferentes, marca sozinho "As parcelas são diferentes" e a despesa sai com "Ajustar parcelas no Sienge" (RF13), sem o colaborador digitar nada.
- Se houver menos boletos que parcelas (ex.: o fornecedor entregou só o primeiro), o colaborador completa as demais parcelas manualmente.
- A linha digitável fica registrada na despesa; não vai automaticamente para a observação (RN12). Com nota + boletos: avisar (sem bloquear) se a soma dos boletos divergir do valor total.

### 7.3 Chave × boleto (ambos com 44 dígitos)
Chave: posições 21–22 ∈ {55, 65}, cUF válido e DV ok. Boleto bancário: posição 4 = 9 e DV geral ok. Arrecadação: começa com 8. Senão: "código não reconhecido".

### 7.4 Recibos e comprovantes de Pix
Recibos costumam ser manuscritos e sem CNPJ/CPF: preenchimento manual (credor por nome ou CNPJ/CPF informado). Comprovantes de Pix trazem o CNPJ do recebedor (útil para leitura por IA na v2); CPF de pessoa física vem mascarado.

### 7.5 CNPJ alfanumérico
Desde julho de 2026, a Receita Federal emite CNPJs com letras nas 12 primeiras posições (os 2 dígitos verificadores continuam numéricos; no cálculo, cada caractere vale o código ASCII menos 48). Documentos são normalizados removendo só a pontuação (letras são mantidas, em maiúsculas), e a chave de acesso de emitentes novos pode ter letras nas posições do CNPJ. A confirmar: cálculo do dígito da chave nesse caso (nota técnica da SEFAZ) e se a API do Sienge aceita esses CNPJs.

## 8. Integração com o Sienge

Detalhes técnicos: skill `sienge-api`.

Sequência por despesa aprovada (worker, idempotente):
1. Resolver credor (cache → API). Não existe → ERRO "credor não cadastrado".
2. Duplicidade pelo banco local; consulta ao Sienge só ao repetir um envio interrompido.
3. Criar título (`POST /bills`): empresa, credor, tipo e número do documento, emissão, observação, valor total, desconto, quantidade de parcelas, data contábil, indexador 0, data base, 1º vencimento e apropriações (em **percentual**, calculado a partir dos valores).
4. Gravar o ID do título **imediatamente**.
5. Enviar cada anexo com sua descrição (`POST /bills/{billId}/attachments`, uma chamada por anexo).
6. Status LANCADA + auditoria.

Limitações conhecidas da API:
- `POST /bills` **não recebe a chave de acesso**; ela fica no app (duplicidade e nome do arquivo). O endpoint que grava a chave (`POST /eletronic-invoice-bills`) exige que o Sienge receba os XMLs das NF-e, o que a empresa não faz.
- `POST /bills` recebe só a quantidade de parcelas e o 1º vencimento; o Sienge gera parcelas iguais e mensais.
- **Títulos criados pela API (origem `SE`) não podem ser alterados pela API** (`PATCH`/`PUT` recusados: "O Título com origem no SE não pode ser alterado para chamadas do SE."). Parcelas diferentes e qualquer correção depois do lançamento são feitas pela Camilla na tela do Sienge (RF13).
- A API de centros de custo não informa se o centro está encerrado (RF27).
- A API não autoriza parcelas: todo título criado por ela nasce "Não autorizado" e a Camilla autoriza no Sienge.
- A situação de pagamento só aparece consultando as parcelas de cada título (`GET /bills/{billId}/installments`, campo `situation`), 1 requisição por título (RN20).

**Cota (pacote de 100 req/dia; regras completas no ADR-0009):** cada lançamento gasta 2 chamadas (título + anexo); cada anexo extra é mais uma; credor novo, mais 1 ou 2. A baixa não gasta cota na v1 (RN20). Prioridade: ações com uma pessoa esperando na tela; depois lançamentos, até `limite − 10`; depois rotinas. Lançamento que não cabe no dia continua aprovado e sai no dia seguinte, na ordem de aprovação. As rotinas que chamam o Sienge (cadastros, títulos novos e alterados, rateio de títulos lançados direto no Sienge) rodam **só aos domingos**: primeiro as curtas (~8 requisições), depois a fila de lançamentos acumulada, depois o resto. Capacidade estimada: cerca de 40 lançamentos por dia útil — suficiente para o piloto, insuficiente para os ~66/dia da operação completa. TODO: perguntar à Softplan sobre cobrança de excedente, planos maiores e o horário em que o contador diário reinicia.

## 9. Importação de planilha

Uma linha por despesa; despesas com rateio usam linhas extras com o mesmo **Código**, preenchendo só as colunas de rateio.

| Coluna | Obrigatória | Observação |
|---|---|---|
| Código | Sim | Agrupa as linhas da mesma despesa |
| Documento | Sim | DANF, NFSE, REC, PAG, REMB |
| Número do documento | Sim | |
| Empresa | Sim | Código 1–5 |
| Credor | Sim | CNPJ/CPF |
| Data de emissão | Sim | dd/mm/aaaa |
| Valor total | Sim | |
| Desconto | Não | Padrão 0 |
| Parcelas | Sim | Padrão 1 |
| Data 1º vencimento | Sim | |
| Centro de custo | Sim | Texto livre: código, placa ou nome da obra, como o colaborador souber; o app escolhe o centro de custo (RN24) |
| Plano financeiro | Sim | Código com ou sem pontos (ex.: 2.01.04.02 ou 2010402) |
| Valor centro de custo | Sim | Soma por Código = valor total |
| Arquivo do comprovante | Sim (1ª linha) | Nome exato do arquivo enviado junto com a planilha; mais de um separado por `;` |

- Linhas inválidas são listadas com o motivo e não importadas; as válidas viram despesas PENDENTES.
- **Comprovantes:** enviados por upload na mesma tela, junto com a planilha (seleção de vários arquivos). Cada linha indica o nome do arquivo na coluna "Arquivo do comprovante"; o app associa pelo nome, sem diferenciar maiúsculas e minúsculas. Arquivo citado e não enviado → linha recusada; arquivo enviado e não citado → aviso, sem importar. Não há integração com Google Drive.

## 10. Requisitos não funcionais

- **RNF01** PWA mobile-first; painel do aprovador usável em desktop e celular.
- **RNF02** Offline com fila local e indicação do que não subiu.
- **RNF03** Credenciais do Sienge e do Google só no servidor; senhas com hash; cookie httpOnly; autorização no backend em toda rota (inclusive empresa e CC).
- **RNF04** LGPD: CPF e chave Pix com acesso restrito e mascarados em UI e logs.
- **RNF05** Auditoria completa de transições e edições.
- **RNF06** Retry com backoff em 429/5xx; nunca repetir criação de título sem verificar.
- **RNF07** Sem homologação: dry-run padrão; testes com mock; primeiros lançamentos reais acompanhados pela Camilla.
- **RNF08** Compressão de imagens no cliente; limite de 70 MB por anexo e nome de arquivo com até 100 caracteres (limites do Sienge).
- **RNF09** Backup diário do banco. Os anexos são transitórios (RN22) e não entram no backup: se forem perdidos antes do envio, a despesa é devolvida ao colaborador para reenviar o comprovante.
- **RNF10** Economia de cota: caches locais, rotinas só aos domingos, duplicidade local, reserva de cota por prioridade (ADR-0009).

## 11. Modelo conceitual de dados

Resumo conceitual. O modelo detalhado (tabelas, colunas, tipos, índices e restrições) está em `docs/modelagem/02-modelo-er.md`; em caso de diferença, vale o detalhado. Entidades acrescentadas na modelagem: TituloSienge (cache), Credor (cache completo), Notificacao, ConferenciaNota, ImportacaoCentro, Sincronizacao, ChamadaApi, CotaDiaria, Configuracao, Sessao e TokenSenha.

- **Usuario** — nome, e-mail, hash da senha, perfil (colaborador de rua, colaborador de escritório, aprovador de centro de custo, aprovador), administrador (bool), ativo, CPF, chave Pix, município (código Sienge), credorSiengeId.
- **Municipio** — código Sienge, nome, UF (seed a partir de `data/municipios-sienge.csv`).
- **PermissaoCentroCusto** — usuário × CC.
- **Empresa** — siengeId, nome, CNPJ.
- **CentroCusto** — siengeId, nome, empresa, oculto (definido pelo administrador).
- **PlanoFinanceiro** — código, descrição, tipo, redutora, grupo pai.
- **Credor** — siengeId, documento, razão social, tipo.
- **TipoDocumento** — código, descrição, usadoNoApp, regras do Sienge (somente números, zeros à esquerda, bloqueio de número repetido).
- **Despesa** — autor, empresa, forma de pagamento, tipo de comprovante, tipo de documento, credor/documento pendente, número, emissão, pagamento, valor, desconto, chave de acesso, linha digitável, observação, paga (bool), parcelasDiferentes (bool), parcelasAjustadasEm, status, motivoDevolucao, siengeTituloId, baixaConfirmadaEm, baixaConfirmadaPor, erro (baixaVerificadaEm só na versão futura da RN20).
- **Apropriacao** — despesa, CC, plano financeiro, valor.
- **Parcela** — despesa, número, valor, vencimento, origem.
- **Anexo** — despesa, caminho no storage (nulo depois de apagado), nome original, descrição, tipo, tamanho, hash, enviadoAoSiengeEm, siengeAttachmentId, apagadoEm.
- **CampoLido** — despesa, campo, valor lido, origem.
- **EventoDespesa** — auditoria.
- **ImportacaoPlanilha** — arquivo, usuário, linhas ok/erro.
- **LogIntegracao** — chamadas ao Sienge sanitizadas; base do contador de cota.

## 12. Fora de escopo / próximas versões

- v2: conferência da baixa no Sienge pelas parcelas (RN20, se sobrar cota); sugestão por IA do centro de custo na importação, para descrições livres que a busca direta não resolve (candidato avaliado: Jev, da TypeSafe AI, modelo de decisão estruturada com confiança calibrada e até 255 opções por escolha; provedor atrás de uma interface própria; medir a taxa de acerto registrando quando o usuário troca a sugestão); leitura por IA de comprovantes (valor, data, CNPJ do recebedor de Pix, recibos); agente que **sugere** plano financeiro (criação de plano novo só com aprovação); dashboards; notificação push.
- Fora: baixa de títulos (não existe na API), aba Inf. Pagamento, vale combustível, folha de pagamento, automação SICOOB, importação via SEFAZ/manifestação.

## 13. Casos de teste reais

| Caso | Entrada | Esperado |
|---|---|---|
| Chave NF-e válida | `33260928070499000122550010000030871000059038` | UF 33, 09/2026, CNPJ 28.070.499/0001-22, modelo 55, série 1, número `003.087`, DV 8 ok |
| NF-e a prazo | DANFE FN do Brasil, R$ 490,80, venc. 12/10/2026 | DANF, "Lançar", 1 parcela com vencimento 12/10/2026 |
| Pix da empresa sem nota | Itaú, R$ 35,20, Acqua Luz (CNPJ 55.932.700/0001-06), 14/09 | PAG, nº `14/09`, anexo `COMP` |
| Reembolso via Pix | Sicoob, empresa 4, R$ 16,58, PF com CPF mascarado | REMB, credor = colaborador do cadastro, anexo `COMP` |
| Recibo com número | Stop Drive Auto Peças nº 17758, 05/10, sem CNPJ | REC, nº `17758`, credor por nome ou CNPJ informado |
| Recibo sem número | Auto Mecânica Córrego D'Antas, 05/10, R$ 500,00, sem CNPJ | REC, nº `dd/mm` do pagamento, credor por nome ou CNPJ informado |
| Rateio 50/50 | R$ 365,55 entre CC 1062 e 1066 | 182,78 + 182,77 |

## 14. Pendências

- [x] Autenticação na API funcionando (20/10/2026).
- [x] A API permite baixa? **Não.** O app só lança.
- [x] Formato das apropriações (percentual dentro do `POST /bills`) e dos anexos (multipart, descrição na query).
- [ ] Spike: itens marcados [spike] na skill `sienge-api` (ID no 201, códigos de inscrição estadual e tipo de credor, `billDate`, precisão do percentual, parcelas).
- [x] O Sienge não recebe os XMLs de NF-e automaticamente.
- [x] `PATCH /bills/{billId}/installments` testado: bloqueado para títulos criados pela API.
- [ ] Perguntar à Softplan se existe configuração ou permissão que libere a alteração, pela API, de títulos com origem `SE` (permitiria enviar as parcelas exatas e dispensar o ajuste manual).
- [ ] Códigos de `typesId` (fornecedor e colaborador) no `POST /creditors`.
- [ ] Softplan: excedente de cota, bulk-data, planos.
- [x] Google Drive descartado: comprovantes por upload.
- [x] Carga inicial do cache pela própria API REST (`GET /bills`). O volume desde 2022 só define em quantos dias a carga termina, respeitando a reserva da cota diária.
- [ ] Limites de período do `GET /bills` e do `GET /bills/by-change-date`.
- [ ] Se a API do Sienge aceita CNPJ alfanumérico (credores e títulos) — baixa prioridade.
- [x] Vencimentos nos dias 29 a 31: a prévia usa o último dia do mesmo mês (31/01 → 28/02 → 31/03); se o Sienge gerar diferente, a Camilla ajusta no Sienge.
- [x] Regras de descarte aprovadas, com lixeira de 30 dias (RN26).
- [x] Formato do arquivo de credores: relatório detalhado em PDF, lido sem perdas nos 2.341 credores (`docs/importacao-credores.md`).
- [ ] Se o relatório de credores permite exportar só os ativos.
- [x] A API não tem endpoint para criar plano financeiro: planos novos são criados no Sienge (RF37).
- [x] Planos do grupo 1 não aparecem no app (retirados da lista inicial).
- [x] Grupos sem planos escolhidos (`1.02.60` e `2.04.03`) não foram liberados.
- [x] API de dados em lote fora do orçamento: os títulos vêm pela API REST, 200 por página.
- [x] Histórico de apropriações: relatório "Contas pagas com apropriações" em Excel (`docs/importacao-apropriacoes.md`).
- [ ] Existe o mesmo relatório para **contas a pagar em aberto**? E dá para exportar o período inteiro (desde 2023, todas as empresas) num arquivo só?
