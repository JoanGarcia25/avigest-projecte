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
| **FD01** | SGBD Central | **PostgreSQL 16 + Rèplica** | Triggers PL/pgSQL avançats, suport TimescaleDB/JSON per a telemetria IoT, Row-Level Security natiu i streaming replication. | [FD01_sgbd.md](file:///c:/Users/jgarcia1_insmollerus/Desktop/Projecte/avigest-projecte/docs/fitxes_decisio/FD01_sgbd.md) |
| **FD02** | Directori Central | **OpenLDAP + phpLDAPadmin** | Lleuger (<80MB RAM), estàndard ASIX, estructura modular LDIF amb 4 rols diferenciats i aïllament per granja. | [FD02_ldap.md](file:///c:/Users/jgarcia1_insmollerus/Desktop/Projecte/avigest-projecte/docs/fitxes_decisio/FD02_ldap.md) |
| **FD03** | Seguretat Perimetral | **OPNsense (`fw-seu`)** | Appliance dedicat amb 3 interfícies físiques (WAN, DMZ, LAN), servidor VPN integrat, llista blanca d'IPs i política estricta DMZ-LAN. | [FD03_tallafocs_dmz.md](file:///c:/Users/jgarcia1_insmollerus/Desktop/Projecte/avigest-projecte/docs/fitxes_decisio/FD03_tallafocs_dmz.md) |
| **FD04** | Còpies de Seguretat | **`srv-backup` dedicat + 2n disc** | Aïllament de fallades (VM pròpia), model 3-2-1 amb segon disc virtual per simular emmagatzematge extern, cron nocturn i RTO < 30 min. | [FD04_backups_prd.md](file:///c:/Users/jgarcia1_insmollerus/Desktop/Projecte/avigest-projecte/docs/fitxes_decisio/FD04_backups_prd.md) |
| **FD05** | Comunicacions IoT | **Model Híbrid Edge (RS485 + LoRaWAN + MQTT)** | `granja1-sim` (Modbus a naus i LoRa a silos exteriors) cap a `granja1-srv` (MQTT local + buffer) i túnel VPN cap a la seu. | [FD05_iot_comunicacions.md](file:///c:/Users/jgarcia1_insmollerus/Desktop/Projecte/avigest-projecte/docs/fitxes_decisio/FD05_iot_comunicacions.md) |

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

- **Model Entitat-Relació:** 9 taules normalitzades (`clients`, `granges`, `naus`, `lots_crianca`, `sensors`, `actuadors`, `lectures_sensors`, `registre_actuacions`, `alarmes_incidencies`).
- **Triggers PL/pgSQL (R5 i R7):** En cada inserció de lectura, si la temperatura supera el llindar màxim de la nau (> 31 ºC), el trigger activa automàticament el ventilador a `ON`, apunta l'acció a `registre_actuacions` i genera l'alarma a `alarmes_incidencies`.
- **Rols de motor SQL (Mínim Privilegi):**
  * `avigest_app`: Permisos DML complets sobre taules de negoci.
  * `avigest_iot`: **NOMÉS permís `INSERT`** a `lectures_sensors`. Mai pot esborrar ni llegir dades de clients.
  * `avigest_consulta`: Només `SELECT` sobre vistes d'informes.
  * `avigest_backup`: Permisos exclusius per a `pg_dump`.

---

## 8. Arquitectura IoT: Simulació, Edge Computing i Comunicacions (Requeriment 4.8)

1. **`granja1-sim` (Simulador de Dispositius):**
   - Simula els microcontroladors ESP32 llegint sensors de temperatura i humitat connectats per un bus sèrie diferencial **RS485 (Modbus RTU)**.
   - Simula les cèl·lules de pesatge dels silos exteriors transmetent per ràdio **LoRaWAN (868 MHz)** gestionats per un servidor **ChirpStack**.
2. **`granja1-srv` (Controlador Local Edge):**
   - Rep les lectures de camp mitjançant un broker MQTT local.
   - **Regles locals d'actuació (Seguretat autònoma):** Si la temperatura supera el llindar crític, commuta el ventilador localment sense dependre d'Internet.
   - **Buffer:** Emmagatzema les lectures si la VPN cau i les transmet cap a la seu central un cop restablerta la connexió.

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
