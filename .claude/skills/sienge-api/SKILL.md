---
name: sienge-api
description: Como integrar com a API REST do Sienge (ERP) neste projeto — autenticação, cota de 100 requisições/dia, endpoints de credores, títulos a pagar (bills), anexos, apropriações financeiras, sincronização de empresas/centros de custo/planos financeiros/tipos de documento, idempotência e modo dry-run. Use esta skill sempre que for escrever, alterar, testar ou depurar qualquer código que chame o Sienge (apps/worker, cliente HTTP, sync de cadastros, cadastro de credor, mocks), mesmo que o pedido não diga "Sienge" — por exemplo "lançar título", "criar credor", "sincronizar centros de custo", "anexar comprovante", "rateio", "plano financeiro".
---

# Integração com a API do Sienge

**Regra zero:** só use os endpoints e campos descritos aqui. Itens marcados **[spike]** ainda não foram testados com o usuário de API real; ao confirmar algo, atualize esta skill (seção "Descobertas") e remova a marcação. Nunca invente campos ou códigos.

## Contexto deste projeto

- Subdomínio: `sencoeng`. Empresas (debtorId): 1 Soluções, 2 Senco Projetos, 3 Bento Gastronomia, 4 Senco Locações e Transportes, 5 Locações Parceria.
- **Não há ambiente de homologação.** Toda escrita afeta produção.
- **Não é possível dar baixa pela API.** O app só lança o título; a baixa é feita pela Camilla no Sienge.
- As abas Impostos, Aprop. Obra, Aprop. Depto, Unidades e Inf. Pagamento do título não são usadas.

## Ambiente, autenticação e URL

```
SIENGE_SUBDOMAIN=sencoeng
SIENGE_API_USER=...           # usuário de API (Integrações > Usuários de APIs)
SIENGE_API_PASSWORD=...
SIENGE_DRY_RUN=true           # padrão; false só em produção, explicitamente
SIENGE_DAILY_QUOTA=100        # pacote contratado
```

- Base (confirmada na documentação): `https://api.sienge.com.br/{subdominio}/public/api/v1` → `https://api.sienge.com.br/sencoeng/public/api/v1`.
- Autenticação: HTTP Basic com o usuário de API. **Funcionando** (testes de 20/10/2026).
- Datas sempre `AAAA-MM-DD`. Valores numéricos em reais com ponto decimal (`490.8`), convertidos dos centavos internos só na borda do cliente HTTP.
- Credenciais só em `apps/api` e `apps/worker`. Nunca logar `Authorization`, senha, CPF completo ou chave Pix.
- **Dry-run:** o cliente monta e valida o payload (Zod), grava em `LogIntegracao` com `dryRun=true` e devolve resposta simulada (`id` negativo). Testes nunca desligam o dry-run.

## Formato de erro

Todas as rotas devolvem erros como:

```json
{ "status": 400, "developerMessage": "...", "clientMessage": "..." }
```

- Mostrar `clientMessage` ao aprovador; gravar `developerMessage` no log.
- `400` → regra de negócio: **não repetir**; despesa vai para `ERRO` com a mensagem.
- `401`/`403` → credencial ou permissão: pausar a fila inteira e avisar administradores.
- `404` → recurso inexistente (ex.: `GET /bills/{id}/attachments` sem anexos também pode vir 404 — tratar como lista vazia).
- `429`, `5xx`, timeout → retry com backoff exponencial + jitter (1s, 4s, 16s… máx. 5), respeitando a idempotência abaixo.

## Cota: 100 requisições/dia

Cada chamada conta. O cliente HTTP reserva a cota **antes** de cada chamada (`cota_diaria`, de forma atômica) e registra em `chamadas_api`. Regras completas no ADR-0009 (`docs/adr/0009-cota-da-api.md`):

- Prioridade `PESSOA` (alguém esperando na tela) > `LANCAMENTO` > `ROTINA`. Lançamentos e rotinas param em `limite − cota_reserva_pessoas` (padrão 10).
- Lançamento que não cabe sai no dia seguinte, na ordem de aprovação, e os aprovadores veem o aviso amarelo.
- Rotinas automáticas que chamam o Sienge só rodam **aos domingos**: primeiro as curtas (cadastros, títulos novos e alterados), depois a fila de lançamentos acumulada, depois o resto (rateio de títulos lançados direto no Sienge).

| Operação | Requisições |
|---|---|
| Lançar título com 1 anexo | 2 (`POST /bills` + `POST attachments`) |
| Cada anexo adicional | +1 |
| Obter o ID do título, se o 201 não trouxer **[spike]** | +1 (`GET /bills`) |
| Verificar baixa de um título pago | **Não usado na v1** ("Já dei baixa" só marca no app). Versão futura: +1 por consulta (`GET /bills/{billId}/installments`) |
| Confirmar ajuste de parcelas | +1 por toque em "Parcelas ajustadas" (`GET /bills/{billId}/installments`) |
| Conferência de notas | +1 por busca (`GET /bills`) e +1 para anexar (`POST attachments`) |
| Credor novo (cadastro) | 1 (`POST /creditors`; o ID vem no header `Location`) |
| Busca de credor fora do cache | 1 (`GET /creditors`, aceita vários CNPJs na mesma chamada) |
| Sincronização de cadastros (domingo ou "Sincronizar agora") | ~5 |
| Títulos alterados (`GET /bills/by-change-date`, domingo) | 1 por semana (mais, se passar de 200) |

