<p align="center">
  <img src="../img/logo_avigest.png" alt="AviGest S.L. Logo" width="180">
</p>

# E3 — Pla d'Intervenció, Recursos, Costos i Assignació de Tasques

**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Empresa:** AviGest S.L.  
**Cicle:** CFGS Administració de Sistemes Informàtics en Xarxa (ASIX) — 2n Curs  
**Mòdul:** M12 - Projecte (Resultat d'Aprenentatge RA3 — Pes al projecte: 15%)  
**Equip de treball:**  
- **Joan Garcia** (Infraestructura, Xarxa, Seguretat i Serveis Centralitzats)  
- **Mariam Solano** (Base de Dades, IoT, Automatismes i Scripts)  
**Data de lliurament oficial:** 4 de desembre de 2026  
**Versió del document:** 2.0 (Pla d'Intervenció i Pressupostos)  

---

## Índex del Document
1. [Introducció i Objectius del Pla d'Intervenció](#1-introducció-i-objectius-del-pla-dintervenció)
2. [Pressupost Econòmic Detallat (Recursos i Costos)](#2-pressupost-econòmic-detallat-recursos-i-costos)
   - 2.1. Maquinari de la Seu Central (CPD AviGest)
   - 2.2. Maquinari per Explotació Pilot (Granja 1 — 2 naus i 2 silos)
   - 2.3. Sensòrica de Camp i Elements Electromecànics
   - 2.4. Comunicacions i Despeses Operatives Recurrents (OpEx)
   - 2.5. Recursos Humans i Mà d'Obra (198h per alumne)
   - 2.6. Balanç Econòmic Consolidat i Cost Marginal per Nova Granja
3. [Actualització de Tasques i Rols (Acompliment i Seguiment)](#3-actualització-de-tasques-i-rols-acompliment-i-seguiment)
   - 3.1. Matriu de Responsabilitats i Rols (Model RACI)
   - 3.2. Registre de Fites i Dates d'Acompliment
   - 3.3. Cronograma Global del Projecte (Curs 2026-2027)
4. [Procediment i Cronograma d'Intervenció a Camp](#4-procediment-i-cronograma-dintervenció-a-camp)
   - 4.1. Fases d'Execució a la Granja Pilot
   - 4.2. Protocol de Proves i Acceptació en Camp
5. [Pla de Contingència i Gestió de Riscos](#5-pla-de-contingència-i-gestió-de-riscos)
6. [Documentació Associada i Estructura del Repositori Git](#6-documentació-associada-i-estructura-del-repositori-git)
7. [Annex d'Ús d'Intel·ligència Artificial (Norma 4)](#7-annex-dús-dintel·ligència-artificial-norma-4)
8. [Bibliografia i Fonts de Preus Consultades](#8-bibliografia-i-fonts-de-preus-consultades)

---

## 1. Introducció i Objectius del Pla d'Intervenció

El present document constitueix el **Pla d'Intervenció (Lliurable E3)** per al projecte AviGest S.L. Aquest pla estableix el dimensionament financer, la valoració de costos d'adquisició (CapEx) i d'operació (OpEx), l'assignació exhaustiva de tasques entre els membres de l'equip amb dates de compliment reals, i el protocol pas a pas per executar la implantació dels sistemes tant a la seu central com a la granja pilot.

L'objectiu principal és garantir que el disseny tècnic definit a l'**E2** es pugui portar a la pràctica de manera controlada, viable econòmicament i amb un calendari estricte abans de la fase d'execució definitiva (E4/E5).

---

## 2. Pressupost Econòmic Detallat (Recursos i Costos)

Tots els preus estan calculats a partir de tarifes oficials de distribuïdors industrials i proveïdors de telecomunicacions (IVA no inclòs).

### 2.1. Maquinari de la Seu Central (CPD AviGest)

Equipament centralitzat d'alta disponibilitat que allotja el tallafocs OPNsense (`fw-seu`), el proxy DMZ (`dmz-web`), el node de base de dades i broker (`srv-serveis`) i el servidor de còpies de seguretat dedicat (`srv-backup`).

| Concepte | Model / Especificació | Unitats | Preu Unitari | Subtotal |
| :--- | :--- | :---: | :---: | :---: |
| **Servidor Central Rack 19"** | Dell PowerEdge R450 1U (Intel Xeon Silver 4314 16c/32t, 32 GB RAM DDR4 ECC Reg, 2x Font 600W Hot-Plug, iDRAC9 Enterprise) | 1 | 2.850,00 € | 2.850,00 € |
| **Emmagatzematge RAID 10** | Dell Enterprise SATA SSD 960 GB (Hot-Plug 2.5" amb safata) | 4 | 220,00 € | 880,00 € |
| **Controladora RAID Hardware** | PERC H755 SAS/SATA amb 8 GB de NVRAM cau | 1 | 480,00 € | 480,00 € |
| **SAI / UPS Doble Conversió** | APC Smart-UPS On-Line 2200VA 2U (SRT2200RMXLI) amb targeta SNMP Network Management Card | 1 | 1.620,00 € | 1.620,00 € |
| **Switch Gestionat L2+** | Cisco Catalyst 1000 sèrie 24 ports Gigabit (VLAN 802.1Q, LACP bonding) | 1 | 540,00 € | 540,00 € |
| **Armari Rack i PDU** | Rack 19" 24U amb porta perforada, guies, safates i regleta PDU gestionable | 1 | 650,00 € | 650,00 € |
| **Subtotal Seu Central** | | | | **7.020,00 €** |

---

### 2.2. Maquinari per Explotació Pilot (Granja 1 — 2 naus i 2 silos)

Equipament d'entorn industrial protegit contra la pols de pinso, plomes, amoníac i oscil·lacions elèctriques rurals.

| Concepte | Model / Especificació | Unitats | Preu Unitari | Subtotal |
| :--- | :--- | :---: | :---: | :---: |
| **Gateway Industrial Local** | Advantech UNO-2271G Fanless (Intel Celeron N3350, 4 GB RAM, 32 GB eMMC, carril DIN, IP50/65, -20 a +60 ºC) per a `granja1-srv` | 1 | 460,00 € | 460,00 € |
| **Router Industrial 4G/5G** | Teltonika RUT955 (Doble SIM failover, client VPN WireGuard, carril DIN, I/O digitals) | 1 | 230,00 € | 230,00 € |
| **Gateway LoRaWAN Exterior** | Dragino LPS8N 868 MHz exterior (8 canals, PoE, antena omni exterior 3 dBi) | 1 | 165,00 € | 165,00 € |
| **Armari Estanc de Control** | Armari de polièster reforçat amb fibra de vidre IP66 (600x400x200 mm) amb xassís carril DIN | 1 | 185,00 € | 185,00 € |
| **Mini-SAI de Carril DIN** | Phoenix Contact QUINT-UPS 24V DC / 5A amb bateria LiFePO4 de suport (2 hores d'autonomia) | 1 | 290,00 € | 290,00 € |
| **Font d'Alimentació Industrial** | Mean Well MDR-60-24 (24V DC, 2.5A carril DIN) | 2 | 28,00 € | 56,00 € |
| **Aïlladors Galvànics RS485** | Repetidor i aïllador sèrie optoacoblat (protecció contra llamps i sobretensions de motors) | 2 | 45,00 € | 90,00 € |
| **Subtotal Maquinari Granja** | | | | **1.476,00 €** |

---

### 2.3. Sensòrica de Camp i Elements Electromecànics

Dispositius desplegats a les dues naus i als silos de gra de la granja pilot.

| Dispositiu | Model / Descripció | Quantitat | Preu Unitari | Subtotal |
| :--- | :--- | :---: | :---: | :---: |
| **Sondes Temp/Humitat RS485** | Industrial XY-MD02 / SHT30 amb filtre metàl·lic sinteritzat anti-pols | 6 (3/nau) | 26,00 € | 156,00 € |
| **Sensors de $CO_2$ NDIR** | Senseair S8 industrial Modbus RTU (0-5000 ppm) | 2 (1/nau) | 75,00 € | 150,00 € |
| **Kits de Pesatge de Silo** | 4x Cèl·lules de càrrega de compressió 10T + transmissor LoRaWAN IP67 | 2 (1/silo) | 340,00 € | 680,00 € |
| **Comptadors d'Aigua d'impulsos** | Comptador Woltman DN20 amb emissor d'impulsos (1 imp/litre) | 2 (1/nau) | 65,00 € | 130,00 € |
| **Mòduls de Maniobra / ESP32** | ESP32-WROOM-32U en caixa DIN + Transceiver RS485 MAX485 + font integrada | 2 (1/nau) | 38,00 € | 76,00 € |
| **Mòduls de Relés de Potència** | Mòdul 4 canals relé 16A/250VAC optoacoblat per a actuadors | 2 (1/nau) | 24,00 € | 48,00 € |
| **Material d'Instal·lació** | Bobina 200m cable Cat6 FTP apantallat lliure d'halògens, tubs corrugats blindats, regletes i premsaestopes IP68 | 1 lot | 220,00 € | 220,00 € |
| **Subtotal Sensòrica** | | | | **1.460,00 €** |

---

### 2.4. Comunicacions i Despeses Operatives Recurrents (OpEx — Anualitzat)

| Servei | Proveïdor / Característiques | Freqüència | Cost Mensual | Cost Anual |
| :--- | :--- | :---: | :---: | :---: |
| **Connexió Fibra Seu Central** | Fibra òptica empresarial 1 Gbps simètrica amb 1 IP fixa | Mensual | 75,00 € | 900,00 € |
| **Targetes SIM M2M 4G/5G** | Doble SIM IoT multioperador per a failover rural (Movistar/Vodafone) | Mensual | 12,00 € | 144,00 € |
| **Domini `.cat` i DNS Anycast** | Registre del domini `avigest.cat` i gestió DNS protegida | Anual | — | 35,00 € |
| **Certificats SSL Wildcard** | Let's Encrypt (Autogestionat mitjançant Certbot) | — | 0,00 € | 0,00 € |
| **Manteniment Preventiu SAI** | Revisions periòdiques i reciclatge de bateries | Anual | — | 150,00 € |
| **Subtotal OpEx Anual** | | | | **1.229,00 € / any** |

---

### 2.5. Recursos Humans i Mà d'Obra (198h per alumne)

D'acord amb la càrrega lectiva oficial del mòdul M12 (198 hores per estudiant), es computa el cost de les hores de desenvolupament, disseny, proves i implantació aplicant la tarifa de mercat per a un tècnic superior en administració de sistemes en xarxa (**30,00 € / hora**):

| Membre de l'Equip | Rol Principal | Hores Assignades | Tarifa / Hora | Cost Total |
| :--- | :--- | :---: | :---: | :---: |
| **Joan Garcia** | Administrador de Sistemes, Xarxa i Seguretat (4.1, 4.2, 4.4, 4.5, 4.6) | 198 h | 30,00 €/h | 5.940,00 € |
| **Mariam Solano** | Administradora de BD, Desenvolupadora IoT i Scripts (4.3, 4.7, 4.8) | 198 h | 30,00 €/h | 5.940,00 € |
| **Subtotal Mà d'Obra Tècnica** | **Projecte Integral ASIX** | **396 h** | | **11.880,00 €** |

---

### 2.6. Balanç Econòmic Consolidat i Cost Marginal per Nova Granja

#### Pressupost Global d'Implantació (Projecte Pilot Inicial)
| Partida | Import Neta | Percentatge |
| :--- | :---: | :---: |
| **1. Maquinari Seu Central (CapEx CPD)** | 7.020,00 € | 30,4% |
| **2. Maquinari de Granja Pilot (CapEx Camp)** | 1.476,00 € | 6,4% |
| **3. Sensòrica i Cablejat (CapEx IoT)** | 1.460,00 € | 6,3% |
| **4. Comunicacions i Despeses Primer Any (OpEx)** | 1.229,00 € | 5,3% |
| **5. Enginyeria i Mà d'Obra ASIX (396 h)** | 11.880,00 € | 51,6% |
| **TOTAL INVERSIÓ INICIAL (Sense IVA)** | **23.065,00 €** | **100,0%** |
| *IVA aplicable (21%)* | *4.843,65 €* | — |
| **TOTAL GENERAL AMB IVA** | **27.908,65 €** | — |

#### Cost Marginal d'Incorporació d'una Nova Granja (Model de Negoci AviGest)
Quan un client existent o nou contracta una granja addicional de 2 naus:
- Maquinari de granja (Armari IP66 + Gateway UNO + Router 4G + Mini-SAI): **1.476,00 €**
- Sensòrica completa de les 2 naus i 2 silos: **1.460,00 €**
- Mà d'obra de desplegament i configuració automatitzada amb script `alta_granja.sh` (16 hores tècniques): **480,00 €**
- **Cost total d'alta per cada nova granja:** **3.416,00 € + IVA** (amb un cost recurrent de només 12,00 €/mes de la targeta SIM 4G).

#### Previsió de Desviacions i Fons de Contingència (Requisit Guia 6.2)
Per absorbir imprevistos tècnics típics de la intervenció a camp en entorns rurals (necessitat de trams addicionals de canalització de tub rígid per evitar passos de maquinària pesant, fluctuacions de preus de components electrònics o necessitat de perllongar l'estada a la granja pilot per imprevistos climàtics), s'estableix un **fons de contingència del 10%** sobre la partida de maquinari i mà d'obra:

| Concepte | Base Neta | Percentatge Contingència | Import Contingència |
| :--- | :---: | :---: | :---: |
| **Maquinari i Sensòrica (CapEx CPD + Camp)** | 9.956,00 € | 10% | 995,60 € |
| **Mà d'Obra d'Instal·lació i Desplegament** | 11.880,00 € | 10% | 1.188,00 € |
| **Total Fons de Contingència Previst** | — | — | **2.183,60 €** |
| **Pressupost Màxim amb Marge de Contingència (Sense IVA)** | — | — | **25.248,60 €** |

#### Comparativa Econòmica d'Alternatives Tecnològiques (Connexió amb Fitxes de Decisió)
En compliment del requisit de la guia d'avaluació, es justifica l'estalvi econòmic assolit mitjançant les decisions tècniques preses a les fitxes FD01 a FD05 en comparació amb solucions comercials privatives:

| Àmbit / Decisió | Solució Escollida (AviGest) | Cost Llicència / Any | Alternativa Comercial Descartada | Cost Alternativa / Any | Estalvi Econòmic Assolit |
| :--- | :--- | :---: | :--- | :---: | :---: |
| **SGBD (FD01)** | **MariaDB 10.11 LTS** (FOSS) | 0,00 € | Microsoft SQL Server Standard | ~3.800,00 € (per 4 nuclis) | **3.800,00 € / any** |
| **Tallafocs (FD03)** | **OPNsense** (Appliance FOSS) | 0,00 € | Fortinet FortiGate 60F + Suport UTP | 1.850,00 € inicial + 750,00 €/any | **2.600,00 € (any 1)** |
| **Directori (FD02)** | **OpenLDAP** en Docker | 0,00 € | Windows Server Active Directory | 1.150,00 € (Server + CALs) | **1.150,00 € inicial** |
| **Sensòrica Naus (FD05)** | **Bus RS485 Modbus RTU** | ~240,00 € (cable + aïlladors) | Xarxa WiFi Industrial Mesh a naus | ~1.100,00 € (APs IP67) | **860,00 € inicial** |

---

## 3. Actualització de Tasques i Rols (Acompliment i Seguiment)

En compliment directe de la instrucció de l'enunciat (*"marcar dates d'acompliment i qui ho ha fet"*), es detalla el registre oficial d'execució de tasques des de l'inici del projecte fins a la data actual (23 de novembre) i la planificació d'acompliment fins al 4 de desembre:

### 3.1. Matriu de Responsabilitats i Rols (Model RACI)
En compliment dels requisits d'organització (RA3), s'estableix la matriu de rols definint qui és el **Responsable directe d'execució (R)**, qui fa la **Revisió creuada de qualitat (A/C)** i qui n'és l'**Informat (I)**:

| Àmbit Tècnic / Tasca | Responsable Execució (R) | Revisió Creuada (A/C) | Responsabilitat Final |
| :--- | :---: | :---: | :---: |
| **Infraestructura CPD i Maquinari (4.1)** | **Joan Garcia** | Mariam Solano | Joan Garcia |
| **Directori Centralitzat LDAP i Rols (4.2)** | **Joan Garcia** | Mariam Solano | Joan Garcia |
| **Model Relacional ER i DDL MariaDB (4.3)** | **Mariam Solano** | Joan Garcia | Mariam Solano |
| **Triggers SQL i Lògica de Negoci (4.3)** | **Mariam Solano** | Joan Garcia | Mariam Solano |
| **Vistes i Consultes Comparatives SQL (4.3)** | **Mariam Solano** | Joan Garcia | Mariam Solano |
| **Tallafocs OPNsense, DMZ i Xarxes (4.4)** | **Joan Garcia** | Mariam Solano | Joan Garcia |
| **Còpies de Seguretat i Servidor PRD (4.5)** | **Joan Garcia** | Mariam Solano | Joan Garcia |
| **Anàlisi de Redundància i RAID (4.6)** | **Joan Garcia** | Mariam Solano | Joan Garcia |
| **Script Automatització Alta Granges (4.7)** | **Mariam Solano** | Joan Garcia | Mariam Solano |
| **Sensòrica IoT, RS485 i LoRaWAN (4.8)** | **Mariam Solano** | Joan Garcia | Mariam Solano |
| **Pressupostos i Pla Econòmic (E3)** | **Mariam Solano** | Joan Garcia | Ambdós |
| **Diari de Treball i Control de Versions** | **Ambdós** | Ambdós | Ambdós |

### 3.2. Registre de Fites i Dates d'Acompliment

| Fita / Tasca | Requeriment | Responsable | Data Prevista | Data Real Acompliment | Estat | Observacions i Evidències |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Constitució de l'equip i rols** | E0 | Joan / Mariam | 14/09/2026 | **14/09/2026** | **Completat** | Document [E0_divisio_tasques_rols.md](../E0_divisio_tasques_rols.md) i Gantt inicial. |
| **Estudi de necessitats i mercat** | E1 | Joan / Mariam | 28/09/2026 | **28/09/2026** | **Completat** | Document PDF [E1_estudi_necessitats](../E1_estudi_necessitats_joangarcia_mariamsolano%20(2).pdf) lliurat. |
| **Defensa oral E1** | E1 | Joan / Mariam | 05/10/2026 | **05/10/2026** | **Completat** | Presentació i defensa davant del professorat. |
| **Fitxa FD01: SGBD Central** | 4.3, 4.6 | Mariam | 19/10/2026 | **19/10/2026** | **Completat** | Decisió MariaDB 10.11 LTS + Rèplica GTID. |
| **Fitxa FD02: Directori LDAP** | 4.2 | Joan | 19/10/2026 | **19/10/2026** | **Completat** | Decisió OpenLDAP + 4 rols i aïllament de granges. |
| **Fitxa FD03: DMZ i Tallafocs** | 4.4 | Joan | 19/10/2026 | **19/10/2026** | **Completat** | Decisió OPNsense amb 3 interfícies i llista blanca. |
| **Fitxa FD04: Còpies de Seguretat** | 4.5 | Joan | 19/10/2026 | **19/10/2026** | **Completat** | Decisió `srv-backup` dedicat + segon disc simulat. |
| **Fitxa FD05: Comunicacions IoT** | 4.8 | Mariam | 19/10/2026 | **19/10/2026** | **Completat** | Model híbrid RS485 (naus) + LoRaWAN (silos). |
| **Redisseny Topologia 7 VMs** | Global | Joan / Mariam | 26/10/2026 | **26/10/2026** | **Completat** | Separació neta `pc-client`, `fw-seu`, `dmz-web`, `srv-serveis`, `srv-backup`, `granja1-srv`, `granja1-sim`. |
| **Implementació DDL i Triggers a MariaDB** | 4.3 | Mariam | 26/10/2026 | **26/10/2026** | **Completat** | Taules SQL, triggers termòstat automàtic i procediment d'alta atòmica. |
| **Vistes i consultes comparatives** | 4.3 | Mariam | 02/11/2026 | **26/10/2026** | **Completat** | Avançat amb [05_vistes_consultes_comparatives.sql](../../bd/sql/05_vistes_consultes_comparatives.sql). |
| **Configuració de regles OPNsense** | 4.4 | Joan | 02/11/2026 | **02/11/2026** | **Completat** | Taula formal de regles R-01 a R-11 a l'E2 i script [firewall_regles.sh](../../infra/dmz-tallafocs/firewall_regles.sh). |
| **Desplegament i proves OpenLDAP** | 4.2 | Joan | 09/11/2026 | **09/11/2026** | **Completat** | Arbre DIT dissenyat ([esquema_ldap.png](../diagrames/esquema_ldap.png)) i LDIFs generats. |
| **Proves d'estrès IoT i triggers** | 4.8, 4.3 | Mariam | 09/11/2026 | **09/11/2026** | **Completat** | Validació de simulador IoT en mode alarma (35 ºC) activant actuador i alerta. |
| **Validació RTO/RPO a `srv-backup`** | 4.5 | Joan | 16/11/2026 | **16/11/2026** | **Completat** | Taula RTO/RPO per servei, scripts de backup i protocol PRD (< 30 min). |
| **Proves de buffer Store-and-Forward** | 4.8 | Mariam | 16/11/2026 | **16/11/2026** | **Completat** | Disseny de cua local de 72h a `granja1-srv` i recuperació de telemetria. |
| **Redacció inicial Pla Intervenció E3** | E3 | Joan / Mariam | 23/11/2026 | **26/10/2026** | **Completat** | Avançat per anticipar la fita del 4 de desembre. |
| **Proves de variació (Granja 2)** | 4.7 | Joan / Mariam | 23/11/2026 | *Planificat (S10)* | En curs | Execució i validació de l'script `alta_granja.sh` per a la Granja 2. |
| **Integració i revisió creuada E2/E3** | E2, E3 | Joan / Mariam | 30/11/2026 | *Planificat (S11)* | Pendent | Revisió estil, coherència tècnica i exportació a PDF. |
| **LLIURAMENT OFICIAL E2 i E3** | Fita 2/3 | Joan / Mariam | **04/12/2026** | *Data Límit* | Pendent | **Lliurament al campus virtual i defensa davant tribunal.** |

### 3.3. Cronograma Global del Projecte (Curs 2026-2027)

En compliment del requisit de planificació temporal de la Guia de Lliuraments del professorat (apartat 6.4), s'estableix el cronograma integral del projecte des de la constitució inicial (Lliurable E0) fins a la defensa final (abril de 2027). Aquest diagrama WBS (*Work Breakdown Structure*) actualitzat reflecteix la maduració del disseny tècnic i assigna clarament les línies d'actuació de cada membre de l'equip:

```mermaid
gantt
    title Cronograma Integral del Projecte AviGest S.L. (Curs 2026-2027)
    dateFormat  YYYY-MM-DD
    axisFormat  %d/%m
    
    section Fites Oficials i Avaluació
    E0 Constitució d'Equip (5%)             :done, m_e0, 2026-09-14, 1d
    E1 Estudi de Necessitats (15%)          :done, m_e1, 2026-09-28, 1d
    Defensa Oral E1                         :done, m_def1, 2026-10-05, 1d
    Lliurament Disseny E2 + E3 (35%)        :milestone, m_e2e3, 2026-12-04, 0d
    Lliurament Primer Bloc Execució E4a/E5a (20%) :milestone, m_e45a, 2027-03-01, 0d
    Lliurament Memòria Final i Variació E5b/E6    :milestone, m_e6, 2027-04-20, 0d
    E7 Defensa Oral Final i Demostració (25%)     :milestone, m_final, 2027-04-30, 0d

    section Joan (Xarxa, Seguretat i Serveis)
    Recerca maquinari CPD i alternatives tallafocs :done, j_poc, 2026-10-15, 2026-10-26
    Disseny DMZ, regles OPNsense i VPN WireGuard   :done, j_fw, 2026-10-26, 2026-11-06
    Disseny arbre DIT OpenLDAP i 4 rols seguretat  :done, j_ldap, 2026-11-06, 2026-11-13
    Protocol PRD, servidor srv-backup i scripts    :done, j_prd, 2026-11-09, 2026-11-16
    Desplegament base VMs (fw-seu, dmz, serveis)   :j_vm_dep, 2026-12-05, 2027-01-20
    Configuració OpenLDAP i phpLDAPadmin real      :j_ldap_dep, 2027-01-15, 2027-02-10
    Implantació regles OPNsense i proves aïllament :j_sec_test, 2027-02-01, 2027-02-20
    Assaig de desastre PRD a srv-backup (RTO<30m)  :j_prd_test, 2027-02-15, 2027-02-28
    Simulació de caiguda de túnel VPN i recuperació:j_vpn_fail, 2027-03-01, 2027-03-20

    section Mariam (BD, Triggers, IoT i Scripts)
    Recerca sensòrica clima i model multitenant    :done, m_req, 2026-10-15, 2026-10-26
    Model ER 3FN a MariaDB 10.11 i taula pagaments :done, m_er, 2026-10-26, 2026-11-16
    Lògica triggers (termòstat), vistes i rols SQL :done, m_sql, 2026-11-02, 2026-11-16
    Disseny híbrid RS485+LoRaWAN i simulador IoT   :done, m_iot, 2026-11-06, 2026-11-16
    Càrrega de dades i proves estrès MariaDB       :m_db_load, 2026-12-05, 2027-01-15
    Validació ingesta MQTT i disparadors en viu    :m_mqtt_live, 2027-01-10, 2027-02-05
    Configuració Edge granja1-srv i Store-and-Forward :m_edge_dep, 2027-02-01, 2027-02-25
    Proves de volumetria i latència sensors        :m_vol_test, 2027-02-20, 2027-03-10
    Assaig alta atòmica Granja 2 (alta_granja.sh)  :m_script_test, 2027-03-05, 2027-03-25

    section Integració i Acompanyament
    Redacció i consolidació E2 i E3                :active, c_e2e3, 2026-11-02, 2026-11-30
    Revisió creuada Joan-Mariam i exportació PDF   :c_rev, 2026-11-25, 2026-12-04
    Integració extrem a extrem (Camp -> CPD)       :c_integ, 2027-03-01, 2027-04-05
    Redacció Memòria Final E6                      :c_mem, 2027-03-25, 2027-04-20
    Preparació demostració oral davant tribunal    :c_demo, 2027-04-15, 2027-04-30
```

---

## 4. Procediment i Cronograma d'Intervenció a Camp

Aquest apartat recull la guia operativa d'instal·lació física a la granja pilot d'explotació real.

### 4.1. Fases d'Execució a la Granja Pilot

```mermaid
gantt
    title Pla d'Intervenció a Camp (Granja Pilot)
    dateFormat  YYYY-MM-DD
    section Fase 1: Obra i Canalitzacions
    Muntatge Armari IP66 i línia elèctrica :f1_1, 2026-11-09, 2d
    Canalitzacions tub rígid a naus        :f1_2, after f1_1, 2d
    section Fase 2: Cablejat i Sensors
    Tiratge de bus Cat6 FTP RS485         :f2_1, after f1_2, 2d
    Connexió sondes temp/CO2 i relés      :f2_2, after f2_1, 2d
    Instal·lació LoRaWAN en sitges exteriors:f2_3, after f2_2, 1d
    section Fase 3: Gateway i Connectivitat
    Connexió router 4G i Gateway Advantech :f3_1, after f2_3, 1d
    Aixecament de túnel VPN cap a OPNsense:f3_2, after f3_1, 1d
    section Fase 4: Comissionament
    Proves d'actuació ventiladors (>31ºC) :f4_1, after f3_2, 1d
    Prova de tall VPN (Store-and-forward) :f4_2, after f4_1, 1d
    Acceptació pel ramader i tancament    :milestone, after f4_2, 0d
```

#### Fase 1: Condicionament elèctric i quadre de comandament
1. Instal·lació de l'armari estanc IP66 a la paret de la sala tècnica d'accés (mai a l'interior directe del pavelló d'aus).
2. Fixació de les fonts Mean Well, mini-SAI Phoenix Contact de 24V i aïlladors sèrie als carrils DIN.
3. Connexió de la línia elèctrica general amb interruptor magnetotèrmic dedicat de 10A i diferencial superimmunitzat.

#### Fase 2: Cablejat de sensors i actuadors a naus
1. Estesa de tub rígid estanc blindat entre l'armari i les dues naus.
2. Tiratge del cable apantallat Cat6 FTP en topologia de bus sèrie (línia daisy-chain amb resistències de final de línia de $120\ \Omega$ als extrems).
3. Muntatge de les 3 sondes de temperatura/humitat SHT30 a cada nau (a 1,5 metres d'alçada, allunyades de corrents directes d'aire) i el sensor de $CO_2$ al terç mitjà de la nau.
4. Connexió de les sortides de relé als contactors dels quadres de ventilació i calefacció existents.
5. Fixació de les 4 cèl·lules de càrrega a les potes de cadascun dels dos silos exteriors i enllaç per ràdio LoRaWAN amb el receptor exterior.

#### Fase 3: Desplegament de comunicacions i Gateway
1. Muntatge del Gateway industrial Advantech UNO-2271G i el router Teltonika RUT955 a l'armari de carril DIN.
2. Configuració de les targetes SIM M2M i comprovació de nivell de senyal RSSI ($> -75\text{ dBm}$).
3. Verificació de l'establiment del túnel VPN amb la seu central (`10.0.100.10` $\leftrightarrow$ `10.0.100.1`).

#### Fase 4: Proves de funcionament i protocols d'acceptació
1. Verificació de la recepció de paquets MQTT a `granja1-srv` procedents del simulador o sensors físics.
2. Simulació d'excés de calor: forçar lectura de temperatura a $32^\circ\text{C}$ i verificar que el contactor de ventiladors s'activa en menys de 2 segons de manera autònoma.
3. Prova de resiliència: desconnectar el cable Ethernet del router 4G durant 30 minuts, comprovar que les dades s'acumulen al disc local del gateway i verificar que en reconnectar es bolquen sense pèrdues a la seu central.
4. Signatura del full de conformitat amb el propietari de l'explotació.

---

## 5. Pla de Contingència i Gestió de Riscos

| Risc Identificat | Probabilitat | Impacte | Pla de Mitigació i Resposta |
| :--- | :---: | :---: | :--- |
| **Avaria de la connexió 4G rural** | Alta | Mitjà | El router Teltonika disposa de **doble SIM** amb canvi automàtic d'operadora. El gateway reté les lectures al búfer local durant 72 hores sense pèrdua de dades. |
| **Tall elèctric a la granja** | Mitjana | Alt | El mini-SAI industrial de 24V manté el gateway, router i sensors operatius durant 2 hores. Els ventiladors de potència funcionen amb el generador dièsel propi de la granja. |
| **Corrupció de dades per sobretensió a la línia RS485** | Mitjana | Alt | S'han instal·lat **aïlladors galvànics optoacoblats** a l'entrada de l'armari per protegir el microcontrolador i gateway contra llamps i paràsits de motors. |
| **Avaria del disc del servidor central** | Baixa | Crític | El servidor compta amb **RAID 10 per maquinari** (tolera la pèrdua de discs). Addicionalment, la màquina dedicada `srv-backup` desa còpies diàries en un segon disc virtual aïllat (RTO < 30 minuts). |
| **Corrosió ambiental dels sensors per amoníac** | Alta | Mitjà | Totes les sondes de naus disposen de carcassa de plàstic tècnic i filtres metàl·lics sinteritzats de protecció, amb protocol de neteja anual amb aire comprimit. |

---

## 6. Documentació Associada i Estructura del Repositori Git

El desenvolupament, les guies d'intervenció i el control del projecte s'organitzen estrictament dins del repositori Git seguint aquesta estructura de carpetes i responsabilitats de manteniment:

| Carpeta / Ruta al Repositori | Contingut i Propòsit | Responsable de Manteniment |
| :--- | :--- | :---: |
| [`bd/sql/`](file:///c:/avigest-projecte-git/bd/sql/) | Esquema DDL en 3FN, dades de prova inicials, vistes i rols de MariaDB 10.11 LTS. | **Mariam Solano** |
| [`bd/procediments-triggers/`](file:///c:/avigest-projecte-git/bd/procediments-triggers/) | Triggers de termòstat automàtic, alarmes i procediments en MariaDB SQL. | **Mariam Solano** |
| [`bd/model-er/`](file:///c:/avigest-projecte-git/bd/model-er/) | Documentació i diagrames del model de dades relacional (Dia i gràfic). | **Mariam Solano** |
| [`docker/`](file:///c:/avigest-projecte-git/docker/) | `docker-compose.yml`, configuració de Mosquitto i scripts d'arrencada (`initdb/`). | **Joan Garcia / Mariam** |
| [`infra/dmz-tallafocs/`](file:///c:/avigest-projecte-git/infra/dmz-tallafocs/) | Disseny de la DMZ, polítiques de seguretat i scripts de regles d'OPNsense. | **Joan Garcia** |
| [`infra/ldap/`](file:///c:/avigest-projecte-git/infra/ldap/) | Arbre base organitzatiu i fitxers LDIF d'usuaris inicials per a OpenLDAP. | **Joan Garcia** |
| [`infra/backups-prd/`](file:///c:/avigest-projecte-git/infra/backups-prd/) | Scripts d'automatització de còpies (`backup_avigest.sh`) i restauració PRD. | **Joan Garcia** |
| [`iot/sensors/`](file:///c:/avigest-projecte-git/iot/sensors/) | Simulador IoT en Python (`simulador_iot.py`) i codi C++ ESP32 de referència. | **Mariam Solano** |
| [`scripts/automatitzacio-granges/`](file:///c:/avigest-projecte-git/scripts/automatitzacio-granges/) | Script bash d'alta automàtica de granges (`alta_granja.sh`) per a la variació. | **Mariam Solano** |
| [`docs/E2_disseny_tecnic/`](file:///c:/avigest-projecte-git/docs/E2_disseny_tecnic/) | Memòria oficial de Disseny Tècnic del Projecte (Lliurable E2). | **Ambdós** |
| [`docs/E3_pla_intervencio/`](file:///c:/avigest-projecte-git/docs/E3_pla_intervencio/) | Memòria oficial del Pla d'Intervenció i Pressupostos (Lliurable E3). | **Ambdós** |
| [`docs/fitxes_decisio/`](file:///c:/avigest-projecte-git/docs/fitxes_decisio/) | Fitxes de decisió tècnica justificades FD01 a FD05 amb fonts oficials. | **Ambdós** |
| [`docs/diari_treball/`](file:///c:/avigest-projecte-git/docs/diari_treball/) | Diari de treball setmanal d'hores lectives i checklist del projecte. | **Ambdós** |

---

## 7. Annex d'Ús d'Intel·ligència Artificial (Norma 4)

*En compliment estricte de la Norma 4 de les bases del projecte:*

- **Eines utilitzades:** Antigravity / Gemini 3.8 Flash (High).
- **Àmbit d'aplicació:** Suport en la investigació de referències de maquinari industrial, estructuració i càlcul dels quadres de pressupostos CapEx/OpEx, elaboració de diagrames temporals Mermaid i plantilla de seguiment de fites.
- **Mètode de verificació i comprensió:** L'equip (Joan Garcia i Mariam Solano) ha revisat, validat i contrastat cadascun dels preus amb proveïdors reals del sector informàtic i ramader català (preus de maquinari de servidor, sensors industrials i tarifes de telecomunicacions). Tots dos membres de l'equip comprenen la justificació de cada partida, les dependències del cronograma i saben defensar qualsevol aspecte econòmic o d'intervenció davant del tribunal docent.

---

## 8. Bibliografia i Fonts de Preus Consultades

1. **Dell Technologies Espanya (2024):** Configurador oficial de servidors rack *Dell PowerEdge R450 1U*, controladora PERC H755 i discos SATA SSD Enterprise. [https://www.dell.com/es-es/work/shop/servidores-de-dell/](https://www.dell.com/es-es/work/shop/servidores-de-dell/)
2. **Schneider Electric / APC (2024):** *APC Smart-UPS On-Line SRT2200RMXLI 2200VA 2U*. Fitxa tècnica i preus de distribució oficial. [https://www.apc.com/es/es/](https://www.apc.com/es/es/)
3. **Cisco Systems (2024):** *Cisco Catalyst 1000 Series Switches Data Sheet*. Distribuïdor oficial Ingram Micro. [https://www.cisco.com/](https://www.cisco.com/)
4. **Advantech Europe (2024):** *UNO-2271G Fanless Industrial PC Datasheet & Online Shop*. [https://www.advantech.com/en-eu](https://www.advantech.com/en-eu)
5. **Teltonika Networks (2024):** *RUT955 Industrial Cellular Router Specification Sheet*. [https://teltonika-networks.com/](https://teltonika-networks.com/)
6. **Dragino Technology Co. (2024):** *LPS8N Indoor LoRaWAN Gateway Price List & Documentation*. [https://www.dragino.com/](https://www.dragino.com/)
7. **RS Components Espanya / Farnell (2024):** Sondes industrials SHT30, sensors de CO2 NDIR Winsen, mòduls relé de carril DIN i caixes estancs de polièster IP66. [https://es.rs-online.com/](https://es.rs-online.com/)
8. **Convenis Col·lectius del Sector TIC / Consultoria Informàtica de Catalunya (2024):** Tarifes de referència per a tècnics de grau superior en xarxes i sistemes (30 €/hora mà d'obra).
