import { criarApp } from './app';
import { lerConfig } from './config';

const config = lerConfig();

const app = criarApp({
  logger: {
    level: config.LOG_LEVEL,
    // Nunca logar credenciais nem cookies de sessão (CLAUDE.md, "Regras de engenharia").
    redact: ['req.headers.authorization', 'req.headers.cookie', 'res.headers["set-cookie"]'],
  },
});

async function encerrar() {
  await app.close();
  process.exit(0);
}
process.once('SIGINT', encerrar);
process.once('SIGTERM', encerrar);

await app.listen({ port: config.API_PORT, host: config.API_HOST });
