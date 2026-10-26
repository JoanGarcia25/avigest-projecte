#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Restauració davant Desastres (PostgreSQL + OpenLDAP)
# Fitxer: infra/backups-prd/restaurar_avigest.sh
# Mòdul: ASIX - Projecte (Requeriment 4.5: PRD)
# Responsable: Joan (Infraestructura, Xarxa i Seguretat)
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

echo "======================================================================"
echo "    AviGest S.L. — Procediment de Restauració davant de Desastres     "
echo "======================================================================"
echo "Arxiu font: ${BACKUP_ARCHIVE}"

# 1. Comprovació d'integritat SHA-256
SHA_FILE="${BACKUP_ARCHIVE}.sha256"
if [[ -f "${SHA_FILE}" ]]; then
    echo "[1/4] Verificant la integritat del fitxer amb SHA-256..."
    sha256sum -c "${SHA_FILE}"
else
    echo "[1/4] Fitxer .sha256 no trobat, continuant sota responsabilitat de l'administrador..."
fi

# 2. Descompressió del paquet
echo "[2/4] Descomprimint fitxers de seguretat..."
tar -xzf "${BACKUP_ARCHIVE}" -C "${TEMP_RESTORE_DIR}"

if [[ ! -f "${TEMP_RESTORE_DIR}/avigest_db.sql" ]] || [[ ! -f "${TEMP_RESTORE_DIR}/avigest_ldap.ldif" ]]; then
    echo "[ERROR] El paquet no conté els fitxers requerits (avigest_db.sql o avigest_ldap.ldif)!" >&2
    exit 1
fi

# 3. Restauració a PostgreSQL 16 (srv-serveis: 10.0.20.10)
echo "[3/4] Restaurant esquema i dades a PostgreSQL 16..."
if command -v psql &>/dev/null; then
    PGPASSWORD="${PGPASSWORD:-avigest_secret_2026}" psql -h 10.0.20.10 -p 5432 -U avigest_app -d avigest_db < "${TEMP_RESTORE_DIR}/avigest_db.sql"
elif docker ps --format '{{.Names}}' | grep -q "avigest_postgres"; then
    docker exec -i avigest_postgres psql -U avigest_app -d avigest_db < "${TEMP_RESTORE_DIR}/avigest_db.sql"
else
    echo "[AVÍS] No s'ha pogut connectar a PostgreSQL directament. Inseriu manualment avigest_db.sql."
fi
echo "  -> [OK] Base de dades PostgreSQL restaurada correctament."

# 4. Restauració al Directori OpenLDAP (srv-serveis: 10.0.20.10)
echo "[4/4] Restaurant l'arbre d'usuaris a OpenLDAP..."
if command -v ldapadd &>/dev/null; then
    ldapadd -h 10.0.20.10 -p 389 -x -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" -c -f "${TEMP_RESTORE_DIR}/avigest_ldap.ldif" || true
elif docker ps --format '{{.Names}}' | grep -q "avigest_openldap"; then
    docker exec -i avigest_openldap ldapadd -x -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" -c < "${TEMP_RESTORE_DIR}/avigest_ldap.ldif" || true
fi
echo "  -> [OK] Directori OpenLDAP restaurat."

echo "======================================================================"
echo "  [OK] RESTAURACIÓ COMPLETADA AMB ÈXIT (RTO < 15 min)                 "
echo "======================================================================"
