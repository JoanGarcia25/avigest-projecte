# AviGest — Sistema de gestió centralitzada de granges avícoles

Projecte de mòdul ASIX (CFGS Administració de Sistemes Informàtics en Xarxa).  
Equip: **Joan** (Infraestructura, Xarxa i Seguretat) i **Mariam** (Base de Dades, IoT i Automatització).

---

## 1. Topologia de Màquines Virtuals

La infraestructura d'AviGest es desplega mitjançant un conjunt coordinat de 6 màquines virtuals. Seguint la recomanació del professor d'unificar sistemes operatius i no barrejar distribucions, **els 5 servidors de serveis utilitzen Ubuntu Server 24.04 LTS** (a partir de la plantilla màster `ubuntu-base` i xarxa Netplan), mantenint **OPNsense** exclusivament com a appliance de seguretat dedicat:

- **`pc-client`:** Navegador web de prova de l'empresa client connectada a través d'Internet (NAT).
- **`fw-seu`:** Tallafocs perimetral OPNsense de 3 interfícies físiques (WAN, DMZ `10.0.10.0/24`, LAN `10.0.20.0/24`) i servidor VPN WireGuard (`10.0.100.0/24`).
- **`dmz-web`:** Proxy invers Nginx, WAF i relay SMTP (`10.0.10.10` a Ubuntu 24.04). Únic servei exposat a Internet sota llista blanca d'IPs de clients.
- **`srv-serveis`:** Nucli intern de la seu (`10.0.20.10` a Ubuntu 24.04): PostgreSQL 16 + Rèplica, Broker MQTT Mosquitto i OpenLDAP.
- **`srv-backup`:** Servidor dedicat de còpies de seguretat (`10.0.20.20` a Ubuntu 24.04) amb cron nocturn i un segon disc virtual simulat (/mnt).
- **`granja1-srv`:** Gateway de camp (`10.1.1.10` a Ubuntu 24.04 / VPN WireGuard `10.0.100.10`): regles locals d'actuadors (>31ºC), buffer *store-and-forward* i client VPN.
- **`granja1-sim`:** Simulador de camp (`10.1.1.20` a Ubuntu 24.04): ESP32 (RS485 Modbus) i silos LoRaWAN (ChirpStack).

> [!TIP]
> **Consulteu les guies de desplegament de laboratori:**
> - [Guia de desplegament de la topologia de VMs (amb plantilles Netplan)](docs/guia_desplegament_maquines_virtuals.md)
> - [Guia del laboratori virtual d'AviGest (PDF)](docs/Guies_MV/Guia%20del%20laboratori%20virtual%20d’AviGest.pdf)
> - [Guia pas a pas de plantilles i xarxes virtuals (Word)](docs/Guies_MV/Pas%20a%20pas%20plantilla%20debian-base%20i%20xarxes%20virtuals.docx)


---

## 2. Arrencada dels serveis centrals (`srv-serveis`)

A la màquina virtual `srv-serveis` (`10.0.20.10`):
```bash
cd /opt/avigest-projecte/docker
docker compose up -d
```

Serveis actius:
- **PostgreSQL 16 (primari):** Port `5432` (Usuari: `avigest_app`, Pass: `avigest_secret_2026`, BD: `avigest_db`)
- **PostgreSQL rèplica (Hot Standby):** Port `5433` (streaming replication; només lectura)
- **Broker MQTT Mosquitto:** Port `1883` (el túnel WireGuard xifra el trànsit de granja)
- **Ingesta MQTT:** contenidor `avigest_mqtt_ingest` (subscriu `avigest/+/telemetria/#` i fa `INSERT` amb el rol `avigest_iot`)
- **OpenLDAP:** Port `389` / `636` (Base: `dc=avigest,dc=cat`; usuaris de prova: contrasenya `avigest2026`)
- **phpLDAPadmin:** `http://localhost:8081` (Login DN: `cn=admin,dc=avigest,dc=cat`, Pass: `admin_ldap_pass_2026`)

Prova RLS (no feu servir `avigest_app`, és superusuari i no filtra files):
```bash
docker exec -it avigest_postgres psql -U avigest_consulta -d avigest_db -c "SELECT sp_set_tenant(1); SELECT nom_granja FROM granges;"
```

---

## 3. Fitxes de Decisió Tècnica Oficials

1. [FD01 — Elecció del SGBD (PostgreSQL 16 amb Streaming Replication)](docs/fitxes_decisio/FD01_sgbd.md)
2. [FD02 — Servidor d'Usuaris Centralitzat (OpenLDAP + phpLDAPadmin)](docs/fitxes_decisio/FD02_ldap.md)
3. [FD03 — Tallafocs OPNsense i DMZ amb Llista Blanca de clients](docs/fitxes_decisio/FD03_tallafocs_dmz.md)
4. [FD04 — Estratègia de Còpies de Seguretat (srv-backup dedicat + 2n disc)](docs/fitxes_decisio/FD04_backups_prd.md)
5. [FD05 — Comunicacions IoT (Edge Computing RS485 + LoRaWAN + MQTT)](docs/fitxes_decisio/FD05_iot_comunicacions.md)

---

## 4. Fites del Projecte i Documents Oficials

- [E0 — Constitució d'Equip i Rols](docs/E0_divisio_tasques_rols.md)
- [E1 — Estudi de Necessitats del Sector (PDF)](docs/E1_estudi_necessitats_joangarcia_mariamsolano%20(2).pdf)
- [E2 — Document de Disseny Tècnic Oficial](docs/E2_disseny_tecnic/E2_document_disseny_tecnic.md)
- [E3 — Pla d'Intervenció, Recursos, Costos i Rols](docs/E3_pla_intervencio/E3_pla_intervencio.md)
- [Diari de Treball i Sessions](docs/diari_treball/diari_treball.md)
- [Guies de Laboratori Virtual (Debian Base i VirtualBox)](docs/Guies_MV/)
- [Arquitectura i Justificació de la Base de Dades (10 Taules, RLS, Triggers)](bd/explicacio_disseny_base_dades.md)
- [Model Entitat-Relació (ER)](bd/model-er/model_er.md)


