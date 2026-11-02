#!/bin/sh
# Arrenca PostgreSQL 16 com a Hot Standby a partir d'un pg_basebackup del primari.
set -eu

PRIMARY_HOST="${PRIMARY_HOST:-postgres}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
REPL_USER="${REPL_USER:-replicator}"
REPL_PASSWORD="${REPL_PASSWORD:-replicator_pass_2026}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"

as_postgres() {
    if command -v gosu >/dev/null 2>&1; then
        gosu postgres "$@"
    elif command -v su-exec >/dev/null 2>&1; then
        su-exec postgres "$@"
    else
        su -s /bin/sh postgres -c "$*"
    fi
}

echo "[AviGest replica] Esperant el primari ${PRIMARY_HOST}:${PRIMARY_PORT}..."
until pg_isready -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT}" -U avigest_app -q; do
    sleep 2
done

until PGPASSWORD="avigest_secret_2026" psql -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT}" -U avigest_app -d avigest_db -tAc \
    "SELECT 1 FROM pg_roles WHERE rolname='replicator'" 2>/dev/null | grep -q 1; do
    echo "[AviGest replica] Esperant el rol replicator..."
    sleep 2
done

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "[AviGest replica] Executant pg_basebackup (streaming replication)..."
    find "${PGDATA}" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "${PGDATA}"
    chown postgres:postgres "${PGDATA}"
    chmod 0700 "${PGDATA}"
    PGPASSWORD="${REPL_PASSWORD}" as_postgres pg_basebackup \
        -h "${PRIMARY_HOST}" \
        -p "${PRIMARY_PORT}" \
        -U "${REPL_USER}" \
        -D "${PGDATA}" \
        -Fp -Xs -P -R
    echo "[AviGest replica] Basebackup complet. standby.signal creat (-R)."
fi

exec docker-entrypoint.sh postgres -c hot_standby=on