Capacidade estimada: ~40 lançamentos por dia útil no pacote atual (90 requisições ÷ ~2,2).

## Mapa de endpoints

| Etapa | Endpoint | Uso |
|---|---|---|
| Sync | `GET /companies` | Empresas |
| Sync | `GET /cost-centers` | Centros de custo e empresa de cada um |
| Sync | `GET /payment-categories` | Planos financeiros |
| Sync | `GET /document-identifications` | Tipos de documento e suas regras |
| Credor | `GET /creditors` | Buscar por CPF, CNPJ (vários) ou nome/código |
| Credor | `POST /creditors` | Cadastrar credor |
| Credor | `PATCH /creditors/{creditorId}` | Atualizar credor do colaborador |
| Credor | `POST /creditors/{creditorId}/pix-informations` | Opcional: chave Pix do colaborador |
| Lançamento | `POST /bills` | Criar título com apropriações |
| Lançamento | `POST /bills/{billId}/attachments` | Enviar cada anexo |
| Idempotência | `GET /bills` | Achar título já criado após falha |
| Idempotência | `GET /bills/{billId}/attachments` | Ver anexos já enviados |

**Não usar:** qualquer `PATCH`/`PUT` em `/bills/...` (títulos criados pela API têm origem `SE` e não podem ser alterados pela API — ver §5 Parcelas), `POST /eletronic-invoice-bills` (a empresa não recebe os XMLs das NF-e no Sienge), `departmentsCost`, `buildingsCost`, `units`, `taxes` (enviar ausentes), `PUT .../departments-cost`, `PUT .../buildings-cost`, `PUT .../units`, todos os `.../payment-information/...` e Contas-Correntes. O `GET /bills/by-change-date` só entra na rotina de domingo (1 chamada por semana, ADR-0010), para atualizar valores e exclusões no cache; ele não informa se o título foi pago, então não serve para detectar baixa.

## 1. Sincronização de cadastros (domingo + "Sincronizar agora")

Upsert por ID; o que sumir vira inativo (nunca apagar — despesas antigas referenciam). Estimar o custo antes e abortar se a cota restante não cobrir. Custo atual: ~5 requisições. **Aplicar `trim()` em todo texto vindo da API** (há nomes e códigos com espaços sobrando).

### `GET /companies?limit=200&offset=0`
`results[]` com `id`, `name`, `tradeName`, `cnpj` (formatado, pode vir `""`). 5 empresas (ids 1–5). Ex.: `"name": "LOCAÇÕES PARCERIA "` (espaço no fim).

### `GET /cost-centers?limit=200&offset=N`
Paginado (máx. 200), ordenado por `id` decrescente. `resultSetMetadata.count` = 220 hoje → 2 páginas. `results[]` com `id`, `name`, `idCompany`, `cnpj` (`""`).
- A API **já omite** os CCs sem empresa (nenhum veio com `idCompany` nulo, e os da exportação sem empresa não aparecem). Manter o filtro por segurança.
- A API **não informa situação** (ativo/encerrado). Um administrador marca no app os CCs a ocultar.

### `GET /payment-categories`
Sem paginação e sem `resultSetMetadata`: a resposta é **um array na raiz** com todos os planos (987 hoje), em 1 requisição. Campos: `id`, `name`, `tpConta`, `flRedutora`, `flAtiva`, `flAdiantamento`, `flImposto`.
- `id` é o **código sem pontos**, como string: `"2010402"` = 2.01.04.02. É esse valor que vai em `paymentCategoriesId`.
- Exibir com pontos: primeiro dígito, depois pares (`"2010402"` → `2.01.04.02`; `"20904"` → `2.09.04`).
- `tpConta`: `"T"` totalizadora, `"R"` resultado. Valores observados: `flRedutora` S/N; `flAtiva`, `flAdiantamento`, `flImposto` sempre S, N, N.
- Mostrar ao usuário só os planos **liberados no app** (curadoria dos aprovadores, SPEC RN08 e RF37) que sejam do grupo 2 (código começando com `2`), `tpConta = "R"`, `flRedutora = "N"` e `flAtiva = "S"`. Lista inicial: `data/planos-financeiros-liberados.json`. A sincronização atualiza nomes e marcações, mas nunca muda o que foi liberado.
- **Não existe** endpoint para criar plano financeiro (confirmado na documentação, 06/11/2026). Planos novos são criados na tela do Sienge e trazidos com o `GET /payment-categories` (1 requisição).
- Grupo pai = prefixo do código (`2010402` → `20104` "VEÍCULOS E EQUIPAMENTOS").

### `GET /document-identifications?active=true&limit=100`
85 documentos, 1 página. Na **lista** a chave é `documentIdentificationId`; no **detalhe** (`GET /document-identifications/DANF`) a chave é `id`. Os códigos vêm com **4 caracteres, completados com espaço** (`"PAG "`, `"CT  "`): fazer `trim()` ao ler. Ao enviar, usar sem espaços (`"PAG"`) **[spike: confirmar que o POST aceita]**.

Flags reais do DANF:

| Flag | DANF | Efeito no app |
|---|---|---|
| `blockDuplicateNumberForSameCreditor` | `true` | O Sienge recusa número repetido para o mesmo credor (ver §7) |
| `considerLeadingZeros` | `true` | Para o Sienge, `003.087` ≠ `0003.087`: o app deve sempre formatar o número igual (§5) |
| `numbersOnly` | `false` | Pode enviar pontos |
| `requireElectronicInvoiceKeyOnPayable` | `false` | Chave não é exigida (o `POST /bills` nem a recebe) |
| `requireAttachmentOnPayableBill` | `false` | Informativo |
| `blockDueDate` | `true` | **[spike]** efeito desconhecido; observar no teste de escrita |
| `requireUnitOnPayable` | `true` (em todos os documentos) | **[spike]** os títulos da Camilla não usam a aba Unidades; ver se o `POST /bills` exige `units` |

