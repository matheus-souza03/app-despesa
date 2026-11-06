-- Banco separado para os testes de integração. As extensões (citext, unaccent, pg_trgm)
-- são criadas pelas migrações (ADR-0002), nos dois bancos.
CREATE DATABASE despesas_teste OWNER despesas;
