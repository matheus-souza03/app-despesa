# Modelagem — App de Despesas → Sienge

Versão 1.0 — 26/10/2026. Base: `docs/SPEC.md` v1.1, `features/*.feature`, skill `sienge-api` e os testes reais da API.

| Documento | Conteúdo |
|---|---|
| [01-estados.md](01-estados.md) | Máquina de estados da despesa, ciclo de vida do anexo e da sincronização, indicadores depois do lançamento |
| [02-modelo-er.md](02-modelo-er.md) | Modelo entidade-relacionamento e dicionário de dados (PostgreSQL) |
| [03-sequencias.md](03-sequencias.md) | Diagramas de sequência dos fluxos com integração |
| [04-classes.md](04-classes.md) | Diagrama de classes do domínio (`packages/shared`) e das portas de integração |

Os diagramas estão em Mermaid (o GitHub e o VS Code mostram direto no arquivo).

## Convenções

- **Nomes:** tabelas e colunas em português, `snake_case`, sem acento. Classes e métodos em português, `PascalCase` / `camelCase`, sem acento.
- **Chaves:** entidades do app usam `uuid` (gerado no cliente quando a despesa nasce offline). Entidades espelhadas do Sienge usam o **id do Sienge** como chave primária (empresa, centro de custo, plano financeiro, tipo de documento, credor, título, município).
- **Dinheiro:** no banco, `numeric(14,2)`; no domínio, inteiro em **centavos** (`Dinheiro`), nunca `float`. Percentual de rateio: `numeric(15,12)` (12 casas, como o Sienge).
- **Datas:** datas de negócio (emissão, pagamento, vencimento, data base, data contábil) são `date`, interpretadas no fuso `America/Sao_Paulo`. Instantes técnicos são `timestamptz` em UTC. Datas e horas do Sienge chegam sem fuso (`"2024-10-29 09:35:08"`) e são convertidas assumindo `America/Sao_Paulo`.
- **Documentos (CPF/CNPJ):** guardados sem máscara, em maiúsculas. O CNPJ é `varchar(14)` **alfanumérico**, não só dígitos (ver [04-classes.md](04-classes.md), "Pontos de atenção").
- **Textos vindos do Sienge:** sempre com `trim()` antes de gravar (códigos de documento chegam como `"PAG "`).
- **Auditoria:** toda transição de estado e toda edição gera uma linha em `eventos_despesa`.
- **Concorrência:** `despesas.versao` (controle otimista). Duas pessoas agindo na mesma despesa: a segunda recebe "já decidida por outra pessoa".

## Decisões desta modelagem

Todas aprovadas na revisão de 28/10/2026:

1. **Descartar despesa (aprovado).** O autor descarta um rascunho ou uma devolvida; o aprovador descarta uma pendente ou uma com erro sem título criado, com motivo. A despesa vai para a **lixeira por 30 dias**, de onde pode ser recuperada ou excluída definitivamente; depois do prazo, é excluída sozinha.
2. **Erro com título já criado (aprovado).** Se o título já existe no Sienge e só falta anexo, a despesa **não pode** voltar a pendente nem ser descartada (o título não pode ser alterado pela API). Saídas: "Tentar de novo", "Anexar outro arquivo" ou "Resolvido no Sienge" (a Camilla anexou à mão), que leva a LANCADA.
3. **Ajuste de parcelas, baixa e título excluído (aprovado)** não são estados: são indicadores independentes de uma despesa LANCADA.
4. **Cache de credores (aprovado).** A tela Títulos filtra por nome e CNPJ do credor, mas o título só traz `creditorId`. Os credores ficam no banco, carregados pelo arquivo exportado do Sienge, mais os criados pelo app e a busca sob demanda de um credor desconhecido.
5. **Avisos de lançamento (aprovado)** ficam gravados (`notificacoes`), para aparecerem mesmo se o aprovador estiver em outra tela ou voltar depois.
6. **Perfis (pedido da equipe, 29/10/2026):** colaborador de rua (sem apropriação, passa pelo estado `AGUARDANDO_CC`), colaborador de escritório, aprovador de centro de custo (só altera apropriações) e aprovador; administrador é uma marcação à parte.