Guardar essas flags para DANF, NFSE, REC, PAG e REMB e aplicar na formatação do número e na checagem de duplicidade local.

## 2. Resolver credor

1. Cache local por documento (só dígitos).
2. Fora do cache: `GET /creditors?cnpj=XXXXXXXXXXXXXX` ou `?cpf=XXXXXXXXXXX` (sem máscara). Na importação de planilha, enviar **vários** `cnpj` na mesma chamada.
3. Busca por nome: `GET /creditors?creditor=texto` (nome, fantasia ou código).
4. Resposta: `results[]` com `id`, `name`, `tradeName`, `cpf`, `cnpj`, `supplier`, `employee`, `active`, `stateRegistrationType`, `address.cityId`, …
5. Ignorar `active = false` (avisar "credor desativado no Sienge").
6. A resposta devolve documento e CEP **formatados** (`"cpf": "000.000.000-00"`, `"cnpj": "28.070.499/0001-22"`, `"zipCode": "28895-600"`), mesmo que a busca seja feita só com dígitos. Normalizar (só dígitos) antes de comparar ou gravar no cache.
   Exemplo real (CNPJ 28070499000122): `"id": 125`, `"name": "FN TAG MATERIAIS EIRELI"`, `"tradeName": "FN DO BRASIL OFFSHORE"`, `"supplier": "S"`, `"stateRegistrationType": "N"`, `"address": {"cityId": 3669, "cityName": "Rio das Ostras", "state": "RJ", ...}`. Note que a razão social pode ser bem diferente do nome no DANFE: mostrar razão social **e** fantasia na busca.
7. Tipo de credor vem em flags `"S"`/`"N"`: `supplier` (fornecedor), `broker` (corretor), `employee` (colaborador). O endereço traz `cityId`, `cityName` e `state` (UF).

Não há filtro por data de alteração: **não sincronizar todos os credores**; o cache cresce sob demanda.

## 3. Cadastrar credor — `POST /creditors`

Corpo mínimo usado pelo app:

```json
{
  "name": "ACQUA LUZ",
  "personType": "J",
  "typesId": ["FO"],
  "registerNumber": "55932700000106",
  "stateRegistrationNumber": " ",
  "stateRegistrationType": "N",
  "address": {
    "cityId": 3669,
    "streetName": "RUA EXEMPLO",
    "number": "100",
    "complement": "",
    "neighborhood": "CENTRO",
    "zipCode": "28890000"
  }
}
```

- `personType`: `"F"` físico ou `"J"` jurídico (confirmado na aba Model).
- `typesId`: lista com o tipo de credor (confirmado na aba Model): `"FO"` fornecedor, `"FU"` colaborador, `"CO"` corretor. Fornecedor → `["FO"]`; credor do colaborador → `["FU"]`. **Atenção:** `"CO"` é corretor, não colaborador — o exemplo da documentação (`["CO","FO"]`) engana. Na leitura (`GET /creditors`) os mesmos tipos aparecem como flags: `supplier` = FO, `employee` = FU, `broker` = CO.
- `registerNumber`: CPF ou CNPJ **sem máscara**.
- `municipalSubscription`: só para pessoa jurídica (não usado).
- `stateRegistrationType`: **sempre `"N"`** (Não contribuinte — regra do negócio). Códigos confirmados na aba Model: `C` contribuinte, `I` isento, `N` não contribuinte.
- `stateRegistrationNumber`: **obrigatório e não pode ser vazio** (`""` ou ausente → `400` "Número de inscrição estadual não informado."). Enviar **`" "` (um espaço)** direto no `POST`, que fica em branco no cadastro (confirmado em 06/11/2026; também aceito no `PATCH`). Não usar `"ISENTO"`.
- `address.cityId`: código Sienge do município (`data/municipios-sienge.csv`; casar nome normalizado + UF).
- Texto sanitizado antes de enviar: remover acentos, `&` → `e`, só letras/números/espaços, colapsar espaços.
- Não enviar: `agents`, `contacts`, `procurators`, `payslipDesonerationYears`, `accountStatement`, `municipalSubscription`, `paymentTypeId` (salvo se o spike mostrar que são obrigatórios).
- Resposta `201 Credor inserido`, corpo vazio; o ID vem no header `Location` (`.../creditors/2404`, confirmado). Só se o header faltar: `GET /creditors?cnpj=...` (+1 requisição).
- Antes de criar, sempre buscar pelo documento (evita duplicata). Se o Sienge estiver indisponível ou sem cota, guardar como "Aguardando cadastro no Sienge" e o worker cria depois.

## 4. Credor do colaborador

