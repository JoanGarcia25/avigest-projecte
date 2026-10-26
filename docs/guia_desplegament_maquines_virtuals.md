# Guia de Desplegament de la Topologia de Màquines Virtuals — AviGest S.L.

**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Autors:** Joan (Infraestructura, Xarxa i Seguretat) i Mariam (Base de Dades, IoT i Automatització)  
**Entorn d'execució:** Hipervisor VMware Workstation / VirtualBox  

---

## 1. Mapa de Màquines Virtuals i Xarxes Virtuals (VMnets)

La infraestructura d'AviGest es desplega mitjançant un conjunt coordinat de màquines virtuals especialitzades interconnectades a través de les següents xarxes:

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
    Internet ==>|HTTPS només des d'IPs de clients| FW
    FW -->|Port 443/80| DMZ_Web
    DMZ_Web ==>|NOMÉS SQL:5432 i LDAP:389| Srv_Serveis
    DMZ_Web -.->|BLOQUEJAT TOTA LA RESTA: DROP| LAN_Net

    Granja1_Sim -->|Dades de camp| Granja1_Srv
    Granja1_Srv ==>|Túnel VPN (10.0.100.0/24)| VPN_Srv
    VPN_Srv ==>|NOMÉS MQTT:1883/8883| Srv_Serveis
    VPN_Srv -.->|BLOQUEJAT ACCÉS A BD I LDAP: DROP| LAN_Net
