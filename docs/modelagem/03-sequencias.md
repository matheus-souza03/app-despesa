# 03 — Sequências

Participantes usados em todos os diagramas:

| Participante | O que é |
|---|---|
| PWA | `apps/web` (celular ou computador) |
| Fila local | IndexedDB do aparelho (despesas e arquivos enquanto não há conexão) |
| API | `apps/api` (Fastify) |
| Banco | PostgreSQL, incluindo a fila de jobs (pg-boss) |
| Storage | Armazenamento temporário dos comprovantes |
| Worker | `apps/worker`, único que fala com o Sienge em segundo plano |
| Sienge | API REST do Sienge (cota de 100 requisições por dia) |
| Consulta CNPJ | API pública de CNPJ (ex.: BrasilAPI) |

Toda chamada ao Sienge passa antes pela reserva atômica em `cota_diaria` e é registrada em `chamadas_api`. Para não repetir, os diagramas mostram a reserva só como "reserva cota".

## S1 — Cadastro e envio da despesa (com e sem conexão)

RF06–RF15, RN09, `cadastro-titulo.feature`.

```mermaid
sequenceDiagram
    autonumber
    actor C as Colaborador
    participant P as PWA
    participant L as Fila local
    participant A as API
    participant D as Banco
    participant ST as Storage

    C->>P: Preenche a despesa e anexa arquivos
    P->>P: Gera o id da despesa e de cada anexo (uuid)
    alt Com conexão
        P->>A: PUT /despesas/{id} (rascunho, upsert)
        A->>D: Insere ou atualiza a despesa em RASCUNHO
        P->>A: PUT /despesas/{id}/anexos/{anexoId} (arquivo)
        A->>ST: Grava o arquivo
        A->>D: Insere o anexo com caminho e hash
    else Sem conexão
        P->>L: Guarda a despesa e os arquivos
    end
    C->>P: Toca em Enviar despesa
    P->>P: Valida V1 a V8 com as regras de packages/shared
    opt Sem conexão
        P->>L: Marca como Aguardando envio
        Note over P,L: Quando a conexão volta, o PWA repete o PUT da despesa, o PUT de cada anexo e o envio, sempre com os mesmos ids
    end
    P->>A: POST /despesas/{id}/envio (versao)
    A->>D: BEGIN e SELECT da despesa FOR UPDATE
    A->>A: Valida V1 a V8 de novo (o servidor não confia no cliente)
    A->>D: UPDATE status PENDENTE e INSERT do evento ENVIADA
    alt Viola um índice único de duplicidade (RN09)
        D-->>A: Erro de unicidade
        A->>D: ROLLBACK
        A-->>P: 409 com o link da despesa existente
        P-->>C: Mostra que a nota já foi enviada
    else Envio aceito
        A->>D: COMMIT
        A-->>P: 200 com status PENDENTE
        P-->>C: Despesa em análise
    end
```

Idempotência: o `PUT` da despesa e dos anexos é um upsert pelo id gerado no cliente, e repetir o envio de uma despesa que já está `PENDENTE` devolve `200` com o estado atual. Assim, a fila do aparelho pode reenviar tudo sem criar duplicatas. Se o autor for aprovador, o passo 15 grava `APROVADA` e enfileira o lançamento (T3); dali em diante, o fluxo é o de S4 a partir do passo 7.

## S2 — Leitura de código e busca do credor

RF06, RF07, §7, RN09.

```mermaid
sequenceDiagram
    autonumber
    actor C as Colaborador
    participant P as PWA
    participant A as API
    participant D as Banco
    participant S as Sienge

    C->>P: Escaneia o código ou cola a chave ou a linha digitável
    P->>P: Identifica o tipo pelo tamanho e pelos dígitos verificadores
    alt Chave de acesso (44 posições)
        P->>P: ChaveAcesso.ler: CNPJ do emitente, modelo, série, número e mês
        P->>A: GET /despesas/duplicidade?chave=...
        A->>D: Procura a chave em despesas não descartadas
        A-->>P: Livre ou link da despesa existente
        P->>A: GET /credores?documento=CNPJ
        A->>D: Procura no cache de credores
        alt Encontrado no cache
            A-->>P: Credor
        else Não está no cache
            A->>S: GET /creditors?cnpj=... (reserva cota)
            alt Existe no Sienge
                S-->>A: 200 com o credor
                A->>D: Upsert em credores
                A-->>P: Credor
            else Não existe
                S-->>A: 200 com lista vazia
                A-->>P: Credor não cadastrado
            end
        end
    else Boleto (47 ou 48 dígitos)
        P->>P: Boleto.ler: valor e vencimento da parcela
        P->>P: Acrescenta uma parcela com origem BOLETO
    else Código não reconhecido
        P-->>C: Aviso e preenchimento manual
    end
    P->>P: Grava cada valor lido em campos_lidos
    P-->>C: Campos preenchidos e marcados como lidos do código
```

