#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Configuració del Tallafocs Perimetral i DMZ
# Fitxer: infra/dmz-tallafocs/firewall_regles.sh
# Mòdul: ASIX - Projecte (Requeriment 4.4)
# Responsable: Joan (Infraestructura i Seguretat)
#
# Descripció:
# Aplica una política de tall per defecte (DROP) i segmenta el trànsit en 3 zones:
#   - WAN (Internet): Entrada restringida per llista blanca d'IPs de clients.
#   - DMZ (Zona Desmilitaritzada): Portal web / API d'ingesta.
#   - LAN Interna (Zona d'Alta Seguretat): MariaDB (3306) i OpenLDAP (389).
# ==============================================================================

set -euo pipefail

# Comprovar privilegis de root
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Aquest script s'ha d'executar com a root (sudo)." >&2
   exit 1
fi

echo "=========================================================="
echo "  AviGest S.L. — Aplicant polítiques de tallafocs (DMZ)   "
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Definició de Variables de Xarxa i Interfícies
# ------------------------------------------------------------------------------
WAN_IF="eth0"                 # Interfície connectada a Internet / Router WAN
DMZ_IF="eth1"                 # Interfície de la xarxa DMZ
LAN_IF="eth2"                 # Interfície de la xarxa segura interna

DMZ_NET="192.168.100.0/24"    # Subxarxa DMZ (Web / Proxy)
LAN_NET="192.168.200.0/24"    # Subxarxa LAN Interna (MariaDB, LDAP)

WEB_SERVER_IP="192.168.100.10"
MARIADB_IP="192.168.200.20"
LDAP_IP="192.168.200.30"

# Llista blanca d'adreces IP de clients contractats (Requeriment 4.4)
CLIENT_IPS=(
    "198.51.100.10"   # Seu central Client 1 (AgroPonent S.L.)
    "203.0.113.25"    # Seu central Client 2 (Avícola del Segrià S.A.)
    "198.51.100.5"    # Oficines tècniques i VPN interna d'AviGest
)

# ------------------------------------------------------------------------------
# 2. Neteja de Regles Prèvies (Flush)
# ------------------------------------------------------------------------------
echo "[1/6] Netejant regles i cadenes anteriors..."
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X

# ------------------------------------------------------------------------------
# 3. Polítiques per Defecte: Principi de Mínim Privilegi (DROP)
# ------------------------------------------------------------------------------
echo "[2/6] Establint polítiques per defecte a DROP..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ------------------------------------------------------------------------------
# 4. Trànsit Local (Loopback) i Connexions Existents
# ------------------------------------------------------------------------------
echo "[3/6] Permetent loopback i connexions establertes/relacionades..."
# Permetre tot el trànsit sobre la interfície de loopback (lo)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Acceptar paquets que formen part de connexions ja establertes o relacionades
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Rebutjar paquets invàlids
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# ------------------------------------------------------------------------------
# 5. Seguretat Perimetral WAN -> DMZ (Llista Blanca)
# ------------------------------------------------------------------------------
echo "[4/6] Configurant llista blanca d'accés web (Requeriment 4.4)..."
# Creem una cadena dedicada per a gestionar la llista blanca de clients
iptables -N CLIENTS_WHITELIST

for IP in "${CLIENT_IPS[@]}"; do
    echo "  -> Autoritzant client amb IP: $IP"
    iptables -A CLIENTS_WHITELIST -s "$IP" -j ACCEPT
done

# Qualsevol altra IP que arribi a la cadena de llista blanca serà rebutjada i registrada
iptables -A CLIENTS_WHITELIST -m limit --limit 5/min -j LOG --log-prefix "[AVIGEST-BLOCKED-WAN]: "
iptables -A CLIENTS_WHITELIST -j DROP

# Permetre connexions noves HTTPS (443) i HTTP (80) només si provenen de la llista blanca
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -d "$WEB_SERVER_IP" -p tcp --dport 443 -m conntrack --ctstate NEW -j CLIENTS_WHITELIST
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -d "$WEB_SERVER_IP" -p tcp --dport 80 -m conntrack --ctstate NEW -j CLIENTS_WHITELIST

# ------------------------------------------------------------------------------
# 6. Trànsit DMZ -> LAN Interna (Accés estrictament controlat)
# ------------------------------------------------------------------------------
echo "[5/6] Controlant connexions entre DMZ i LAN Interna..."
# El servidor Web/Proxy de la DMZ pot consultar MariaDB (port 3306)
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$WEB_SERVER_IP" -d "$MARIADB_IP" -p tcp --dport 3306 -m conntrack --ctstate NEW -j ACCEPT

# El servidor Web/Proxy de la DMZ pot autenticar usuaris contra OpenLDAP (ports 389 i 636)
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$WEB_SERVER_IP" -d "$LDAP_IP" -p tcp --dport 389 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$WEB_SERVER_IP" -d "$LDAP_IP" -p tcp --dport 636 -m conntrack --ctstate NEW -j ACCEPT

# REGISTRE I BLOQUEIG de qualsevol altre intent des de la DMZ cap a la LAN interna
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -j LOG --log-prefix "[AVIGEST-DMZ-INTRUSION]: "
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -j DROP

# BLOQUEIG de qualsevol connexió directa des de la WAN cap a la LAN interna
iptables -A FORWARD -i "$WAN_IF" -o "$LAN_IF" -j DROP

# ------------------------------------------------------------------------------
# 7. Resum de l'Estat
# ------------------------------------------------------------------------------
echo "[6/6] Polítiques de tallafocs aplicades correctament."
echo "Regles actives per a FORWARD:"
iptables -L FORWARD -n -v --line-numbers
