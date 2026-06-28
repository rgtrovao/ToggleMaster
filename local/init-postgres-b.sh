#!/bin/bash
# Executado uma vez na inicialização do postgres-b.
# Cria o usuário e banco para o targeting-service (além do flagdb criado pelas variáveis de ambiente).
set -e

# Cria o usuário "target" e o banco "targetdb" usando o superusuário do container (flag)
psql -v ON_ERROR_STOP=1 --username "flag" --dbname "postgres" <<-'EOSQL'
    CREATE USER target WITH PASSWORD 'target_pass';
    CREATE DATABASE targetdb OWNER target;
    GRANT ALL PRIVILEGES ON DATABASE targetdb TO target;
EOSQL

# Inicializa o schema do targeting-service em targetdb
# Usa heredoc quoted (<<-'EOSQL') para preservar $$ do PL/pgSQL sem expansão pelo bash
psql -v ON_ERROR_STOP=1 --username "flag" --dbname "targetdb" <<-'EOSQL'
    CREATE TABLE IF NOT EXISTS targeting_rules (
        id SERIAL PRIMARY KEY,
        flag_name VARCHAR(100) UNIQUE NOT NULL,
        is_enabled BOOLEAN NOT NULL DEFAULT true,
        rules JSONB NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

    CREATE OR REPLACE FUNCTION trigger_set_timestamp()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS set_timestamp ON targeting_rules;

    CREATE TRIGGER set_timestamp
    BEFORE UPDATE ON targeting_rules
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_set_timestamp();

    ALTER TABLE targeting_rules OWNER TO target;
EOSQL

echo ">>> init-postgres-b.sh concluído: usuário 'target' e banco 'targetdb' criados."