A leitura é toda local (sem SEFAZ e sem certificado). A única chamada ao Sienge acontece quando o credor ainda não está no cache.

## S3 — Cadastro de credor

RF16–RF18, RN13, RN17, RN18, `cadastro-credor.feature`.

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant P as PWA
    participant A as API
    participant D as Banco
    participant B as Consulta CNPJ
    participant S as Sienge

    U->>P: Informa o CNPJ e toca em Buscar
    P->>A: GET /cnpj/{cnpj}
    A->>B: Consulta pública do CNPJ
    B-->>A: Razão social e endereço
    A->>D: Casa o município por nome normalizado e UF
    A-->>P: Dados preenchidos e código do município
    U->>P: Confere e toca em Salvar credor
    P->>A: POST /credores
    A->>D: Procura o documento no cache de credores
    A->>S: GET /creditors?cnpj=... (reserva cota, evita duplicata)
    alt Já existe no Sienge
        S-->>A: Credor existente
        A->>D: Upsert em credores
    else Não existe
        A->>A: Sanitiza o nome e monta o corpo (typesId FO, N, número com espaço)
        A->>S: POST /creditors (reserva cota)
        S-->>A: 201 com Location .../creditors/{id}
        A->>D: Upsert em credores com criado_pelo_app_em
    end
    A-->>P: Credor com o id do Sienge
    P->>A: PUT /despesas/{id} com o credor_id
```

O credor do colaborador (RN14) usa o mesmo fluxo a partir do passo 8, com `personType F`, `typesId FU` e os dados do cadastro do usuário. A atualização usa `PATCH /creditors/{id}`, que é aceito em credores criados pela API.

## S4 — Aprovação e lançamento

RF20–RF22, RF33, RN05, RN12, RN16, RN22, T7, T12–T15.

```mermaid
sequenceDiagram
    autonumber
    actor AP as Aprovador
    participant P as PWA
    participant A as API
    participant D as Banco
    participant W as Worker
    participant ST as Storage
    participant S as Sienge

    AP->>P: Toca em Lançar no Sienge
    P->>A: POST /despesas/{id}/aprovacao (versao)
    A->>D: BEGIN, SELECT FOR UPDATE, confere versao e credor_id
    A->>D: UPDATE status APROVADA, evento APROVADA e job lancar-despesa na mesma transação
    A->>D: COMMIT
    A-->>P: 200, a próxima pendente abre sozinha
    W->>D: Pega o job e bloqueia a despesa
    alt Cota do dia insuficiente
        W->>D: Grava aguardando_cota_desde, reagenda para o dia seguinte
        W->>D: Notificação LANCAMENTO_RETENTATIVA
    else Cota disponível
        W->>D: UPDATE status ENVIANDO e tentativas mais 1
        opt Título ainda não criado
            W->>W: Monta o corpo: percentuais (Rateio), número formatado, notes ou espaço, indexId 0
            W->>S: POST /bills (reserva cota)
            alt 201
                S-->>W: Location .../bills/{billId}
                W->>D: Grava sienge_titulo_id e evento TITULO_CRIADO (commit imediato)
            else 400 recusa por dados
                S-->>W: clientMessage
                W->>D: status ERRO, erro_mensagem e notificação LANCAMENTO_ERRO
            else Tempo esgotado ou 5xx
                W->>D: Marca resultado incerto, status APROVADA e reagenda (S5)
            end
        end
        loop Cada anexo sem enviado_em
            W->>ST: Lê o arquivo
            W->>S: POST /bills/{billId}/attachments?description=DANFe (reserva cota)
            S-->>W: 201
            W->>D: Grava enviado_em no anexo
            W->>ST: Apaga o arquivo
            W->>D: Grava apagado_em
        end
        W->>D: BEGIN, status LANCADA e lancada_em
        W->>D: INSERT em titulos_sienge com o corpo enviado e o billId
        W->>D: Notificação LANCAMENTO_SUCESSO para o aprovador e COMMIT
        A-->>P: Aviso pelo canal em tempo real (SSE)
        P-->>AP: Caixa verde: Título N lançado, com botão de copiar
    end
