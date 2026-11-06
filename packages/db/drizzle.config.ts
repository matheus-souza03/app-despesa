import { defineConfig } from 'drizzle-kit';

// Lê o .env da raiz do repositório, se existir.
try {
  process.loadEnvFile('../../.env');
} catch {
  // sem .env: usa as variáveis do ambiente
}

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema/index.ts',
  out: './migrations',
  casing: 'snake_case',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? 'postgres://despesas:despesas@localhost:5432/despesas',
  },
});