- Criar com `POST /creditors` (`personType: "F"`, `typesId: ["FU"]`, `registerNumber` = CPF sem máscara, `stateRegistrationType: "N"`, município obrigatório).
- Se o colaborador já existir como fornecedor (`supplier "S"`, `employee "N"`), não criar outro: avisar o administrador (a API não tem endpoint para acrescentar tipo a um credor existente).
- Atualizar com `PATCH /creditors/{creditorId}` — envio parcial; aceita `name`, `personType`, `cpf`, `cnpj`, `stateRegistrationNumber`, `stateRegistrationType`, `taxClassificationId`, `municipalSubscription`, `address{...}`. Resposta `204`.
- Diferente dos títulos, **credores criados pela API podem ser alterados pela API**: `PATCH /creditors/2404` (criado pelo app) → `204` (confirmado).
- Opcional: `POST /creditors/{creditorId}/pix-informations` com `type`, `key`, `beneficiary`, `cpfCnpjBeneficiary`, `defaultFlag`. Valores de `type` e `defaultFlag` **[spike]**. Custa 1 requisição; fazer só na criação ou quando a chave mudar.

## 5. Lançar título — `POST /bills`

Worker, um job por despesa, lock por `despesaId`, só a partir de `APROVADA`.

### Mapeamento (aba Model confirmada)

| Domínio | Campo | Obrig. | Regra |
|---|---|---|---|
| empresa | `debtorId` | sim | 1–5 |
| credor | `creditorId` | sim | resolvido (§2) |
| tipo de documento | `documentIdentificationId` | sim | `DANF`, `NFSE`, `REC`, `PAG`, `REMB` |
| número | `documentNumber` | sim | 1 a 20 caracteres; formato abaixo |
| emissão | `issueDate` | sim | |
| data contábil | `billDate` | sim | Model: "Data de competência" = campo "Data contábil" da tela; = emissão |
| data base | `baseDate` | sim | dia 1 do mês da emissão |
| 1º vencimento | `dueDate` | sim | pagamento, se paga; senão o vencimento da 1ª parcela |
| parcelas | `installmentsNumber` | sim | 1 a 840 |
| indexador | `indexId` | sim | `0` (REAL) |
| valor total | `totalInvoiceAmount` | sim | **bruto** (já somando o desconto); 2 casas; mín. 0,01 |
| desconto | `discount` | sim | `0` salvo importação; 2 casas |
| observação | `notes` | **sim** | até 500 caracteres; nunca vazio (ver abaixo) |
| apropriações | `budgetCategories[]` | sim | `costCenterId`, `paymentCategoriesId` (código **sem pontos**), `percentage` |

- **Valor:** o Model define `totalInvoiceAmount` como valor bruto, somando impostos e desconto. Na regra do app (valor pago, desconto 0) os dois coincidem. Quando houver desconto (importação), enviar `totalInvoiceAmount = valor pago + desconto` e `discount = desconto`; os percentuais de apropriação são calculados sobre o bruto.
- **Observação (`notes`):** obrigatória na API, que recusa vazio. O valor é o texto que o usuário escreveu no campo "Observação" do app (opcional, até 500 caracteres); se ele não escrever nada, enviar **`" "` (um espaço)** — confirmado no título 17120; na tela do Sienge aparece em branco. O app **não** acrescenta nada automaticamente (nem a linha digitável).
- **Número do documento:** a Camilla digita o número da nota em grupos de 3 dígitos separados por ponto, **sem os grupos iniciais zerados**, com o primeiro grupo completado até 3 dígitos: NF 000.003.087 → `003.087`; 3072580 → `003.072.580`; 85414 → `085.414`. Como o DANF tem `considerLeadingZeros = true`, seguir sempre esse formato (senão o bloqueio de duplicidade do Sienge não reconhece o mesmo número). Sem nota: `dd/mm` do pagamento (ex. `14/09`), como nos títulos PAG existentes.

```ts
function formatarNumeroNota(n: string): string {
  const d = n.replace(/\D/g, '').replace(/^0+/, '') || '0';
  const grupos = d.replace(/\B(?=(\d{3})+(?!\d))/g, '.').split('.');
  grupos[0] = grupos[0].padStart(3, '0');
  return grupos.join('.');
}
```

### Exemplo (NF-e da FN do Brasil, título real 16720)

```json
{
  "debtorId": 1,
  "creditorId": 125,
  "documentIdentificationId": "DANF",
  "documentNumber": "003.087",
  "issueDate": "2026-09-14",
  "installmentsNumber": 1,
  "indexId": 0,
  "baseDate": "2026-09-01",
  "dueDate": "2026-10-12",
  "billDate": "2026-09-14",
  "totalInvoiceAmount": 490.8,
  "notes": "Material de consumo e ferramental",
  "discount": 0,
  "budgetCategories": [
    { "costCenterId": 107, "paymentCategoriesId": "2010106", "percentage": 100 }
  ]
}
```

### Apropriações: só percentual

A API não recebe valores, só `percentage`; o Sienge calcula o valor de cada linha. Algoritmo em `packages/shared`, com teste: `Rateio.percentuais` (`docs/modelagem/04-classes.md` §2.1), com aritmética decimal exata (nunca `number` em ponto flutuante), 12 casas, e a 1ª linha recebendo `100 − soma das demais` (padrão observado no Sienge). A precisão aceita no `percentage` ainda é **[spike]**.

Depois do cálculo, conferir que `round(total × pct / 100)` reproduz cada valor com tolerância de 1 centavo; se não reproduzir, registrar aviso no log (não bloquear).

### Parcelas

`POST /bills` só recebe `installmentsNumber` e `dueDate` (1º vencimento); o Sienge gera as parcelas sozinho. **Regra observada:** valores iguais (17.214,96 em 3 → 5.738,32 cada) e vencimentos mensais no mesmo dia a partir do `dueDate` (19/11, 19/12, 19/01), todas com a mesma data base. Onde fica o centavo de sobra em divisões não exatas **[spike]**.

