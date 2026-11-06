# ADR-0006 — Storage temporário dos anexos

- Situação: Aceita (06/11/2026)

## Contexto

Os comprovantes só ficam no app até o Sienge confirmar cada anexo com `201` (RN22, invariante 6.5). Eles não entram no backup (RNF09). A hospedagem ainda não foi escolhida (ADR-0011).

## Decisão

- Porta `Armazenamento` (`gravar`, `ler`, `apagar`), com a implementação **disco local** (`STORAGE_PATH`) por enquanto. Uma implementação S3 compatível entra se a hospedagem pedir; o resto do código não muda.
- O arquivo é gravado com o id do anexo como nome, com `hash_sha256`, tipo e tamanho registrados. Os limites são os do Sienge: 70 MB e nome com até 100 caracteres (RNF08). As imagens são comprimidas no aparelho antes do envio.
- Upload pela API (`multipart`, em streaming) e leitura sempre pela API, com checagem de permissão. Não há URL pública de arquivo.
- O arquivo só é apagado pelo job `apagar-anexo`, enfileirado depois do `201` daquele anexo, ou na exclusão definitiva da lixeira. A `limpeza-diaria` remove órfãos e repete exclusões que falharam.

## Consequências

- Se o disco for perdido antes do envio, a despesa volta ao colaborador para reenviar o comprovante (RNF09).
- O disco local exige volume persistente na hospedagem.
