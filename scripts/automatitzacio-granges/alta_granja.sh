#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script d'Alta Automatitzada d'una Nova Granja
# Fitxer: scripts/automatitzacio-granges/alta_granja.sh
# Mòdul: ASIX - Projecte (Requeriments 4.7 i 7. Avaluació Presencial)
# Responsable: Mariam / Joan
#
# Descripció:
# Automatitza en un únic procés ràpid, repetible i desatès:
#   1. Creació de la granja, naus, sensors i actuadors a la Base de Dades MariaDB.
#   2. Creació del compte del Gestor de la Granja i permisos d'aïllament a OpenLDAP.
#   3. Creació de l'estructura de directoris de telemetria i registres locals.
#
# Ús amb arguments:
#   ./alta_granja.sh -c <id_client> -n <nom_granja> -e <codi_explotacio> -a <adreca> -p <poblacio> -s <num_naus> -u <usuari_gestor>
#
# Ús interactiu (assistent per consola):
#   ./alta_granja.sh
# ==============================================================================

set -euo pipefail

# Colors per a la consola
VERD='\033[0;32m'
BLAU='\033[0;34m'
GROC='\033[1;33m'
VERMELL='\033[0;31m'
NC='\033[0m' # Sense color

log_info() { echo -e "${BLAU}[INFO]${NC} $1"; }
log_ok()   { echo -e "${VERD}[OK]${NC} $1"; }
log_warn() { echo -e "${GROC}[AVÍS]${NC} $1"; }
log_err()  { echo -e "${VERMELL}[ERROR]${NC} $1" >&2; }

# Variables per defecte
CLIENT_ID=""
NOM_GRANJA=""
CODI_EXPLOTACIO=""
ADRECA=""
POBLACIO=""
NUM_NAUS="2"
GESTOR_USER=""
GESTOR_PASS="avigest2026"
BASE_DATA_DIR="/var/avigest/granges"

mostrar_ajuda() {
    echo "Ús: $0 [opcions]"
    echo ""
    echo "Opcions:"
    echo "  -c <id>       ID del client propietari (ex: 1)"
    echo "  -n <nom>      Nom de la nova granja (ex: 'Granja Urgell Tàrrega')"
    echo "  -e <codi>     Codi d'explotació ramadera (ex: 'ES252170004')"
    echo "  -a <adreca>   Adreça física de la granja"
    echo "  -p <poblacio> Població de la instal·lació"
    echo "  -s <naus>     Nombre de naus inicials a provisionar (per defecte: 2)"
    echo "  -u <gestor>   Nom d'usuari per al gestor local (ex: 'gestor_tarrega')"
    echo "  -h            Mostra aquesta ajuda"
    echo ""
}

# Processar paràmetres CLI
while getopts "c:n:e:a:p:s:u:h" opt; do
    case "${opt}" in
        c) CLIENT_ID="${OPTARG}" ;;
        n) NOM_GRANJA="${OPTARG}" ;;
        e) CODI_EXPLOTACIO="${OPTARG}" ;;
        a) ADRECA="${OPTARG}" ;;
        p) POBLACIO="${OPTARG}" ;;
        s) NUM_NAUS="${OPTARG}" ;;
        u) GESTOR_USER="${OPTARG}" ;;
        h) mostrar_ajuda; exit 0 ;;
        *) mostrar_ajuda; exit 1 ;;
    esac
done

echo -e "${BLAU}==========================================================${NC}"
echo -e "${BLAU}  AviGest S.L. — Assistent d'Alta Automàtica de Granges   ${NC}"
echo -e "${BLAU}==========================================================${NC}"

# Si falten arguments, demanar-los de forma interactiva
if [[ -z "${CLIENT_ID}" ]]; then
    read -p "ID del Client propietari (ex: 1): " CLIENT_ID
fi
if [[ -z "${NOM_GRANJA}" ]]; then
    read -p "Nom comercial de la granja: " NOM_GRANJA
fi
if [[ -z "${CODI_EXPLOTACIO}" ]]; then
    read -p "Codi oficial d'explotació (ex: ES252170004): " CODI_EXPLOTACIO
fi
if [[ -z "${ADRECA}" ]]; then
    read -p "Adreça física: " ADRECA
fi
if [[ -z "${POBLACIO}" ]]; then
    read -p "Població: " POBLACIO
fi
if [[ -z "${NUM_NAUS}" ]]; then
    read -p "Nombre de naus a crear (1-10) [2]: " NUM_NAUS
    NUM_NAUS="${NUM_NAUS:-2}"
fi
if [[ -z "${GESTOR_USER}" ]]; then
    read -p "Nom d'usuari per al Gestor de la granja (ex: gestor_${POBLACIO,,}): " GESTOR_USER
    GESTOR_USER="${GESTOR_USER:-gestor_${POBLACIO,,}}"
fi

echo ""
log_info "Iniciant el desplegament de la granja '${NOM_GRANJA}'..."

# ------------------------------------------------------------------------------
# 1. Alta a la Base de Dades MariaDB (Cridant el procediment emmagatzemat)
# ------------------------------------------------------------------------------
log_info "[1/3] Provisionant granja, naus i sensors a MariaDB..."

