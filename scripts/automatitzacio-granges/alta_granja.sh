#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script d'Alta Automatitzada d'una Nova Granja (Requeriment 4.7)
# Fitxer: scripts/automatitzacio-granges/alta_granja.sh
# ==============================================================================

set -euo pipefail

VERD='\033[0;32m'
BLAU='\033[0;34m'
GROC='\033[1;33m'
VERMELL='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLAU}[INFO]${NC} $1"; }
log_ok()   { echo -e "${VERD}[OK]${NC} $1"; }
log_warn() { echo -e "${GROC}[AVÍS]${NC} $1"; }
log_err()  { echo -e "${VERMELL}[ERROR]${NC} $1" >&2; }

sql_escape() { printf "%s" "$1" | sed "s/'/''/g"; }

CLIENT_ID=""
NOM_GRANJA=""
CODI_EXPLOTACIO=""
ADRECA=""
POBLACIO=""
NUM_NAUS="2"
GESTOR_USER=""
GESTOR_PASS="avigest2026"
RANG_XARXA="10.1.2.0/24"
VPN_IP_ASSIGNADA=""
BASE_DATA_DIR="/var/avigest/granges"

HOST_SERVEIS="${HOST_SERVEIS:-10.0.20.10}"
PG_USER="avigest_app"
PG_PASS="avigest_secret_2026"
PG_DB="avigest_db"
LDAP_BIND_DN="cn=admin,dc=avigest,dc=cat"
LDAP_PASS="admin_ldap_pass_2026"

mostrar_ajuda() {
    echo "Ús: $0 [opcions]"
    echo "  -c <id>       ID del client propietari (ex: 1)"
    echo "  -n <nom>      Nom de la nova granja"
    echo "  -e <codi>     Codi d'explotació ramadera"
    echo "  -a <adreca>   Adreça física"
    echo "  -p <poblacio> Població"
    echo "  -s <naus>     Nombre de naus (per defecte: 2)"
    echo "  -u <gestor>   Nom d'usuari del gestor"
    echo "  -r <xarxa>    Rang LAN de la granja (per defecte: 10.1.2.0/24)"
    echo "  -i <ip>       IP WireGuard (si es buida: 10.0.100.<10+id_granja>)"
    echo "  -h            Ajuda"
}

while getopts "c:n:e:a:p:s:u:r:i:h" opt; do
    case "${opt}" in
        c) CLIENT_ID="${OPTARG}" ;;
        n) NOM_GRANJA="${OPTARG}" ;;
        e) CODI_EXPLOTACIO="${OPTARG}" ;;
        a) ADRECA="${OPTARG}" ;;
        p) POBLACIO="${OPTARG}" ;;
        s) NUM_NAUS="${OPTARG}" ;;
        u) GESTOR_USER="${OPTARG}" ;;
        r) RANG_XARXA="${OPTARG}" ;;
        i) VPN_IP_ASSIGNADA="${OPTARG}" ;;
        h) mostrar_ajuda; exit 0 ;;
        *) mostrar_ajuda; exit 1 ;;
    esac
done

echo -e "${BLAU}======================================================================${NC}"
echo -e "${BLAU}  AviGest S.L. — Assistent d'Alta Automàtica de Granges (4.7)          ${NC}"
echo -e "${BLAU}======================================================================${NC}"

if [[ -z "${CLIENT_ID}" ]]; then
    read -r -p "ID del Client propietari (ex: 1): " CLIENT_ID
fi
if [[ -z "${NOM_GRANJA}" ]]; then
    read -r -p "Nom comercial de la granja: " NOM_GRANJA
fi
if [[ -z "${CODI_EXPLOTACIO}" ]]; then
    read -r -p "Codi oficial d'explotació (ex: ES252170004): " CODI_EXPLOTACIO
fi
if [[ -z "${ADRECA}" ]]; then
    read -r -p "Adreça física: " ADRECA
fi
if [[ -z "${POBLACIO}" ]]; then
    read -r -p "Població: " POBLACIO
fi
if [[ -z "${NUM_NAUS}" ]]; then
    read -r -p "Nombre de naus a crear (1-10) [2]: " NUM_NAUS
    NUM_NAUS="${NUM_NAUS:-2}"
