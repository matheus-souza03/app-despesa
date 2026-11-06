#!/usr/bin/env node
// Busca todos os planos financeiros do Sienge (1 requisição) e salva em CSV e JSON.
// Node 18+. Credenciais pelas mesmas variáveis do sienge-probe.mjs:
//   export SIENGE_USER='usuario-de-api'
//   read -s SIENGE_PASS && export SIENGE_PASS
// Uso: node exportar-planos.mjs

import { writeFile, readFile } from 'node:fs/promises';

// Lista de planos liberados no app (SPEC RN08); opcional
let liberados = new Set();
try { liberados = new Set(JSON.parse(await readFile(new URL('../data/planos-financeiros-liberados.json', import.meta.url), 'utf8')).map((p) => String(p.id).trim())); } catch {}

const SUB = process.env.SIENGE_SUBDOMAIN || 'sencoeng';
const { SIENGE_USER: USER, SIENGE_PASS: PASS } = process.env;
if (!USER || !PASS) { console.error('Defina SIENGE_USER e SIENGE_PASS antes de rodar.'); process.exit(1); }

const url = `https://api.sienge.com.br/${SUB}/public/api/v1/payment-categories`;
const res = await fetch(url, { headers: { Authorization: 'Basic ' + Buffer.from(`${USER}:${PASS}`).toString('base64'), Accept: 'application/json' } });
if (!res.ok) { console.error(`Erro ${res.status}: ${await res.text()}`); process.exit(1); }
const corpo = await res.json();
const planos = Array.isArray(corpo) ? corpo : (corpo.results ?? []);

// "2010402" -> "2.01.04.02" (1º dígito, depois pares)
const formatar = (id) => [id.slice(0, 1), ...(id.slice(1).match(/.{1,2}/g) ?? [])].join('.');
const linhas = planos
  .map((p) => {
    const id = String(p.id).trim();
    return {
      codigo: formatar(id),
      codigoSemPontos: id,
      nome: String(p.name ?? '').trim(),
      nivel: Math.ceil(id.length / 2),
      grupoPai: id.length > 1 ? formatar(id.slice(0, id.length - 2)) : '',
      tipo: p.tpConta === 'T' ? 'Totalizadora' : 'Resultado',
      redutora: p.flRedutora,
      ativa: p.flAtiva,
      adiantamento: p.flAdiantamento,
      imposto: p.flImposto,
      liberadoNoApp: liberados.has(id) ? 'S' : 'N',
      // mesma regra do app (SPEC RN08): liberado, de resultado, não redutor e ativo
      selecionavelNoApp: liberados.has(id) && p.tpConta === 'R' && p.flRedutora === 'N' && p.flAtiva === 'S' ? 'S' : 'N',
    };
  })
  .sort((a, b) => a.codigoSemPontos.localeCompare(b.codigoSemPontos));

const colunas = Object.keys(linhas[0] ?? { codigo: '' });
const escapar = (v) => { const s = String(v ?? ''); return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
const csv = '\uFEFF' + [colunas.join(';'), ...linhas.map((l) => colunas.map((c) => escapar(l[c])).join(';'))].join('\r\n');

await writeFile('planos-financeiros.csv', csv, 'utf8');
await writeFile('planos-financeiros.json', JSON.stringify(planos, null, 2), 'utf8');
const selecionaveis = linhas.filter((l) => l.selecionavelNoApp === 'S').length;
console.log(`${linhas.length} planos salvos em planos-financeiros.csv e planos-financeiros.json (${selecionaveis} selecionáveis no app). 1 requisição usada.`);
