#!/usr/bin/env node
// Testes da API do Sienge — Node 18+ (sem dependências).
//
// Credenciais por variável de ambiente (nunca no código):
//   export SIENGE_USER='usuario-de-api'
//   read -s SIENGE_PASS && export SIENGE_PASS
//
// Comandos:
//   node sienge-probe.mjs gets                     → roda todas as consultas GET do roteiro
//   node sienge-probe.mjs get "/bills/16720/installments"
//   node sienge-probe.mjs post /eletronic-invoice-bills corpo-nfe.json --confirmo
//   node sienge-probe.mjs post /bills corpo-titulo.json --confirmo
//   node sienge-probe.mjs patch /bills/123/installments corpo-parcelas.json --confirmo
//   node sienge-probe.mjs attach 123 comprovante.pdf DANFe --confirmo
//
// Saídas:
//   respostas/bruto/        → resposta completa (NÃO enviar; contém dados pessoais)
//   respostas/para-enviar/  → resposta anonimizada e resumida (pode enviar no chat)

import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { basename } from 'node:path';

const SUB = process.env.SIENGE_SUBDOMAIN || 'sencoeng';
const USER = process.env.SIENGE_USER;
const PASS = process.env.SIENGE_PASS;
const BASE = `https://api.sienge.com.br/${SUB}/public/api/v1`;

// Parâmetros do roteiro (ajuste se quiser outros exemplos)
const CNPJ_CREDOR = process.env.CNPJ_CREDOR || '28070499000122';   // FN do Brasil
const NOME_CREDOR = process.env.NOME_CREDOR || 'morelate';
const TITULO_SIMPLES = process.env.TITULO_SIMPLES || '16720';      // FN do Brasil, 1 parcela
const TITULO_RATEIO = process.env.TITULO_RATEIO || '16821';        // Morelate, rateio 50/50
const TITULO_PARCELADO = process.env.TITULO_PARCELADO || '';       // peça à Camilla um título com 2+ parcelas
const EMISSAO = process.env.EMISSAO || '2026-09-14';               // emissão do TITULO_SIMPLES

if (!USER || !PASS) {
  console.error('Defina SIENGE_USER e SIENGE_PASS antes de rodar.');
  process.exit(1);
}
const AUTH = 'Basic ' + Buffer.from(`${USER}:${PASS}`).toString('base64');
let contador = 0;

// ---------- anonimização ----------
const CHAVES_SENSIVEIS = /^(cpf|registerNumber|cpfCnpjBeneficiary|accountBeneficiaryCpfNumber|key|email|skype|msn|ddd|number|phoneNumber|phoneDdd|rg)$/i;
const CHAVES_PESSOA_FISICA = /^(name|tradeName|beneficiary|accountBeneficiaryName|streetName|complement|neighborhood|zipCode|addressNumber)$/;
const FORA_DO_RESUMO = /^(name|tradeName|cpf|cnpj|registerNumber|notes|documentNumber|description|email|key|beneficiary|streetName|number|complement|neighborhood|zipCode|cityName|accessKeyNumber|registeredBy|changedBy|registeredUserId|changedUserId)$/i;

function anonimizar(v, pf = false) {
  if (Array.isArray(v)) {
    const itens = v.slice(0, 5).map((x) => anonimizar(x, pf));
    if (v.length > 5) itens.push({ _omitidos: v.length - 5 });
    return itens;
  }
  if (v && typeof v === 'object') {
    const pessoaFisica = pf || (typeof v.cpf === 'string' && v.cpf.replace(/\D/g, '').length > 0);
    const out = {};
    for (const [k, val] of Object.entries(v)) {
      if (val === null || val === '' ) { out[k] = val; continue; }
      if (typeof val !== 'object' && CHAVES_SENSIVEIS.test(k)) out[k] = mascarar(String(val));
      else if (typeof val !== 'object' && pessoaFisica && CHAVES_PESSOA_FISICA.test(k)) out[k] = '(oculto)';
      else out[k] = anonimizar(val, pessoaFisica);
    }
    return out;
  }
  return v;
}
function mascarar(s) {
  const manter = s.length > 6 ? 2 : 0;
  return s.replace(/[0-9A-Za-z]/g, (c, i) => (i < s.length - manter ? 'X' : c));
}

// Resumo de listas grandes: valores distintos de campos-código (nunca nomes ou documentos)
function resumo(dados) {
  const lista = Array.isArray(dados) ? dados : Array.isArray(dados?.results) ? dados.results : null;
  if (!lista || lista.length === 0) return undefined;
  const r = { total: lista.length, camposPorItem: Object.keys(lista[0]) };
  for (const campo of Object.keys(lista[0])) {
    if (FORA_DO_RESUMO.test(campo)) continue;
    const valores = new Set(lista.map((x) => x?.[campo]).filter((x) => x === null || ['string', 'boolean'].includes(typeof x)));
    if (valores.size > 0 && valores.size <= 12) r[`valores_${campo}`] = [...valores];
  }
  if ('idCompany' in lista[0]) r.semEmpresa = lista.filter((x) => x.idCompany == null).length;
  if ('id' in lista[0]) r.exemplosDeId = lista.slice(0, 8).map((x) => x.id);
  return r;
}

