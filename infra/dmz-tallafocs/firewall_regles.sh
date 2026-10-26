#!/usr/bin/env bash
# ==============================================================================
# AviGest S.L. — Script de Configuració i Equivalència de Regles del Tallafocs
# Fitxer: infra/dmz-tallafocs/firewall_regles.sh
# Mòdul: ASIX - Projecte (Requeriment 4.4: Regles documentades i justificades)
# Responsable: Joan (Infraestructura, Xarxa i Seguretat)
#
# Descripció:
# Implementa la política estricta de tallafocs de 3 potes (WAN, DMZ, LAN) + VPN
# aplicable tant a fw-seu (OPNsense) com a tallafocs Linux basat en iptables.
#
# TOPOLOGIA I ZONES:
#   - WAN (Internet): eth0 (Enllaç públic o NAT hipervisor)
#   - DMZ:            eth1 (10.0.10.0/24) -> Allotja dmz-web (10.0.10.10)
#   - LAN seu:        eth2 (10.0.20.0/24) -> srv-serveis (10.0.20.10), srv-backup (10.0.20.20)
#   - VPN:            tun0/wg0 (10.0.100.0/24) -> granja1-srv (10.0.100.10)
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Aquest script s'ha d'executar amb privilegis de root (sudo)." >&2
   exit 1
fi

echo "======================================================================"
echo "  AviGest S.L. — Aplicant regles del tallafocs perimetral (fw-seu)    "
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Variables de Xarxa i Adreces IP de les Màquines Virtuals
# ------------------------------------------------------------------------------
WAN_IF="eth0"
DMZ_IF="eth1"
LAN_IF="eth2"
VPN_IF="tun0"

DMZ_NET="10.0.10.0/24"
LAN_NET="10.0.20.0/24"
VPN_NET="10.0.100.0/24"

DMZ_WEB_IP="10.0.10.10"
SRV_SERVEIS_IP="10.0.20.10"
SRV_BACKUP_IP="10.0.20.20"

# Llista blanca d'IPs de clients contractats autoritzats a accedir al portal web
CLIENT_IPS=(
    "198.51.100.10"   # Exemple IP pública Client 1 (AgroPonent S.L.)
    "203.0.113.25"    # Exemple IP pública Client 2 (Avícola del Segrià S.A.)
    "10.0.2.2"        # IP de NAT de pc-client a entorn de laboratori hipervisor
)

# ------------------------------------------------------------------------------
# 2. Neteja de Regles Prèvies (Flush)
# ------------------------------------------------------------------------------
echo "[1/6] Netejant regles anteriors..."
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X

# ------------------------------------------------------------------------------
# 3. Política per Defecte: MÍNIM PRIVILEGI (DROP GLOBAL)
# ------------------------------------------------------------------------------
echo "[2/6] Aplicant política per defecte DROP a totes les cadenes..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ------------------------------------------------------------------------------
# 4. Loopback i Connexions Establertes (Stateful Inspection)
# ------------------------------------------------------------------------------
echo "[3/6] Habilitant loopback i connexions establertes/relacionades..."
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# ------------------------------------------------------------------------------
# 5. REGLES WAN -> DMZ (Accés dels clients al portal web)
# JUSTIFICACIÓ: Només les empreses que han contractat el servei poden accedir
# al portal. Tota la resta d'Internet queda completament bloquejada.
# ------------------------------------------------------------------------------
echo "[4/6] Configurant llista blanca d'accés client (WAN -> DMZ)..."
iptables -N CLIENTS_WHITELIST
for IP in "${CLIENT_IPS[@]}"; do
    echo "  -> Autoritzant accés HTTPS per a client: $IP"
    iptables -A CLIENTS_WHITELIST -s "$IP" -j ACCEPT
done
iptables -A CLIENTS_WHITELIST -m limit --limit 5/min -j LOG --log-prefix "[AVIGEST-BLOCKED-WAN]: "
iptables -A CLIENTS_WHITELIST -j DROP

# Reenviament de WAN a DMZ únicament a ports 443 (HTTPS) i 80 (HTTP) si són a la llista
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -d "$DMZ_WEB_IP" -p tcp --dport 443 -m conntrack --ctstate NEW -j CLIENTS_WHITELIST
iptables -A FORWARD -i "$WAN_IF" -o "$DMZ_IF" -d "$DMZ_WEB_IP" -p tcp --dport 80 -m conntrack --ctstate NEW -j CLIENTS_WHITELIST

# Port del túnel VPN a fw-seu (OpenVPN / WireGuard) des de la WAN
iptables -A INPUT -i "$WAN_IF" -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -i "$WAN_IF" -p udp --dport 51820 -j ACCEPT

# ------------------------------------------------------------------------------
# 6. REGLES DMZ -> LAN (Aïllament estricte de la zona DMZ)
# JUSTIFICACIÓ CRÍTICA: Si el servidor web és compromès, l'atacant NO pot
# escanejar la LAN, ni atacar srv-backup, ni accedir per SSH. Únicament
# pot connectar a la BD (PostgreSQL: 5432) i al directori d'usuaris (LDAP: 389/636).
# ------------------------------------------------------------------------------
echo "[5/6] Aplicant aïllament estricte DMZ -> LAN..."

# Permès 1: Consultes SQL del portal web cap a srv-serveis (PostgreSQL)
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$DMZ_WEB_IP" -d "$SRV_SERVEIS_IP" -p tcp --dport 5432 -m conntrack --ctstate NEW -j ACCEPT

# Permès 2: Validació d'autenticació LDAP cap a srv-serveis (OpenLDAP)
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$DMZ_WEB_IP" -d "$SRV_SERVEIS_IP" -p tcp --dport 389 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -s "$DMZ_WEB_IP" -d "$SRV_SERVEIS_IP" -p tcp --dport 636 -m conntrack --ctstate NEW -j ACCEPT

# Bloqueig explícit i auditat de qualsevol altre intent DMZ cap a LAN
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -m limit --limit 3/min -j LOG --log-prefix "[AVIGEST-INTRUSION-DMZ2LAN]: "
iptables -A FORWARD -i "$DMZ_IF" -o "$LAN_IF" -j DROP

# ------------------------------------------------------------------------------
# 7. REGLES VPN (Granges) -> LAN
# JUSTIFICACIÓ CRÍTICA: Els gateways de granja (granja1-srv) NO tenen permís
# per connectar directament a la base de dades ni a LDAP. Únicament publiquen
# les seves telemetries al Broker MQTT de la seu central (1883 / 8883).
# ------------------------------------------------------------------------------
echo "[6/6] Aplicant aïllament de tràfic VPN de granja cap a la LAN..."

# Permès: Trànsit MQTT cap a srv-serveis
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -s "$VPN_NET" -d "$SRV_SERVEIS_IP" -p tcp --dport 1883 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -s "$VPN_NET" -d "$SRV_SERVEIS_IP" -p tcp --dport 8883 -m conntrack --ctstate NEW -j ACCEPT

# Bloqueig explícit i auditat de qualsevol altre trànsit de la granja cap a la LAN
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -m limit --limit 3/min -j LOG --log-prefix "[AVIGEST-BLOCKED-VPN2LAN]: "
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -j DROP

echo "======================================================================"
echo "  [OK] Regles de tallafocs aplicades i actives amb èxit.              "
echo "======================================================================"