**Títulos criados pela API não podem ser alterados pela API.** O `PATCH /bills/{billId}/installments` no título 17120 respondeu:

```json
{ "status": 400, "developerMessage": null, "clientMessage": "O Título com origem no SE não pode ser alterado para chamadas do SE." }
```

Todo título criado pela API recebe `originId: "SE"` (Sistemas Externos), e o Sienge bloqueia alterações de títulos SE vindas da API. Consequências:
- **Não usar** `PATCH /bills/{billId}/installments`, `PATCH /bills/{billId}/installments/{installmentId}` nem `PATCH /bills/{billId}` em títulos criados pelo app.
- O worker envia só `installmentsNumber` + `dueDate`. Se a despesa tiver parcelas com valores ou datas diferentes da regra do Sienge, a despesa é marcada **"Ajustar parcelas no Sienge"** e os valores reais ficam visíveis para a Camilla ajustar na tela do Sienge (SPEC RF13).
- Para comparar com a regra do Sienge: valores iguais com tolerância de 1 centavo e vencimentos mensais no mesmo dia do 1º vencimento.

### Chave de acesso

`POST /bills` **não aceita** `accessKeyNumber` (só aparece na leitura). A chave fica no app, para duplicidade e no nome do arquivo do DANFE.

### Resposta

`201 Título inserido`, **corpo vazio**. O `billId` vem no header `Location` (confirmado): `https://api.sienge.com.br/sencoeng/public/api/v1/bills/17120` → `17120`. Extrair o último segmento numérico; se o header faltar por algum motivo, `GET /bills` com os filtros da §7 (+1 requisição). Gravar o `billId` na despesa **imediatamente**, na mesma transação da mudança de estado.

### Consultar parcelas — `GET /bills/{billId}/installments`

`results[]` com `installmentNumber`, `dueDate`, `amount`, `baseDate`, `billDate`, `indexId`, `paymentTypeId`, `paymentType`, `situation`, `sentToBank`, `batchNumber`. O campo **`situation`** indica o pagamento: `"Não paga"` (na tela, `NP`) ou `"Totalmente paga"` (confirmados); provavelmente existe um valor para pagamento parcial **[spike]**. É a única forma de saber pela API se a Camilla já deu baixa.

### Verificar baixa (tela "Baixas pendentes") — versão futura

**Não usado na v1 (ADR-0009):** "Já dei baixa" só marca no app, sem requisição. O roteiro abaixo fica para quando sobrar cota.

Só para despesas com `paga = true` e `siengeTituloId` preenchido, ainda sem `baixaConfirmadaEm`.

1. `GET /bills/{billId}/installments` (1 requisição por título).
2. Títulos pagos têm 1 parcela: `situation = "Totalmente paga"` → gravar `baixaConfirmadaEm` e nunca mais consultar esse título. Qualquer outro valor → pendente.
3. Senão → gravar `baixaVerificadaEm` e manter na lista.
4. Quando consultar (RN20 do SPEC): ao abrir a tela, só os não verificados há mais de `BAIXA_RECHECK_HORAS` (padrão **12**, parâmetro de configuração — deve mudar depois); no botão "Já dei baixa", só aquele título; e uma rodada diária no worker. Antes de cada rodada, conferir a cota restante; se não couber, mostrar o último resultado com a data da verificação.
5. 404 → título excluído no Sienge: marcar a despesa e avisar o aprovador.

### Confirmar ajuste de parcelas ("Parcelas ajustadas")

Para despesas marcadas "Ajustar parcelas no Sienge", quando o aprovador toca em "Parcelas ajustadas":
1. `GET /bills/{billId}/installments` (1 requisição).
2. Comparar cada parcela (`installmentNumber`, `dueDate`, `amount`) com as parcelas reais guardadas na despesa: mesma data e valor com tolerância de 1 centavo; mesma quantidade.
3. Bateu → gravar `parcelasAjustadasEm` e tirar a marca. Não bateu → mensagem "O Sienge ainda mostra as parcelas antigas" e manter a marca.

### Cache local de títulos (SPEC RN25)

Observado em 26/10/2026 (`GET /bills?startDate=2018-01-01&endDate=2026-10-26`, sem `limit`): `resultSetMetadata = {count: 16513, offset: 0, limit: 100}`, 100 itens na resposta, **em ordem crescente de `id`** (a primeira página traz os mais antigos: ids 35 a 141, emissão de 2023). Cerca de 1,4 KB por título (~22 MB para tudo). Campos de cada título: `id`, `debtorId`, `creditorId`, `documentIdentificationId`, `documentNumber`, `contractNumber`, `measurementNumber`, `purchaseOrderId`, `formattedPurchaseOrderId`, `issueDate`, `installmentsNumber`, `totalInvoiceAmount`, `tenantUrl`, `notes`, `discount`, `status`, `originId` (`CP`, `FP` e `SE` observados), `registeredUserId`, `registeredBy`, `registeredDate`, `changedUserId`, `changedBy`, `changedDate`, `accessKeyNumber`, `links`. **`limit` máximo = 200**: `limit=1000` foi aceito sem erro, mas a resposta veio com `limit: 200` e 200 itens. `offset=16400` trouxe os 114 últimos (ids 17048 em diante, emissão de outubro de 2026). Carga completa: `ceil(count / 200)` = 83 chamadas.