// ---------- HTTP ----------
async function chamar(metodo, caminho, { json, form } = {}) {
  contador++;
  const url = caminho.startsWith('http') ? caminho : BASE + caminho;
  const headers = { Authorization: AUTH, Accept: 'application/json' };
  let body;
  if (json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(json); }
  if (form) body = form;
  const t0 = Date.now();
  const res = await fetch(url, { method: metodo, headers, body });
  const ms = Date.now() - t0;
  const texto = await res.text();
  let dados; try { dados = texto ? JSON.parse(texto) : null; } catch { dados = texto; }
  const hdrs = {};
  for (const h of ['location', 'content-type', 'x-ratelimit-limit', 'x-ratelimit-remaining', 'x-request-id']) {
    if (res.headers.get(h)) hdrs[h] = res.headers.get(h);
  }
  return { metodo, url: url.replace(BASE, ''), status: res.status, ms, headers: hdrs, dados };
}

async function existe(caminho) {
  try { await access(caminho); return true; } catch { return false; }
}

async function salvar(nomeBase, r) {
  await mkdir('respostas/bruto', { recursive: true });
  await mkdir('respostas/para-enviar', { recursive: true });
  // não sobrescreve: a mesma consulta feita antes e depois de uma alteração vira -2, -3...
  let nome = nomeBase;
  for (let i = 2; await existe(`respostas/para-enviar/${nome}.json`); i++) nome = `${nomeBase}-${i}`;
  await writeFile(`respostas/bruto/${nome}.json`, JSON.stringify(r, null, 2));
  const enviar = { ...r, resumo: resumo(r.dados), dados: anonimizar(r.dados) };
  await writeFile(`respostas/para-enviar/${nome}.json`, JSON.stringify(enviar, null, 2));
  console.log(`${String(r.status).padEnd(4)} ${r.metodo.padEnd(6)} ${r.url}  (${r.ms} ms) → respostas/para-enviar/${nome}.json`);
}

// ---------- roteiro de GETs ----------
async function gets() {
  const passos = [
    ['01-companies', '/companies?limit=200'],
    ['02-cost-centers-p1', '/cost-centers?limit=200&offset=0'],
    ['03-cost-centers-p2', '/cost-centers?limit=200&offset=200'],
    ['04-payment-categories', '/payment-categories'],
    ['05-document-identifications', '/document-identifications?limit=100&active=true'],
    ['06-document-DANF', '/document-identifications/DANF'],
    ['07-creditor-por-cnpj', `/creditors?cnpj=${CNPJ_CREDOR}`],
    ['08-creditor-por-nome', `/creditors?creditor=${encodeURIComponent(NOME_CREDOR)}&limit=5`],
    ['09-bills-busca-idempotencia', `/bills?startDate=${EMISSAO}&endDate=${EMISSAO}&limit=10`],
    ['10-bill-detalhe', `/bills/${TITULO_SIMPLES}`],
    ['11-bill-anexos', `/bills/${TITULO_SIMPLES}/attachments`],
    ['12-bill-parcelas-simples', `/bills/${TITULO_SIMPLES}/installments`],
    ['13-bill-rateio', `/bills/${TITULO_RATEIO}/budget-categories`],
    ['14-bills-by-change-date', `/bills/by-change-date?startDate=${hoje(-1)}&endDate=${hoje(0)}&limit=5`],
  ];
  if (TITULO_PARCELADO) passos.push(['15-bill-parcelas-multiplas', `/bills/${TITULO_PARCELADO}/installments`]);
  for (const [nome, caminho] of passos) {
    try { await salvar(nome, await chamar('GET', caminho)); }
    catch (e) { console.error(`ERRO ${nome}: ${e.message}`); }
  }
  console.log(`\n${contador} requisições usadas da cota diária.`);
}
function hoje(delta) {
  const d = new Date(Date.now() + delta * 86400000);
  return d.toISOString().slice(0, 10);
}

// ---------- escrita (exige --confirmo) ----------
function exigirConfirmacao() {
  if (!process.argv.includes('--confirmo')) {
    console.error('Esta operação GRAVA dados no Sienge de produção. Rode de novo com --confirmo.');
    process.exit(1);
  }
}

const [, , cmd, a1, a2, a3] = process.argv;
const nomeArquivo = (s) => s.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase();

if (cmd === 'gets') {
  await gets();
} else if (cmd === 'get' && a1) {
  await salvar('get-' + nomeArquivo(a1), await chamar('GET', a1));
} else if ((cmd === 'post' || cmd === 'patch' || cmd === 'put') && a1 && a2) {
  exigirConfirmacao();
  const corpo = JSON.parse(await readFile(a2, 'utf8'));
  await salvar(`${cmd}-${nomeArquivo(a1)}`, await chamar(cmd.toUpperCase(), a1, { json: corpo }));
} else if (cmd === 'attach' && a1 && a2 && a3) {
  exigirConfirmacao();
  const form = new FormData();
  form.append('file', new Blob([await readFile(a2)]), basename(a2));
  await salvar(`attach-${a1}`, await chamar('POST', `/bills/${a1}/attachments?description=${encodeURIComponent(a3)}`, { form }));
} else {
  console.log('Uso: veja o cabeçalho do arquivo.');
}
