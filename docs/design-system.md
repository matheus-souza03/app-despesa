# Design system — App de Despesas Senco

Extraído dos wireframes aprovados (`docs/telas/`). É a referência para montar a interface (Tailwind + shadcn/ui, conforme o CLAUDE.md). Quando uma tela e este documento divergirem, vale este documento.

## Marca

- **Cores da marca:** azul Midnight `#211261` (Pantone 2755 C), amarelo Sunglow `#FFC844` (Pantone 1225 C) e branco.
- **Logo:** `assets/marca/logo-senco-*.png` (anel amarelo, fundo transparente; 32, 96, 192 e 512 px; original em `logo-senco-original.png`). Sempre à esquerda do cabeçalho: no celular, antes do título (depois da seta de voltar, quando houver); no computador, antes do nome "Despesas", sobre o azul.
- **Faixa de sinalização** (listras diagonais azul e amarelo, 8 px de altura): só na tela inicial "Nova despesa" do celular e no login. Não usar em outras telas.

## Cores

| Token | Valor | Uso |
|---|---|---|
| `primaria` | `#211261` | Títulos, botões principais, cabeçalho do computador, texto sobre amarelo |
| `primaria-hover` | `#3A2A8C` | Hover de link e botão principal |
| `destaque` | `#FFC844` | Botão de escanear/ler código, aba ativa (sublinhado de 3 px), indicador da navegação inferior, badge de contagem no cabeçalho, botão "Nova despesa" do financeiro |
| `texto` | `#1D1A33` | Texto do corpo |
| `texto-suave` | `#5B5876` | Rótulos, metadados, legendas |
| `texto-cabecalho` | `#D9D6EE` | Abas inativas sobre o azul |
| `fundo-pagina` | `#F6F5FA` | Fundo das páginas do computador e áreas neutras |
| `superficie` | `#FFFFFF` | Cartões, campos, celular |
| `borda` | `#E3E1EC` | Bordas de cartões e divisões principais |
| `borda-campo` | `#CFCCDA` | Borda de campos e botões não selecionados |
| `divisoria` | `#EEEDF3` | Linhas entre itens de lista e tabela |
| `selecionado` | `#EEEDF7` | Fundo de item selecionado, opção marcada, pílula "Em análise" |
| `sucesso` / `sucesso-fundo` | `#0E6245` / `#E5F4EE` | "Lido do código", saldo zerado, "Lançada", aviso verde (fundo sólido `#0E6245` com texto branco) |
| `erro` / `erro-fundo` | `#A4251B` / `#FDECEA` | Devolvida, erro, mensagem do Sienge, "Sair" |
| `alerta-texto` / `alerta-fundo` | `#5C3D00` / `#FFF4D6` | Avisos (credor não cadastrado, parcelas diferentes, pagamento já lançado, lembrete de autorizar) |
| `alerta-destaque` | `#7A5200` | Avisos curtos em listas e campos alterados ("Alterado · antes: …") |

Regras de contraste: o amarelo **nunca** é cor de texto sobre branco; sobre o amarelo o texto é sempre o azul. O texto suave (`#5B5876`) passa 4,5:1 sobre branco e sobre `fundo-pagina`.

## Tipografia

- Fonte: **Barlow** (Google Fonts), pesos 400, 500 e 600. Números com `font-variant-numeric: tabular-nums` (valores alinhados).
- Três tamanhos por superfície:

| Superfície | Título | Corpo | Pequeno |
|---|---|---|---|
| Celular | 22 px / 600 | 16 px | 13 px |
| Computador | 24 px / 600 | 15 px | 13 px |

- Rótulos de campo: 13 px / 500. Títulos de seção: tamanho do corpo / 600, cor `primaria`.

## Espaçamento, raios e tamanhos

- Escala de espaçamento: 4, 6, 8, 12, 16, 20, 24, 32, 48 px. Margem lateral: 20 px no celular, 32 px no computador (conteúdo com largura máxima de 1280–1440 px).
- Raios: campos 8 px; botões 10 px; cartões 12 px; pílulas 999 px.
- Alturas: campos 48 px (celular) e 44 px (computador); botão principal 52 px (celular, rodapé) e 48 px (computador); botões secundários 44–48 px. **Alvos de toque com no mínimo 44 px.**

## Componentes

| Componente | Como é |
|---|---|
| Cabeçalho do celular | Branco; logo + título 22 px à esquerda; avatar circular azul (44 px, iniciais brancas) à direita; nas telas internas, seta de voltar antes do logo e botão amarelo "Escanear" à direita |
| Navegação inferior (celular) | 3 itens (Nova despesa, Status, Meu usuário), 64 px de altura, ícone + rótulo 13 px; o ativo em azul com barra amarela de 3 px no topo |
| Cabeçalho do computador | Faixa azul de 64 px; logo + "Despesas · <área>"; abas com sublinhado amarelo na ativa e contagem em badge amarelo; à direita, botão amarelo "Nova despesa" (financeiro), link "Administração" e avatar branco |
| Botão principal | Fundo azul, texto branco, 600; um por tela |
| Botão de leitura de código | Fundo amarelo, texto azul, 600, ícone de código de barras |
| Botão secundário | Borda azul de 1,5 px, fundo branco, texto azul |
| Campo | Borda `borda-campo`, raio 8, rótulo acima; "Lido do código" em verde abaixo ou ao lado do rótulo |
| Opções (rádio em cartão) | Cartões com borda; o selecionado com borda azul de 2 px e fundo `selecionado` |
| Seção recolhida | Linha de 64 px com título 600, situação ("Falta preencher") e seta |
| Aviso | Caixa `alerta-fundo`, título 600 + texto 13 px em `alerta-texto`; sem borda lateral colorida |
| Pílula de situação | Texto 13 px / 500 sobre o fundo claro da mesma família (Em análise, Devolvida, Lançada) |
| Lista e detalhe | Lista à esquerda (≈ 340–420 px), detalhe à direita; o item aberto com fundo `selecionado` |
| Tabela | Cabeçalho 13 px em `texto-suave`, linhas com `divisoria`; números alinhados à direita; total em rodapé com borda superior azul de 2 px |
| Aviso de lançamento | Canto inferior direito, 400 px, fundo verde sólido, texto branco, ícone de confirmação e botão de ícone para copiar o número do título; empilha; some em 15 s |
| Editável em destaque | Área com borda azul de 2 px e o rótulo "Editável" (apropriação na tela do aprovador de CC) |

## Ícones e acessibilidade

- Ícones de traço (24×24, traço 2), como Lucide; nunca emoji. Ícone sem texto tem `aria-label`.
- Elementos reais de formulário (`button`, `a`, `input` + `label`), mesmo em listas; avisos com `role="status"`.
- As páginas do computador precisam funcionar em largura de celular: menus quebram linha, tabelas largas rolam dentro de uma caixa.
