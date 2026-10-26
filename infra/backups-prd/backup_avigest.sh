#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Còpia de Seguretat per al Servidor Dedicat (srv-backup)
# Fitxer: infra/backups-prd/backup_avigest.sh
# Mòdul: ASIX - Projecte (Requeriment 4.5: Còpies i PRD)
# Responsable: Joan (Infraestructura, Xarxa i Seguretat)
#
# Descripció:
# Executat des de la màquina virtual dedicada srv-backup (10.0.20.20):
#   1. Extreu el buidatge transaccional de PostgreSQL 16 des de srv-serveis (10.0.20.10).
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

# Dades de connexió cap a srv-serveis
SRV_SERVEIS_HOST="10.0.20.10"
PG_PORT="5432"
PG_DB="avigest_db"
PG_USER="avigest_backup"
export PGPASSWORD="${PGPASSWORD:-backup_secret_pass_2026}"

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
# 1. Buidatge Transaccional de PostgreSQL 16 (srv-serveis:5432)
# ------------------------------------------------------------------------------
log "[1/5] Realitzant buidatge de la base de dades PostgreSQL 16..."

# Comprovem si s'executa amb client pg_dump directe o mitjançant Docker
if command -v pg_dump &>/dev/null; then
    pg_dump -h "${SRV_SERVEIS_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" \
        --clean --if-exists --format=plain > "${TEMP_DIR}/avigest_db.sql"
else
    # Fallback si s'executa a través de docker a srv-serveis
    docker exec avigest_postgres pg_dump -U avigest_app -d avigest_db > "${TEMP_DIR}/avigest_db.sql"
fi

if [[ -s "${TEMP_DIR}/avigest_db.sql" ]]; then
    log "  -> Dump de PostgreSQL completat correctament ($(du -h "${TEMP_DIR}/avigest_db.sql" | cut -f1))."
else
    log "  -> [ERROR] El dump de PostgreSQL és buit o la connexió ha fallat!"
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
sha256sum "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" > "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}.sha256"

log "  -> Arxiu creat: ${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME} ($(du -h "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" | cut -f1))"
log "  -> SHA-256: $(cat "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}.sha256" | cut -d' ' -f1)"

# ------------------------------------------------------------------------------
# 4. Còpia al Segon Disc Simulat (Ubicació Externa / Off-site)
# ------------------------------------------------------------------------------
log "[4/5] Copiant l'arxiu al segon disc virtual simulat (${EXTERNAL_DISK_MOUNT})..."
if [[ -d "${EXTERNAL_DISK_MOUNT}" ]]; then
    cp "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}" "${EXTERNAL_DISK_MOUNT}/avigest_backups/"
    cp "${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}.sha256" "${EXTERNAL_DISK_MOUNT}/avigest_backups/"
    log "  -> [OK] Còpia al segon disc virtual completada amb èxit."
else
    log "  -> [AVÍS] El segon disc (${EXTERNAL_DISK_MOUNT}) no està muntat. Es manté només la còpia local."
fi

# ------------------------------------------------------------------------------
# 5. Neteja de Temporals i Política de Retenció (30 dies)
# ------------------------------------------------------------------------------
log "[5/5] Aplicant retenció de ${RETENTION_DAYS} dies i netejant temporals..."
rm -rf "${TEMP_DIR}"

find "${BACKUP_LOCAL_DIR}" -name "backup_avigest_*.tar.gz*" -type f -mtime +"${RETENTION_DAYS}" -delete
if [[ -d "${EXTERNAL_DISK_MOUNT}/avigest_backups" ]]; then
    find "${EXTERNAL_DISK_MOUNT}/avigest_backups" -name "backup_avigest_*.tar.gz*" -type f -mtime +"${RETENTION_DAYS}" -delete
fi

log "=== CÒPIA DE SEGURETAT FINALITZADA AMB ÈXIT ==="
