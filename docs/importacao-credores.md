# Importação de credores (arquivo exportado do Sienge)

Referências: SPEC RN25, `docs/modelagem/02-modelo-er.md` (tabela `credores`), `features/configuracoes.feature`.

## Arquivo usado

**"Relatório de Credores" detalhado**, exportado do Sienge em PDF (gerado pelo iText): **uma página por credor**, campos com rótulo à esquerda e valor à direita. O relatório resumido (tabela com várias linhas por credor e nomes quebrados em mais de uma linha) **não** é usado: é menos confiável de ler e não traz o nome fantasia.

Amostra para testes: `data/fixtures/relatorio-credores-detalhado-amostra.pdf` (3 páginas: credores 1, 9 e 125, todos pessoa jurídica).

## Resultado da leitura do arquivo real (28/10/2026)

| Verificação | Resultado |
|---|---|
| Páginas / credores | 2.341 / 2.341 (ids de 1 a 2406, sem repetição) |
| Pessoa jurídica / física | 1.910 com CNPJ / 431 com CPF |
| Documento com dígito verificador válido | 2.341 (100%) |
| Documento repetido | nenhum |
| Município encontrado em `data/municipios-sienge.csv` (nome sem acento + UF) | 2.341 (100%) |
| Com nome fantasia | 1.267 (54%) |
| Tipo de credor | `Forn.` (2.325) e `Forn. Col.` (16) |

## Como ler cada página

Texto extraído com `pdftotext -layout` (ou equivalente), página por página. Campos:

| Rótulo no PDF | Exemplo | Coluna em `credores` | Regra |
|---|---|---|---|
| `Credor N - NOME` | `Credor 125 - FN TAG MATERIAIS EIRELI` | `id` = N, `nome` | Linha do título da página; obrigatória |
| `Tipo de Credor` | `Forn. Col.` | `fornecedor`, `colaborador`, `corretor` | `Forn.` → fornecedor; `Col.` → colaborador; `Corr.` → corretor (pode ter mais de um) |
| `Nome Fantasia` | `FN DO BRASIL OFFSHORE` | `nome_fantasia` | Vazio → nulo |
| `CNPJ` ou `CPF` | `28.070.499/0001-22` | `documento`, `tipo_pessoa` | CNPJ → `J`; CPF → `F`; guardar sem pontuação |
| `I.E.` | `252510690` | `raw` | Só informativo |
| `Endereço`, `Bairro` | `RODOVIA AMARAL PEIXOTO, SN, LOJA 03 E 04` | `raw` | Só informativo |
| `Município` | `Rio das Ostras/RJ` | `municipio_id` | Casar nome sem acento e UF com o CSV de municípios |
| `CEP` | `28895-600` | `raw` | Mesma linha do município, à direita |
| `Telefone`, `Email` | | — | Não guardar (não são usados pelo app) |

Regras gerais:
- **Upsert pelo `id`** do Sienge. Reenviar o arquivo atualiza os existentes e inclui os novos; credores que estavam no banco e não vieram no arquivo **não** são apagados.
- `origem_carga = 'ARQUIVO'`; `raw` guarda os campos lidos da página.
- A importação é **tudo ou nada**: se alguma página não tiver a linha `Credor N - NOME` ou um documento válido, nada é gravado e a tela mostra as páginas com problema.
- Nomes vêm como cadastrados no Sienge (a maioria em maiúsculas e sem acento, mas há exceções, como o credor 2404); gravar como vieram.
- Tempo esperado: alguns segundos para as 2.341 páginas; processar no worker, não na requisição da tela.

## Ponto a confirmar

O relatório não mostra se o credor está **ativo ou desativado**. Se credores desativados vierem no arquivo e forem escolhidos numa despesa, o Sienge recusa o título ("Credor desativado", tela de Erros). Confirmar com a Camilla se o relatório permite filtrar só os ativos; se permitir, exportar sempre com esse filtro.
