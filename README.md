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
Vegeu `docs/E0_divisio_tasques_rols.md` per al Gantt inicial i la divisió de rols.
