# AviGest — Sistema de gestió centralitzada de granges avícoles

Projecte de mòdul ASIX (CFGS Administració de Sistemes Informàtics en Xarxa).
Equip: Joan i Mariam.

## Estructura del repositori

```
avigest-projecte/
├── docs/                       # Documentació de totes les fases
│   ├── E1_estudi_necessitats/
│   ├── E2_disseny_tecnic/
│   ├── E3_pla_intervencio/
│   ├── E4_pla_seguiment/
│   ├── fitxes_decisio/         # Una fitxa per cada decisió tècnica rellevant
│   └── diari_treball/          # Diari setmanal, lliurament quinzenal
├── infra/                      # Àrea de Joan
│   ├── ldap/                   # Usuaris i grups centralitzats
│   ├── dmz-tallafocs/          # DMZ i regles de tallafocs
│   ├── backups-prd/            # Còpies de seguretat i pla de recuperació
│   └── xarxa/                  # Topologia, maquinari, redundància
├── bd/                         # Àrea de Mariam
│   ├── model-er/               # Diagrama Entitat-Relació
│   ├── sql/                    # Esquema, dades de prova
│   └── procediments-triggers/  # Triggers, procediments emmagatzemats
├── iot/                        # Àrea de Mariam
│   ├── sensors/
│   ├── actuadors/
│   └── comunicacions/          # LoRaWAN / RS485
├── scripts/
│   └── automatitzacio-granges/ # Alta automàtica d'una granja nova
├── docker/                     # docker-compose.yml (LDAP, BD...)
└── web/                        # Pàgina web d'administració (4.extra)
    ├── admin-avigest/          # Visió AviGest
    └── admin-client/           # Visió client
```

## Flux de treball
- Branca `main` sempre estable.
- Branques per àrea: `infra/`, `bd/`, `iot/`, `scripts/`, `web/`.
- Cada decisió tècnica rellevant necessita una fitxa a `docs/fitxes_decisio/` **abans** d'implementar-se.
- El diari de treball es lliura quinzenalment a `docs/diari_treball/`.
- Tauler de tasques: GitHub Projects d'aquest repositori.

## Fites del projecte
- [E0 — Constitució i Rols](docs/E0_divisio_tasques_rols.md)
- [E2 — Document de Disseny Tècnic](docs/E2_disseny_tecnic/E2_document_disseny_tecnic.md)
- [Diari de Treball (Actualització quinzenal)](docs/diari_treball/diari_treball.md)

## Guia de Laboratori i Desplegament en Màquines Virtuals
> [!TIP]
> **Consulteu la guia pas a pas:** [docs/guia_desplegament_maquines_virtuals.md](docs/guia_desplegament_maquines_virtuals.md) per a les instruccions exactes de configuració a VMware / VirtualBox i el guió per a la defensa davant del professor.

### Arrencada ràpida dels serveis (Seu Central)
```bash
cd docker
docker compose up -d
```
- **phpMyAdmin (Base de dades):** `http://localhost:8080` (Usuari: `avigest_app`, Pass: `avigest_secret_2026`)
- **phpLDAPadmin (Directori d'usuaris):** `http://localhost:8081` (Login DN: `cn=admin,dc=avigest,dc=cat`, Pass: `admin_ldap_pass_2026`)

## Fitxes de Decisió Tècnica Oficials
1. [FD01 — Elecció del SGBD (MariaDB vs PostgreSQL)](docs/fitxes_decisio/FD01_sgbd.md)
2. [FD02 — Servidor d'Usuaris Centralitzat (OpenLDAP vs Samba 4)](docs/fitxes_decisio/FD02_ldap.md)
3. [FD03 — Tallafocs i DMZ (iptables amb Llista Blanca de clients)](docs/fitxes_decisio/FD03_tallafocs_dmz.md)
4. [FD04 — Estratègia de Còpies de Seguretat i PRD](docs/fitxes_decisio/FD04_backups_prd.md)
5. [FD05 — Comunicacions IoT (RS485 a naus vs LoRaWAN a silos)](docs/fitxes_decisio/FD05_iot_comunicacions.md)