fi
if [[ -z "${GESTOR_USER}" ]]; then
    POBLACIO_CLEAN=$(echo "${POBLACIO}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 'y/áàéèíïóòúüñç/aaeeiioouunc/' 2>/dev/null || echo "${POBLACIO,,}")
    read -r -p "Nom d'usuari per al Gestor de la granja (ex: gestor_${POBLACIO_CLEAN}): " GESTOR_USER
    GESTOR_USER="${GESTOR_USER:-gestor_${POBLACIO_CLEAN}}"
fi

executar_sql() {
    local sql="$1"
    if command -v psql &>/dev/null; then
        PGPASSWORD="${PG_PASS}" psql -h "${HOST_SERVEIS}" -U "${PG_USER}" -d "${PG_DB}" -v ON_ERROR_STOP=1 -t -A -c "${sql}"
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q '^avigest_postgres$'; then
        docker exec -i avigest_postgres psql -U avigest_app -d avigest_db -v ON_ERROR_STOP=1 -t -A -c "${sql}"
    else
        log_err "No s'ha trobat psql ni el contenidor avigest_postgres. Abortant."
        exit 1
    fi
}

ldap_apply() {
    local ldif="$1"
    if command -v ldapadd &>/dev/null; then
        echo "${ldif}" | ldapadd -h "${HOST_SERVEIS}" -p 389 -x -D "${LDAP_BIND_DN}" -w "${LDAP_PASS}"
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q '^avigest_openldap$'; then
        echo "${ldif}" | docker exec -i avigest_openldap ldapadd -x -D "${LDAP_BIND_DN}" -w "${LDAP_PASS}"
    else
        log_err "No s'ha trobat ldapadd ni el contenidor avigest_openldap. Abortant."
        exit 1
    fi
}

ldap_modify() {
    local ldif="$1"
    if command -v ldapmodify &>/dev/null; then
        echo "${ldif}" | ldapmodify -h "${HOST_SERVEIS}" -p 389 -x -D "${LDAP_BIND_DN}" -w "${LDAP_PASS}"
    elif command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q '^avigest_openldap$'; then
        echo "${ldif}" | docker exec -i avigest_openldap ldapmodify -x -D "${LDAP_BIND_DN}" -w "${LDAP_PASS}"
    else
        log_err "No s'ha trobat ldapmodify ni OpenLDAP. Abortant."
        exit 1
    fi
}

echo ""
log_info "Iniciant el provisionament complet de '${NOM_GRANJA}'..."

# ------------------------------------------------------------------------------
# 1. Alta a PostgreSQL
# ------------------------------------------------------------------------------
log_info "[1/4] Creant esquema, naus, sensors i actuadors a PostgreSQL..."

SQL_QUERY="SELECT sp_alta_granja_completa(${CLIENT_ID}::int, '$(sql_escape "${NOM_GRANJA}")', '$(sql_escape "${CODI_EXPLOTACIO}")', '$(sql_escape "${ADRECA}")', '$(sql_escape "${POBLACIO}")', ${NUM_NAUS}::int);"
NOVA_GRANJA_ID="$(executar_sql "${SQL_QUERY}" | tr -d '[:space:]')"

if [[ -z "${NOVA_GRANJA_ID}" || ! "${NOVA_GRANJA_ID}" =~ ^[0-9]+$ ]]; then
    log_err "PostgreSQL no ha retornat un id_granja vàlid ('${NOVA_GRANJA_ID}')."
    exit 1
fi

if [[ -z "${VPN_IP_ASSIGNADA}" ]]; then
    VPN_OCTET=$((10 + NOVA_GRANJA_ID))
    if (( VPN_OCTET > 254 )); then
        log_err "No hi ha octet VPN lliure per a la granja ${NOVA_GRANJA_ID}."
        exit 1
    fi
    VPN_IP_ASSIGNADA="10.0.100.${VPN_OCTET}"
fi

log_ok "Granja registrada a PostgreSQL amb ID: #${NOVA_GRANJA_ID}"
log_ok "  -> S'han creat ${NUM_NAUS} naus amb sensors i actuadors."

# ------------------------------------------------------------------------------
# 2. Alta LDAP
# ------------------------------------------------------------------------------
log_info "[2/4] Creant compte d'usuari Gestor a OpenLDAP..."

case "${CLIENT_ID}" in
    1) LDAP_OU="client_agroponent" ;;
    2) LDAP_OU="client_segria" ;;
    *) LDAP_OU="client_${CLIENT_ID}" ;;
esac

GESTOR_DN="uid=${GESTOR_USER},ou=${LDAP_OU},ou=clients,ou=users,dc=avigest,dc=cat"

if [[ "${LDAP_OU}" == client_[0-9]* ]]; then
    OU_LDIF="dn: ou=${LDAP_OU},ou=clients,ou=users,dc=avigest,dc=cat
objectClass: top
objectClass: organizationalUnit
ou: ${LDAP_OU}
description: Empresa client ID ${CLIENT_ID}
"
    ldap_apply "${OU_LDIF}" || log_warn "OU ${LDAP_OU} ja existia o no s'ha pogut crear de nou."
fi

LDIF_ENTRY="dn: ${GESTOR_DN}
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
description: Gestor assignat exclusivament a Granja ID ${NOVA_GRANJA_ID} (${NOM_GRANJA})
"
ldap_apply "${LDIF_ENTRY}"

