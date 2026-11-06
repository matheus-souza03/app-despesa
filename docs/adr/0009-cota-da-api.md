# ADR-0009 — Cota da API: prioridade por tipo, lançamentos no dia seguinte e rotinas aos domingos

- Situação: Aceita (06/11/2026). Substitui a regra "pausar a fila em 90%" da skill `sienge-api` e a `reserva_cota_sincronizacao` do modelo.

## Contexto

O pacote contratado é de 100 requisições por dia. Um lançamento gasta cerca de 2 (título + 1 anexo, mais 1 por anexo extra). A demanda estimada é de cerca de 66 lançamentos por dia, e a capacidade, de 40 a 45. Domingo normalmente não tem lançamentos.

## Decisão

1. **Reserva antes da chamada.** Toda chamada reserva a cota antes, de forma atômica, em `cota_diaria`: `update … set usadas = usadas + n where dia = $1 and usadas + n <= teto returning usadas`. Sem linha retornada, a chamada não é feita. O dia de cota é o dia civil de São Paulo (a confirmar com a Softplan quando o contador do Sienge reinicia).
2. **Três classes**, nesta ordem de prioridade:

   | Classe | O que entra | Teto do dia |
   |---|---|---|
   | `PESSOA` | Alguém esperando na tela: buscar credor fora do cache, criar credor, conferência de notas, "Atualizar agora", "Parcelas ajustadas", "Sincronizar agora", abrir comprovante no Sienge | `limite` |
   | `LANCAMENTO` | Worker: `POST /bills`, anexos, busca de idempotência, criação de credor que ficou pendente | `limite − cota_reserva_pessoas` (padrão 10) |
   | `ROTINA` | Worker, **só no dia das rotinas** (domingo): cadastros, títulos novos, `by-change-date`, credores desconhecidos, rateio de títulos lançados direto no Sienge | `limite − cota_reserva_pessoas` |

3. **Lançamento que não cabe fica guardado para o dia seguinte.** A despesa continua `APROVADA`, com `aguardando_cota_desde` e o aviso amarelo "Será lançada amanhã". O job é reagendado para o início do próximo dia de cota e sai na ordem de aprovação, antes dos novos. Esperar cota não conta como tentativa.
4. **De segunda a sábado, nenhuma rotina automática chama o Sienge.** As rotinas locais (lixeira de 30 dias, arquivos órfãos) rodam todo dia, porque não gastam cota.
5. **Ordem no domingo** (dia configurável em `rotinas_dia_semana`, padrão 0):
   1. Rotinas curtas, garantidas: cadastros (~5), títulos novos (1 a 3), `by-change-date` (1) e credores desconhecidos encontrados neles. A fila de lançamentos só é liberada depois delas.
   2. A fila de lançamentos acumulada.
   3. Com o que sobrar: rateio dos títulos lançados direto no Sienge (`GET /bills/{id}/budget-categories`, 1 por título). O que não couber continua no domingo seguinte, pelo cursor.
6. **Carga inicial dos títulos** (~83 requisições): disparada pelo administrador no dia da implantação, de preferência num domingo, com o teto de `ROTINA`. Se não terminar, continua no dia seguinte a partir do cursor. É a única exceção à regra do domingo, por ser única e anterior ao uso.
7. **Baixas na v1:** "Já dei baixa", depois de uma confirmação, só registra no app (`baixa_confirmada_em`, `baixa_confirmada_por_id` e o evento `BAIXA_CONFIRMADA`), **sem consultar o Sienge** (0 requisição). A conferência pelas parcelas (RN20 original: ao abrir a tela, no botão e na rodada diária) fica para uma versão futura, se sobrar cota.
8. O dry-run passa pela mesma reserva, para a lógica ser testada.
9. O consumo do dia ("37 de 100") e a fila aguardando cota aparecem em Configurações. O administrador altera o limite quando o pacote mudar.

## Consequências

- Capacidade em dia útil: cerca de 40 lançamentos (90 requisições ÷ ~2,2). A regra organiza a cota, mas não aumenta a capacidade: na operação completa (~66/dia) a fila cresce durante a semana e o domingo não zera. A negociação de um pacote maior com a Softplan continua sendo o principal risco (`PENDENCIAS.md` §2). Para o piloto, sobra cota.
- A lista "Baixas pendentes" depende de a Camilla marcar "Já dei baixa", sem conferência no Sienge. Para evitar marcação por engano, o app pede confirmação antes de tirar o título da lista (decidido em 06/11/2026).
- Documentos alterados por esta decisão: SPEC (RF26, RF29, RN20, RN25, RN28, §8), `01-estados.md` (T12, indicadores, sincronização), `02-modelo-er.md` (`despesas`, `cota_diaria`, `configuracoes`), skill `sienge-api` e as features `baixas-pendentes`, `configuracoes`, `consulta-titulos` e `integracao-sienge`.
