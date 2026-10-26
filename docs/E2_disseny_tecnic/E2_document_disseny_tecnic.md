# E2 — Document de Disseny Tècnic del Projecte
**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Empresa:** AviGest S.L.  
**Cicle:** CFGS Administració de Sistemes Informàtics en Xarxa (ASIX) — 2n Curs  
**Mòdul:** M12 - Projecte (Pes: 20%)  
**Equip de treball:** Joan (Infraestructura, Xarxa i Seguretat) i Mariam (Base de Dades, IoT i Automatització)  
**Data:** Actualitzat a 26 d'octubre de 2026 (Lliurament oficial: 4 de desembre de 2026)  

---

## Índex de Continguts
1. [Introducció i Visió Global del Sistema](#1-introducció-i-visió-global-del-sistema)
2. [Arquitectura de Màquines Virtuals i Xarxa](#2-arquitectura-de-màquines-virtuals-i-xarxa)
3. [Fitxes de Decisió Tècnica (Resum Executiu)](#3-fitxes-de-decisió-tècnica-resum-executiu)
4. [Infraestructura de Maquinari i Redundància (Requeriments 4.1 i 4.6)](#4-infraestructura-de-maquinari-i-redundància-requeriments-41-i-46)
5. [Seguretat Perimetral: OPNsense, DMZ i Tallafocs (Requeriment 4.4)](#5-seguretat-perimetral-opnsense-dmz-i-tallafocs-requeriment-44)
6. [Directori Centralitzat d'Usuaris — OpenLDAP (Requeriment 4.2)](#6-directori-centralitzat-dusuaris--openldap-requeriment-42)
7. [Base de Dades Centralitzada: PostgreSQL 16 i Rèplica (Requeriment 4.3)](#7-base-de-dades-centralitzada-postgresql-16-i-rèplica-requeriment-43)
8. [Arquitectura IoT: Simulació, Edge Computing i Comunicacions (Requeriment 4.8)](#8-arquitectura-iot-simulació-edge-computing-i-comunicacions-requeriment-48)
9. [Còpies de Seguretat i Servidor Dedicat — PRD (Requeriment 4.5)](#9-còpies-de-seguretat-i-servidor-dedicat--prd-requeriment-45)
10. [Automatització de Creació de Granges i Variació (Requeriment 4.7)](#10-automatització-de-creació-de-granges-i-variació-requeriment-47)
11. [Annex d'Ús d'Intel·ligència Artificial](#11-annex-dús-dintel·ligència-artificial)

---

## 1. Introducció i Visió Global del Sistema

AviGest S.L. és una companyia tecnològica especialitzada en la implantació de sistemes de control telemàtic i gestió automatitzada per a explotacions avícoles (granges d'engreix de pollastres).

El sistema ofereix:
- **Centralització multitenant:** Una seu central consolida les dades de múltiples empreses clientes.
- **Aïllament estricte:** Cada client gestiona les seves granges des d'un únic accés, i cada gestor només visualitza la seva pròpia granja.
- **Seguretat perimetral per disseny:** Tallafocs **OPNsense** amb DMZ aïllada i túnel VPN xifrat des de les granges.
- **Monitorització i control ambiental IoT:** Recollida de temperatura, humitat i nivell de gra en silos, amb actuació automàtica sobre ventiladors i calefactors quan se superen llindars crítics.
- **Arquitectura Edge Computing:** Les granges continuen executant les regles de ventilació d'emergència en local encara que es talli la connexió amb la seu central.

---

## 2. Arquitectura de Màquines Virtuals i Xarxa

L'entorn es desplega mitjançant un conjunt coordinat de màquines virtuals especialitzades, seguint el recorregut complet d'una lectura de sensor des del camp fins a la seu central:

```mermaid
flowchart TD
    Client["pc-client<br/>(Navegador de prova)"]
    Internet["Internet (NAT de l'hipervisor)"]

    subgraph FW["fw-seu (OPNsense)"]
        direction TB
        WAF_Rules["3 Interfícies + Regles d'Estat"]
        VPN_Srv["Servidor VPN (10.0.100.0/24)"]
    end

    subgraph DMZ_Net["DMZ (10.0.10.0/24)"]
        DMZ_Web["dmz-web<br/>Nginx + proxy invers<br/>WAF i relay SMTP"]
    end

    subgraph LAN_Net["LAN seu (10.0.20.0/24)"]
        Srv_Serveis["srv-serveis<br/>Docker: OpenLDAP<br/>PostgreSQL 16 + rèplica<br/>Broker MQTT Mosquitto"]
        Srv_Backup["srv-backup<br/>Còpies amb cron<br/>Disc extern simulat"]
    end

    subgraph Granja1_Net["Granja 1 (10.1.1.0/24)"]
        Granja1_Sim["granja1-sim<br/>Sensors ESP32 simulats<br/>Bus RS485 (Modbus)<br/>LoRaWAN (ChirpStack)"]
        Granja1_Srv["granja1-srv<br/>Client VPN i MQTT local<br/>Regles dels actuadors<br/>Buffer de dades"]
    end

    Client --> Internet
    Internet ==>|HTTPS (443) només des d'IPs autoritzades| FW
    FW -->|Port 443/80| DMZ_Web
    DMZ_Web ==>|NOMÉS SQL:5432 i LDAP:389| Srv_Serveis
    DMZ_Web -.->|BLOQUEJAT TOTA LA RESTA: DROP| LAN_Net

    Granja1_Sim -->|Dades de camp| Granja1_Srv
    Granja1_Srv ==>|Túnel VPN (10.0.100.0/24)| VPN_Srv
    VPN_Srv ==>|NOMÉS MQTT:1883/8883| Srv_Serveis
    VPN_Srv -.->|BLOQUEJAT ACCÉS DIRECTE A BD: DROP| LAN_Net
```

### Recorregut d'una lectura telemètrica (End-to-End):
1. **`granja1-sim`:** Simula els sensors de temperatura/humitat (ESP32 via RS485 Modbus) i els sensors de silos (LoRaWAN amb ChirpStack) i envia les trames a `granja1-srv`.
2. **`granja1-srv`:** Desa les lectures en un búfer local (*store-and-forward*), avalua les regles locals (si T > 31ºC activa el ventilador immediatament) i reenvia les lectures pel túnel VPN fins a `fw-seu`.
3. **`fw-seu`:** Rep el trànsit de la VPN (`10.0.100.0/24`) i **només permet el pas cap al port del broker MQTT (1883/8883) de la LAN**.
4. **`srv-serveis`:** El broker MQTT rep les lectures i un servei d'ingesta les emmagatzema a **PostgreSQL 16**, que alhora manté una rèplica sincronitzada. Al mateix equip resideix **OpenLDAP** per a l'autenticació centralitzada.
5. **`srv-backup`:** Màquina dedicada que executa les còpies de seguretat diàries amb `cron` i les arxiva en un segon disc virtual simulant una ubicació externa.
6. **`dmz-web`:** L'únic servei exposat a Internet: rep les peticions dels clients (`pc-client`), aplica WAF i proxy invers Nginx, i només consulta a la LAN els ports estrictament indispensables (PostgreSQL 5432 i LDAP 389).

---

## 3. Fitxes de Decisió Tècnica (Resum Executiu)

| Codi Fitxa | Àmbit Tècnic | Decisió Presa | Justificació Principal | Document Detallat |
| :--- | :--- | :--- | :--- | :--- |
| **FD01** | SGBD Central | **PostgreSQL 16 + Rèplica** | Triggers PL/pgSQL avançats, suport TimescaleDB/JSON per a telemetria IoT, Row-Level Security natiu i streaming replication. | [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md) |
| **FD02** | Directori Central | **OpenLDAP + phpLDAPadmin** | Lleuger (<80MB RAM), estàndard ASIX, estructura modular LDIF amb 4 rols diferenciats i aïllament per granja. | [FD02_ldap.md](../fitxes_decisio/FD02_ldap.md) |
| **FD03** | Seguretat Perimetral | **OPNsense (`fw-seu`)** | Appliance dedicat amb 3 interfícies físiques (WAN, DMZ, LAN), servidor VPN integrat, llista blanca d'IPs i política estricta DMZ-LAN. | [FD03_tallafocs_dmz.md](../fitxes_decisio/FD03_tallafocs_dmz.md) |
| **FD04** | Còpies de Seguretat | **`srv-backup` dedicat + 2n disc** | Aïllament de fallades (VM pròpia), model 3-2-1 amb segon disc virtual per simular emmagatzematge extern, cron nocturn i RTO < 30 min. | [FD04_backups_prd.md](../fitxes_decisio/FD04_backups_prd.md) |
| **FD05** | Comunicacions IoT | **Model Híbrid Edge (RS485 + LoRaWAN + MQTT)** | `granja1-sim` (Modbus a naus i LoRa a silos exteriors) cap a `granja1-srv` (MQTT local + buffer) i túnel VPN cap a la seu. | [FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md) |

---

## 4. Infraestructura de Maquinari i Redundància (Requeriments 4.1 i 4.6)

### 4.1. Seu Central
- **Servidor:** Rack 19" amb CPU Intel Xeon (16 nuclis), 32 GB RAM ECC Registered i 4x SSD 960 GB en RAID 10.
- **SAI:** APC Smart-UPS On-Line 2200VA amb doble conversió i targeta SNMP per a aturada ordenada.
- **Redundància de Base de Dades (Nota d'arquitectura 4.6):**
  - La rèplica de PostgreSQL està configurada com a servei de rèplica contínua (*Streaming Replication*).
  - *Com a decisió tècnica documentada:* En el laboratori la rèplica s'executa com a contenidor secundari dins de `srv-serveis`. Es documenta la limitació que, si cau la VM sencera de `srv-serveis`, cal restaurar des de `srv-backup`. En producció empresarial, la rèplica s'allotja en una segona màquina física independent.

### 4.2. Cada Granja (Entorn Hostil)
- **`granja1-srv` (Gateway de Granja):** Fanless Industrial PC IP50/IP65 en carril DIN dins d'armari estanc IP66. Dissipació passiva immune a la pols de pinso i plomissol.
- **Connexió WAN redundant:** Router 4G/5G Teltonika amb doble SIM de suport (failover automàtic entre operadores).
- **Buffer de dades (*Store-and-Forward*):** Si cau la VPN o la connexió rural, `granja1-srv` reté les dades localment fins a 72 hores i les sincronitza automàticament en restablir-se l'enllaç.

---

## 5. Seguretat Perimetral: OPNsense, DMZ i Tallafocs (Requeriment 4.4)

El tallafocs perimetral `fw-seu` (OPNsense) aplica una política estricta de tall per defecte (**`Default DROP`**):

1. **Accés WAN restringit per Llista Blanca:**
   - Només les adreces IP públiques de les empreses que han contractat el servei (`CLIENTS_AUTORITZATS`, com `pc-client`) poden connectar-se al port HTTPS (443) de `dmz-web`. Tota la resta d'Internet és descartada automàticament.
2. **Aïllament estricte DMZ -> LAN:**
   - **La DMZ no pot iniciar connexions cap a la LAN**, amb les úniques excepcions imprescindibles per al servei:
     * `dmz-web` -> `srv-serveis:5432` (PostgreSQL)
     * `dmz-web` -> `srv-serveis:389` (OpenLDAP)
   - Qualsevol intent d'iniciar connexions cap a `srv-backup` o ports administratius (SSH, gestió) és immediatament **bloquejat i registrat al log d'OPNsense**.
3. **Control d'accés VPN:**
   - El túnel VPN (`10.0.100.0/24`) que prové de `granja1-srv` **únicament té permès el trànsit cap a `srv-serveis:1883/8883` (Broker MQTT)**. No té accés a la base de dades ni a LDAP.

---

## 6. Directori Centralitzat d'Usuaris — OpenLDAP (Requeriment 4.2)
*Allotjat a `srv-serveis` (`10.0.20.10`)*. Base del directori: `dc=avigest,dc=cat`.

- **Quatre Rols Diferenciats (R2):**
  1. `cn=AdminsAviGest`: Administrador global de plataforma.
  2. `cn=AdminsClient`: Propietari de compte amb N granges contractades (`businessCategory: CLIENT_<ID>`).
  3. `cn=GestorsGranja`: Responsable operatiu assignat a una única granja (`departmentNumber: GRANJA_<ID>`).
  4. `cn=UsuarisConsulta`: Accés de només lectura per a veterinaris o auditories.
- **Aïllament Multitenant (R3):** Cada client disposa de la seva pròpia unitat organitzativa (`ou=client_agroponent`, `ou=client_segria`).

---

## 7. Base de Dades Centralitzada: PostgreSQL 16 i Rèplica (Requeriment 4.3)
*Allotjada a `srv-serveis` (`10.0.20.10`)*.

### 7.1. Model Entitat-Relació Complet (Mermaid)

```mermaid
erDiagram
    CLIENTS ||--o{ GRANGES : "contracta (R1)"
    GRANGES ||--o{ NAUS : "conte"
    NAUS ||--o{ LOTS_CRIANCA : "allotja cicles (R6)"
    NAUS ||--o{ SENSORS : "monitoritza (R4)"
    NAUS ||--o{ ACTUADORS : "regula ambient (R5)"
    NAUS ||--o{ ALARMES_INCIDENCIES : "genera alertes (R7)"
    SENSORS ||--o{ LECTURES_SENSORS : "enregistra"
    ACTUADORS ||--o{ REGISTRE_ACTUACIONS : "executa canvis"
    SENSORS ||--o{ ALARMES_INCIDENCIES : "dispara per llindar"

    CLIENTS {
        INT id_client PK
        VARCHAR nif UK
        VARCHAR nom_empresa
        VARCHAR email
        BOOLEAN actiu
    }
    GRANGES {
        INT id_granja PK
        INT id_client FK
        VARCHAR nom_granja
        VARCHAR codi_explotacio UK
        BOOLEAN activa
    }
    NAUS {
        INT id_nau PK
        INT id_granja FK
        VARCHAR codi_nau
        INT capacitat_aus
    }
    LOTS_CRIANCA {
        INT id_lot PK
        INT id_nau FK
        VARCHAR codi_lot UK
        INT num_aus_inicials
        INT num_baixes
        DATE data_entrada
        VARCHAR estat
    }
    SENSORS {
        INT id_sensor PK
        INT id_nau FK
        VARCHAR tipus_sensor
        VARCHAR tecnologia
        NUMERIC llindar_minim
        NUMERIC llindar_maxim
    }
    ACTUADORS {
        INT id_actuador PK
        INT id_nau FK
        VARCHAR tipus_actuador
        VARCHAR estat_actual
    }
    LECTURES_SENSORS {
        BIGINT id_lectura PK
        INT id_sensor FK
        NUMERIC valor
        TIMESTAMP data_hora
    }
    REGISTRE_ACTUACIONS {
        BIGINT id_actuacio PK
        INT id_actuador FK
        VARCHAR accio
        VARCHAR motiu
        TIMESTAMP data_hora
    }
    ALARMES_INCIDENCIES {
        BIGINT id_alarma PK
        INT id_nau FK
        VARCHAR nivell_gravetat
        VARCHAR missatge
        BOOLEAN resolta
    }
```

### 7.2. Lògica Procedural i Triggers PL/pgSQL (R5 i R7)
- **Control de termòstat automàtic:** Trigger `fn_control_llindars_sensor()` que commuta ventiladors a `ON` i calefactors a `OFF` si $T > 31^\circ\text{C}$, generant l'acció a `registre_actuacions` i alarma crítica a `alarmes_incidencies` si $T \ge 33^\circ\text{C}$.
- **Normalització de temperatura:** Aturada automàtica de ventilació quan la temperatura retorna al rang òptim ($20^\circ\text{C} \le T \le 31^\circ\text{C}$).

### 7.3. Consultes i Vistes Comparatives de Negoci (Requeriment 4.3)
1. **`v_comparativa_lots_rendiment`:** Mortalitat, percentatge de baixes i durada de cicles entre naus i granges.
2. **`v_resum_diari_climatic`:** Agrupacions diàries de temperatures mitjanes, mínimes, màximes i volum d'alarmes per nau per detectar estrès tèrmic.
3. **`v_estat_silos_gra`:** Monitoratge de pes romanent de pinso als silos i avís precoç de comandes abans d'esgotar l'estoc.
4. **`v_panell_executiu_global`:** Visió agregada multitenant amb recompte de naus, capacitat d'aus en producció i incidències pendents per client.

### 7.4. Rols SQL de Mínim Privilegi
- `avigest_app`: Accés DML complet.
- `avigest_iot`: **Només permís `INSERT`** a `lectures_sensors` (sense accés a clients ni usuaris).
- `avigest_consulta`: Només `SELECT` sobre les vistes d'informació.
- `avigest_backup`: Permís per a `pg_dump`.

---

## 8. Arquitectura IoT: Simulació, Edge Computing i Inventari (Requeriments 4.8 i R4)

### 8.1. Arquitectura de Comunicacions (Híbrid RS485 + LoRaWAN)
1. **`granja1-sim` (Simulador de Dispositius):**
   - Simula microcontroladors ESP32 amb sensors ambientals connectats per bus sèrie diferencial **RS485 (Modbus RTU)** dins de les naus.
   - Simula cèl·lules de pesatge de silos exteriors transmetent per ràdio **LoRaWAN (868 MHz)** gestionats per servidor **ChirpStack**.
2. **`granja1-srv` (Controlador Local Edge):**
   - Rep lectures mitjançant broker MQTT local.
   - **Regles locals d'actuació autònoma:** Execució immediata de ventilació si $T > 31^\circ\text{C}$ sense dependre d'Internet.
   - **Buffer Store-and-Forward:** Retenció local de dades fins a 72 hores si cau el túnel VPN.

### 8.2. Inventari Necessari de l'IoT (Requisit Explícit d'Avaluació)

La següent taula recull el dimensionament físic de sensors, actuadors i equipament de comunicacions per a una explotació pilot estàndard (Granja de 2 naus i 2 silos):

| Dispositiu / Sensor | Model de Referència Industrial | Protocol / Tecnologia | Rang de Treball i Precisió | Ubicació Física | Quantitat per Nau / Granja |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Sonda Temp / Humitat** | Industrial SHT30 / XY-MD02 (amb filtre sinteritzat) | RS485 (Modbus RTU) | -40 a +80 ºC ($\pm 0.3^\circ\text{C}$) / 0-100% RH ($\pm 3\%$) | Interior de cada nau (repartits a terç davanter, central i posterior) | 3 per nau (6 per granja) |
| **Sensor de $CO_2$ industrial** | Senseair S8 / Winsen MH-Z19C NDIR | RS485 (Modbus RTU) | 0 a 5.000 ppm ($\pm 50$ ppm) | Alçada d'aus (centre de la nau) | 1 per nau (2 per granja) |
| **Cèl·lules de pesatge de Sitja** | Transductor de càrrega per a potes de silo (4x cel·les) | Mòdul LoRaWAN 868 MHz (IP67) | 0 a 20.000 kg ($\pm 0.5\%$) | Base exterior dels silos de gra | 1 kit per silo (2 per granja) |
| **Comptador d'Aigua d'impulsos** | Comptador d'emissor de polsos Woltman DN20 | RS485 / Entrada digital ESP32 | 1 pols / litre | Entrada de línia d'abeuradors | 1 per nau (2 per granja) |
| **Mòdul de Control / Micro** | ESP32-WROOM-32U amb xassís DIN i antena exterior | WiFi / Ethernet + RS485 transceiver MAX485 | 240 MHz Dual Core, 3.3V/5V DC | Armari elèctric de capçalera de nau | 1 per nau (2 per granja) |
| **Mòdul de Relés Actuadors** | Mòdul 4/8 canals relé optoacoblat 16A/250VAC | RS485 Modbus / GPIO 5V | Suport càrregues inductives de motors | Quadre de maniobra de ventiladors/calefacció | 1 per nau (2 per granja) |
| **Gateway LoRaWAN exterior** | Dragino LPS8N / Milesight UG65 | LoRaWAN 868 MHz (8 canals) cap a Ethernet | Cobertura exterior fins a 2-3 km | Façana exterior de la sala de control | 1 per granja |
| **Gateway Industrial Local** | Advantech UNO-2271G (Fanless IP50/65) | Dual GbE, RS485 integrat, MQTT / VPN | Linux Debian 12, xassís carril DIN | Armari de control IP66 | 1 per granja (`granja1-srv`) |

---

## 9. Còpies de Seguretat i Servidor Dedicat — PRD (Requeriment 4.5)
*Allotjat a `srv-backup` (`10.0.20.20`)*.

- **Estratègia 3-2-1:** 3 còpies, 2 suports, 1 còpia aïllada.
- **Segon disc simulat:** La VM `srv-backup` disposa d'un segon disc dur virtual muntat a `/mnt/disc-extern-backup/`, simulant la ubicació física externa de seguretat.
- **Automatització:** Crontab programat a les 02:00 AM que executa un buidatge transaccional de PostgreSQL (`pg_dump`) i d'OpenLDAP (`slapcat`), genera la suma SHA-256 i aplica retenció de 30 dies.
- **Mètriques:** RPO = 24 h (reduït a < 1 h pel búfer de granja) i RTO ≤ 30 min.

---

## 10. Automatització de Creació de Granges i Variació (Requeriment 4.7)

L'script d'automatització està preparat per donar resposta a la **prova presencial de variació** exigida al punt 7 de l'enunciat:

> *"Per afegir la Granja 2 (la variació que us demanaran), es clonen `granja1-srv` i `granja1-sim` en una xarxa nova (`10.1.2.0/24`). L'script del 4.7 crea l'usuari a LDAP, l'esquema a la BD i la regla al firewall."*

L'script `scripts/automatitzacio-granges/alta_granja.sh`:
1. Crea la nova granja i naus a la base de dades PostgreSQL de `srv-serveis`.
2. Crea la unitat organitzativa i l'usuari gestor a OpenLDAP amb `departmentNumber: GRANJA_2`.
3. Provisiona la regla d'accés a l'alias d'OPNsense per permetre el nou túnel VPN des de `10.1.2.0/24`.

---

## 11. Annex d'Ús d'Intel·ligència Artificial
*En compliment estricte de la Norma 4 de l'enunciat:*

- **Eina utilitzada:** Antigravity / Gemini 3.8 Flash (High).
- **Finalitat de l'ús:** Eina de suport per al disseny de la topologia de xarxes, diagrames de flux, estructuració de fitxes de decisió i esborranys de configuració.
- **Mètode de verificació i comprensió:** L'equip (Joan i Mariam) ha definit l'esquema de màquines virtuals, entén cadascuna de les regles de tallafocs d'OPNsense, la separació DMZ-LAN, el flux MQTT de sensors i la lògica de rèplica i backups per poder defensar-ho íntegrament en la sessió oral davant del tribunal.