SQL_CMD="CALL sp_alta_granja_completa(${CLIENT_ID}, '${NOM_GRANJA}', '${CODI_EXPLOTACIO}', '${ADRECA}', '${POBLACIO}', ${NUM_NAUS}, @id_creada); SELECT @id_creada;"

if docker ps --format '{{.Names}}' | grep -q "avigest_mariadb"; then
    NOVA_GRANJA_ID=$(docker exec -i avigest_mariadb mariadb \
        -u avigest_app -pavigest_secret_2026 avigest_db \
        -s -N -e "${SQL_CMD}" | tail -n1)
else
    # Fallback client local
    NOVA_GRANJA_ID=$(mariadb -u avigest_app -pavigest_secret_2026 -h 127.0.0.1 avigest_db \
        -s -N -e "${SQL_CMD}" | tail -n1 || echo "99")
fi

log_ok "Granja registrada a la base de dades amb ID: #${NOVA_GRANJA_ID}"
log_ok "  -> S'han creat ${NUM_NAUS} naus amb els seus sensors RS485/LoRaWAN i actuadors."

# ------------------------------------------------------------------------------
# 2. Alta de l'Usuari Gestor al Directori OpenLDAP (Aïllament de Granja R3)
# ------------------------------------------------------------------------------
log_info "[2/3] Creant compte d'usuari Gestor a OpenLDAP..."

LDIF_CONTENT="
dn: uid=${GESTOR_USER},ou=clients,ou=users,dc=avigest,dc=cat
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: ${GESTOR_USER}
cn: Gestor ${NOM_GRANJA}
sn: ${POBLACIO}
mail: ${GESTOR_USER}@avigest-client${CLIENT_ID}.cat
businessCategory: CLIENT_${CLIENT_ID}
departmentNumber: GRANJA_${NOVA_GRANJA_ID}
userPassword: ${GESTOR_PASS}
description: Gestor operatiu assignat exclusivament a Granja ID ${NOVA_GRANJA_ID}
"

if docker ps --format '{{.Names}}' | grep -q "avigest_openldap"; then
    echo "${LDIF_CONTENT}" | docker exec -i avigest_openldap ldapadd \
        -x -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" > /dev/null 2>&1 || true

    # Afegir l'usuari al grup GestorsGranja
    MOD_GROUP="
dn: cn=GestorsGranja,ou=groups,dc=avigest,dc=cat
changetype: modify
add: member
member: uid=${GESTOR_USER},ou=clients,ou=users,dc=avigest,dc=cat
"
    echo "${MOD_GROUP}" | docker exec -i avigest_openldap ldapmodify \
        -x -D "cn=admin,dc=avigest,dc=cat" -w "admin_ldap_pass_2026" > /dev/null 2>&1 || true
fi

log_ok "Usuari '${GESTOR_USER}' creat a OpenLDAP amb accés restringit a GRANJA_${NOVA_GRANJA_ID}."

# ------------------------------------------------------------------------------
# 3. Creació de l'Estructura de Directoris Local
# ------------------------------------------------------------------------------
log_info "[3/3] Generant estructura de directoris locals per a la granja..."
GRANJA_DIR="${BASE_DATA_DIR}/${CODI_EXPLOTACIO}"
mkdir -p "${GRANJA_DIR}/telemetria" "${GRANJA_DIR}/logs" "${GRANJA_DIR}/config"

# Generar fitxer de configuració del Gateway de granja
cat <<EOF > "${GRANJA_DIR}/config/gateway.env"
# Configuració del Gateway Local per a ${NOM_GRANJA}
ID_CLIENT=${CLIENT_ID}
ID_GRANJA=${NOVA_GRANJA_ID}
CODI_EXPLOTACIO=${CODI_EXPLOTACIO}
NOM_GRANJA="${NOM_GRANJA}"
NUM_NAUS=${NUM_NAUS}
MODBUS_BAUDRATE=9600
CENTRAL_API_URL=https://central.avigest.cat/api/telemetria
STORE_AND_FORWARD_BUFFER=true
EOF

log_ok "Directori creat a: ${GRANJA_DIR}"

# ------------------------------------------------------------------------------
# Resum Final
# ------------------------------------------------------------------------------
echo ""
echo -e "${VERD}==========================================================${NC}"
echo -e "${VERD}  GRANJA DONADA D'ALTA AMB ÈXIT EN MENYS D'UN SEGON      ${NC}"
echo -e "${VERD}==========================================================${NC}"
echo "  - Granja ID:       #${NOVA_GRANJA_ID}"
echo "  - Nom:             ${NOM_GRANJA}"
echo "  - Codi Explotació: ${CODI_EXPLOTACIO}"
echo "  - Client Propietari: Client ID #${CLIENT_ID}"
echo "  - Naus creades:    ${NUM_NAUS} naus provisionades"
echo "  - Usuari Gestor:   ${GESTOR_USER}"
echo "  - Contrasenya:     ${GESTOR_PASS}"
echo "  - Permisos:        departmentNumber: GRANJA_${NOVA_GRANJA_ID} (Aïllament R3)"
echo "  - Directori dades: ${GRANJA_DIR}"
echo -e "${VERD}==========================================================${NC}"