LDIF_MEMBER="dn: cn=GestorsGranja,ou=groups,dc=avigest,dc=cat
changetype: modify
add: member
member: ${GESTOR_DN}
"
ldap_modify "${LDIF_MEMBER}"

log_ok "Usuari '${GESTOR_USER}' creat a ${GESTOR_DN} (GRANJA_${NOVA_GRANJA_ID})."

# ------------------------------------------------------------------------------
# 3. Regla de tallafocs
# ------------------------------------------------------------------------------
log_info "[3/4] Generant regla de tallafocs per a ${RANG_XARXA} (VPN ${VPN_IP_ASSIGNADA})..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGLES_TALLAFOCS_DIR="${SCRIPT_DIR}/../../infra/dmz-tallafocs"
if [[ ! -d "${REGLES_TALLAFOCS_DIR}" ]]; then
    REGLES_TALLAFOCS_DIR="/opt/avigest-projecte/infra/dmz-tallafocs"
fi
mkdir -p "${REGLES_TALLAFOCS_DIR}"

cat <<EOF > "${REGLES_TALLAFOCS_DIR}/regla_granja_${NOVA_GRANJA_ID}.sh"
#!/usr/bin/env bash
# Granja ID ${NOVA_GRANJA_ID} (${NOM_GRANJA}) — només MQTT cap a srv-serveis
iptables -A FORWARD -s ${VPN_IP_ASSIGNADA} -d ${HOST_SERVEIS} -p tcp --dport 1883 -m conntrack --ctstate NEW -j ACCEPT
EOF
chmod +x "${REGLES_TALLAFOCS_DIR}/regla_granja_${NOVA_GRANJA_ID}.sh"

if [[ ${EUID} -eq 0 ]] && command -v iptables &>/dev/null; then
    bash "${REGLES_TALLAFOCS_DIR}/regla_granja_${NOVA_GRANJA_ID}.sh"
    log_ok "Regla de tallafocs injectada a les cadenes actives."
else
    log_ok "Fitxer de regla creat a ${REGLES_TALLAFOCS_DIR}/regla_granja_${NOVA_GRANJA_ID}.sh"
fi

# ------------------------------------------------------------------------------
# 4. Directoris del gateway
# ------------------------------------------------------------------------------
log_info "[4/4] Provisionant estructura de fitxers del gateway..."
GRANJA_DIR="${BASE_DATA_DIR}/${CODI_EXPLOTACIO}"
if ! mkdir -p "${GRANJA_DIR}/telemetria" "${GRANJA_DIR}/logs" "${GRANJA_DIR}/config" 2>/dev/null; then
    GRANJA_DIR="${SCRIPT_DIR}/../../var/granges/${CODI_EXPLOTACIO}"
    mkdir -p "${GRANJA_DIR}/telemetria" "${GRANJA_DIR}/logs" "${GRANJA_DIR}/config"
    log_warn "Sense permís a ${BASE_DATA_DIR}; s'ha usat ${GRANJA_DIR}"
fi

cat <<EOF > "${GRANJA_DIR}/config/gateway.env"
ID_CLIENT=${CLIENT_ID}
ID_GRANJA=${NOVA_GRANJA_ID}
CODI_EXPLOTACIO=${CODI_EXPLOTACIO}
NOM_GRANJA="${NOM_GRANJA}"
NUM_NAUS=${NUM_NAUS}
RANG_LOCAL=${RANG_XARXA}
VPN_LOCAL_IP=${VPN_IP_ASSIGNADA}
CENTRAL_MQTT_BROKER=10.0.20.10
CENTRAL_MQTT_PORT=1883
STORE_AND_FORWARD_BUFFER=true
EOF

log_ok "Configuració generada a: ${GRANJA_DIR}/config/gateway.env"

echo ""
echo -e "${VERD}======================================================================${NC}"
echo -e "${VERD}  GRANJA DONADA D'ALTA                                                ${NC}"
echo -e "${VERD}======================================================================${NC}"
echo "  - Granja ID:       #${NOVA_GRANJA_ID}"
echo "  - Nom:             ${NOM_GRANJA}"
echo "  - Codi Explotació: ${CODI_EXPLOTACIO}"
echo "  - Xarxa Granja:    ${RANG_XARXA} (VPN IP: ${VPN_IP_ASSIGNADA})"
echo "  - Client:          Client ID #${CLIENT_ID}"
echo "  - Naus creades:    ${NUM_NAUS}"
echo "  - Usuari Gestor:   ${GESTOR_USER} / Pass: ${GESTOR_PASS}"
echo "  - DN LDAP:         ${GESTOR_DN}"
echo "  - Permís LDAP:     departmentNumber: GRANJA_${NOVA_GRANJA_ID}"
echo "  - Regla Tallafocs: ${VPN_IP_ASSIGNADA} -> ${HOST_SERVEIS}:1883"
echo "  - Directori dades: ${GRANJA_DIR}"
echo -e "${VERD}======================================================================${NC}"
