import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/main.ts'],
  format: ['esm'],
  platform: 'node',
  target: 'node24',
  clean: true,
  sourcemap: true,
  // Os pacotes do workspace são consumidos pelo código-fonte e entram no pacote final.
  noExternal: [/^@despesas\//],
});
