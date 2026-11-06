# Importação do rateio dos títulos (relatório de contas pagas com apropriações)

Referências: SPEC RN28, `docs/modelagem/02-modelo-er.md` (tabela `titulos_sienge_apropriacoes`).

## Para que serve

A API traz os títulos sem o centro de custo, e buscar o rateio título por título (`GET /bills/{id}/budget-categories`) custaria uma requisição por título. O histórico (cerca de 16,5 mil títulos) vem deste relatório exportado do Sienge, sem gastar requisições.

## Arquivo

Relatório **"Contas pagas com apropriações"**, exportado do Sienge em Excel (`cpg_contas_pagas_apropriacoes_*.xlsx`), com 99 colunas e uma linha por **pagamento × centro de custo × plano financeiro**. Um título rateado em dois centros de custo e pago em três parcelas gera seis linhas.

Amostra para testes, sem dados pessoais: `data/fixtures/contas-pagas-apropriacoes-amostra.xlsx` (6 linhas; inclui o título 16913, rateado em 30% e 70%).

## Colunas usadas

| Coluna | Exemplo | Uso |
|---|---|---|
| `numeroTitulo` | 16913 | Título (`titulos_sienge.id`) |
| `numeroParcela`, `numeroSequencialBaixa` | 1, 1 | Identificam o pagamento; servem só para conferir |
| `codigoCentroCusto` | 34 | `centro_custo_id` |
| `codigoPlanoFinanceiro` | `2.01.01.94` | `plano_financeiro_id`, gravado sem pontos (`2010194`) |
| `percentualApropriado` | 30 | `percentual` |
| `codigoEmpresa`, `codigoCredor`, `dataEmissao`, `valorTotalTituloOuMovimento`, `origemMovimento` | 1, 242, 2026-10-01, 587,14, `CP` | Conferência com o título no cache; se o título ainda não estiver no cache, criar o cabeçalho com esses dados |
| `valorPagamentoBruto` | 176,142 | Só para conferir: é o valor pago na parcela × percentual |

As outras colunas não são gravadas. Em especial, **não** guardar `cpfCredor`, `nomeCredor`, observações nem dados bancários: os credores vêm da importação de credores e o resto não é usado pelo app.

## Regras

- Para cada título, as apropriações são as combinações distintas de (`codigoCentroCusto`, `codigoPlanoFinanceiro`, `percentualApropriado`). O percentual é o mesmo em todas as parcelas do título (confirmado no arquivo de exemplo); se não for, a importação marca o título como inconsistente e não grava o rateio dele.
- A soma dos percentuais de cada pagamento deve dar 100 (confirmado no arquivo de exemplo).
- `valor` em `titulos_sienge_apropriacoes` = valor total do título × percentual ÷ 100, com `origem = 'RELATORIO'`.
- Títulos que já têm rateio gravado pelo app (`origem = 'APP'`) não são sobrescritos.
- Reenviar um arquivo com períodos que se sobrepõem é seguro: o rateio de cada título é substituído pelo do arquivo (upsert por título).
- Os textos do arquivo chegam com acentuação quebrada (`SOLUÃ‡Ã•ES` em vez de `SOLUÇÕES`): como só os códigos são usados, isso não afeta a importação.

## Limitações

- O relatório só traz títulos **pagos** no período escolhido. Títulos ainda em aberto não aparecem. **[a confirmar]** se existe o mesmo relatório para contas a pagar em aberto; senão, o rateio dos títulos em aberto lançados direto no Sienge vem por `GET /bills/{id}/budget-categories`.
- Um título pago parcialmente aparece só com as parcelas já pagas, mas o percentual é o mesmo; o rateio fica correto.
