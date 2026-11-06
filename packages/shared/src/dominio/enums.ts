import { z } from 'zod';

// Tipos enumerados de docs/modelagem/02-modelo-er.md §2. O schema do banco (packages/db)
// e as telas usam estas listas, para existir uma fonte só.

export const STATUS_DESPESA = [
  'RASCUNHO',
  'AGUARDANDO_CC',
  'PENDENTE',
  'DEVOLVIDA',
  'APROVADA',
  'ENVIANDO',
  'LANCADA',
  'ERRO',
  'DESCARTADA',
] as const;
export const StatusDespesa = z.enum(STATUS_DESPESA);
export type StatusDespesa = z.infer<typeof StatusDespesa>;

export const PERFIS_USUARIO = [
  'COLABORADOR_RUA',
  'COLABORADOR_ESCRITORIO',
  'APROVADOR_CC',
  'APROVADOR',
] as const;
export const PerfilUsuario = z.enum(PERFIS_USUARIO);
export type PerfilUsuario = z.infer<typeof PerfilUsuario>;

// Classes de prioridade da reserva de cota da API do Sienge (ADR-0009).
export const CLASSES_COTA = ['PESSOA', 'LANCAMENTO', 'ROTINA'] as const;
export const ClasseCota = z.enum(CLASSES_COTA);
export type ClasseCota = z.infer<typeof ClasseCota>;