- **Carga inicial:** `GET /bills?startDate=AAAA-MM-DD&endDate=AAAA-MM-DD&limit=200&offset=N`, por janelas de período (ex.: mês a mês desde 2022-01), guardando cada página antes de pedir a próxima e retomando do ponto em que parou. Antes, medir o total com `limit=1` (`resultSetMetadata.count`) para estimar o custo. A carga usa o teto da classe `ROTINA` (ADR-0009): disparada pelo administrador no dia da implantação (de preferência um domingo), continua no dia seguinte se não couber.
- **Lançamento pelo app:** gravar no cache logo após o `201`, com o corpo enviado e o `billId` do `Location` (0 requisição).
- **Incremental (observado):** `by-change-date` de 25 a 26/10/2026 → `count: 16`, mesmos campos do `GET /bills`; trouxe títulos de 2024 e 2025 com `changedDate` do dia e `changedBy` da Camilla (provavelmente baixas). Uso decidido: 1 chamada por semana, na rotina de domingo, desde a última execução (ADR-0010).
- **Títulos novos (decidido):** rotina de domingo e "Atualizar agora": `GET /bills?startDate=2018-01-01&endDate=hoje&limit=200&offset=count−200` (última página; pegar o `count` da própria resposta ou de uma chamada com `limit=1`), gravar os que não estão no banco e, se a página inteira for nova, pedir a anterior. Trava global de 5 minutos entre execuções sob demanda (`ATUALIZAR_TITULOS_INTERVALO_MIN`). API de dados em lote fora do orçamento.
- **Apropriações de título lançado direto no Sienge:** `GET /bills/{id}/budget-categories` (1 requisição por título novo), gravando em `titulos_sienge_apropriacoes`. Títulos do app gravam as apropriações no próprio lançamento.
- Guardar a resposta completa em `raw jsonb` e extrair para colunas: `id`, `debtorId`, `creditorId`, `documentIdentificationId` (trim), `documentNumber`, `issueDate`, `totalInvoiceAmount`, `originId`, `registeredBy`, `registeredDate`.
- **[spike]**: limites de período do `GET /bills` e do `by-change-date`; formato da resposta do `by-change-date`.

### Conferência de notas (lançamento já existente)

Para a nota que chega depois de um pagamento já lançado (SPEC RF30, RF31, RN23):
0. Buscar os títulos novos (última página do `GET /bills`, 1 requisição) e buscar no cache local; só usar a API diretamente se o cache ainda não tiver o período.
1. `GET /bills?startDate=&endDate=&creditorId=` com o período de emissão (da menor à maior data entre emissão da nota e pagamento, ± `CONFERENCIA_MARGEM_DIAS`, padrão 3). Paginar se `count` > 200 (raro para um credor).
2. Filtrar localmente por `totalInvoiceAmount` igual ao valor pago (tolerância 1 centavo).
3. Para cada candidato, `GET /bills/{billId}/attachments` só se o usuário abrir o detalhe (mostrar anexos atuais custa 1 requisição por título).
4. Anexar: `POST /bills/{billId}/attachments?description=DANFe` com o arquivo. **[spike]**: confirmar que anexar funciona em títulos lançados pela tela (origem `CP`); em títulos de origem `SE` o anexo é inserção, não alteração, e já é usado no fluxo normal.
5. Não alterar o título encontrado (nem tipo, nem número): a nota entra só como anexo.

A API **não autoriza parcelas**: todo título criado por ela nasce com "Autorizado: Não". A Camilla autoriza no Sienge antes da baixa — não procurar endpoint para isso.

## 6. Anexos — `POST /bills/{billId}/attachments`

- `multipart/form-data` com campo `file` (máx. 70 MB; nome do arquivo até 100 caracteres).
- `description` vai na **query string** (máx. 500 caracteres): `DANFe`, `NFSE`, `REC`, `PAG`, `REMB` ou `COMP`.
- Uma chamada por anexo, em sequência. Ao receber `201`, gravar `enviadoAoSiengeEm` no anexo **e só então** agendar a exclusão do arquivo no storage (job separado, com retry). Nunca apagar antes do `201`: se o envio falhar, o arquivo é necessário para o retry.
- A resposta do `201` não traz o ID do anexo **[spike]**; se for preciso, `GET /bills/{billId}/attachments` devolve `attachmentid`.
- Depois do lançamento o app não tem mais o arquivo. Para mostrar o comprovante a um aprovador, baixar sob demanda com `GET /bills/{billId}/attachments/{attachmentId}` (1 requisição) e exibir sem gravar.

```http
POST /bills/16720/attachments?description=DANFe
Content-Type: multipart/form-data; boundary=...

file=@33260928070499000122550010000030871000059038.pdf
```

`GET /bills/{billId}/attachments` → `results[]` com `attachmentid` (**i minúsculo**), `name`, `description`, `size`, `contentType` e `links[].href` (download). Nos títulos atuais a Camilla usa descrições livres (ex. `"14-10-26 - COMPROVANTE"`); o app padroniza em `DANFe`, `NFSE`, `REC`, `PAG`, `REMB`, `COMP`.

## 7. Idempotência e retentativas

Nunca repetir um `POST /bills` às cegas. Antes de cada retentativa:

1. Despesa já tem `billId`? Pular para os anexos.
2. Senão: `GET /bills?startDate={issueDate}&endDate={issueDate}&debtorId={empresa}&creditorId={credor}&documentNumber={numero}`. Encontrou com o mesmo `totalInvoiceAmount` → gravar o `id` e seguir para os anexos.
3. Anexos: `GET /bills/{billId}/attachments` → comparar por `name` e `description`; reenviar só os que faltam.

