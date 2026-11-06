// Consulta "Pagamentos" — relatório "Contas pagas com apropriações" do Sienge
// Lê todos os arquivos .xlsx da pasta indicada no parâmetro PastaRelatorios,
// junta tudo, remove linhas repetidas (arquivos com períodos sobrepostos),
// corrige a acentuação quebrada do relatório e deixa só as colunas do painel.
// Não importa CPF, dados bancários nem observações.

let
    // Pares "texto quebrado" -> "texto certo" (ex.: "SOLUÃ‡Ã•ES" -> "SOLUÇÕES")
    Mapa = {
        {"#(00C3)#(00A1)", "#(00E1)"},
        {"#(00C3)#(00A0)", "#(00E0)"},
        {"#(00C3)#(00A2)", "#(00E2)"},
        {"#(00C3)#(00A3)", "#(00E3)"},
        {"#(00C3)#(00A4)", "#(00E4)"},
        {"#(00C3)#(00A9)", "#(00E9)"},
        {"#(00C3)#(00A8)", "#(00E8)"},
        {"#(00C3)#(00AA)", "#(00EA)"},
        {"#(00C3)#(00AB)", "#(00EB)"},
        {"#(00C3)#(00AD)", "#(00ED)"},
        {"#(00C3)#(00AC)", "#(00EC)"},
        {"#(00C3)#(00AE)", "#(00EE)"},
        {"#(00C3)#(00AF)", "#(00EF)"},
        {"#(00C3)#(00B3)", "#(00F3)"},
        {"#(00C3)#(00B2)", "#(00F2)"},
        {"#(00C3)#(00B4)", "#(00F4)"},
        {"#(00C3)#(00B5)", "#(00F5)"},
        {"#(00C3)#(00B6)", "#(00F6)"},
        {"#(00C3)#(00BA)", "#(00FA)"},
        {"#(00C3)#(00B9)", "#(00F9)"},
        {"#(00C3)#(00BB)", "#(00FB)"},
        {"#(00C3)#(00BC)", "#(00FC)"},
        {"#(00C3)#(00A7)", "#(00E7)"},
        {"#(00C3)#(00B1)", "#(00F1)"},
        {"#(00C3)#(0081)", "#(00C1)"},
        {"#(00C3)#(20AC)", "#(00C0)"},
        {"#(00C3)#(201A)", "#(00C2)"},
        {"#(00C3)#(0192)", "#(00C3)"},
        {"#(00C3)#(201E)", "#(00C4)"},
        {"#(00C3)#(2030)", "#(00C9)"},
        {"#(00C3)#(02C6)", "#(00C8)"},
        {"#(00C3)#(0160)", "#(00CA)"},
        {"#(00C3)#(2039)", "#(00CB)"},
        {"#(00C3)#(008D)", "#(00CD)"},
        {"#(00C3)#(0152)", "#(00CC)"},
        {"#(00C3)#(017D)", "#(00CE)"},
        {"#(00C3)#(008F)", "#(00CF)"},
        {"#(00C3)#(201C)", "#(00D3)"},
        {"#(00C3)#(2019)", "#(00D2)"},
        {"#(00C3)#(201D)", "#(00D4)"},
        {"#(00C3)#(2022)", "#(00D5)"},
        {"#(00C3)#(2013)", "#(00D6)"},
        {"#(00C3)#(0161)", "#(00DA)"},
        {"#(00C3)#(2122)", "#(00D9)"},
        {"#(00C3)#(203A)", "#(00DB)"},
        {"#(00C3)#(0153)", "#(00DC)"},
        {"#(00C3)#(2021)", "#(00C7)"},
        {"#(00C3)#(2018)", "#(00D1)"},
        {"#(00C2)#(00BA)", "#(00BA)"},
        {"#(00C2)#(00AA)", "#(00AA)"},
        {"#(00C2)#(00B0)", "#(00B0)"}
    },
    Consertar = (valor as any) as any =>
        if valor is text then
            Text.Trim(List.Accumulate(Mapa, valor, (atual, par) => Text.Replace(atual, par{0}, par{1})))
        else
            valor,

    Colunas = {"BAIXA", "origemMovimento", "dataPagamento", "dataEmissao", "numeroTitulo", "numeroParcela",
        "nomeCredor", "nomeFantasiaCredor", "codigoDocumento", "numeroDocumento",
        "codigoPlanoFinanceiro", "descricaoPlanoFinanceiro", "codigoCentroCusto", "descricaoCentroCusto",
        "codigoEmpresa", "descricaoEmpresa", "percentualApropriado", "valorPagamentoLiquido",
        "valorTotalTituloOuMovimento", "usuarioCadastro"},

    Arquivos = Folder.Files(PastaRelatorios),
    SoExcel = Table.SelectRows(Arquivos, each Text.Lower([Extension]) = ".xlsx" and not Text.StartsWith([Name], "~$")),
    Planilhas = Table.AddColumn(SoExcel, "Dados", each
        let
            Livro = Excel.Workbook([Content], true),
            Abas = Table.SelectRows(Livro, each [Kind] = "Sheet"),
            Primeira = Abas{0}[Data]
        in
            Table.SelectColumns(Primeira, Colunas, MissingField.UseNull)),
    Juntas = Table.Combine(Planilhas[Dados]),
    ComChave = Table.SelectRows(Juntas, each [BAIXA] <> null and [BAIXA] <> ""),
    SemRepetidos = Table.Distinct(ComChave, {"BAIXA"}),

    Textos = {"origemMovimento", "nomeCredor", "nomeFantasiaCredor", "codigoDocumento",
        "codigoPlanoFinanceiro", "descricaoPlanoFinanceiro", "descricaoCentroCusto", "descricaoEmpresa", "usuarioCadastro"},
    Consertados = Table.TransformColumns(SemRepetidos, List.Transform(Textos, each {_, Consertar})),

    Tipos = Table.TransformColumnTypes(Consertados, {
        {"dataPagamento", type date}, {"dataEmissao", type date},
        {"numeroTitulo", Int64.Type}, {"numeroParcela", Int64.Type},
        {"codigoCentroCusto", Int64.Type}, {"codigoEmpresa", Int64.Type},
        {"percentualApropriado", type number},
        {"valorPagamentoLiquido", Currency.Type}, {"valorTotalTituloOuMovimento", Currency.Type}}, "pt-BR"),
    NumeroDoc = Table.TransformColumns(Tipos, {{"numeroDocumento", each if _ = null then null else Text.From(_), type nullable text}}),

    ComCentro = Table.AddColumn(NumeroDoc, "Centro de custo", each Text.From([codigoCentroCusto]) & " · " & ([descricaoCentroCusto] ?? ""), type text),
    ComPlano = Table.AddColumn(ComCentro, "Plano financeiro", each ([codigoPlanoFinanceiro] ?? "") & " · " & ([descricaoPlanoFinanceiro] ?? ""), type text),
    ComEmpresa = Table.AddColumn(ComPlano, "Empresa", each Text.From([codigoEmpresa]) & " · " & ([descricaoEmpresa] ?? ""), type text),
    ComCredor = Table.AddColumn(ComEmpresa, "Credor", each
        if [nomeFantasiaCredor] <> null and [nomeFantasiaCredor] <> "" then [nomeFantasiaCredor] else [nomeCredor], type text),
    ComOrigem = Table.AddColumn(ComCredor, "Origem", each if [origemMovimento] = "FP" then "Folha de pagamento" else "Contas a pagar", type text),

    Renomeadas = Table.RenameColumns(ComOrigem, {
        {"dataPagamento", "Data do pagamento"}, {"dataEmissao", "Data de emissão"},
        {"numeroTitulo", "Título"}, {"numeroParcela", "Parcela"},
        {"codigoDocumento", "Tipo de documento"}, {"numeroDocumento", "Número do documento"},
        {"codigoCentroCusto", "Código do centro de custo"}, {"percentualApropriado", "Percentual"},
        {"valorPagamentoLiquido", "Valor pago"}, {"valorTotalTituloOuMovimento", "Valor do título"},
        {"usuarioCadastro", "Lançado por"}}),
    Final = Table.SelectColumns(Renomeadas, {"BAIXA", "Data do pagamento", "Data de emissão", "Título", "Parcela",
        "Credor", "Tipo de documento", "Número do documento", "Centro de custo", "Código do centro de custo",
        "Plano financeiro", "Empresa", "Origem", "Percentual", "Valor pago", "Valor do título", "Lançado por"})
in
    Final
