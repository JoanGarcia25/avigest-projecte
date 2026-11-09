#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Còpia de Seguretat per al Servidor Dedicat (srv-backup)
# Fitxer: infra/backups-prd/backup_avigest.sh
# Mòdul: ASIX - Projecte (Requeriment 4.5: Còpies i PRD)
# Responsable: Joan (Infraestructura, Xarxa i Seguretat)
#
# Descripció:
# Executat des de la màquina virtual dedicada srv-backup (10.0.20.20):
#   1. Extreu el buidatge transaccional de MariaDB 10.11 des de srv-serveis (10.0.20.10).
#   2. Extreu l'arbre d'usuaris i grups d'OpenLDAP des de srv-serveis (10.0.20.10).
#   3. Comprimeix els arxius en un tar.gz datat amb hash SHA-256.
#   4. Copia el paquet al segon disc virtual muntat (/mnt/disc-extern-backup)
#      simulant la ubicació física externa (Estratègia 3-2-1).
#   5. Aplica política de retenció de 30 dies.
# ==============================================================================

set -euo pipefail

# Directori base local a srv-backup i punt de muntatge del 2n disc simulat
BACKUP_LOCAL_DIR="${BACKUP_LOCAL_DIR:-/var/backups/avigest}"
EXTERNAL_DISK_MOUNT="${EXTERNAL_DISK_MOUNT:-/mnt/disc-extern-backup}"
TEMP_DIR="${BACKUP_LOCAL_DIR}/tmp_$$"
LOG_FILE="${BACKUP_LOCAL_DIR}/backup.log"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="backup_avigest_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=30

# Dades de connexió cap a srv-serveis (MariaDB 10.11)
SRV_SERVEIS_HOST="10.0.20.10"
DB_PORT="3306"
DB_NAME="avigest_db"
DB_USER="avigest_backup"
DB_PASS="${DB_PASS:-backup_secret_pass_2026}"

LDAP_PORT="389"
LDAP_BASE="dc=avigest,dc=cat"
LDAP_BIND_DN="cn=admin,dc=avigest,dc=cat"
LDAP_PASS="admin_ldap_pass_2026"

mkdir -p "${BACKUP_LOCAL_DIR}" "${TEMP_DIR}"
if [[ -d "${EXTERNAL_DISK_MOUNT}" ]]; then
    mkdir -p "${EXTERNAL_DISK_MOUNT}/avigest_backups"
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log "======================================================================"
log "=== INICI CÒPIA DE SEGURETAT CENTRALITZADA (srv-backup -> srv-serveis) ==="
log "======================================================================"

# ------------------------------------------------------------------------------
# 1. Buidatge Transaccional de MariaDB 10.11 (srv-serveis:3306)
# ------------------------------------------------------------------------------
log "[1/5] Realitzant buidatge de la base de dades MariaDB 10.11..."

if command -v mariadb-dump &>/dev/null; then
    mariadb-dump -h "${SRV_SERVEIS_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
        --single-transaction --quick --routines --triggers --events "${DB_NAME}" > "${TEMP_DIR}/avigest_db.sql"
elif command -v mysqldump &>/dev/null; then
    mysqldump -h "${SRV_SERVEIS_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
        --single-transaction --quick --routines --triggers --events "${DB_NAME}" > "${TEMP_DIR}/avigest_db.sql"
else
    docker exec avigest_mariadb mariadb-dump -u avigest_app -pavigest_secret_2026 --single-transaction --routines --triggers avigest_db > "${TEMP_DIR}/avigest_db.sql"
fi

if [[ -s "${TEMP_DIR}/avigest_db.sql" ]]; then
    log "  -> Dump de MariaDB completat correctament ($(du -h "${TEMP_DIR}/avigest_db.sql" | cut -f1))."
else
    log "  -> [ERROR] El dump de MariaDB és buit o la connexió ha fallat!"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Exportació de l'Arbre d'Usuaris OpenLDAP (srv-serveis:389)
# ------------------------------------------------------------------------------
log "[2/5] Exportant el directori d'usuaris d'OpenLDAP..."

if command -v ldapsearch &>/dev/null; then
    ldapsearch -h "${SRV_SERVEIS_HOST}" -p "${LDAP_PORT}" \
        -x -D "${LDAP_BIND_DN}" -w "${LDAP_PASS}" \
        -b "${LDAP_BASE}" > "${TEMP_DIR}/avigest_ldap.ldif"
else
    docker exec avigest_openldap slapcat -b "${LDAP_BASE}" > "${TEMP_DIR}/avigest_ldap.ldif"
fi

if [[ -s "${TEMP_DIR}/avigest_ldap.ldif" ]]; then
    log "  -> Exportació LDAP completada ($(du -h "${TEMP_DIR}/avigest_ldap.ldif" | cut -f1))."
else
    log "  -> [ERROR] L'arxiu LDIF d'OpenLDAP és buit!"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Empaquetament i Suma de Verificació SHA-256
# ------------------------------------------------------------------------------
log "[3/5] Empaquetant arxius i calculant hash d'integritat..."
tar -czf "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" -C "${TEMP_DIR}" avigest_db.sql avigest_ldap.ldif
rm -rf "${TEMP_DIR}"

(cd "${BACKUP_LOCAL_DIR}" && sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256")
log "  -> Paquet generat: ${ARCHIVE_NAME} ($(du -h "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" | cut -f1))"

# ------------------------------------------------------------------------------
# 4. Sincronització amb el Disc Extern Simulat (/mnt/disc-extern-backup)
# ------------------------------------------------------------------------------
log "[4/5] Replicant la còpia al segon disc virtual de srv-backup (Estratègia 3-2-1)..."
if [[ -d "${EXTERNAL_DISK_MOUNT}/avigest_backups" ]]; then
    cp "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" "${EXTERNAL_DISK_MOUNT}/avigest_backups/"
    cp "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}.sha256" "${EXTERNAL_DISK_MOUNT}/avigest_backups/"
    log "  -> [OK] Còpia duplicada amb èxit al volum separat."
else
    log "  -> [AVÍS] Punt de muntatge extern no disponible; la còpia només s'ha desat en local."
fi

# ------------------------------------------------------------------------------
# 5. Política de Purga i Retenció (Rotació de còpies antigues > 30 dies)
# ------------------------------------------------------------------------------
log "[5/5] Netejant còpies més antigues de ${RETENTION_DAYS} dies..."
find "${BACKUP_LOCAL_DIR}" -name "backup_avigest_*.tar.gz*" -mtime +"${RETENTION_DAYS}" -delete
if [[ -d "${EXTERNAL_DISK_MOUNT}/avigest_backups" ]]; then
    find "${EXTERNAL_DISK_MOUNT}/avigest_backups" -name "backup_avigest_*.tar.gz*" -mtime +"${RETENTION_DAYS}" -delete
fi

log "=== CÒPIA DE SEGURETAT FINALITZADA SATISFACTÒRIAMENT ==="