O Sienge também bloqueia número repetido para o mesmo credor quando o tipo de documento tem `blockDuplicateNumberForSameCreditor = true` (DANF tem "Bloquear numeração" na configuração) — um `400` por duplicidade deve ser tratado como "título já existe": buscar pela §7.2 em vez de marcar erro.

`GET /bills` exige `startDate` e `endDate` (emissão), pagina até 200 e devolve `status` de consistência (`S` completo, `N` incompleto, `I` em inclusão). Um título criado pelo app deve ficar `S`; `N`/`I` → aviso ao aprovador.

## 8. Corrigir um título já criado — pela tela do Sienge

Pelo mesmo bloqueio de títulos `SE`, **não** usar `PUT /bills/{billId}/budget-categories` (nem outros `PUT`/`PATCH`) para corrigir títulos criados pelo app. Erros depois do lançamento são corrigidos pela Camilla na tela do Sienge. Por isso a revisão antes de aprovar é a última chance de corrigir dados pelo app.

## 9. Título a partir de NF-e recebida — não usado

`POST /eletronic-invoice-bills` cria o título a partir de uma NF-e que o Sienge já recebeu da SEFAZ (corpo com `accessKeyNumber`, sem número, emissão e valor). **A empresa não recebe os XMLs automaticamente**, então este endpoint não se aplica. Reavaliar se a integração com a SEFAZ for ativada no futuro.

## Testes

- Mock HTTP (MSW/nock) com fixtures das respostas reais, sanitizadas.
- Casos obrigatórios: sucesso; título com 3 parcelas iguais; despesa com parcelas diferentes marcada "Ajustar parcelas no Sienge"; `429` com retry; timeout no `POST /bills` seguido de `GET /bills` que encontra o título; `400` de número duplicado; falha no anexo após título criado; credor inexistente; percentuais de rateio (365,55 → 50/50; 490,80 → 390,80 + 100,00); cota esgotada.

## A confirmar no spike

- [x] Autenticação.
- [x] `stateRegistrationType`: `N` não contribuinte (`C`, `I`, `N`).
- [x] `billDate` = data de competência (campo "Data contábil").
- [x] `paymentCategoriesId` = código sem pontos; `tpConta` `T`/`R`.
- [x] O Sienge não recebe NF-e automaticamente (§9 descartado; teste retornou 400).
- [x] `typesId`: `FO` fornecedor, `FU` colaborador, `CO` corretor.
- [x] ID do `POST /bills`: header `Location`, corpo vazio.
- [x] ID do `POST /creditors`: header `Location`, corpo vazio.
- [x] `PATCH /creditors/{id}` funciona em credor criado pela API.
- [x] `stateRegistrationNumber`: vazio recusado; `"ISENTO"` aceito no POST; `" "` aceito no PATCH.
- [x] `stateRegistrationNumber: " "` diretamente no `POST` (aceito; o plano B com `"ISENTO"` foi removido).
- [x] Parcelas criadas pela API saem com **Autorizado = Não** e são autorizadas manualmente no Sienge (comportamento aceito).
- [x] `notes` vazio é recusado; `" "` é aceito.
- [x] `situation`: `"Não paga"` / `"Totalmente paga"`.
- [ ] Onde fica o centavo de sobra na divisão automática das parcelas.
- [ ] Anexar arquivo em título lançado pela tela (origem `CP`), usado na conferência de notas.
- [ ] Dar baixa altera o `changedDate` do título (otimização da conferência de baixas)?
- [ ] Limites de período do `GET /bills` e do `GET /bills/by-change-date`.
- [x] `documentIdentificationId` aceito sem os espaços de preenchimento (`"DANF"` no título 17120).
- [x] `requireUnitOnPayable` e `blockDueDate` não impediram o `POST /bills` do DANF (título 17120 criado com consistência completa e sem unidade).
- [ ] Precisão aceita em `percentage`.
- [x] `PATCH /bills/{billId}/installments` em título criado pela API → bloqueado (origem `SE`).
- [ ] Valores de `type`/`defaultFlag` do Pix.

## Descobertas

### 06/11/2026 — inscrição estadual no POST /creditors
- `POST /creditors` com `"stateRegistrationNumber": " "` (um espaço) e `stateRegistrationType "N"` → aceito, com a inscrição em branco no cadastro (confirmado pela equipe). O cadastro de credor custa 1 requisição; não é mais preciso criar com `"ISENTO"` e depois fazer `PATCH`.

### 23/10/2026 — POST /creditors
- Sem o campo `stateRegistrationNumber` → `400`: "Número de inscrição estadual não informado."
- Com `"stateRegistrationNumber": ""` → **o mesmo `400`**. A API exige um número de inscrição estadual não vazio, embora credores pessoa jurídica cadastrados pela tela como "Não contribuinte" tenham o campo vazio (ex.: credor 125, `stateRegistrationNumber ""`, `stateRegistrationType "N"`). Com `"stateRegistrationNumber": "ISENTO"` → **`201`**, credor 2404 criado; o ID vem no header `Location` (`.../creditors/2404`), corpo vazio.
- `PATCH /creditors/2404` com `{"stateRegistrationNumber": " "}` → `204`; o `GET` devolve `"stateRegistrationNumber": " "`, `stateRegistrationType "N"`, `supplier "S"`, `tradeName null`, `zipCode` como enviado (`"03139010"`), `cityId 3` → `cityName "São Paulo"`.
- Conferido na tela do Sienge (credor 2404): Fornecedor, Pessoa jurídica, inscrição estadual em branco com "Não contribuinte", município 3 – SP – São Paulo, CEP exibido formatado (03139-010), **consistência do registro: Completo**. Fluxo `POST` + `PATCH` de credor validado de ponta a ponta.

