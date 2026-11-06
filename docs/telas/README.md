# Telas (wireframes aprovados)

Imagens exportadas do canvas de wireframes em 06/11/2026, já com os ajustes pedidos pela equipe (perfis de rua e escritório, aprovador de centro de custo, filtro por centro de custo nos títulos, planos financeiros liberados). Os dados nas telas são exemplos. Visual e componentes: `docs/design-system.md`.

A pasta `fonte/` tem o HTML de cada tela (`.dc.html`) e o `canvas.json` do canvas. Eles dependem do runtime do canvas para abrir, mas servem para consultar medidas, cores e textos exatos: os estilos estão escritos no próprio elemento (`style="…"`).

## Colaborador — celular (390 px de largura)

| Imagem | Tela | Perfis | Referências |
|---|---|---|---|
| `celular/01-entrar.png` | Entrar | Todos | RF01 · `login.feature` |
| `celular/02-nova-despesa.png` | Nova despesa (escanear, digitar, importar) | Todos | RF06 · `cadastro-titulo.feature` |
| `celular/03-nota-lida-credor-nao-cadastrado.png` | Nota lida, credor não cadastrado | Todos | RF06–RF09, RF16 · `cadastro-titulo.feature` |
| `celular/04-nota-e-boletos-lidos.png` | Nota e 3 boletos lidos, com rateio | Escritório, aprovador de CC, aprovador | RF09–RF15, §7.2 · `cadastro-titulo.feature` |
| `celular/05-nova-despesa-colaborador-de-rua.png` | Nova despesa sem apropriação | Colaborador de rua | RN27 · `definir-centro-custo.feature` |
| `celular/06-status-das-despesas.png` | Status das despesas | Todos | RF23 · `status-despesas.feature` |
| `celular/07-cadastrar-credor.png` | Cadastrar credor | Todos | RF16–RF18 · `cadastro-credor.feature` |
| `celular/08-meu-usuario.png` | Meu usuário | Todos | RF28 · `meu-usuario.feature` |

## Colaborador — computador (página fluida, preview em 1440 px)

| Imagem | Tela | Perfis | Referências |
|---|---|---|---|
| `computador-colaborador/01-nova-despesa.png` | Nova despesa com painel de comprovantes e aviso de pagamento já lançado | Todos | RF31, RF32 · `cadastro-titulo.feature`, `conferencia-notas.feature` |
| `computador-colaborador/02-status-das-despesas.png` | Status das despesas (lista e detalhe) | Todos | RF23 · `status-despesas.feature` |
| `computador-colaborador/03-importar-planilha.png` | Importar planilha, com centro de custo escolhido pelo texto | Todos (rua: sem centro de custo) | §9, RN24 · `cadastro-titulo.feature` |

## Aprovador de centro de custo — computador

| Imagem | Tela | Perfis | Referências |
|---|---|---|---|
| `aprovador-cc/01-definir-centro-de-custo.png` | Definir centro de custo (só apropriações editáveis) | Aprovador de CC | RF36, RN27 · `definir-centro-custo.feature` |

## Financeiro — computador

No cabeçalho do financeiro, as abas são: Aprovação, Títulos, Conferência, Baixas pendentes, Faturas a vencer, Erros e Planos financeiros.

| Imagem | Tela | Perfis | Referências |
|---|---|---|---|
| `financeiro/01-aprovacao.png` | Aprovação (com o aviso verde do título lançado) | Aprovador | RF20–RF22, RF33 · `aprovacao-titulo.feature`, `consulta-titulos.feature` |
| `financeiro/02-aprovacao-editando.png` | Aprovação editando a despesa na própria tela | Aprovador | RF21 · `aprovacao-titulo.feature` |
| `financeiro/03-erros-no-lancamento.png` | Erros no lançamento | Aprovador | T15–T19 · `aprovacao-titulo.feature`, `integracao-sienge.feature` |
| `financeiro/04-titulos.png` | Títulos, filtrado por centro de custo, com total | Aprovador | RF35, RN25, RN28 · `consulta-titulos.feature` |
| `financeiro/05-conferencia-titulo-encontrado.png` | Conferência de notas: título encontrado | Aprovador | RF30, RN23 · `conferencia-notas.feature` |
| `financeiro/06-conferencia-nada-encontrado.png` | Conferência de notas: nada encontrado | Aprovador | RF30 · `conferencia-notas.feature` |
| `financeiro/07-baixas-pendentes.png` | Baixas pendentes | Aprovador | RF29, RN20 · `baixas-pendentes.feature` |
| `financeiro/08-faturas-a-vencer.png` | Faturas a vencer, com parcelas a ajustar | Aprovador | RF13 · `aprovacao-titulo.feature` |
| `financeiro/09-planos-financeiros.png` | Planos financeiros liberados no app (adicionar do Sienge, importar lista, tirar do app) | Aprovador e aprovador de CC (no cabeçalho do aprovador de CC, a aba "Planos financeiros" leva à mesma tela) | RN08, RF37 · `planos-financeiros.feature` |

## Administração — computador

| Imagem | Tela | Perfis | Referências |
|---|---|---|---|
| `administracao/01-usuarios.png` | Usuários (perfis e centros de custo liberados) | Administrador | RF02–RF05 · `gestao-usuarios.feature` |
| `administracao/02-configuracoes.png` | Configurações | Administrador | RNF, RN07, RN20 · `configuracoes.feature` |

## Telas que ainda não têm wireframe

Ver `PENDENCIAS.md` (seção "Wireframes que faltam"): lixeira, envio dos arquivos do Sienge em Configurações, botão "Resolvido no Sienge" em Erros, grupo "Aguardando centro de custo" no Status, recuperação de senha e os avisos vermelho e amarelo de lançamento.
