import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // apps/web entra quando tiver testes de componente (ambiente jsdom).
    projects: ['packages/*', 'apps/api', 'apps/worker'],
    passWithNoTests: true,
  },
});
