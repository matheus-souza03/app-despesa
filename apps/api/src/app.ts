import Fastify, { type FastifyServerOptions } from 'fastify';

export function criarApp(opcoes: FastifyServerOptions = {}) {
  const app = Fastify(opcoes);

  app.get('/api/saude', async () => ({ status: 'ok' }));

  return app;
}
