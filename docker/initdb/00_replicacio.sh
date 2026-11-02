#!/bin/sh
# Crea l'usuari de replicació i permet connexions de streaming des de la LAN Docker.
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass_2026';
    END IF;
END
$$;
SQL

if ! grep -q "host replication replicator" "${PGDATA}/pg_hba.conf"; then
    echo "host replication replicator 0.0.0.0/0 scram-sha-256" >> "${PGDATA}/pg_hba.conf"
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "SELECT pg_reload_conf();"
echo "[AviGest] Usuari replicator i pg_hba de streaming configurats."
