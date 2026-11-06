import { describe, expect, it } from 'vitest';
import { criarApp } from './app';

describe('GET /api/saude', () => {
  it('responde que a API está no ar', async () => {
    const app = criarApp();
    const resposta = await app.inject({ method: 'GET', url: '/api/saude' });

    expect(resposta.statusCode).toBe(200);
    expect(resposta.json()).toEqual({ status: 'ok' });
    await app.close();
  });
});
