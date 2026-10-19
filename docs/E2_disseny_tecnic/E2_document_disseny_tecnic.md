# E2 — Document de Disseny Tècnic del Projecte
**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Empresa:** AviGest S.L.  
**Cicle:** CFGS Administració de Sistemes Informàtics en Xarxa (ASIX) — 2n Curs  
**Mòdul:** M12 - Projecte (Pes: 20%)  
**Equip de treball:** Joan (Infraestructura, Xarxa i Seguretat) i Mariam (Base de Dades, IoT i Automatització)  
**Data:** 19 d'octubre de 2026 (Lliurament oficial: 4 de desembre de 2026)  

---

## Índex de Continguts
1. [Introducció i Visió Global del Sistema](#1-introducció-i-visió-global-del-sistema)
2. [Fitxes de Decisió Tècnica (Resum Executiu)](#2-fitxes-de-decisió-tècnica-resum-executiu)
3. [Infraestructura de Maquinari i Redundància (Requeriments 4.1 i 4.6)](#3-infraestructura-de-maquinari-i-redundància-requeriments-41-i-46)
4. [Seguretat Perimetral: DMZ i Tallafocs (Requeriment 4.4)](#4-seguretat-perimetral-dmz-i-tallafocs-requeriment-44)
5. [Directori Centralitzat d'Usuaris i Aïllament de Dades — LDAP (Requeriment 4.2)](#5-directori-centralitzat-dusuaris-i-aïllament-de-dades--ldap-requeriment-42)
6. [Disseny de la Base de Dades i Triggers Automàtics (Requeriment 4.3)](#6-disseny-de-la-base-de-dades-i-triggers-automàtics-requeriment-43)
7. [Arquitectura IoT: LoRaWAN, RS485 i Flux de Dades (Requeriment 4.8)](#7-arquitectura-iot-lorawan-rs485-i-flux-de-dades-requeriment-48)
8. [Còpies de Seguretat i Pla de Recuperació davant de Desastres — PRD (Requeriment 4.5)](#8-còpies-de-seguretat-i-pla-de-recuperació-davant-de-desastres--prd-requeriment-45)
9. [Automatització de Creació de Granges (Requeriment 4.7)](#9-automatització-de-creació-de-granges-requeriment-47)
10. [Annex d'Ús d'Intel·ligència Artificial](#10-annex-dús-dintel·ligència-artificial)

---

## 1. Introducció i Visió Global del Sistema

AviGest S.L. és una companyia tecnològica especialitzada en la implantació de sistemes de control telemàtic i gestió automatitzada per a explotacions avícoles (granges d'engreix de pollastres).

El sistema ofereix:
- **Centralització multitenant:** Una única seu central consolida les dades de múltiples empreses clientes.
- **Aïllament estricte:** Cada client gestiona les seves granges des d'un únic accés, i cada gestor només visualitza la seva pròpia granja.
- **Monitorització i control ambiental IoT:** Recollida de temperatura, humitat, CO2 i nivell de gra en silos, amb actuació automàtica sobre ventiladors i calefactors quan se superen llindars crítics.
- **Fiabilitat en el món rural:** Dissenyat específicament per a les condicions de pols, humitat i connectivitat rural inestable.

```mermaid
flowchart TD
    subgraph SeuCentral["SEU CENTRAL AVIGEST (Docker Compose & Rack 19\")"]
        DMZ["DMZ (192.168.100.0/24)<br/>Nginx Web / Ingesta"]
        LAN["LAN Interna (192.168.200.0/24)<br/>MariaDB 10.11 + OpenLDAP"]
        DMZ -->|Només SQL 3306 i LDAP 389| LAN
    end

    subgraph ClientsExt["CLIENTS I EXPLOTACIONS CONTRACTANTS"]
        Granja1["Granja Bellpuig (Client 1)<br/>Gateway Fanless IP65 + RS485 / LoRaWAN"]
        Granja2["Granja Mollerussa (Client 1)<br/>Gateway Fanless IP65 + RS485 / LoRaWAN"]
        Granja3["Granja Alcarràs (Client 2)<br/>Gateway Fanless IP65 + RS485 / LoRaWAN"]
        Oficina["Oficina Corporativa Client<br/>(Llista blanca d'IPs WAN)"]
    end

    Oficina ==>|HTTPS (443)| DMZ
    Granja1 ==>|Telemetria JSON TLS| DMZ
    Granja2 ==>|Telemetria JSON TLS| DMZ
    Granja3 ==>|Telemetria JSON TLS| DMZ
```

---

## 2. Fitxes de Decisió Tècnica (Resum Executiu)

En compliment estricte de la Norma 3 de l'enunciat, totes les decisions rellevants disposen de la seva fitxa oficial d'anàlisi amb almenys dues alternatives avaluades:

| Codi Fitxa | Àmbit Tècnic | Alternatives Avaluades | Decisió Presa | Document Detallat |
| :--- | :--- | :--- | :--- | :--- |
| **FD01** | SGBD Central | PostgreSQL vs **MariaDB 10.11 LTS** vs SQLite | **MariaDB 10.11 LTS** (Simplicitat, suport phpMyAdmin, triggers eficients) | [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md) |
| **FD02** | Directori Central | **OpenLDAP + phpLDAPadmin** vs Samba 4 AD vs FreeIPA | **OpenLDAP** (Lleuger, <80MB RAM, estàndard ASIX, càrrega LDIF neta) | [FD02_ldap.md](../fitxes_decisio/FD02_ldap.md) |
| **FD03** | Seguretat Perimetral | **iptables natiu amb Whitelist** vs pfSense VM vs Appliance físic | **iptables amb Llista Blanca** (Integració neta en scripts versionables a Git) | [FD03_tallafocs_dmz.md](../fitxes_decisio/FD03_tallafocs_dmz.md) |
| **FD04** | Còpies de Seguretat | **Scripts Bash (`mariadb-dump` + `slapcat`)** vs Borg vs Bacula | **Scripts Bash modulars + Crontab** (Model 3-2-1, independència, verificable) | [FD04_backups_prd.md](../fitxes_decisio/FD04_backups_prd.md) |
| **FD05** | Comunicacions IoT | **RS485 Modbus a naus** vs **LoRaWAN a silos exteriors** | **Model Híbrid Especialitzat** segons distància, consum, volum i entorn | [FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md) |

---

## 3. Infraestructura de Maquinari i Redundància (Requeriments 4.1 i 4.6)
*Document de referència:* [infraestructura_maquinari.md](../../infra/xarxa/infraestructura_maquinari.md)

### 3.1. Seu Central (Alta Disponibilitat)
- **Servidor:** Rack 19" (Dell PowerEdge R450 o similar) amb processador Intel Xeon Silver (16 nuclis) i 32 GB RAM DDR4 ECC Registered.
- **Redundància de disc (4.6):** Controladora RAID per maquinari amb **4x 960 GB SSD Enterprise en RAID 10**. Proporciona el màxim rendiment en escriptures concurrents de sensors i tolerància a la pèrdua de 2 discs.
- **Alimentació:** Doble font redundant Hot-Plug (600W) + **SAI APC Smart-UPS On-Line 2200VA** de doble conversió amb targeta de gestió SNMP per a tancament ordenat (*graceful shutdown*).

### 3.2. Cada Granja (Condicions Reals Hostils)
- **Problemàtica real:** Pols densa de pinso i plomissol, humitat fins al 80%, gas d'amoníac corrosiu i fluctuacions de tensió elèctrica per maquinària agrícola.
- **Solució aplicada:**
  - **Gateway Industrial Fanless IP50/IP65** (Advantech / Moxa / Siemens) muntat en carril DIN: xassís segellat d'alumini amb dissipació 100% passiva (sense ventiladors que es puguin embussar).
  - Instal·lació en un armari estanc de polièster **IP66** al vestíbul tècnic exterior a les aus.
  - Memòria cau local (*Store-and-Forward*): si cau la connexió a Internet rural, emmagatzema fins a 72 hores de telemetria i la sincronitza en restablir-se la WAN.
  - Router 4G/5G industrial amb doble ranura SIM de suport (failover entre operadores mòbils).

---

## 4. Seguretat Perimetral: DMZ i Tallafocs (Requeriment 4.4)
*Documents de referència:* [disseny_dmz_seguretat.md](../../infra/dmz-tallafocs/disseny_dmz_seguretat.md) i [firewall_regles.sh](../../infra/dmz-tallafocs/firewall_regles.sh)

- **Segmentació en 3 Zones:**
  1. **WAN:** Internet públic. Política per defecte `DROP`.
  2. **DMZ (192.168.100.0/24):** Allotja el servidor web i l'API d'ingesta.
  3. **LAN Interna (192.168.200.0/24):** Aïllada completament de l'exterior. Allotja MariaDB (3306) i OpenLDAP (389).
- **Llista blanca de clients (Requisit explícit de l'enunciat):**
  - Només es permet l'accés HTTPS (443) al portal web des de les adreces IP de les seus de les empreses que han contractat el servei (cadena `CLIENTS_WHITELIST`). La resta d'Internet és descartada automàticament.
  - La DMZ només té obertura estricta cap a la LAN Interna als ports autoritzats (3306 per a consultes i 389 per a autenticació).

---

## 5. Directori Centralitzat d'Usuaris i Aïllament de Dades — LDAP (Requeriment 4.2)
*Documents de referència:* [politica_permisos_ldap.md](../../infra/ldap/politica_permisos_ldap.md), [01_arbre_base.ldif](../../infra/ldap/ldif/01_arbre_base.ldif) i [02_usuaris_inicials.ldif](../../infra/ldap/ldif/02_usuaris_inicials.ldif)

- **Base del directori (Suffix):** `dc=avigest,dc=cat`
- **Quatre Rols Diferenciats (R2):**
  1. `cn=AdminsAviGest`: Administrador global de plataforma.
  2. `cn=AdminsClient`: Propietari de compte amb N granges contractades.
  3. `cn=GestorsGranja`: Responsable operatiu assignat a una única granja.
  4. `cn=UsuarisConsulta`: Accés de només lectura per a veterinaris o auditories.
- **Aïllament Multitenant (R3):**
  - Cada client disposa de la seva pròpia unitat organitzativa (`ou=client_agroponent`, `ou=client_segria`).
  - L'atribut `businessCategory: CLIENT_<ID>` aïlla les dades per client.
  - L'atribut `departmentNumber: GRANJA_<ID>` limita l'accés dels gestors a la seva explotació física concreta.

---

## 6. Disseny de la Base de Dades i Triggers Automàtics (Requeriment 4.3)
*Documents de referència:* [model_er.md](../../bd/model-er/model_er.md), [01_esquema.sql](../../bd/sql/01_esquema.sql), [02_triggers_procedures.sql](../../bd/procediments-triggers/02_triggers_procedures.sql), [03_dades_prova.sql](../../bd/sql/03_dades_prova.sql) i [04_usuaris_rols_bd.sql](../../bd/sql/04_usuaris_rols_bd.sql)

- **Model Entitat-Relació (9 taules normalitzades):**
  `clients` -> `granges` -> `naus` -> `lots_crianca`, `sensors`, `actuadors`, `lectures_sensors`, `registre_actuacions`, `alarmes_incidencies`.
- **Automatismes mitjançant Triggers (`tg_control_llindars_sensor`) (R5 i R7):**
  En cada inserció de telemetria a `lectures_sensors`, el trigger avalua els llindars configurats a la taula `sensors` i actua de forma immediata i transaccional:
  1. **Sobre-escalfament (> llindar màxim, ex: 31 ºC):** Activa el ventilador (`ON`), insereix traça a `registre_actuacions` i genera alarma `CRITICAL` a `alarmes_incidencies`.
  2. **Temperatura baixa (< llindar mínim, ex: 20 ºC):** Atura ventiladors, activa calefacció (`ON`), insereix traça i genera alarma `WARNING`.
  3. **Normalització tèrmica:** Atura automàticament tant ventiladors com calefactors si estaven actius i en registra el restabliment.
  4. **Humitat excessiva (> 70 %):** Activa ventiladors per dissipar condensació i genera alarma `WARNING`.
  5. **Qualitat de l'aire CO2 (> 3000 ppm):** Activa ventilació forçada d'emergència i genera alarma `CRITICAL` per prevenir asfíxia de les aus.
  6. **Reserva de pinso al silo (< 1500 kg):** Genera alarma `WARNING` de sol·licitud immediata de recàrrega de pinso.
- **Procediment Emmagatzemat `sp_alta_granja_completa`:**
  - Valida prèviament l'existència del client i la no-duplicitat del codi d'explotació amb senyals d'error `SIGNAL SQLSTATE '45000'`.
  - Provisiona atòmicament la granja, N naus, 4 sensors per nau (Temperatura, Humitat, CO2 i Silo) i 2 actuadors (Ventilador i Calefactor) retornant el nou ID de granja mitjançant paràmetre `OUT`.
- **Vistes i Seguretat de BD:**
  - Vistes `v_resum_granges_avigest` (quadre de comandament global) i `v_estat_actual_sensors` (darrera telemetria en temps real).
  - 4 rols de BD segregats amb mínim privilegi: `avigest_app`, `avigest_iot` (només INSERT a lectures), `avigest_consulta` i `avigest_backup`.

---

## 7. Arquitectura IoT: LoRaWAN, RS485 i Flux de Dades (Requeriment 4.8)
*Documents de referència:* [FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md), [arquitectura_flux_dades.md](../../iot/comunicacions/arquitectura_flux_dades.md) i [simulador_iot.py](../../iot/sensors/simulador_iot.py)

- **Justificació de tecnologies:**
  - **Interior de les naus (RS485 Modbus RTU):** Sensors de temperatura, humitat, CO2 i actuadors. Cable apantallat d'alta immunitat al soroll elèctric de grans motors, alimentat permanentment per cable i amb reacció de mil·lisegons.
  - **Exterior i Silos de Gra (LoRaWAN 868 MHz):** Cèl·lules de pesatge de silos situades a desenes o centenars de metres de les naus. Evita rases costoses vulnerables a maquinària agrícola; l'ESP32 funciona 3-5 anys amb una bateria gràcies al mode *Deep Sleep*.
- **Seguretat local a la vora (*Life-Safety Edge Computing*):** Si cau la connexió WAN, l'ESP32 local manté el control autònom dels ventiladors per protegir la vida dels animals.
- **Simulador en Python (`simulador_iot.py`):**
  - Suporta 3 modes (`normal`, `alarma`, `interactiu`), verificació prèvia de connexió a la BD, suport per als rols `avigest_iot`/`avigest_app` i telemetria completa per a Bellpuig, Mollerussa i Alcarràs.

---

## 8. Còpies de Seguretat i Pla de Recuperació davant de Desastres — PRD (Requeriment 4.5)
*Documents de referència:* [FD04_backups_prd.md](../fitxes_decisio/FD04_backups_prd.md), [pla_recuperacio_desastres_prd.md](../../infra/backups-prd/pla_recuperacio_desastres_prd.md), [backup_avigest.sh](../../infra/backups-prd/backup_avigest.sh), [restaurar_avigest.sh](../../infra/backups-prd/restaurar_avigest.sh) i [crontab.txt](../../infra/backups-prd/crontab.txt)

- **Estratègia 3-2-1:** 3 còpies, 2 suports, 1 còpia fora de la seu.
- **Mètriques oficials:**
  - **RPO:** 24 hores (mitigat a < 1 hora pel búfer local de les granges).
  - **RTO:** ≤ 30 minuts (recuperació demostrada en 2 minuts i 14 segons).
- **Scripts executables:**
  - `backup_avigest.sh`: Buidatge transaccional nocturn (`mariadb-dump` + `slapcat`) programat per crontab a les 02:00 AM, amb suma de verificació SHA-256 i rotació de 30 dies.
  - `restaurar_avigest.sh`: Script d'un sol pas per recuperar la base de dades i usuaris davant d'una caiguda total.

---

## 9. Automatització de Creació de Granges (Requeriment 4.7)
*Documents de referència:* [alta_granja.sh](../../scripts/automatitzacio-granges/alta_granja.sh) i [README.md](../../scripts/automatitzacio-granges/README.md)

- **Resposta a la prova presencial del professor (Requeriment 7):**
  - L'script `alta_granja.sh` permet afegir una nova explotació amb naus, sensors i usuari gestor en qüestió de segons:
  ```bash
  ./alta_granja.sh -c 1 -n "Granja Urgell Tàrrega" -e "ES252170004" -a "Camí de Verdú s/n" -p "Tàrrega" -s 2 -u "gestor_tarrega" -P "PassSegura123!"
  ```
  - Executa la creació SQL a MariaDB amb protecció contra injecció per apòstrofs, dóna d'alta el gestor amb el seu grup i restriccions a OpenLDAP, i genera els directoris de treball per al gateway de camp.

---

## 10. Annex d'Ús d'Intel·ligència Artificial
*En compliment estricte de la Norma 4 de l'enunciat:*

- **Eina utilitzada:** Antigravity / Gemini 3.8 Flash (High).
- **Finalitat de l'ús:** Eina de suport per a l'estructuració del repositori, disseny preliminar dels esquemes SQL, redacció de la documentació tècnica i esborranys dels scripts d'automatització.
- **Mètode de verificació i comprensió:** L'equip (Joan i Mariam) ha revisat, adaptat i provat cadascun dels fitxers, entenent la sintaxi de les comandes d'iptables, la jerarquia de l'arbre LDAP, les consultes i triggers de MariaDB, i les justificacions tècniques de LoRaWAN vs RS485 per poder defensar-les oralment davant del professor i replicar qualsevol modificació en directe.
