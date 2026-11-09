#!/bin/sh
# ==============================================================================
# AviGest S.L. — Script d'inici per a la Rèplica MariaDB 10.11 LTS
# Fitxer: docker/mariadb/replica-entrypoint.sh
# ==============================================================================
set -eu

PRIMARY_HOST="${PRIMARY_HOST:-mariadb}"
PRIMARY_PORT="${PRIMARY_PORT:-3306}"
REPL_USER="${REPL_USER:-replicator}"
REPL_PASSWORD="${REPL_PASSWORD:-replicator_pass_2026}"
ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-root_secret_2026}"

echo "[AviGest MariaDB Replica] Esperant que el primari (${PRIMARY_HOST}:${PRIMARY_PORT}) estigui actiu..."
until mariadb-admin ping -h "${PRIMARY_HOST}" -P "${PRIMARY_PORT}" -u "${REPL_USER}" -p"${REPL_PASSWORD}" --silent >/dev/null 2>&1; do
    sleep 2
done

echo "[AviGest MariaDB Replica] Primari detectat. Arrencant MariaDB com a Slave (Read-Only)..."

# Iniciem el dimoni mariadbd en segon pla
docker-entrypoint.sh mariadbd --server-id=2 --read-only=1 --log-basename=avigest-replica --relay-log=mariadb-relay-bin &
PID="$!"

# Esperem que el dimoni local de la rèplica accepti connexions
until mariadb-admin ping -u root -p"${ROOT_PASSWORD}" --silent >/dev/null 2>&1; do
    sleep 2
done

echo "[AviGest MariaDB Replica] Configurant connexió de replicació amb GTID..."
mariadb -u root -p"${ROOT_PASSWORD}" <<SQL
STOP SLAVE;
CHANGE MASTER TO
    MASTER_HOST='${PRIMARY_HOST}',
    MASTER_PORT=${PRIMARY_PORT},
    MASTER_USER='${REPL_USER}',
    MASTER_PASSWORD='${REPL_PASSWORD}',
    MASTER_CONNECT_RETRY=5,
    MASTER_USE_GTID=current_pos;
START SLAVE;
SQL

echo "[AviGest MariaDB Replica] Rèplica sincronitzada i activa correctament."
wait "$PID"

