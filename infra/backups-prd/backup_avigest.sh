#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Còpia de Seguretat Automàtica (MariaDB + OpenLDAP)
# Fitxer: infra/backups-prd/backup_avigest.sh
# Mòdul: ASIX - Projecte (Requeriment 4.5)
# Responsable: Joan (Infraestructura i Seguretat)
#
# Descripció:
# Executa un buidatge transaccional en calent de MariaDB i d'OpenLDAP, empaqueta
# els fitxers en un tar.gz datat, genera el hash SHA-256 i aplica la retenció.
# ==============================================================================

set -euo pipefail

# Directori base de còpies de seguretat
BACKUP_DIR="${BACKUP_DIR:-/var/backups/avigest}"
TEMP_DIR="${BACKUP_DIR}/tmp_$$"
LOG_FILE="${BACKUP_DIR}/backup.log"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="backup_avigest_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=30

mkdir -p "${BACKUP_DIR}" "${TEMP_DIR}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

log "=== INICI DEL PROCÉS DE CÒPIA DE SEGURETAT AVIGEST ==="

# ------------------------------------------------------------------------------
# 1. Buidatge de la Base de Dades MariaDB
# ------------------------------------------------------------------------------
log "[1/5] Realitzant buidatge transaccional de MariaDB (avigest_db)..."
# Si s'executa amb contenidors Docker:
if docker ps --format '{{.Names}}' | grep -q "avigest_mariadb"; then
    docker exec avigest_mariadb mariadb-dump \
        -u root -proot_avigest_2026 \
        --single-transaction \
        --routines \
        --triggers \
        --databases avigest_db > "${TEMP_DIR}/avigest_db.sql"
else
    # Fallback si s'executa en local amb client mariadb-dump
    mariadb-dump -u root -p"root_avigest_2026" -h 127.0.0.1 \
        --single-transaction --routines --triggers --databases avigest_db > "${TEMP_DIR}/avigest_db.sql"
fi

if [[ -s "${TEMP_DIR}/avigest_db.sql" ]]; then
    log "  -> Dump de MariaDB completat correctament ($(du -h "${TEMP_DIR}/avigest_db.sql" | cut -f1))."
else
    log "  -> [ERROR] El dump de MariaDB és buit o ha fallat!"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Exportació del Directori Centralitzat OpenLDAP
# ------------------------------------------------------------------------------
log "[2/5] Exportant l'arbre d'usuaris i grups d'OpenLDAP..."
if docker ps --format '{{.Names}}' | grep -q "avigest_openldap"; then
    docker exec avigest_openldap slapcat -b "dc=avigest,dc=cat" > "${TEMP_DIR}/ldap_backup.ldif"
else
    # Fallback amb comanda ldapsearch
    ldapsearch -x -H ldap://127.0.0.1:389 -b "dc=avigest,dc=cat" -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" > "${TEMP_DIR}/ldap_backup.ldif"
fi

log "  -> Directori LDAP exportat correctament."

# ------------------------------------------------------------------------------
# 3. Empaquetament i Compressió
# ------------------------------------------------------------------------------
log "[3/5] Comprimint còpia en format tar.gz..."
tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "${TEMP_DIR}" avigest_db.sql ldap_backup.ldif

# Generar suma de comprovació SHA256 per a verificar integritat
sha256sum "${BACKUP_DIR}/${ARCHIVE_NAME}" > "${BACKUP_DIR}/${ARCHIVE_NAME}.sha256"
log "  -> Arxiu generat: ${ARCHIVE_NAME} ($(du -h "${BACKUP_DIR}/${ARCHIVE_NAME}" | cut -f1))"

# Netejar temporal
rm -rf "${TEMP_DIR}"

# ------------------------------------------------------------------------------
# 4. Rotació i Política de Retenció (Eliminar còpies antigues)
# ------------------------------------------------------------------------------
log "[4/5] Aplicant política de retenció (eliminant arxius de més de ${RETENTION_DAYS} dies)..."
find "${BACKUP_DIR}" -name "backup_avigest_*.tar.gz*" -mtime "+${RETENTION_DAYS}" -exec rm -f {} \;

# ------------------------------------------------------------------------------
# 5. Sincronització Remota (Opcional si hi ha servidor/NAS remot definit)
# ------------------------------------------------------------------------------
REMOTE_BACKUP_DEST="${REMOTE_BACKUP_DEST:-}"
if [[ -n "${REMOTE_BACKUP_DEST}" ]]; then
    log "[5/5] Sincronitzant paquet cap a la ubicació remota (${REMOTE_BACKUP_DEST})..."
    rsync -avz -e "ssh -o BatchMode=yes" "${BACKUP_DIR}/${ARCHIVE_NAME}"* "${REMOTE_BACKUP_DEST}"
    log "  -> Sincronització remota completada."
else
    log "[5/5] Sincronització remota omesa (destinació REMOTE_BACKUP_DEST no definida)."
fi

log "=== CÒPIA DE SEGURETAT FINALITZADA AMB ÈXIT ==="
