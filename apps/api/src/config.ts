import { z } from 'zod';

const Ambiente = z.object({
  API_PORT: z.coerce.number().int().positive().default(3000),
  API_HOST: z.string().min(1).default('127.0.0.1'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
});

export type Config = z.infer<typeof Ambiente>;

export function lerConfig(env: Record<string, string | undefined> = process.env): Config {
  return Ambiente.parse(env);
}
