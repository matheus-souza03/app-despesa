import { PgBoss } from 'pg-boss';
import { pino } from 'pino';
import { lerConfig } from './config';

const config = lerConfig();
const log = pino({ level: config.LOG_LEVEL, name: 'worker' });

const boss = new PgBoss(config.DATABASE_URL);
boss.on('error', (erro) => log.error({ erro }, 'erro no pg-boss'));

await boss.start();
log.info({ dryRun: config.SIENGE_DRY_RUN }, 'worker iniciado');
// As filas (lancar-despesa, apagar-anexo, rotinas-domingo, limpeza-diaria…) entram nas
// etapas 5, 7 e 9 do README (ADR-0003 e ADR-0009).

async function encerrar() {
  await boss.stop();
  process.exit(0);
}
process.once('SIGINT', encerrar);
process.once('SIGTERM', encerrar);