```

O `sienge_titulo_id` é gravado **antes** dos anexos, numa transação própria: se o worker cair depois disso, a retomada nunca cria um segundo título. Nenhuma chamada de alteração (`PATCH`/`PUT`) é feita no título.

## S5 — Retomada idempotente depois de falha incerta

`integracao-sienge.feature`, "Uma despesa nunca gera dois títulos".

```mermaid
sequenceDiagram
    autonumber
    participant W as Worker
    participant D as Banco
    participant S as Sienge

    W->>D: Pega o job de novo (nova tentativa ou queda do worker)
    W->>D: Lê sienge_titulo_id e os anexos
    alt sienge_titulo_id vazio e a tentativa anterior foi incerta
        W->>S: GET /bills?creditorId&documentNumber&startDate=emissão&endDate=emissão (reserva cota)
        alt Título encontrado com o mesmo credor, número, emissão e valor
            S-->>W: Título existente
            W->>D: Grava sienge_titulo_id sem criar outro
        else Não encontrado
            W->>S: POST /bills (reserva cota)
        end
    else sienge_titulo_id vazio e a tentativa anterior foi recusada
        W->>S: POST /bills (reserva cota)
    end
    opt Algum anexo com envio incerto
        W->>S: GET /bills/{billId}/attachments (reserva cota)
        S-->>W: Lista com name e description
        W->>D: Marca como enviados os que já estão lá
    end
    W->>S: POST dos anexos que faltam (reserva cota cada)
```

A busca do passo 3 só acontece quando a tentativa anterior pode ter chegado ao Sienge (tempo esgotado ou 5xx depois do envio). Uma recusa clara (4xx) não deixa título criado, então não gasta essa requisição.

## S6 — Conferência de notas

RF30, RN23, RN25, `conferencia-notas.feature`.

```mermaid
sequenceDiagram
    autonumber
    actor AP as Aprovador
    participant P as PWA
    participant A as API
    participant D as Banco
    participant ST as Storage
    participant S as Sienge

    AP->>P: Envia o arquivo da nota
    P->>A: POST /conferencias (arquivo)
    A->>ST: Grava o arquivo
    A->>D: Cria a conferência e o anexo ligado a ela
    A-->>P: Credor e número lidos da chave
    AP->>P: Confirma valor, emissão e pagamento e toca em Procurar
    P->>A: POST /conferencias/{id}/busca
    A->>S: GET /bills, última página (títulos novos, reserva cota)
    S-->>A: Títulos mais recentes
    A->>D: Upsert em titulos_sienge
    A->>A: Período = menor e maior data entre emissão e pagamento, com 3 dias de margem
    A->>D: Títulos do credor no período com o mesmo valor e despesas não lançadas iguais
    alt Encontrou
        A-->>P: Lista de títulos e despesas parecidos
        AP->>P: Escolhe o tipo e toca em Anexar a nota ao título N
        P->>A: POST /conferencias/{id}/anexar (tituloId)
        A->>S: POST /bills/{tituloId}/attachments (reserva cota)
        S-->>A: 201
        A->>D: Anexo enviado e conferência concluída
        A->>ST: Apaga o arquivo
        A-->>P: Nota anexada ao título N
    else Não encontrou
        A-->>P: Nenhum lançamento encontrado
        AP->>P: Cadastrar título com esta nota
        P->>A: POST /conferencias/{id}/despesa
        A->>D: Cria a despesa em RASCUNHO (canal CONFERENCIA) e passa o anexo para ela
        A-->>P: Cadastro aberto já preenchido
    end
```

O título encontrado não é alterado: a nota entra só como anexo. Ponto de teste: anexar em títulos lançados pela tela (origem `CP`).

## S7 — Cache de títulos e de credores

RN25, RF35, `consulta-titulos.feature`.

```mermaid
sequenceDiagram
    autonumber
    actor AP as Aprovador
    participant A as API
    participant W as Worker
    participant D as Banco
    participant S as Sienge

    Note over W,S: Carga inicial (uma vez, no dia da implantação)
    W->>D: Cria a sincronização CARGA_TITULOS com cursor 0
    loop Até cursor maior ou igual ao total
        W->>D: Reserva cota dentro da reserva de sincronização
        alt Reserva disponível
            W->>S: GET /bills?startDate=2018-01-01&endDate=hoje&limit=200&offset=cursor
            S-->>W: Até 200 títulos e o count
            W->>D: Upsert da página e cursor mais 200 na mesma transação
        else Reserva do dia acabou
            W->>D: Status INTERROMPIDA, retoma amanhã do mesmo cursor
        end
    end
    W->>D: Status CONCLUIDA

    Note over AP,S: Títulos novos (rotina de domingo e Atualizar agora)
    AP->>A: Atualizar agora
    A->>D: Confere a trava: última atualização manual há menos de 5 minutos?
    alt Travado
        A-->>AP: Disponível em N minutos (nenhuma requisição)
    else Liberado
        A->>D: Cria a sincronização INCREMENTAL_TITULOS
        loop Da última página para trás, até achar títulos que o banco já tem
            A->>S: GET /bills?startDate=2018-01-01&endDate=hoje&limit=200&offset=última página
            S-->>A: Até 200 títulos e o count
            A->>D: Grava os que ainda não estão no banco
        end
        opt Título novo lançado direto no Sienge
            A->>S: GET /bills/{id}/budget-categories (reserva cota)
            A->>D: Grava as apropriações em titulos_sienge_apropriacoes
        end
        opt Credor que o cache não conhece
            A->>S: GET /creditors/{id} (reserva cota)
            A->>D: Upsert em credores
        end
        A->>D: Status CONCLUIDA e periodo_fim
        A-->>AP: Lista atualizada
    end
