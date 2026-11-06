import { describe, expect, it } from 'vitest';
import { lerConfig } from './config';

const base = { DATABASE_URL: 'postgres://despesas:despesas@localhost:5432/despesas' };

describe('SIENGE_DRY_RUN', () => {
  it('é dry-run quando a variável não existe', () => {
    expect(lerConfig(base).SIENGE_DRY_RUN).toBe(true);
  });

  it('é dry-run quando a variável está vazia', () => {
    expect(lerConfig({ ...base, SIENGE_DRY_RUN: '' }).SIENGE_DRY_RUN).toBe(true);
  });

  it('só faz chamadas reais com "false" explícito', () => {
    expect(lerConfig({ ...base, SIENGE_DRY_RUN: 'false' }).SIENGE_DRY_RUN).toBe(false);
  });

  it.each(['0', 'False', 'nao', 'no'])('recusa o valor ambíguo "%s"', (valor) => {
    expect(() => lerConfig({ ...base, SIENGE_DRY_RUN: valor })).toThrow();
  });
});
