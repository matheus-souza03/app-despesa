import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import * as schema from './schema';

export function criarConexao(url: string) {
  const pool = new pg.Pool({ connectionString: url });
  const db = drizzle({ client: pool, schema, casing: 'snake_case' });
  return { db, pool };
}

export type Banco = ReturnType<typeof criarConexao>['db'];
