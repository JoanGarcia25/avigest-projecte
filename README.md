# AviGest — Sistema de gestió centralitzada de granges avícoles

Projecte de mòdul ASIX (CFGS Administració de Sistemes Informàtics en Xarxa).  
Equip: **Joan** (Infraestructura, Xarxa i Seguretat) i **Mariam** (Base de Dades, IoT i Automatització).

---

## 1. Topologia de Màquines Virtuals

La infraestructura d'AviGest es desplega mitjançant un conjunt coordinat de màquines virtuals:

- **`pc-client`:** Navegador web de prova de l'empresa client connectada a través d'Internet (NAT).
- **`fw-seu`:** Tallafocs perimetral OPNsense de 3 interfícies físiques (WAN, DMZ `10.0.10.0/24`, LAN `10.0.20.0/24`) i servidor VPN (`10.0.100.0/24`).
- **`dmz-web`:** Proxy invers Nginx, WAF i relay SMTP (`10.0.10.10`). Únic servei exposat a Internet sota llista blanca d'IPs de clients.
- **`srv-serveis`:** Nucli intern de la seu (`10.0.20.10`): PostgreSQL 16 + Rèplica, Broker MQTT Mosquitto i OpenLDAP.
- **`srv-backup`:** Servidor dedicat de còpies de seguretat (`10.0.20.20`) amb cron nocturn i un segon disc virtual simulat.
- **`granja1-srv`:** Gateway de camp (`10.1.1.10` / VPN `10.0.100.10`): regles locals d'actuadors (>31ºC), buffer *store-and-forward* i client VPN.
- **`granja1-sim`:** Simulador de camp (`10.1.1.20`): ESP32 (RS485 Modbus) i silos LoRaWAN (ChirpStack).

> [!TIP]
> **Consulteu la guia pas a pas:** [docs/guia_desplegament_maquines_virtuals.md](docs/guia_desplegament_maquines_virtuals.md) per a les instruccions exactes de configuració a VMware / VirtualBox i el guió per a la defensa davant del professor.

---

## 2. Arrencada dels serveis centrals (`srv-serveis`)

A la màquina virtual `srv-serveis` (`10.0.20.10`):
```bash
cd /opt/avigest-projecte/docker
docker compose up -d
```

Serveis actius:
- **PostgreSQL 16 (Base de Dades):** Port `5432` (Usuari: `avigest_app`, Pass: `avigest_secret_2026`, BD: `avigest_db`)
- **PostgreSQL Rèplica:** Port `5433` (Hot Standby local de demostració)
- **Broker MQTT Mosquitto:** Port `1883` (Recepció de telemetria des de la VPN de granja)
- **OpenLDAP (Directori d'usuaris):** Port `389` / `636` (Base: `dc=avigest,dc=cat`)
- **phpLDAPadmin (Interfície web LDAP):** `http://localhost:8081` (Login DN: `cn=admin,dc=avigest,dc=cat`, Pass: `admin_ldap_pass_2026`)

---

## 3. Fitxes de Decisió Tècnica Oficials

1. [FD01 — Elecció del SGBD (PostgreSQL 16 amb Streaming Replication)](docs/fitxes_decisio/FD01_sgbd.md)
2. [FD02 — Servidor d'Usuaris Centralitzat (OpenLDAP + phpLDAPadmin)](docs/fitxes_decisio/FD02_ldap.md)
3. [FD03 — Tallafocs OPNsense i DMZ amb Llista Blanca de clients](docs/fitxes_decisio/FD03_tallafocs_dmz.md)
4. [FD04 — Estratègia de Còpies de Seguretat (srv-backup dedicat + 2n disc)](docs/fitxes_decisio/FD04_backups_prd.md)
5. [FD05 — Comunicacions IoT (Edge Computing RS485 + LoRaWAN + MQTT)](docs/fitxes_decisio/FD05_iot_comunicacions.md)

---

## 4. Fites del Projecte

- [E0 — Constitució d'Equip i Rols](docs/E0_divisio_tasques_rols.md)
- [E1 — Estudi de Necessitats del Sector (PDF)](docs/E1_estudi_necessitats_joangarcia_mariamsolano%20(2).pdf)
- [E2 — Document de Disseny Tècnic Oficial](docs/E2_disseny_tecnic/E2_document_disseny_tecnic.md)
- [E3 — Pla d'Intervenció, Recursos, Costos i Rols](docs/E3_pla_intervencio/E3_pla_intervencio.md)
- [Diari de Treball i Sessions](docs/diari_treball/diari_treball.md)