### 21/10/2026 — PATCH de parcelas (título 17120)
- `PATCH /bills/17120/installments` → `400`: "O Título com origem no SE não pode ser alterado para chamadas do SE." Títulos criados pela API (`originId "SE"`, `registeredUserId "SIENGEAPI"`) não aceitam alteração pela API.
- `GET /bills/17120/installments`: `situation "Não paga"`, `billDate` da parcela = `billDate` do título.
- `GET /bills/17120`: `status "S"` (completo), `originId "SE"`, `registeredBy "Sienge Api"`.

### 21/10/2026 — primeiro título criado pela API (17120)
- `POST /bills` → `201` em ~1,3 s, corpo `null`, header `location: .../bills/17120`. Tentativas anteriores com `notes: ""` foram recusadas; `notes: " "` foi aceito.
- Parcelas criadas pela API sempre ficam "Autorizado: Não"; a Camilla autoriza manualmente.
- Empresa 3, 3 parcelas, total 17.214,96: o Sienge gerou 3 × 5.738,32, vencimentos 19/11/2026, 19/12/2026, 19/01/2027, data base 01/10/2026, situação `NP`, **Autorizado: Não** em todas.

### 21/10/2026 — aba Model do `POST /creditors` e unidades
- `typesId`: `CO` corretor, `FO` fornecedor, `FU` colaborador.
- `GET /bills/16720/units` → `404 Resource not found` (título sem unidade, consistência "Completo"): a flag `requireUnitOnPayable` não parece exigir unidade nos títulos da empresa; confirmar no `POST /bills`.

### 20/10/2026 — consultas GET reais (respostas anonimizadas)
- Tempo de resposta típico: 150–600 ms.
- `GET /companies`: 5 empresas; nomes com espaço no fim.
- `GET /cost-centers`: 220, ordem decrescente de id, nenhum sem empresa.
- `GET /payment-categories`: array na raiz, 987 itens, `id` = código sem pontos.
- `GET /document-identifications`: 85; lista usa `documentIdentificationId`, detalhe usa `id`; códigos com 4 caracteres preenchidos com espaço. Flags do DANF na §1.
- `GET /creditors?cnpj=`: documento, CEP formatados; razão social pode diferir do nome comercial.
- `GET /bills?startDate=&endDate=`: `resultSetMetadata.count`; `documentNumber` livre (`003.087`, `14/09`, `Agrofest 2026`); `accessKeyNumber` nulo nos títulos da Camilla; `originId` `CP`.
- `GET /bills/{id}`: inclui `links` para installments, taxes, budget-categories, company, creditor.
- `GET /bills/{id}/budget-categories`: `percentage` numérico (`50`), `paymentCategoriesId` sem pontos.
- `GET /bills/{id}/installments`: `installmentNumber`, `situation` (`"Totalmente paga"`).
- `GET /bills/{id}/attachments`: `attachmentid` minúsculo.
- `POST /eletronic-invoice-bills` com NF-e não recebida → `400`.

### 20/10/2026 — primeiros testes reais e parcelas
- Autenticação funcionando com o usuário de API.
- `GET /creditors` (colaboradora existente): `supplier "N"`, `broker "N"`, `employee "S"`, `stateRegistrationType "N"`, `stateRegistrationNumber ""`, `cpf` **formatado com pontos e traço**, `cnpj null`, `address` com `cityId`, `cityName`, `state`; `links[].href` no formato `/sienge/api/v1/creditors/{id}/bank-informations`.
- `PATCH /bills/{billId}/installments`: array com `installmentId`, `dueDate`, `amount`, `interestAmount`, `fineAmount`, `monetaryCorrectionAmount`, `discountAmount`; atômico; `204`.
- A empresa não recebe XMLs de NF-e: `POST /eletronic-invoice-bills` descartado.

### 20/10/2026 — documentação oficial (prints e corpos enviados pelo Ronald)
Endpoints, corpos e parâmetros desta skill vieram da documentação oficial (`api.sienge.com.br/docs`). Confirmado: base URL; corpos de `POST /bills`, `POST /eletronic-invoice-bills`, `PUT budget-categories`, `POST /creditors`, `PATCH /creditors/{id}`, `POST pix-informations`; parâmetros de `GET /bills`, `GET /bills/by-change-date`, `GET /creditors`, `GET /cost-centers`, `GET /companies`, `GET /payment-categories`, `GET /document-identifications`, anexos; formato de erro; não existe baixa via API.

### 13/10/2026 — telas do Sienge
- Título: Documento*, Chave de acesso NF-e, Número* (como impresso, ex. `003.072.580`), Empresa*, Credor*, Emissão*, Observação, Valor total*, Parcelas*, Desconto, Data contábil*, Indexador* (0 REAL), Data base*, 1º vencimento*.
- Rateio 50/50 de 365,55 → 182,78 + 182,77 (centavo extra na 1ª linha).
- Anexos: Descrição* + Arquivo*; PDF do DANFE nomeado com a chave.
- Credor: tipo*, pessoa*, documento*, razão social*, município*; inscrição estadual sempre "Não contribuinte".

### 13/10/2026 — autenticação
- Primeiro teste deu `401 Invalid authentication credentials`: era credencial incorreta (usuário/senha), não formato de URL nem de usuário. Resolvido em 20/10/2026.
