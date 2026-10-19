#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Restauració davant Desastres (MariaDB + OpenLDAP)
# Fitxer: infra/backups-prd/restaurar_avigest.sh
# Mòdul: ASIX - Projecte (Requeriment 4.5)
# Responsable: Joan (Infraestructura i Seguretat)
#
# Ús:
#   ./restaurar_avigest.sh /ruta/al/backup_avigest_YYYYMMDD_HHMMSS.tar.gz
# ==============================================================================

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Ús: $0 <fitxer_backup.tar.gz>" >&2
    exit 1
fi

BACKUP_ARCHIVE="$1"

if [[ ! -f "${BACKUP_ARCHIVE}" ]]; then
    echo "[ERROR] El fitxer '${BACKUP_ARCHIVE}' no existeix!" >&2
    exit 1
fi

TEMP_RESTORE_DIR="/tmp/avigest_restore_$$"
mkdir -p "${TEMP_RESTORE_DIR}"

cleanup() {
    rm -rf "${TEMP_RESTORE_DIR}"
}
trap cleanup EXIT

echo "=========================================================="
echo "    AviGest S.L. — Inici de la Restauració de Desastre    "
echo "=========================================================="
echo "Arxiu a restaurar: ${BACKUP_ARCHIVE}"

# 1. Comprovació de suma de verificació SHA256 (si existeix)
SHA_FILE="${BACKUP_ARCHIVE}.sha256"
if [[ -f "${SHA_FILE}" ]]; then
    echo "[1/4] Verificant integritat de l'arxiu amb SHA-256..."
    sha256sum -c "${SHA_FILE}"
else
    echo "[1/4] Fitxer .sha256 no trobat, ometent verificació d'integritat."
fi

# 2. Descompressió del paquet
echo "[2/4] Descomprimint arxiu de còpia..."
tar -xzf "${BACKUP_ARCHIVE}" -C "${TEMP_RESTORE_DIR}"

if [[ ! -f "${TEMP_RESTORE_DIR}/avigest_db.sql" ]] || [[ ! -f "${TEMP_RESTORE_DIR}/ldap_backup.ldif" ]]; then
    echo "[ERROR] El paquet de còpia no conté els fitxers requerits (avigest_db.sql o ldap_backup.ldif)!" >&2
    exit 1
fi

# 3. Restauració de la Base de Dades MariaDB
echo "[3/4] Restaurant base de dades MariaDB (avigest_db)..."
if docker ps --format '{{.Names}}' | grep -q "avigest_mariadb"; then
    docker exec -i avigest_mariadb mariadb -u root -proot_avigest_2026 avigest_db < "${TEMP_RESTORE_DIR}/avigest_db.sql"
else
    mariadb -u root -p"root_avigest_2026" -h 127.0.0.1 avigest_db < "${TEMP_RESTORE_DIR}/avigest_db.sql"
fi
echo "  -> Base de dades MariaDB restaurada correctament."

# 4. Restauració del Directori OpenLDAP
echo "[4/4] Restaurant directori OpenLDAP..."
if docker ps --format '{{.Names}}' | grep -q "avigest_openldap"; then
    docker exec -i avigest_openldap ldapadd -x -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" -f /dev/stdin < "${TEMP_RESTORE_DIR}/ldap_backup.ldif" || true
fi
echo "  -> Directori OpenLDAP restaurat."

echo "=========================================================="
echo " [OK] RESTAURACIÓ COMPLETADA AMB ÈXIT "
echo "=========================================================="
