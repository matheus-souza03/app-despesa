# Painel de gastos por centro de custo — Power BI

Fonte dos dados: relatório **"Contas pagas com apropriações"** do Sienge, exportado em Excel (`cpg_contas_pagas_apropriacoes_*.xlsx`).

| Arquivo | Para quê |
|---|---|
| `1-consulta-pagamentos.pq` | Consulta do Power Query que lê **todos** os relatórios de uma pasta |
| `2-tabela-e-medidas.dax` | Tabela de datas e as medidas do painel |
| `3-tema-senco.json` | Tema com as cores da Senco (azul `#211261` e amarelo `#FFC844`) |
| `4-logo-senco.png` | Logo para o cabeçalho do painel |

## 1. Pasta dos relatórios (uma vez)

Crie uma pasta, por exemplo `C:\Relatorios Sienge\Contas pagas`, e salve nela os relatórios exportados do Sienge. Pode ter vários arquivos (um por ano, por mês…): o painel junta todos. Períodos repetidos entre arquivos não duplicam valores, porque cada linha do relatório tem uma chave única (coluna `BAIXA`).

## 2. Carregar os dados (uma vez)

1. Abra o Power BI Desktop e salve o arquivo novo (ex.: `Gastos por centro de custo.pbix`).
2. **Página Inicial > Transformar dados** para abrir o Power Query.
3. **Gerenciar parâmetros > Novo parâmetro**: nome `PastaRelatorios`, tipo **Texto**, valor atual = o caminho da pasta do passo 1.
4. **Nova fonte > Consulta nula**. Renomeie a consulta para `Pagamentos`.
5. **Editor avançado**: apague o conteúdo, cole todo o arquivo `1-consulta-pagamentos.pq` e confirme.
6. **Fechar e aplicar**.

A consulta corrige a acentuação quebrada que vem no relatório ("SOLUÃ‡Ã•ES" vira "SOLUÇÕES") e **não importa** CPF, dados bancários nem observações.

## 3. Tema da Senco (uma vez)

**Exibir > Temas > Procurar temas** e escolha `3-tema-senco.json`. O azul vira a cor principal dos gráficos e o amarelo, a segunda.

## 4. Tabela de datas e medidas (uma vez)

Siga os comentários do `2-tabela-e-medidas.dax`:
1. **Modelagem > Nova tabela**: cole a tabela `Calendario`.
2. Marque `Calendario` como tabela de datas (coluna `Date`) e, na **Exibição de modelo**, ligue `Calendario[Date]` a `Pagamentos[Data do pagamento]`.
3. Em `Calendario[Mês]`, **Classificar por coluna > Mês ordem**.
4. Crie as 6 medidas (Total gasto, Títulos pagos, Média por título, Gasto no mês anterior, Variação no mês e Participação no total).
5. Formate `Total gasto`, `Média por título` e `Gasto no mês anterior` como moeda (R$), e `Variação no mês` e `Participação no total` como porcentagem.

## 5. Montar a página (tela 16:9, 1280 × 720)

| Área | Visual | Campos | Posição (x, y, largura × altura) |
|---|---|---|---|
| Cabeçalho | Retângulo azul `#211261`, imagem `4-logo-senco.png` e caixa de texto "Gastos por centro de custo" em branco | — | 0, 0, 1280 × 64 |
| Filtros | Segmentação **Lista suspensa com pesquisa** | `Pagamentos[Centro de custo]` | 16, 80, 360 × 56 |
| | Segmentação **Entre** (controle deslizante) | `Calendario[Date]` | 392, 80, 300 × 56 |
| | Segmentação lista suspensa | `Pagamentos[Empresa]` | 708, 80, 260 × 56 |
| | Segmentação lista suspensa | `Pagamentos[Origem]` (contas a pagar / folha) | 984, 80, 280 × 56 |
| Indicadores | 4 **Cartões** | Total gasto · Títulos pagos · Média por título · Variação no mês | y = 152, altura 96, larguras de 304 com 12 de espaço |
| Gráfico 1 | **Colunas** "Gasto por mês" | Eixo `Calendario[Mês]`, valor `Total gasto`, rótulos de dados ligados | 16, 260, 760 × 220 |
| Gráfico 2 | **Barras** "Maiores centros de custo" | Eixo `Pagamentos[Centro de custo]`, valor `Total gasto`; filtro do visual **N superior = 10**; cor das barras amarela `#FFC844` | 788, 260, 476 × 220 |
| Gráfico 3 | **Barras** "Por plano financeiro" | Eixo `Pagamentos[Plano financeiro]`, valor `Total gasto`, dica de ferramenta `Participação no total` | 16, 492, 460 × 212 |
| Detalhe | **Tabela** "Pagamentos" | Data do pagamento, Título, Credor, Plano financeiro, Centro de custo, Valor pago | 488, 492, 776 × 212 |

Dicas:
- No cartão **Variação no mês**, use **Formatação condicional > Cor da fonte** por regra: abaixo de 0 em verde `#0E6245` (gastou menos), acima de 0 em vermelho `#A4251B`. Ele só faz sentido com um mês selecionado.
- Clicar numa barra ou coluna filtra os outros visuais: escolher um centro de custo no gráfico 2 mostra o gasto mensal e os planos só dele.
- Para não ver a folha de pagamento junto com as compras, escolha "Contas a pagar" no filtro **Origem**.

## 6. Atualizar com dados novos (sempre que quiser)

1. Exporte do Sienge um novo relatório "Contas pagas com apropriações" (o período pode se sobrepor ao dos anteriores).
2. Salve o arquivo na mesma pasta.
3. No Power BI, **Página Inicial > Atualizar**.

## O que os números significam

- **Valor pago** é o valor efetivamente pago (líquido) já dividido pelo rateio: um pagamento de R$ 587,14 rateado 30% e 70% entra como R$ 176,14 num centro de custo e R$ 411,00 no outro.
- O painel olha a **data do pagamento**, ou seja, o que saiu do caixa em cada período. Títulos ainda não pagos não aparecem, porque não estão neste relatório.
- Publicação no Power BI Online com atualização automática exige que a pasta esteja no OneDrive ou SharePoint, ou um gateway instalado no computador da pasta.