```

### Pla d'adreçament i assignació d'adaptadors a VMware:

| Màquina Virtual | Sistema Operatiu | Adaptadors de Xarxa a VMware | Adreça IP | Funció en el sistema |
| :--- | :--- | :--- | :--- | :--- |
| **`pc-client`** | Qualsevol OS / Host | NAT | IP de NAT | Simula l'equip de l'empresa client contractant que accedeix des d'Internet. |
| **`fw-seu`** | OPNsense | **NIC 1:** NAT (WAN)<br/>**NIC 2:** VMnet10 (DMZ)<br/>**NIC 3:** VMnet20 (LAN) | **WAN:** DHCP NAT<br/>**DMZ:** `10.0.10.1`<br/>**LAN:** `10.0.20.1`<br/>**VPN:** `10.0.100.1` | Tallafocs perimetral de 3 potes, servidor VPN i aplicació de regles. |
| **`dmz-web`** | Ubuntu Server | **NIC 1:** VMnet10 (DMZ) | `10.0.10.10` | Nginx, proxy invers, WAF i relay SMTP. Únic servei exposat al client. |
| **`srv-serveis`** | Ubuntu Server | **NIC 1:** VMnet20 (LAN) | `10.0.20.10` | Docker: OpenLDAP, PostgreSQL 16 + rèplica, Broker MQTT Mosquitto. |
| **`srv-backup`** | Ubuntu Server | **NIC 1:** VMnet20 (LAN) | `10.0.20.20` | Servidor dedicat de còpies de seguretat amb cron i 2n disc virtual. |
| **`granja1-srv`**| Ubuntu Server | **NIC 1:** VMnet30 (Granja 1)<br/>**NIC 2:** NAT (sortida Internet/VPN) | `10.1.1.10`<br/>(VPN: `10.0.100.10`) | Gateway de granja: client VPN, MQTT local, regles d'actuadors i buffer. |
| **`granja1-sim`**| Ubuntu Server / Alpine | **NIC 1:** VMnet30 (Granja 1) | `10.1.1.20` | Simulador ESP32, bus RS485 Modbus i LoRaWAN (ChirpStack). |

---

## 2. Recorregut Detallat d'una Lectura de Sensor

1. **`granja1-sim`:**
   - Simula els microcontroladors ESP32 llegint els sensors ambientals per RS485 Modbus i les cèl·lules de pesatge dels silos per LoRaWAN (ChirpStack).
   - Publica la lectura cap al broker MQTT local de `granja1-srv`.
2. **`granja1-srv` (Edge Computing):**
   - Rep la lectura pel seu MQTT local.
   - Avalua immediatament les regles locals dels actuadors: si la temperatura mesurada supera el llindar crític (> 31 ºC), **activa el ventilador localment** sense dependre de la seu central ni d'Internet.
   - Emmagatzema la lectura al búfer local (*store-and-forward*).
   - Envia el missatge telemètric pel túnel xifrat VPN (`10.0.100.0/24`) cap a la seu central.
3. **`fw-seu` (OPNsense):**
   - Rep el paquet a través de la interfície VPN.
   - Aplica les regles del tallafocs: **l'únic trànsit permès des de la VPN cap a la LAN és el port del Broker MQTT (`srv-serveis:1883/8883`)**. Qualsevol altre trànsit és bloquejat.
4. **`srv-serveis` (Nucli Central):**
   - El broker MQTT Mosquitto rep la lectura i la persistència a la base de dades **PostgreSQL 16**.
   - La base de dades s'encarrega d'alimentar la rèplica contínua.
   - OpenLDAP manté els comptes d'usuaris per a les autenticacions.
5. **`srv-backup` (Còpies i PRD):**
   - Executa les tasques programades mitjançant `cron` connectant-se a `srv-serveis` per extreure el buidatge de la BD i LDAP.
   - Copia els arxius a un segon disc virtual separat que simula la ubicació física externa.
6. **`dmz-web` (Accés Client):**
   - El client es connecta des de `pc-client` per Internet/HTTPS.
   - OPNsense comprova la llista blanca d'IPs de clients contractats.
   - Si és autoritzat, la connexió arriba a `dmz-web`, que passa pel proxy invers Nginx i consulta a `srv-serveis` les dades estrictament necessàries per PostgreSQL (5432) i LDAP (389).

---

## 3. Punts Crítics de Seguretat i Configuració

### 3.1. Regles del Tallafocs OPNsense (`fw-seu`)
- **Aïllament estricte DMZ -> LAN:**
  * La DMZ **mai no ha de poder iniciar connexions cap a la LAN**, excepte allò estrictament necessari:
    - `dmz-web` -> `srv-serveis:5432` (PostgreSQL)
    - `dmz-web` -> `srv-serveis:389/636` (OpenLDAP)
  * Qualsevol altre intent d'iniciar trànsit cap a la LAN (com ara intents cap a `srv-backup`, SSH, etc.) és **bloquejat i registrat al log**.
- **Aïllament VPN -> LAN:**
  * Des de la VPN (`granja1-srv`) **només es permet trànsit cap al Broker MQTT de `srv-serveis` (port 1883/8883)**. La granja mai té accés a la BD ni a LDAP directament.

### 3.2. Redundància de la Base de Dades (Justificació de disseny)
- Al laboratori, la rèplica de PostgreSQL està allotjada com a contenidor secundari dins de `srv-serveis`.
- **Aquesta limitació està documentada a la fitxa de decisió FD01:** Si cau el procés o es corrompen les dades, la rèplica protegeix el servei; però si cau la màquina virtual `srv-serveis` sencera, la redundància s'assumeix mitjançant el servidor independent `srv-backup`. En producció real, la rèplica s'allotjaria en una VM pròpia.

---

## 4. Procediment per a la Variació Presencial (Granja 2 — Requeriment 4.7)

Durant la defensa o sessió presencial, quan el professor demani afegir una segona granja:

1. **Clonació de les màquines de camp a VMware:**
   - Es clona `granja1-srv` com a `granja2-srv`.
   - Es clona `granja1-sim` com a `granja2-sim`.
   - S'assigna una xarxa nova a VMware: **Granja 2 (`10.1.2.0/24`)**.
2. **Execució de l'script d'automatització:**
   - L'script `scripts/automatitzacio-granges/alta_granja.sh`:
     1. Crea l'esquema i registres a PostgreSQL per a la nova granja.
     2. Crea l'usuari gestor a OpenLDAP (`departmentNumber: GRANJA_2`).
     3. Afegeix la regla al tallafocs OPNsense per autoritzar el nou túnel VPN des de la nova granja.