```

Detalhes:
- A lista vem em ordem crescente de id e cada título novo entra no fim, então paginar por `offset` não pula títulos enquanto a carga acontece. O que mudar durante a carga entra na primeira atualização incremental.
- Os títulos novos ficam no fim da lista: a rotina começa pela última página (`offset = count − 200`) e volta página por página enquanto todos os títulos forem novos. Alterações em títulos antigos não entram por essa rotina (ver RN25 c).
- Credores: a carga inicial vem do **arquivo exportado do Sienge** (o administrador envia em Configurações; nenhuma requisição). Depois, os criados pelo app entram na hora, e um credor desconhecido que apareça num título é buscado sob demanda (passos do `opt`, 1 requisição cada, raro). O administrador pode reenviar o arquivo quando quiser atualizar tudo.

## S8 — Conferência de baixa e de ajuste de parcelas

RN20, RF13, RF29, `baixas-pendentes.feature`, `aprovacao-titulo.feature`.

**v1 (ADR-0009):** a conferência de baixa no Sienge (primeiro laço do diagrama) **não é usada**: "Já dei baixa" só grava `baixa_confirmada_em` e `baixa_confirmada_por_id` no app, sem requisição. Essa parte fica como referência para a versão futura. A conferência do ajuste de parcelas (segunda parte) continua valendo.

```mermaid
sequenceDiagram
    autonumber
    actor AP as Aprovador
    participant A as API
    participant D as Banco
    participant S as Sienge

    AP->>A: Abre Baixas pendentes
    A->>D: Despesas lançadas e pagas sem baixa confirmada
    loop Cada título não conferido há mais de 12 horas, enquanto houver cota
        A->>S: GET /bills/{billId}/installments (reserva cota)
        alt Todas as parcelas Totalmente paga
            A->>D: Grava baixa_confirmada_em e evento BAIXA_CONFIRMADA
        else Alguma parcela Não paga
            A->>D: Grava baixa_verificada_em
        else 404
            A->>D: Grava titulo_excluido_em e evento TITULO_EXCLUIDO
        end
    end
    A-->>AP: Só os títulos ainda pendentes, com a hora da conferência

    AP->>A: Parcelas ajustadas (título N)
    A->>S: GET /bills/{N}/installments (reserva cota)
    S-->>A: Parcelas atuais no Sienge
    A->>A: PlanoParcelas.confere: mesma quantidade, mesmas datas, valores com 1 centavo de tolerância
    alt Bate com as parcelas reais
        A->>D: Grava parcelas_ajustadas_em e evento PARCELAS_AJUSTADAS
        A-->>AP: Aviso removido
    else Não bate
        A-->>AP: O Sienge ainda mostra as parcelas antigas
    end
```

Otimização a confirmar (RN20): se a baixa mudar o `changedDate` do título, a conferência passa a consultar só os títulos pagos que aparecerem na atualização incremental (S7).

## S9 — Definir centro de custo (despesa de colaborador de rua)

RN27, RF36, T22–T24.

```mermaid
sequenceDiagram
    autonumber
    actor R as Colaborador de rua
    actor CC as Aprovador de CC
    participant P as PWA
    participant A as API
    participant D as Banco

    R->>P: Envia a despesa sem apropriação
    P->>A: POST /despesas/{id}/envio
    A->>A: Valida V1 a V3, V7 e V8 (sem V4 a V6) e a duplicidade
    A->>D: status AGUARDANDO_CC e evento ENVIADA
    A-->>P: Aguardando centro de custo
    CC->>P: Abre Definir centro de custo e escolhe a despesa
    P->>A: GET /despesas?status=AGUARDANDO_CC
    A->>D: Despesas da fila, mais antigas primeiro
    CC->>P: Preenche centro de custo, plano e valor e toca em Enviar para aprovação
    P->>A: PUT /despesas/{id}/apropriacoes (versao)
    A->>D: BEGIN e SELECT FOR UPDATE
    A->>A: Confere o perfil (só apropriações) e valida V4 a V6
    A->>D: Substitui as apropriações, status PENDENTE e evento APROPRIACAO_DEFINIDA
    A->>D: COMMIT
    A-->>P: Despesa enviada para a aprovação
```

A rota só aceita as apropriações: qualquer outro campo enviado nessa chamada é recusado, garantindo pelo servidor que o aprovador de centro de custo não altera o resto da despesa.

