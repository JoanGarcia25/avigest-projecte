# E2 â€” Document de Disseny TÃ¨cnic del Projecte
**Projecte:** ImplantaciÃ³ d'un sistema informÃ tic de gestiÃ³ de granges de pollastres  
**Empresa:** AviGest S.L.  
**Cicle:** CFGS AdministraciÃ³ de Sistemes InformÃ tics en Xarxa (ASIX) â€” 2n Curs  
**MÃ²dul:** M12 - Projecte (Pes: 20%)  
**Equip de treball:** Joan (Infraestructura, Xarxa i Seguretat) i Mariam (Base de Dades, IoT i AutomatitzaciÃ³)  
**Data:** Actualitzat a 26 d'octubre de 2026 (Lliurament oficial: 4 de desembre de 2026)  

---

## Ãndex de Continguts
1. [Resum Executiu](#resum-executiu)
2. [IntroducciÃ³ i VisiÃ³ Global del Sistema](#1-introducciÃ³-i-visiÃ³-global-del-sistema)
3. [Arquitectura de MÃ quines Virtuals i Xarxa](#2-arquitectura-de-mÃ quines-virtuals-i-xarxa)
4. [Fitxes de DecisiÃ³ TÃ¨cnica (Resum Executiu)](#3-fitxes-de-decisiÃ³-tÃ¨cnica-resum-executiu)
5. [Infraestructura de Maquinari i RedundÃ ncia (Requeriments 4.1 i 4.6)](#4-infraestructura-de-maquinari-i-redundÃ ncia-requeriments-41-i-46)
6. [Seguretat Perimetral: OPNsense, DMZ i Tallafocs (Requeriment 4.4)](#5-seguretat-perimetral-opnsense-dmz-i-tallafocs-requeriment-44)
7. [Directori Centralitzat d'Usuaris â€” OpenLDAP (Requeriment 4.2)](#6-directori-centralitzat-dusuaris--openldap-requeriment-42)
8. [Base de Dades Centralitzada: MariaDB 10.11 LTS i RÃ¨plica (Requeriment 4.3)](#7-base-de-dades-centralitzada-mariadb-1011-lts-i-rÃ¨plica-requeriment-43)
9. [Arquitectura IoT: SimulaciÃ³, Edge Computing i Comunicacions (Requeriment 4.8)](#8-arquitectura-iot-simulaciÃ³-edge-computing-i-comunicacions-requeriment-48)
10. [CÃ²pies de Seguretat i Servidor Dedicat â€” PRD (Requeriment 4.5)](#9-cÃ²pies-de-seguretat-i-servidor-dedicat--prd-requeriment-45)
11. [AutomatitzaciÃ³ de CreaciÃ³ de Granges i VariaciÃ³ (Requeriment 4.7)](#10-automatitzaciÃ³-de-creaciÃ³-de-granges-i-variaciÃ³-requeriment-47)
12. [Fases del Projecte i PlanificaciÃ³ Actualitzada](#11-fases-del-projecte-i-planificaciÃ³-actualitzada)
13. [Annex d'Ãšs d'IntelÂ·ligÃ¨ncia Artificial](#12-annex-dÃºs-dintelÂ·ligÃ¨ncia-artificial)
14. [Bibliografia i Fonts Consultades](#13-bibliografia-i-fonts-consultades)

---

## Resum Executiu

El present document recull el disseny tÃ¨cnic integral d'**AviGest S.L.**, una soluciÃ³ tecnolÃ²gica concebuda per a la transformaciÃ³ digital, telemetria climÃ tica i gestiÃ³ automatitzada d'explotacions avÃ­coles d'engreix de pollastres (*broilers*) a les comarques de Ponent (Lleida). 

El sistema s'adreÃ§a principalment a empreses integradores avÃ­coles que necessiten centralitzar i analitzar en temps real les mÃ¨triques crÃ­tiques de benestar animal i producciÃ³ (temperatura, humitat, nivell de $CO_2$, consums d'aigua i pes de gra en silos) de mÃºltiples granges distribuÃ¯des geogrÃ ficament, garantint alhora un aÃ¯llament dades estricte (*multitenant*).

Per assolir els objectius de disponibilitat, ciberseguretat i continuÃ¯tat de negoci sota condicions rurals adverses, s'han pres les segÃ¼ents **decisions estructurals clau**:
1. **Seguretat Perimetral i AÃ¯llament de Zones:** Desplegament del tallafocs dedicat **OPNsense** amb una polÃ­tica estricta de tall per defecte (*Default DROP*), accÃ©s WAN filtrat per llista blanca d'IPs cap a una DMZ aÃ¯llada i comunicaciÃ³ des de les granges mitjanÃ§ant tÃºnels xifrats d'alt rendiment amb **WireGuard**.
2. **Arquitectura IoT HÃ­brida amb Edge Computing:** CombinaciÃ³ de cablejat industrial diferencial **RS485 (Modbus RTU)** dins de les naus (immune a interferÃ¨ncies i pols) amb rÃ dio **LoRaWAN 868 MHz** per a la sensÃ²rica de silos exteriors. El control crÃ­tic d'actuadors (ventilaciÃ³ davant de risc de cop de calor a $T > 31^\circ\text{C}$) s'executa autÃ²nomament en local al gateway de granja (*Edge*), acompanyat d'un buffer *Store-and-Forward* de fins a 72 hores per tolerar talls d'Internet rural sense pÃ¨rdua de telemetria.
3. **Plataforma de Dades Robustada:** Motor relacional **MariaDB 10.11 LTS** normalitzat en 3FN amb motor InnoDB, lÃ²gica de negoci mitjanÃ§ant triggers i procediments emmagatzemats, aÃ¯llament multitenant per vistes segures i variables de sessiÃ³, i rÃ¨plica *Hot Standby* amb sincronitzaciÃ³ GTID.
4. **Identitat Unificada i ContinuÃ¯tat PRD:** Directori centralitzat **OpenLDAP** amb 4 rols diferenciats i servidor de cÃ²pies dedicat **`srv-backup`** amb segon disc simulat extern, assegurant un RPO diari (< 1 h real en IoT) i un RTO inferior a 30 minuts davant desastres.

---

---

## 1. IntroducciÃ³ i VisiÃ³ Global del Sistema

### 1.1. Context de l'Empresa i Model de Negoci
AviGest S.L. Ã©s una companyia tecnolÃ²gica especialitzada en la implantaciÃ³ de sistemes de control telemÃ tic i gestiÃ³ automatitzada per a explotacions avÃ­coles (granges d'engreix de pollastres).

El sistema ofereix:
- **CentralitzaciÃ³ multitenant:** Una seu central consolida les dades de mÃºltiples empreses clientes.
- **AÃ¯llament estricte:** Cada client gestiona les seves granges des d'un Ãºnic accÃ©s, i cada gestor nomÃ©s visualitza la seva prÃ²pia granja.
- **Seguretat perimetral per disseny:** Tallafocs **OPNsense** amb DMZ aÃ¯llada i tÃºnel VPN xifrat des de les granges.
- **MonitoritzaciÃ³ i control ambiental IoT:** Recollida de temperatura, humitat i nivell de gra en silos, amb actuaciÃ³ automÃ tica sobre ventiladors i calefactors quan se superen llindars crÃ­tics.
- **Arquitectura Edge Computing:** Les granges continuen executant les regles de ventilaciÃ³ d'emergÃ¨ncia en local encara que es talli la connexiÃ³ amb la seu central.

### 1.2. Abast del Projecte (QuÃ¨ s'inclou i quÃ¨ en queda fora)
D'acord amb l'estudi de necessitats realitzat a l'E1, l'abast del projecte queda delimitat formalment:
- **InclÃ²s dins de l'abast:**
  - Disseny i desplegament de la infraestructura del CPD central (servidors de serveis, directori OpenLDAP, base de dades MariaDB 10.11 LTS amb rÃ¨plica GTID i tallafocs OPNsense amb xarxes WAN, DMZ i LAN).
  - Seguretat perimetral amb DMZ, regles d'accÃ©s estricte mitjanÃ§ant llista blanca d'adreces IP i tÃºnel xifrat WireGuard entre les granges i la seu central.
  - Arquitectura IoT de recollida de telemetria mitjanÃ§ant xarxa hÃ­brida (RS485 Modbus a l'interior de les naus i LoRaWAN 868 MHz per a silos exteriors) amb suport Edge Computing per a actuacions immediates davant risc de cop de calor.
  - Disseny relacional normalitzat en 3FN, procediments MariaDB Procedural per a control de llindars climÃ tics, alarmes automÃ tiques, Row Level Security (RLS) i consultes comparatives de negoci.
  - AutomatitzaciÃ³ d'alta rÃ pida de granges i usuaris mitjanÃ§ant scripts bash (`alta_granja.sh`) per respondre a variacions de requeriment.
  - Pla de cÃ²pies de seguretat (3-2-1) i recuperaciÃ³ davant de desastres (PRD) amb servidor dedicat `srv-backup`.
- **ExclÃ²s de l'abast (Fores de l'abast inicial):**
  - Desenvolupament de frontend web complet d'administraciÃ³ (requeriment extra 4.extra, supeditat a la finalitzaciÃ³ de tota la infraestructura).
  - Connectivitat fÃ­sica real mitjanÃ§ant satÃ¨lÂ·lit Starlink o rÃ dio-enllaÃ§os WISP de llarg abast a camp (se simula mitjanÃ§ant tÃºnels VPN sobre xarxes virtuals).
  - IntegraciÃ³ de sistemes de pesatge automÃ tic continu d'aus individuals mitjanÃ§ant visiÃ³ per computador o bÃ scules penjades de pas lliure.

### 1.3. Requeriments Funcionals Concretats i TraÃ§abilitat (R1 a R7)
A partir de la llista mÃ­nima de l'enunciat i ampliant-la amb l'Estudi de Necessitats (E1), el sistema cobreix els segÃ¼ents requeriments amb traÃ§abilitat directa al document de disseny:

| ID Requeriment | DescripciÃ³ Concretada del Requeriment | MÃ²dul Enunciat | SecciÃ³ del Document E2 que el cobreix |
| :---: | :--- | :---: | :--- |
| **R1** | **Alta i baixa de clients i granges:** GestiÃ³ del cicle de vida d'empreses integradores avÃ­coles i les seves granges contractades. | 4.3, 4.7 | [SecciÃ³ 7](#7-base-de-dades-centralitzada-MariaDB-16-i-rÃ¨plica-requeriment-43) (taules `clients`, `granges`, `naus`) i [SecciÃ³ 10](#10-automatitzaciÃ³-de-creaciÃ³-de-granges-i-variaciÃ³-requeriment-47) (`alta_granja.sh`). |
| **R2** | **GestiÃ³ d'usuaris amb rols diferenciats:** Administrador AviGest, Administrador de Client, Gestor de Granja i Usuari de Consulta. | 4.2, 4.3 | [SecciÃ³ 6](#6-directori-centralitzat-dusuaris--openldap-requeriment-42) (OpenLDAP) i [SecciÃ³ 7.4](#74-rols-sql-de-mÃ­nim-privilegi) (rols SQL). |
| **R3** | **AÃ¯llament estricte i accÃ©s multitenant:** Cada granja nomÃ©s accedeix a les seves dades. Un client amb $N$ granges les visualitza totes amb un Ãºnic compte d'accÃ©s. | 4.2, 4.3, 4.4 | [SecciÃ³ 6](#6-directori-centralitzat-dusuaris--openldap-requeriment-42) (OUs LDAP), [SecciÃ³ 7.2](#72-lÃ²gica-procedural-i-triggers-mariadb-procedural-r5-i-r7) (RLS a MariaDB) i [SecciÃ³ 5](#5-seguretat-perimetral-opnsense-dmz-i-tallafocs-requeriment-44) (OPNsense). |
| **R4** | **Registre i telemetria de sensors:** Captura contÃ­nua de temperatura, humitat, nivell de silos de gra i consums d'aigua/aliment. | 4.3, 4.8 | [SecciÃ³ 8](#8-arquitectura-iot-simulaciÃ³-edge-computing-i-inventari-requeriments-48-i-r4) (xarxa hÃ­brida RS485/LoRaWAN) i [SecciÃ³ 7.1](#71-model-entitat-relaciÃ³-complet-mermaid-i-normalitzaciÃ³-3fn) (`lectures_sensors`). |
| **R5** | **Llindars i actuaciÃ³ automÃ tica sobre actuadors:** Encesa immediata de ventiladors i aturada de calefactors si $T > 31^\circ\text{C}$; dosificaciÃ³ i climatitzaciÃ³ automÃ tica. | 4.3, 4.8 | [SecciÃ³ 8.1](#81-arquitectura-de-comunicacions-hÃ­brid-rs485--lorawan) (Edge Computing a granja) i [SecciÃ³ 7.2](#72-lÃ²gica-procedural-i-triggers-mariadb-procedural-r5-i-r7) (trigger `trg_control_llindars_sensor`). |
| **R6** | **HistÃ²ric de cicles i lots de crianÃ§a:** TraÃ§abilitat de cada lot des de l'entrada dels pollets (dia 0) fins a la sortida cap a escorxador (dia 42-45), amb registre de baixes, pes mitjÃ  i Ã­ndex de conversiÃ³. | 4.3 | [SecciÃ³ 7.1](#71-model-entitat-relaciÃ³-complet-mermaid-i-normalitzaciÃ³-3fn) (taula `lots_crianca`) i [SecciÃ³ 7.3](#73-consultes-i-vistes-comparatives-de-negoci-requeriment-43) (`v_comparativa_lots_rendiment`). |
| **R7** | **Alarmes i notificacions d'incidÃ¨ncia:** Alerta crÃ­tica per risc de cop de calor ($T \ge 33^\circ\text{C}$), asfÃ­xia per $CO_2$ (> 3.000 ppm) o avÃ­s de sitja buida (< 1.000 kg). | 4.3, 4.8 | [SecciÃ³ 7.1](#71-model-entitat-relaciÃ³-complet-mermaid-i-normalitzaciÃ³-3fn) (`alarmes_incidencies`), [SecciÃ³ 7.2](#72-lÃ²gica-procedural-i-triggers-mariadb-procedural-r5-i-r7) i [SecciÃ³ 7.3](#73-consultes-i-vistes-comparatives-de-negoci-requeriment-43) (`v_alarmes_actives`). |

---

## 2. Arquitectura de MÃ quines Virtuals i Xarxa

L'entorn es desplega mitjanÃ§ant un conjunt coordinat de mÃ quines virtuals especialitzades, seguint el recorregut complet d'una lectura de sensor des del camp fins a la seu central:

### 2.1. Arquitectura de MÃ quines Virtuals i Xarxa (Diagrama de Blocs)

![Arquitectura de Xarxa i MÃ quines Virtuals](../diagrames/esquema_xarxa_vms.png)
*Figura 1: Topologia de xarxa perimetral (WAN, DMZ, LAN i VPN WireGuard) i distribuciÃ³ de mÃ quines virtuals d'AviGest.*

> [!TIP]
> Teniu disponible el diagrama font vectorial editable a [`docs/diagrames/esquema_xarxa_vms.drawio`](../diagrames/esquema_xarxa_vms.drawio) (llest per obrir amb Draw.io / diagrams.net).

```mermaid
flowchart TD
    Client["pc-client<br/>(Navegador de prova)"]
    Internet["Internet (NAT de l'hipervisor)"]

    subgraph FW["fw-seu (OPNsense)"]
        direction TB
        WAF_Rules["3 InterfÃ­cies + Regles d'Estat"]
        VPN_Srv["Servidor VPN (10.0.100.0/24)"]
    end

    subgraph DMZ_Net["DMZ (10.0.10.0/24)"]
        DMZ_Web["dmz-web<br/>Nginx + proxy invers<br/>WAF i relay SMTP"]
    end

    subgraph LAN_Net["LAN seu (10.0.20.0/24)"]
        Srv_Serveis["srv-serveis<br/>Docker: OpenLDAP<br/>MariaDB 10.11 LTS + rÃ¨plica GTID<br/>MQTT + ingesta a MariaDB"]
        Srv_Backup["srv-backup<br/>CÃ²pies amb cron<br/>Disc extern simulat"]
    end

    subgraph Granja1_Net["Granja 1 (10.1.1.0/24)"]
        Granja1_Sim["granja1-sim<br/>Sensors ESP32 simulats<br/>Bus RS485 (Modbus)<br/>LoRaWAN (ChirpStack)"]
        Granja1_Srv["granja1-srv<br/>Client VPN i MQTT local<br/>Regles dels actuadors<br/>Buffer de dades"]
    end

    Client --> Internet
    Internet ==>|HTTPS (443) nomÃ©s des d'IPs autoritzades| FW
    FW -->|Port 443/80| DMZ_Web
    DMZ_Web ==>|NOMÃ‰S SQL:3306 i LDAP:389| Srv_Serveis
    DMZ_Web -.->|BLOQUEJAT TOTA LA RESTA: DROP| LAN_Net

    Granja1_Sim -->|Dades de camp| Granja1_Srv
    Granja1_Srv ==>|TÃºnel VPN (10.0.100.0/24)| VPN_Srv
    VPN_Srv ==>|NOMÃ‰S MQTT:1883 (xifrat WireGuard)| Srv_Serveis
    VPN_Srv -.->|BLOQUEJAT ACCÃ‰S DIRECTE A BD: DROP| LAN_Net
```

### Recorregut d'una lectura telemÃ¨trica (End-to-End):
1. **`granja1-sim`:** Simula els sensors de temperatura/humitat (ESP32 via RS485 Modbus) i els sensors de silos (LoRaWAN amb ChirpStack) i envia les trames a `granja1-srv`.
2. **`granja1-srv`:** Desa les lectures en un bÃºfer local (*store-and-forward*), avalua les regles locals (si T > 31ÂºC activa el ventilador immediatament) i reenvia les lectures pel tÃºnel VPN fins a `fw-seu`.
3. **`fw-seu`:** Rep el trÃ nsit de la VPN (`10.0.100.0/24`) i **nomÃ©s permet el pas cap al port MQTT 1883 de la LAN**. El xifratge l'aporta WireGuard; no s'exposa MQTTTLS (8883) sense certificats al laboratori.
4. **`srv-serveis`:** Mosquitto rep les lectures. El contenidor **`avigest_mqtt_ingest`** les persisteix a **MariaDB 10.11 LTS**. La rÃ¨plica (port 3307) Ã©s un *Hot Standby* amb rÃ¨plica GTID. **OpenLDAP** autentica usuaris.
5. **`srv-backup`:** MÃ quina dedicada que executa les cÃ²pies de seguretat diÃ ries amb `cron` i les arxiva en un segon disc virtual simulant una ubicaciÃ³ externa.
6. **`dmz-web`:** L'Ãºnic servei exposat a Internet: rep les peticions dels clients (`pc-client`), aplica WAF i proxy invers Nginx, i nomÃ©s consulta a la LAN els ports estrictament indispensables (MariaDB 3306 i LDAP 389).

---

## 3. Fitxes de DecisiÃ³ TÃ¨cnica (Resum Executiu)

| Codi Fitxa | Ã€mbit TÃ¨cnic | DecisiÃ³ Presa | JustificaciÃ³ Principal | Document Detallat |
| :--- | :--- | :--- | :--- | :--- |
| **FD01** | SGBD Central | **MariaDB 10.11 LTS + rÃ¨plica GTID** | Triggers MariaDB Procedural, JSON, Row-Level Security i *streaming replication* (Hot Standby al port 3307). TimescaleDB no estÃ  desplegat. | [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md) |
| **FD02** | Directori Central | **OpenLDAP + phpLDAPadmin** | Lleuger (<80MB RAM), estÃ ndard ASIX, estructura modular LDIF amb 4 rols diferenciats i aÃ¯llament per granja. | [FD02_ldap.md](../fitxes_decisio/FD02_ldap.md) |
| **FD03** | Seguretat Perimetral | **OPNsense (`fw-seu`)** | Appliance dedicat amb 3 interfÃ­cies fÃ­siques (WAN, DMZ, LAN), servidor VPN integrat, llista blanca d'IPs i polÃ­tica estricta DMZ-LAN. | [FD03_tallafocs_dmz.md](../fitxes_decisio/FD03_tallafocs_dmz.md) |
| **FD04** | CÃ²pies de Seguretat | **`srv-backup` dedicat + 2n disc** | AÃ¯llament de fallades (VM prÃ²pia), model 3-2-1 amb segon disc virtual per simular emmagatzematge extern, cron nocturn i RTO < 30 min. | [FD04_backups_prd.md](../fitxes_decisio/FD04_backups_prd.md) |
| **FD05** | Comunicacions IoT | **Model HÃ­brid Edge (RS485 + LoRaWAN + MQTT)** | `granja1-sim` (Modbus a naus i LoRa a silos exteriors) cap a `granja1-srv` (MQTT local + buffer) i tÃºnel VPN cap a la seu. | [FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md) |

---

## 4. Infraestructura de Maquinari i RedundÃ ncia (Requeriments 4.1 i 4.6)

### 4.1. Infraestructura de Maquinari a la Seu Central (CPD AviGest)
Per allotjar els serveis d'alta disponibilitat que donen servei a totes les granges clientes (`fw-seu`, `dmz-web`, `srv-serveis` i `srv-backup`), s'especifica equipament empresarial de referÃ¨ncia homologat:
- **Servidor Principal (Host de VirtualitzaciÃ³):** Dell PowerEdge R450 1U en xassÃ­s rack 19". Equipat amb processador Intel Xeon Silver 4314 (16 nuclis / 32 fils a 2.4 GHz), 32 GB de memÃ²ria RAM DDR4 ECC Registered (ampliable a 1 TB), dues fonts d'alimentaciÃ³ redundants de 600W Hot-Plug en configuraciÃ³ $1+1$ i mÃ²dul de gestiÃ³ fora de banda iDRAC9 Enterprise per a telemetria tÃ¨rmica i gestiÃ³ remota.
- **Emmagatzematge en RAID 10 Hardware:** 4x unitats Dell Enterprise SATA SSD de 960 GB (Hot-Plug 2.5" amb safata extraÃ¯ble en calent), gestionades per controladora fÃ­sica dedicada PERC H755 amb 8 GB de NVRAM cau protegida per bateria, oferint 1.92 TB Ãºtils d'alt rendiment en IOPS i tolerÃ ncia a la fallada simultÃ nia de fins a dos discos de branques mirall diferents.
- **ElectrÃ²nica de Xarxa i SegmentaciÃ³ (VLANs):** Switch gestionable L2+ Cisco Catalyst sÃ¨rie 1000 de 24 ports Gigabit Ethernet amb suport d'enllaÃ§os agregats LACP (802.3ad) i etiquetatge de VLANs (802.1Q). A la seu central s'estableix una topologia amb separaciÃ³ fÃ­sica i lÃ²gica de trÃ nsit:
  - **VLAN 10 (DMZ):** Rang `10.0.10.0/24` destinat exclusivament al servidor intermediari invers `dmz-web`.
  - **VLAN 20 (LAN Seu):** Rang `10.0.20.0/24` per a la base de dades `srv-serveis` i el node de cÃ²pies `srv-backup`.
  - **VLAN 99 (GestiÃ³ iDRAC):** Rang privat fora de banda per al monitoratge de maquinari i SAI.
- **Sistema d'AlimentaciÃ³ Ininterrompuda (SAI / UPS):** APC Smart-UPS On-Line 2200VA 2U (SRT2200RMXLI) amb tecnologia de doble conversiÃ³ real ($VFI$), targeta de gestiÃ³ SNMP Network Management Card (AP9641) per llanÃ§ar ordres d'aturada ordenada dels hipervisors i bateries segellades de plom-Ã cid que garanteixen un mÃ­nim de 45 minuts d'autonomia davant de talls de xarxa elÃ¨ctrica general.
- **ClimatitzaciÃ³ i Rack:** Armari Rack de 19" 24U amb porta perforada al 80% per a flux d'aire davanter-posterior, PDU gestionable per presa i termÃ²stat ambiental de control de sala.

### 4.2. Infraestructura a Cada Granja (Condicions Reals d'Entorn Hostil)
Les granges avÃ­coles d'engreix presenten ambients especialment severs: presÃ¨ncia massiva de pols en suspensiÃ³ procedent del pinso i la jaÃ§a, plomissol d'aus que embussa ventiladors convencionals, vapors corrosius d'amonÃ­ac ($NH_3$), humitat relativa superior al 80% i micro-talls freqÃ¼ents en lÃ­nies elÃ¨ctriques rurals:
- **Gateway Industrial Local (`granja1-srv`):** Equip fanless (sense ventilador) Advantech UNO-2271G amb certificaciÃ³ industrial IP50/IP65, processador Intel Celeron N3350, 4 GB RAM, 32 GB eMMC i rang de temperatura operativa de -20 ÂºC a +60 ÂºC. S'allotja sobre carril DIN a l'interior d'un armari de poliÃ¨ster reforÃ§at amb fibra de vidre IP66 (600x400x200 mm) amb premsaestopes estancs. La dissipaciÃ³ tÃ¨rmica passiva a travÃ©s del xassÃ­s d'alumini evita l'entrada de pols o humitat a l'electrÃ²nica.
- **ConnexiÃ³ WAN Redundant:** Router industrial 4G/5G Teltonika RUT955 amb ranura doble SIM per a commutaciÃ³ automÃ tica (*failover*) entre dues operadores de telefonia mÃ²bil diferents (ex: Movistar com a primÃ ria i Vodafone com a secundÃ ria) i client VPN WireGuard resident.
- **AÃ¯llament ElÃ¨ctric i ProtecciÃ³ de Sobretensions:** Protectors de sobretensiÃ³ i aÃ¯lladors galvÃ nics optoacoblats sobre el bus sÃ¨rie RS485 per desacoblar els impulsos electromagnÃ¨tics generats per l'arrencada dels grans motors dels ventiladors i les descÃ rregues de tempestes rurals.
- **Mini-SAI de Carril DIN:** Phoenix Contact QUINT-UPS 24V DC / 5A amb acumulador LiFePO4 que assegura un mÃ­nim de 2 hores de funcionament ininterromput per al gateway `granja1-srv`, el router 4G i els sensors en cas de caiguda del subministrament a la granja.
- **Buffer de dades (*Store-and-Forward*):** Davant la pÃ¨rdua de connectivitat celÂ·lular o caiguda del tÃºnel VPN, `granja1-srv` acumula les trames telemÃ¨triques a la seva memÃ²ria flash local (amb capacitat per a mÃ©s de 72 hores de lectures) i executa una sincronitzaciÃ³ ordenada un cop restablert l'enllaÃ§ sense saturar el broker central ni perdre informaciÃ³.

### 4.3. AnÃ lisi de Criticitat i Mecanismes de RedundÃ ncia (Requeriment 4.6)
S'estableix una classificaciÃ³ dels components del sistema segons el seu nivell de criticitat operacional i el cost associat:

| Servei / Recurs | Nivell de Criticitat | Mecanisme de RedundÃ ncia Escollit | Impacte Admissible de Caiguda | JustificaciÃ³ TÃ¨cnica |
| :--- | :---: | :--- | :--- | :--- |
| **Control de Clima i VentilaciÃ³ (Camp)** | **MÃ€XIMA (Vital)** | **Edge Computing Local a `granja1-srv`** | **0 segons (Temps real)** | La fallada de ventilaciÃ³ en dies de calor extrema causa la mort per asfÃ­xia de milers d'aus en menys de 20 minuts. L'actuaciÃ³ sobre relÃ©s s'executa en local sense dependre d'Internet ni de la seu central. |
| **Emmagatzematge CPD (Seu)** | **ALTA** | **RAID 10 Hardware (4x SSD)** | **0 segons (TransparÃ¨ncia total)** | Tolera la pÃ¨rdua de discos fÃ­sics sense interrupciÃ³ del servei ni degradaciÃ³ greu d'IOPS. |
| **Base de Dades Transaccional (CPD)** | **ALTA** | **MariaDB Streaming Replication (Hot Standby)** | **Pocs segons / minuts** | rÃ¨plica GTID contÃ­nua. Protegeix contra la caiguda del procÃ©s MariaDB. Si cau la VM completa de serveis, la restauraciÃ³ es coordina des de `srv-backup` en < 30 minuts. |
| **EnllaÃ§ de Xarxa a la Granja** | **MITJANA** | **Doble SIM (Failover 4G/5G) + Store-and-Forward** | **Fins a 72 hores sense dades en viu** | Si cauen ambdues operadores mÃ²bils, la granja no envia grÃ fiques al portal central perÃ² el bestiar estÃ  protegit pel control Edge local. |
| **Servei Directori LDAP** | **MITJANA** | **Imatge contenidoritzada + Buidatges diaris `slapcat`** | **< 30 minuts (RTO)** | L'arbre d'usuaris Ã©s prÃ cticament estÃ tic; en cas d'incident greu es desplega un contenidor nou i s'injecta l'arxiu LDIF d'origen. |

---

## 5. Seguretat Perimetral: OPNsense, DMZ i Tallafocs (Requeriment 4.4)

El tallafocs perimetral `fw-seu` (OPNsense) aplica una polÃ­tica estricta de tall per defecte (**`Default DROP`**) en totes les interfÃ­cies. NomÃ©s es permet el trÃ nsit explÃ­citament autoritzat per la polÃ­tica de seguretat corporativa.

### 5.1. Taula Formal de Regles de Tallafocs
En compliment del requisit d'avaluaciÃ³ de la guia oficial, s'especifica la matriu formal de regles implementades al tallafocs OPNsense:

| NÃºm | InterfÃ­cie / Zona | AdreÃ§a Origen | Port Origen | AdreÃ§a DestÃ­ | Port DestÃ­ | Protocol | AcciÃ³ | JustificaciÃ³ TÃ¨cnica i Seguretat |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **R-01** | WAN | `CLIENTS_AUTORITZATS` (Llista blanca IPs) | Qualsevol | `10.0.10.10` (`dmz-web`) | 443 | TCP | **PASS** | Permet l'accÃ©s web HTTPS dels clients autoritzats al portal de gestiÃ³. |
| **R-02** | WAN | `CLIENTS_AUTORITZATS` (Llista blanca IPs) | Qualsevol | `10.0.10.10` (`dmz-web`) | 80 | TCP | **PASS** | RedirecciÃ³ automÃ tica HTTP cap a HTTPS (Port 443). |
| **R-03** | WAN | Qualsevol (`0.0.0.0/0`) | Qualsevol | WAN Address (`fw-seu`) | 51820 | UDP | **PASS** | EncapÃ§alament del tÃºnel VPN WireGuard des de les granges remotes. |
| **R-04** | WAN | Qualsevol (`0.0.0.0/0`) | Qualsevol | Qualsevol | Qualsevol | Qualsevol | **DROP (Log)** | Regla implÃ­cita per defecte: bloqueig de tot intent d'accÃ©s no reconegut des d'Internet. |
| **R-05** | DMZ | `10.0.10.10` (`dmz-web`) | Qualsevol | `10.0.20.10` (`srv-serveis`) | 3306 | TCP | **PASS** | Consultes de la capa d'aplicaciÃ³ web a la base de dades MariaDB 10.11 LTS. |
| **R-06** | DMZ | `10.0.10.10` (`dmz-web`) | Qualsevol | `10.0.20.10` (`srv-serveis`) | 389 / 636 | TCP | **PASS** | AutenticaciÃ³ d'usuaris i resoluciÃ³ de rols mitjanÃ§ant OpenLDAP / LDAPS. |
| **R-07** | DMZ | `10.0.10.0/24` (DMZ Net) | Qualsevol | `10.0.20.0/24` (LAN Net) | Qualsevol | Qualsevol | **DROP (Log)** | **AÃ¯llament estricte DMZ->LAN:** Si la mÃ quina web Ã©s compromesa, no pot pivotar a la LAN ni a `srv-backup`. |
| **R-08** | VPN (WireGuard) | `10.0.100.10` (`granja1-srv`) | Qualsevol | `10.0.20.10` (`srv-serveis`) | 1883 / 8883 | TCP | **PASS** | Ingesta de lectures telemÃ¨triques des del gateway de camp al Broker MQTT central. |
| **R-09** | VPN (WireGuard) | `10.0.100.0/24` (VPN Net) | Qualsevol | `10.0.20.0/24` (LAN Net) | Qualsevol | Qualsevol | **DROP (Log)** | Les granges tenen vetat l'accÃ©s directe a la BD, a LDAP i a qualsevol altre servei intern de la seu. |
| **R-10** | LAN | `10.0.20.20` (`srv-backup`) | Qualsevol | `10.0.20.10` (`srv-serveis`) | 22 (SSH), 3306, 389 | TCP | **PASS** | ExtracciÃ³ programada de cÃ²pies de seguretat nocturnes (`mariadb-dump` i `slapcat`). |
| **R-11** | LAN | `10.0.20.0/24` (LAN Net) | Qualsevol | Qualsevol (WAN) | 80, 443 | TCP | **PASS** | Sortida a Internet exclusiva per a actualitzacions de paquets del sistema operatiu (APT / Docker). |

### 5.2. AÃ¯llament i MitigaciÃ³ d'Amenaces
1. **Llista Blanca DinÃ mica (`CLIENTS_AUTORITZATS`):** OPNsense empra un Ã lies de tipus *Host/Network* amb les IPs fixes dels operadors o proveÃ¯dors autoritzats, protegint el portal web contra atacs d'escaneig massiu i denegaciÃ³ de servei (DDoS).
2. **Defensa en Profunditat contra CompromÃ­s del Servidor Web:** La regla `R-07` impedeix qualsevol intent de moviment lateral cap a la mÃ quina de cÃ²pies `srv-backup` o cap als ports d'administraciÃ³ de la base de dades.
3. **RestricciÃ³ de les Granges per Disseny:** El tÃºnel VPN no integra la granja a la LAN interna; actua Ãºnicament com a canonada d'enllaÃ§ per a paquets MQTT autenticats.

---

## 6. Directori Centralitzat d'Usuaris â€” OpenLDAP (Requeriment 4.2)
*Allotjat a `srv-serveis` (`10.0.20.10`)*. Base del directori: `dc=avigest,dc=cat`.

El sistema implementa una gestiÃ³ centralitzada d'identitats i control d'accessos mitjanÃ§ant OpenLDAP per autenticar tant el personal tÃ¨cnic i directiu d'AviGest com els usuaris de les empreses integradores i operaris de camp.

### 6.1. Diagrama de l'Arbre Organitzatiu LDAP (DIT - Directory Information Tree)
L'arbre s'estructura separant l'organitzaciÃ³ central d'AviGest, els grups globals de seguretat i les unitats organitzatives per cada client integrador, forÃ§ant l'aÃ¯llament per disseny:

> [!TIP]
> Teniu disponible el diagrama font vectorial de l'arbre LDAP a [`docs/diagrames/esquema_ldap.drawio`](../diagrames/esquema_ldap.drawio) (llest per obrir amb Draw.io / diagrams.net).

```mermaid
graph TD
    Root["dc=avigest,dc=cat"]
    
    OU_AviGest["ou=avigest<br/>(Personal Central)"]
    OU_Groups["ou=groups<br/>(Grups de Seguretat)"]
    OU_Clients["ou=clients<br/>(Clients Multitenant)"]
    
    Root --> OU_AviGest
    Root --> OU_Groups
    Root --> OU_Clients
    
    User_Admin["uid=admin_avigest<br/>(Admin Plataforma)"]
    User_Suport["uid=tecnic_suport"]
    OU_AviGest --> User_Admin
    OU_AviGest --> User_Suport
    
    Grp_Admins["cn=AdminsAviGest"]
    Grp_Clients["cn=AdminsClient"]
    Grp_Gestors["cn=GestorsGranja"]
    Grp_Consulta["cn=UsuarisConsulta"]
    OU_Groups --> Grp_Admins
    OU_Groups --> Grp_Clients
    OU_Groups --> Grp_Gestors
    OU_Groups --> Grp_Consulta
    
    OU_Client1["ou=client_agroponent (ID: 1)"]
    OU_Client2["ou=client_segria (ID: 2)"]
    OU_Clients --> OU_Client1
    OU_Clients --> OU_Client2
    
    User_C1_Admin["uid=jaume_admin<br/>businessCategory: CLIENT_1<br/>(Veu Bellpuig i Mollerussa)"]
    OU_Client1 --> User_C1_Admin
    
    OU_G1["Granja 1: Bellpuig (id_granja: 1)"]
    OU_G2["Granja 2: Mollerussa (id_granja: 2)"]
    OU_Client1 --> OU_G1
    OU_Client1 --> OU_G2
    
    User_G1["uid=gestor_bellpuig<br/>departmentNumber: GRANJA_1"]
    User_G2["uid=gestor_mollerussa<br/>departmentNumber: GRANJA_2"]
    OU_G1 --> User_G1
    OU_G2 --> User_G2

    User_C2_Admin["uid=laura_admin<br/>businessCategory: CLIENT_2"]
    OU_Client2 --> User_C2_Admin
    OU_G3["Granja 3: AlcarrÃ s (id_granja: 3)"]
    OU_Client2 --> OU_G3
    User_G3["uid=gestor_alcarras<br/>departmentNumber: GRANJA_3"]
    OU_G3 --> User_G3
```

### 6.2. Matriu de Permisos i Control d'AccÃ©s per Rol (R2 i R3)
En compliment estricte de la guia d'avaluaciÃ³, s'estableix la matriu formal **Rol $\times$ Recurs $\times$ AcciÃ³**:

| Rol del Sistema | Ã€mbit Organitzatiu | Atribut LDAP Identificador | AccÃ©s a Portal Web | AccÃ©s a BD MariaDB | PermÃ­s sobre Dades de Granja | AccÃ©s SSH / AdministraciÃ³ |
| :--- | :--- | :--- | :---: | :---: | :--- | :---: |
| **Administrador AviGest** (`AdminsAviGest`) | Global (Tota la plataforma) | Membre de `cn=AdminsAviGest` | Total (Panell Superadmin) | Total (`avigest_app` Superuser) | CreaciÃ³/baixa de clients, gestiÃ³ global de tarifes i suport tÃ¨cnic | SÃ­ (Seu i Servidors) |
| **Administrador de Client** (`AdminsClient`) | Empresa integradora concreta | `businessCategory: CLIENT_<ID>` | Panell Client Multitenant | Consulta filtrada (`avigest_consulta`) | Lectura i informes de **totes les granges** del seu grup empresarial | No |
| **Gestor de Granja** (`GestorsGranja`) | Ãšnica explotaciÃ³ ramadera | `departmentNumber: GRANJA_<ID>` | Panell Operari de Granja | Consulta filtrada (`avigest_consulta`) | **NomÃ©s la seva prÃ²pia granja** (lectures, estat de silos i alarmes) | No |
| **Usuari de Consulta** (`UsuarisConsulta`) | EspecÃ­fic per granja/client | `businessCategory` o `departmentNumber` | Mode AudiciÃ³ / Consulta | NomÃ©s lectura (`SELECT` RLS) | NomÃ©s visualitzaciÃ³ d'histÃ²rics i informes veterinaris (sense canvis) | No |

### 6.3. Mecanisme TÃ¨cnic d'AÃ¯llament Multitenant (R3)
L'aÃ¯llament requerit es garanteix mitjanÃ§ant una doble barrera coordinada entre LDAP i la BD:
1. Quan un usuari s'autentica al portal web contra OpenLDAP, el sistema llegeix els seus atributs `businessCategory` (identificador de client) i `departmentNumber` (identificador de granja).
2. La connexiÃ³ a MariaDB executa automÃ ticament la funciÃ³ de context de sessiÃ³:
   ```sql
   CALL sp_set_tenant(p_id_client := 1, p_id_granja := 1);
   ```
3. Les polÃ­tiques de seguretat a nivell de fila (**Row Level Security - RLS**) de MariaDB filtren automÃ ticament qualsevol sentÃ¨ncia `SELECT`, impedint de forma matemÃ tica que un gestor de Bellpuig pugui visualitzar dades o alarmes d'AlcarrÃ s.

---

## 7. Base de Dades Centralitzada: MariaDB 10.11 LTS i RÃ¨plica (Requeriment 4.3)
*Allotjada a `srv-serveis` (`10.0.20.10`)*.

### 7.1. Model Entitat-RelaciÃ³ Complet (Mermaid) i NormalitzaciÃ³ 3FN

#### JustificaciÃ³ del Modelat i NormalitzaciÃ³ (Tercera Forma Normal - 3FN)
L'esquema relacional d'AviGest ha estat dissenyat estrictament en **3FN** per garantir la integritat referencial, eliminar redundÃ ncies i assegurar un rendiment Ã²ptim davant la concurrÃ¨ncia d'ingesta IoT:
1. **Primera Forma Normal (1FN):** Tots els atributs contenen valors atÃ²mics (sense llistes ni conjunts repetitius). Cada taula disposa d'una clau primÃ ria Ãºnica (`id_client`, `id_granja`, `id_nau`, `id_sensor`, etc.).
2. **Segona Forma Normal (2FN):** En complir la 1FN, cap atribut no clau depÃ¨n parcialment de la clau primÃ ria. Totes les entitats empren claus substitutives simples (`INT AUTO_INCREMENT` o `BIGINT AUTO_INCREMENT`), evitant qualsevol dependÃ¨ncia funcional parcial.
3. **Tercera Forma Normal (3FN):** No hi ha dependÃ¨ncies transitives entre atributs no clau. Per exemple, les dades de contacte del client no es repliquen a `granges`, ni les dimensions de la nau es repeteixen a `lectures_sensors`. Cada taula modela exclusivament el seu domini.

#### TraÃ§abilitat de Codi i Dades de Prova
El disseny estÃ  directament implementat i versionat al repositori per a la seva execuciÃ³ a Docker:
- **DDL d'Esquema i Ãndexs:** [`bd/sql/01_esquema.sql`](file:///c:/avigest-projecte-git/bd/sql/01_esquema.sql) (amb rÃ¨plica a [`docker/initdb/01_esquema.sql`](file:///c:/avigest-projecte-git/docker/initdb/01_esquema.sql)).
- **LÃ²gica procedural (Triggers i Funcions MariaDB Procedural):** [`bd/procediments-triggers/02_triggers_procedures.sql`](file:///c:/avigest-projecte-git/bd/procediments-triggers/02_triggers_procedures.sql).
- **Dades de prova inicials:** [`bd/sql/03_dades_prova.sql`](file:///c:/avigest-projecte-git/bd/sql/03_dades_prova.sql) (precarrega clients com *AgroPonent S.L.* i *AvÃ­cola del SegriÃ  S.A.*, granges a Bellpuig i AlcarrÃ s, sensors amb llindars reals i un histÃ²ric de lectures per comprovar vistes).

### 2.1. Arquitectura de MÃ quines Virtuals i Xarxa (Diagrama de Blocs)
> [!TIP]
> Teniu disponible el diagrama font editable a [`docs/diagrames/esquema_xarxa_vms.drawio`](../diagrames/esquema_xarxa_vms.drawio) (llest per obrir amb Draw.io / diagrams.net).

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
        NUMERIC pes_mitja_kg
        NUMERIC pinso_consumit_kg
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
        BIGINT id_registre PK
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
        TEXT observacions_resolucio
    }
    AUDITORIA_CANVIS {
        BIGINT id_auditoria PK
        VARCHAR taula
        VARCHAR operacio
        VARCHAR usuari_bd
        JSON dades_antigues
        JSON dades_noves
        TIMESTAMP data_hora
    }
```

### 7.2. LÃ²gica Procedural i Triggers MariaDB Procedural (R5 i R7)
- **Control de termÃ²stat automÃ tic:** Trigger `trg_control_llindars_sensor` que commuta ventiladors a `ON` i calefactors a `OFF` si $T > 31^\circ\text{C}$, generant l'acciÃ³ a `registre_actuacions` i alarma crÃ­tica a `alarmes_incidencies` si $T \ge 33^\circ\text{C}$. TambÃ© cobreix CO2 i silo buit.
- **NormalitzaciÃ³ de temperatura:** Aturada automÃ tica de ventilaciÃ³ quan la temperatura retorna al rang Ã²ptim ($20^\circ\text{C} \le T \le 31^\circ\text{C}$).
- **Auditoria:** Trigger `trg_audit_*` sobre `clients`, `granges`, `lots_crianca` i `sensors` (no sobre telemetria, per volum).
- **RLS:** Sense `sp_set_tenant()` el rol `avigest_consulta` no veu files. `CALL sp_set_tenant(1, 1)` limita a la granja Bellpuig. El rol `avigest_app` Ã©s superusuari de Docker i **no** demostra l'aÃ¯llament.

### 7.3. Consultes i Vistes Comparatives de Negoci (Requeriment 4.3)
1. **`v_comparativa_lots_rendiment`:** Mortalitat, percentatge de baixes i durada de cicles entre naus i granges.
2. **`v_resum_diari_climatic`:** Agrupacions diÃ ries de temperatures mitjanes, mÃ­nimes, mÃ ximes i volum d'alarmes per nau per detectar estrÃ¨s tÃ¨rmic.
3. **`v_estat_silos_gra`:** Monitoratge de pes romanent de pinso als silos i avÃ­s precoÃ§ de comandes abans d'esgotar l'estoc.
4. **`v_panell_executiu_global`:** VisiÃ³ agregada multitenant amb recompte de naus, capacitat d'aus en producciÃ³ i incidÃ¨ncies pendents per client.

### 7.4. Rols SQL de MÃ­nim Privilegi
- `avigest_app`: Superusuari del clÃºster Docker (portal i administraciÃ³).
- `avigest_iot`: **NomÃ©s `INSERT`** a `lectures_sensors` (`BYPASSRLS` per poder ingestir totes les granges).
- `avigest_consulta`: NomÃ©s `SELECT`; l'aÃ¯llament R3 s'hi aplica via RLS i vistes `security_invoker`.
- `avigest_backup`: `mariadb-dump` amb `BYPASSRLS`.

---

## 8. Arquitectura IoT: SimulaciÃ³, Edge Computing i Inventari (Requeriments 4.8 i R4)

### 8.1. Arquitectura de Comunicacions (HÃ­brid RS485 + LoRaWAN)

![Arquitectura i Flux IoT End-to-End](../diagrames/esquema_flux_iot.png)
*Figura 2: Arquitectura de recollida de dades i flux telemÃ¨tric en 5 capes, des de la sensÃ²rica de camp fins a MariaDB 10.11 LTS.*

> [!TIP]
> Teniu disponible el diagrama font vectorial editable a [`docs/diagrames/esquema_flux_iot.drawio`](../diagrames/esquema_flux_iot.drawio) (llest per obrir amb Draw.io / diagrams.net).

1. **`granja1-sim` (Simulador de Dispositius):**
   - Simula microcontroladors ESP32 amb sensors ambientals connectats per bus sÃ¨rie diferencial **RS485 (Modbus RTU)** dins de les naus.
   - Simula cÃ¨lÂ·lules de pesatge de silos exteriors transmetent per rÃ dio **LoRaWAN (868 MHz)** gestionats per servidor **ChirpStack**.
2. **`granja1-srv` (Controlador Local Edge):**
   - Rep lectures mitjanÃ§ant broker MQTT local.
   - **Regles locals d'actuaciÃ³ autÃ²noma:** ExecuciÃ³ immediata de ventilaciÃ³ si $T > 31^\circ\text{C}$ sense dependre d'Internet.
   - **Buffer Store-and-Forward:** RetenciÃ³ local de dades fins a 72 hores si cau el tÃºnel VPN.

### 8.2. Inventari Necessari de l'IoT i FreqÃ¼Ã¨ncies de Mostreig (Requisit ExplÃ­cit d'AvaluaciÃ³)

La segÃ¼ent taula recull el dimensionament fÃ­sic de sensors, actuadors, equipament de comunicacions i la **freqÃ¼Ã¨ncia de mostreig / enviament** per a una explotaciÃ³ pilot estÃ ndard (Granja de 2 naus i 2 silos):

| Dispositiu / Sensor | Model de ReferÃ¨ncia Industrial | Protocol / Tecnologia | Rang de Treball i PrecisiÃ³ | FreqÃ¼Ã¨ncia de Mostreig | UbicaciÃ³ FÃ­sica | Quantitat per Nau / Granja |
| :--- | :--- | :--- | :--- | :---: | :--- | :---: |
| **Sonda Temp / Humitat** | Industrial SHT30 / XY-MD02 (amb filtre sinteritzat) | RS485 (Modbus RTU) | -40 a +80 ÂºC ($\pm 0.3^\circ\text{C}$) / 0-100% RH ($\pm 3\%$) | **Cada 30 segons** (mostreig rÃ pid per prevenciÃ³ d'estrÃ¨s tÃ¨rmic) | Interior de cada nau (repartits a terÃ§ davanter, central i posterior) | 3 per nau (6 per granja) |
| **Sensor de $CO_2$ industrial** | Senseair S8 / Winsen MH-Z19C NDIR | RS485 (Modbus RTU) | 0 a 5.000 ppm ($\pm 50$ ppm) | **Cada 60 segons** (evoluciÃ³ lenta de gasos en nau) | AlÃ§ada d'aus (centre de la nau) | 1 per nau (2 per granja) |
| **CÃ¨lÂ·lules de pesatge de Sitja** | Transductor de cÃ rrega per a potes de silo (4x celÂ·les) | MÃ²dul LoRaWAN 868 MHz (IP67) | 0 a 20.000 kg ($\pm 0.5\%$) | **Cada 15 minuts** (estalvi de bateria i compliment de *Duty Cycle* 1%) | Base exterior dels silos de gra | 1 kit per silo (2 per granja) |
| **Comptador d'Aigua d'impulsos** | Comptador d'emissor de polsos Woltman DN20 | RS485 / Entrada digital ESP32 | 1 pols / litre | **Cada 5 minuts** (acumulat de litres consumits) | Entrada de lÃ­nia d'abeuradors | 1 per nau (2 per granja) |
| **MÃ²dul de Control / Micro** | ESP32-WROOM-32U amb xassÃ­s DIN i antena exterior | WiFi / Ethernet + RS485 transceiver MAX485 | 240 MHz Dual Core, 3.3V/5V DC | En temps real (gestiÃ³ d'interrupcions) | Armari elÃ¨ctric de capÃ§alera de nau | 1 per nau (2 per granja) |
| **MÃ²dul de RelÃ©s Actuadors** | MÃ²dul 4/8 canals relÃ© optoacoblat 16A/250VAC | RS485 Modbus / GPIO 5V | Suport cÃ rregues inductives de motors | Per canvi d'estat immediat | Quadre de maniobra de ventiladors/calefacciÃ³ | 1 per nau (2 per granja) |
| **Gateway LoRaWAN exterior** | Dragino LPS8N / Milesight UG65 | LoRaWAN 868 MHz (8 canals) cap a Ethernet | Cobertura exterior fins a 2-3 km | Ininterromput (encaminament de paquets) | FaÃ§ana exterior de la sala de control | 1 per granja |
| **Gateway Industrial Local** | Advantech UNO-2271G (Fanless IP50/65) | Dual GbE, RS485 integrat, MQTT / VPN | Linux Ubuntu Server 24.04 LTS, xassÃ­s carril DIN | Ininterromput (broker Edge i buffer) | Armari de control IP66 | 1 per granja (`granja1-srv`) |

---

## 9. CÃ²pies de Seguretat i Servidor Dedicat â€” PRD (Requeriment 4.5)
*Allotjat a `srv-backup` (`10.0.20.20`)*.

El sistema implementa una estratÃ¨gia integral de continuÃ¯tat de negoci mitjanÃ§ant cÃ²pies de seguretat automatitzades i un Pla de RecuperaciÃ³ davant Desastres (**PRD**) dissenyat per complir amb les mÃ¨triques d'RTO i RPO exigides.

### 9.1. AnÃ lisi i ElecciÃ³ del Tipus de CÃ²pia
Per a la seu central d'AviGest s'ha avaluat la tipologia de cÃ²pies:
- **CÃ²pia Completa diÃ ria (OpciÃ³ triada):** ExecuciÃ³ nocturna d'un buidatge lÃ²gic transaccional complet de MariaDB (`mariadb-dump -Fc` en format personalitzat comprimit) i del directori OpenLDAP (`slapcat`). Donat que el volum diari consolidat de la BD oscilÂ·la entre 200 MB i 500 MB, la cÃ²pia completa Ã©s la mÃ©s neta, simplifica al mÃ xim la restauraciÃ³ (evita cadenes complexes de diferencials o incrementals) i redueix el temps de recuperaciÃ³ a menys de 15 minuts.
- **CÃ²pies Incrementals / Diferencials (Descartades inicialment):** Tot i consumir menys amplada de banda, requereixen gestionar cadenes de restauraciÃ³ dependents del darrer *full backup*. Si falla un fitxer intermedi de la cadena, la restauraciÃ³ queda compromesa.
- **RetenciÃ³ i Integritat:** RetenciÃ³ de 30 dies a disc amb comprovaciÃ³ d'integritat mitjanÃ§ant hash criptogrÃ fic **SHA-256** generat immediatament en finalitzar el fitxer `.tar.gz`.

### 9.2. MÃ¨triques RTO i RPO Justificades per Servei

| Servei / Tipus de Dades | RPO (PÃ¨rdua mÃ x. de dades admissible) | RTO (Temps mÃ x. de restauraciÃ³ operatiu) | JustificaciÃ³ Operativa |
| :--- | :---: | :---: | :--- |
| **Directori LDAP (Usuaris i Rols)** | **24 hores** | **15 minuts** | L'arbre organitzatiu Ã©s gairebÃ© estÃ tic; una pÃ¨rdua de canvis recents no atura les granges i la restauraciÃ³ amb `slapadd` Ã©s gairebÃ© instantÃ nia. |
| **ConfiguraciÃ³ i Regles OPNsense** | **24 hores** | **10 minuts** | CÃ²pia en fitxer XML de configuraciÃ³; restaurable immediatament des de la consola o GUI del tallafocs. |
| **Base de Dades: Dades de Negoci (Lots, Granges)** | **24 hores** | **30 minuts** | Les altes de lots o granges sÃ³n transaccions planificades que es poden reintroduir manualment si cal. |
| **Base de Dades: Telemetria de Sensors IoT** | **< 1 hora** | **30 minuts** | Tot i que el backup a la seu Ã©s diari, el buffer *Store-and-Forward* resident a `granja1-srv` mantÃ© fins a 72 h de dades que es reenvien automÃ ticament en restablir-se la BD central, deixant el RPO real de telemetria en 0 pÃ¨rdues. |

### 9.3. AutomatitzaciÃ³ del Buidatge (Crontab i Scripts)
El procÃ©s estÃ  completament desatÃ¨s a la mÃ quina `srv-backup` mitjanÃ§ant crontab:
```cron
# ExecuciÃ³ cada nit a les 02:00 AM (baixa cÃ rrega)
0 2 * * * /usr/local/bin/backup_avigest.sh >> /var/log/avigest_backup.log 2>&1
```

L'script [`infra/backups-prd/backup_avigest.sh`](file:///c:/avigest-projecte-git/infra/backups-prd/backup_avigest.sh) executa:
1. ComprovaciÃ³ de connectivitat cap a `srv-serveis:3306` i `srv-serveis:389`.
2. Buidatge `mariadb-dump` amb l'usuari `avigest_backup` (amb permÃ­s `BYPASSRLS`).
3. ExtracciÃ³ en calent de la base LDAP amb `slapcat`.
4. Empaquetat comprimit `.tar.gz` amb marca temporal (`avigest_backup_YYYYMMDD_HHMMSS.tar.gz`).
5. GeneraciÃ³ del fitxer de comprovaciÃ³ `.sha256`.
6. CÃ²pia al segon disc dur muntat a `/mnt/disc-extern-backup/` (simulant suport extern) i purga de fitxers de mÃ©s de 30 dies.

### 9.4. Protocol de Prova de RestauraciÃ³ davant Desastre (SimulaciÃ³ PRD)
Per validar el compliment del **RTO â‰¤ 30 minuts**, s'ha establert el segÃ¼ent protocol de prova:
1. **InvocaciÃ³:** ExecuciÃ³ de l'script [`infra/backups-prd/restaurar_avigest.sh`](file:///c:/avigest-projecte-git/infra/backups-prd/restaurar_avigest.sh) indicant el paquet de cÃ²pia.
2. **ValidaciÃ³ del Hash:** L'script verifica `sha256sum -c` per comprovar que el paquet no s'ha corromput al disc.
3. **Parada i neteja controlada:** Aturada temporal d'`avigest_mariadb` o recreaciÃ³ del volum de base de dades.
4. **RestauraciÃ³:** InjecciÃ³ del bolcat amb `mariadb -u avigest_app -pavigest_secret_2026 avigest_db`.
5. **ComprovaciÃ³ de salut:** ExecuciÃ³ de la consulta `SELECT COUNT(*) FROM lectures_sensors;` i comprovaciÃ³ del panell executiu. El procediment complet triga menys de 8 minuts en laboratori.

---

## 10. AutomatitzaciÃ³ de CreaciÃ³ de Granges i VariaciÃ³ (Requeriment 4.7)

L'script d'automatitzaciÃ³ estÃ  preparat per donar resposta a la **prova presencial de variaciÃ³** exigida al punt 7 de l'enunciat:

> *"Per afegir la Granja 2 (la variaciÃ³ que us demanaran), es clonen `granja1-srv` i `granja1-sim` en una xarxa nova (`10.1.2.0/24`). L'script del 4.7 crea l'usuari a LDAP, l'esquema a la BD i la regla al firewall."*

L'eina desenvolupada Ã©s [`scripts/automatitzacio-granges/alta_granja.sh`](file:///c:/avigest-projecte-git/scripts/automatitzacio-granges/alta_granja.sh). Per complir amb el grau de detall de disseny requerit per la guia oficial d'avaluaciÃ³, s'especifiquen els parÃ metres, comprovacions i arquitectura del procÃ©s.

### 10.1. ParÃ metres d'Entrada de l'Script
L'script accepta arguments mitjanÃ§ant flags estÃ ndard POSIX (`getopts`):
- `-c <id_client>`: Identificador numÃ¨ric del client existent a la plataforma.
- `-n <nom_granja>`: Nom descriptiu de l'explotaciÃ³ (ex: "Granja AlcarrÃ s").
- `-e <codi_explotacio>`: Codi REGA oficial de la granja (ex: "ES250020000002").
- `-a <adreca>`: AdreÃ§a postal fÃ­sica.
- `-p <poblacio>`: Municipi de l'explotaciÃ³.
- `-s <num_naus>`: Nombre de naus que contÃ© la granja (per defecte: 2).
- `-u <usuari_gestor>`: Nom d'usuari per al responsable de la granja a OpenLDAP.
- `-r <rang_xarxa>`: Subxarxa LAN assignada a la granja (per defecte: `10.1.2.0/24`).

### 10.2. Comprovacions i Validacions PrÃ¨vies
Abans de dur a terme qualsevol modificaciÃ³ a l'entorn de producciÃ³, l'script valida:
1. **ComprovaciÃ³ de binaris:** ExistÃ¨ncia de `mariadb` (o `mysql`), `ldapadd`, `ssh` i eines de xarxa al sistema amfitriÃ³.
2. **ConnexiÃ³ amb els serveis centrals:** Ping i sondeig de port a `srv-serveis` (Port 3306 per a MariaDB i 389 per a LDAP).
3. **Integritat de parÃ metres:** VerificaciÃ³ de camps buits obligatoris i sanejament d'injecciÃ³ SQL (`sql_escape`).
4. **VerificaciÃ³ de no duplicitat:** ComprovaciÃ³ que el codi d'explotaciÃ³ i el compte d'usuari no existeixin prÃ¨viament ni a MariaDB ni a LDAP.

### 10.3. Ordre d'ExecuciÃ³ i Accions AtÃ²miques
1. **CreaciÃ³ a Base de Dades (MariaDB 10.11 LTS):**
   - InserciÃ³ atÃ²mica a la taula `granges` associada a l'`id_client`.
   - Bucle automÃ tic per generar les $N$ naus a la taula `naus` amb nomenclatura estandarditzada (`NAU-01`, `NAU-02`, etc.) i capacitat per defecte.
   - CreaciÃ³ automÃ tica del sensor de temperatura/humitat, $CO_2$ i pesatge de sitja per cada nau a la taula `sensors`.
2. **CreaciÃ³ d'Identitat i Rols a OpenLDAP:**
   - ConnexiÃ³ mitjanÃ§ant `ldapadd` amb el compte administratiu (`cn=admin,dc=avigest,dc=cat`).
   - GeneraciÃ³ de la Unitat Organitzativa de la granja si no existeix: `ou=Granja_<id>,ou=granges,dc=avigest,dc=cat`.
   - CreaciÃ³ de l'objecte usuari gestor tipus `inetOrgPerson` assignant el camp `departmentNumber: GRANJA_<id>` per forÃ§ar l'aÃ¯llament de permisos multitenant (R3).
3. **Provisionament de Seguretat i Tallafocs (OPNsense / iptables):**
   - CÃ lcul de la IP assignada al tÃºnel VPN de la nova granja: `10.0.100.<10 + id_granja>`.
   - AplicaciÃ³ de la regla estricta de trÃ nsit: permetre Ãºnicament el port MQTT (`TCP 1883`) des d'aquesta IP d'origen cap al broker de `srv-serveis` (`10.0.20.10`) i bloquejar (`DROP`) qualsevol altre accÃ©s cap a la LAN central.
4. **CreaciÃ³ de l'Estructura de Directoris Local:**
   - CreaciÃ³ del directori `/var/avigest/granges/granja_<id>/` amb permisos `750` per a l'emmagatzematge de logs i configuracions VPN locals.

### 10.4. GestiÃ³ d'Errors i Rollback
Si qualsevol dels passos falla a causa d'un problema de xarxa o de validaciÃ³, l'script atrapa el senyal `ERR` mitjanÃ§ant `trap`, atura el flux d'execuciÃ³ immediatament (`set -euo pipefail`), mostra l'error per la sortida estÃ ndard d'error (`stderr`) i deixa constÃ ncia de l'Ãºltim pas executat per permetre la neteja manual o la reexecuciÃ³ neta.

---

## 11. Fases del Projecte i PlanificaciÃ³ Actualitzada

L'execuciÃ³ del projecte es divideix en fases seqÃ¼encials amb fites i criteris d'acabament objectius des de la fase inicial de disseny fins al tancament i defensa final:

### 11.1. Fases d'ExecuciÃ³ i Criteris d'Acabament

| Fase | PerÃ­ode | DescripciÃ³ Operativa | Fita / Entregable | Criteri d'Acabament Objectiu |
| :---: | :---: | :--- | :---: | :--- |
| **Fase 0** | 14/09/2026 | ConstituciÃ³ d'equip, rols i cas de negoci. | **E0** (5%) | Repositori Git creat, rols Joan/Mariam assignats i tauler de tasques operatiu. |
| **Fase 1** | 15/09 â€“ 28/09/2026 | Estudi de mercat i anÃ lisi de necessitats del sector avÃ­cola. | **E1** (15%) | Document de necessitats entregat i defensat davant del tribunal (05/10). |
| **Fase 2** | 01/10 â€“ 04/12/2026 | Disseny tÃ¨cnic de detall, modelat de BD, xarxa, IoT, PRD i pressupostos. | **E2 + E3** (35%) | MemÃ²ries E2 i E3 entregades en PDF, fitxes de decisiÃ³ amb fonts i proves POC validades. |
| **Fase 3** | 05/12 â€“ 01/03/2027 | Desplegament de la infraestructura base de laboratoris i serveis centrals. | **E4a + E5a** (20%) | VMs `fw-seu`, `dmz-web`, `srv-serveis` i `srv-backup` operatives; Docker i LDAP funcionant. |
| **Fase 4** | 02/03 â€“ 30/04/2027 | IntegraciÃ³ IoT a camp, simulaciÃ³, proves Store-and-Forward i variaciÃ³. | **E5b + E6 + E7** (25%) | Tot el sistema provat d'extrem a extrem, variaciÃ³ de la Granja 2 resolta i defensa oral final. |

### 11.2. Diagrama de Gantt Global del Projecte

### 2.1. Arquitectura de MÃ quines Virtuals i Xarxa (Diagrama de Blocs)
> [!TIP]
> Teniu disponible el diagrama font editable a [`docs/diagrames/esquema_xarxa_vms.drawio`](../diagrames/esquema_xarxa_vms.drawio) (llest per obrir amb Draw.io / diagrams.net).

```mermaid
gantt
    title Cronograma Global del Projecte AviGest S.L. (Curs 2026-2027)
    dateFormat  YYYY-MM-DD
    axisFormat  %d/%m
    section Fases Oficials
    E0 ConstituciÃ³ Equip (5%)         :done, e0, 2026-09-14, 1d
    E1 Estudi Necessitats (15%)       :done, e1, 2026-09-15, 2026-09-28
    Defensa Oral E1                   :done, def1, 2026-10-05, 1d
    E2 Disseny TÃ¨cnic (20%)           :active, e2, 2026-10-01, 2026-12-04
    E3 Pla d'IntervenciÃ³ (15%)        :active, e3, 2026-10-15, 2026-12-04
    Lliurament Oficial E2 i E3        :milestone, m_e2e3, 2026-12-04, 0d
    E4a/E5a Primer Bloc ExecuciÃ³ (20%):e45a, 2026-12-05, 2027-03-01
    Lliurament Estat ExecuciÃ³ 1 MarÃ§  :milestone, m_mar, 2027-03-01, 0d
    E5b ExecuciÃ³ Final i VariaciÃ³     :e5b, 2027-03-02, 2027-04-20
    E6 MemÃ²ria Final i Tancament      :e6, 2027-04-10, 2027-04-30
    E7 Defensa Oral i DemostraciÃ³     :milestone, m_final, 2027-04-30, 0d
```

---

## 12. Annex d'Ãšs d'IntelÂ·ligÃ¨ncia Artificial
*En compliment estricte de la Norma 4 de l'enunciat:*

- **Eines utilitzades:** Antigravity / Gemini 3.8 Flash (High) per a esborranys de disseny; Cursor (Grok) per a revisiÃ³ creuada amb l'enunciat i correcciÃ³ de configuraciÃ³ (rÃ¨plica GTID, LDAP, RLS, ingesta MQTT).
- **Finalitat de l'Ãºs:** Eina de suport per al disseny de la topologia de xarxes, diagrames de flux, estructuraciÃ³ de fitxes de decisiÃ³, esborranys de configuraciÃ³ i depuraciÃ³. No substitueix la comprensiÃ³ de l'equip.
- **MÃ¨tode de verificaciÃ³ i comprensiÃ³:** L'equip (Joan i Mariam) ha definit l'esquema de mÃ quines virtuals, entÃ©n les regles de tallafocs, la separaciÃ³ DMZ-LAN, el flux MQTTâ†’ingestaâ†’MariaDB, el RLS amb `avigest_consulta` i la lÃ²gica de rÃ¨plica i backups per poder-ho defensar a l'oral.

---

## 13. Bibliografia i Fonts Consultades

### 13.1. Normatives i DocumentaciÃ³ TÃ¨cnica de ReferÃ¨ncia
1. **MariaDB Global Development Group (2024):** *MariaDB Foundation (2024): *MariaDB 10.11 LTS Documentation*. GTID Replication, InnoDB Engine, Stored Procedures and Triggers. [https://mariadb.com/kb/en/documentation/](https://mariadb.com/kb/en/documentation/)
2. **OPNsense Documentation (2024):** *OPNsense User Manual*. Architecture, Firewall Rule Processing, Virtual IPs, WireGuard Site-to-Site. Deciso B.V. [https://docs.opnsense.org/](https://docs.opnsense.org/)
3. **OpenLDAP Foundation (2024):** *OpenLDAP Software 2.6 Administrator's Guide*. Schema Specification, Access Control, slapcat/slapadd utilities. [https://www.openldap.org/doc/admin26/](https://www.openldap.org/doc/admin26/)
4. **LoRa Alliance (2023):** *LoRaWAN Regional Parameters RP002-1.0.4*. Especificacions per a la banda europea ISM 868 MHz i limitacions de Duty Cycle. [https://lora-alliance.org/](https://lora-alliance.org/)
5. **Modbus Organization (2022):** *Modbus over INT AUTO_INCREMENT Line Specification and Implementation Guide V1.02*. [https://modbus.org/](https://modbus.org/)
6. **CISA (Cybersecurity and Infrastructure Security Agency):** *Data Backup Options â€” The 3-2-1 Rule for Enterprise Resiliency*. [https://www.cisa.gov/](https://www.cisa.gov/)
7. **NIST (National Institute of Standards and Technology):** *SP 800-41 Rev. 1: Guidelines on Firewalls and Firewall Policy*. [https://csrc.nist.gov/](https://csrc.nist.gov/)

### 13.2. Eines d'IntelÂ·ligÃ¨ncia Artificial (CitaciÃ³ ObligatÃ²ria segons Norma 4)
8. **Google DeepMind (2026):** *Gemini 3.8 Flash (High)* emprat com a assistent en l'entorn Antigravity per a la generaciÃ³ d'esborranys de disseny, taules comparatives i estructuraciÃ³ de documents.
9. **Anysphere / xAI (2026):** *Cursor IDE amb Grok* per a la revisiÃ³ creuada de fitxers de configuraciÃ³ Docker i consultes SQL.
