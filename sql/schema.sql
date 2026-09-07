-- DDL DuckDB — Pricing Non-Pecuniary Harm (executado por R/db.R::db_init)
CREATE TABLE IF NOT EXISTS collection_log (
  collected_at TIMESTAMP, source VARCHAR, request_url VARCHAR, request_body VARCHAR,
  page INTEGER, n_records INTEGER, raw_file VARCHAR, sha256 VARCHAR
);
CREATE TABLE IF NOT EXISTS acordaos (
  uuid VARCHAR PRIMARY KEY, identificador VARCHAR, base VARCHAR, subbase VARCHAR,
  processo VARCHAR, classe_cnj INTEGER, orgao_julgador VARCHAR, cod_orgao INTEGER,
  relator VARCHAR, data_julgamento DATE, data_publicacao DATE, decisao VARCHAR,
  ementa VARCHAR, uf VARCHAR, turma_recursal BOOLEAN, segredo_justica BOOLEAN,
  possui_inteiro_teor BOOLEAN, inteiro_teor VARCHAR, inteiro_teor_chars INTEGER,
  raw_file VARCHAR, collected_at TIMESTAMP
);
CREATE TABLE IF NOT EXISTS value_mentions (
  uuid VARCHAR, section VARCHAR, idx INTEGER, amount_brl DOUBLE, amount_text VARCHAR,
  role VARCHAR, role_conf DOUBLE, is_moral BOOLEAN, context VARCHAR, position INTEGER,
  PRIMARY KEY (uuid, section, idx)
);
CREATE TABLE IF NOT EXISTS annotations (
  uuid VARCHAR, annotator VARCHAR, round INTEGER, award_brl DOUBLE, award_role VARCHAR,
  first_instance_brl DOUBLE, harm_type VARCHAR, outcome VARCHAR, notes VARCHAR,
  annotated_at TIMESTAMP, PRIMARY KEY (uuid, annotator, round)
);
CREATE TABLE IF NOT EXISTS ipca (ref_month DATE PRIMARY KEY, pct DOUBLE, index_value DOUBLE);
