import { z } from 'zod';

// Dry-run é o padrão: só o texto "false", explícito, libera chamadas reais ao Sienge
// (não existe homologação do Sienge; CLAUDE.md e ADR-0008). Qualquer outro valor é erro.
const DryRun = z
  .enum(['true', 'false'], { message: 'SIENGE_DRY_RUN deve ser "true" ou "false"' })
  .default('true')
  .transform((valor) => valor === 'true');

const Ambiente = z.object({
  DATABASE_URL: z.string().min(1, 'Informe DATABASE_URL'),
  SIENGE_DRY_RUN: z.preprocess((valor) => (valor === '' ? undefined : valor), DryRun),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
});

export type Config = z.infer<typeof Ambiente>;

export function lerConfig(env: Record<string, string | undefined> = process.env): Config {
  return Ambiente.parse(env);
}
