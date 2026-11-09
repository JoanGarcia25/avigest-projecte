# Guia de Desplegament de la Topologia de Màquines Virtuals — AviGest S.L.

**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Autors:** Joan (Infraestructura, Xarxa i Seguretat) i Mariam (Base de Dades, IoT i Automatització)  
**Entorn d'execució:** Hipervisor Oracle VirtualBox (entorn estàndard d'aula) / VMware Workstation  
**Criteri d'homogeneïtat docent:** Seguint la recomanació del professor de no barrejar distribucions Linux a la capa de serveis, s'adopta **Ubuntu Server 24.04 LTS** per a les 5 màquines de serveis mitjançant una única plantilla màster (`ubuntu-base`), mantenint **OPNsense** exclusivament com a appliance de seguretat perimetral dedicat.  
**Guies complementàries:**
- [docs/Guies_MV/Guia del laboratori virtual d'AviGest.pdf](Guies_MV/Guia%20del%20laboratori%20virtual%20d’AviGest.pdf)
- [docs/Guies_MV/Pas a pas plantilla debian-base i xarxes virtuals.docx](Guies_MV/Pas%20a%20pas%20plantilla%20debian-base%20i%20xarxes%20virtuals.docx)

---

## 1. Mapa de Màquines Virtuals i Xarxes Virtuals

La infraestructura d'AviGest es desplega mitjançant un conjunt coordinat de 6 màquines virtuals (més l'equip client físic o virtualitzat) interconnectades a través de segments de xarxa privats i aïllats:

```mermaid
flowchart TD
    Client["pc-client / Host físic<br/>(Navegador de prova)"]
    Internet["Internet (Xarxa NAT: 10.0.2.0/24)"]

    subgraph FW["fw-seu (OPNsense)"]
        direction TB
        WAF_Rules["3 Interfícies + Regles d'Estat"]
        VPN_Srv["Servidor VPN WireGuard (10.0.100.1)"]
    end

    subgraph DMZ_Net["DMZ (10.0.10.0/24)"]
        DMZ_Web["dmz-web (10.0.10.10)<br/>Ubuntu 24.04: Nginx + proxy invers<br/>WAF i relay SMTP"]
    end

    subgraph LAN_Net["LAN seu (10.0.20.0/24)"]
        Srv_Serveis["srv-serveis (10.0.20.10)<br/>Ubuntu 24.04 + Docker Engine:<br/>MariaDB 10.11 LTS + Rèplica GTID<br/>Mosquitto MQTT + OpenLDAP"]
        Srv_Backup["srv-backup (10.0.20.20)<br/>Ubuntu 24.04: Còpies amb cron<br/>2n Disc virtual simulat (/mnt)"]
    end

    subgraph Granja1_Net["Granja 1 (10.1.1.0/24)"]
        Granja1_Sim["granja1-sim (10.1.1.20)<br/>Ubuntu 24.04: Simulador ESP32<br/>RS485 Modbus i ChirpStack LoRa"]
        Granja1_Srv["granja1-srv (10.1.1.10)<br/>Ubuntu 24.04: Gateway Edge<br/>Client WireGuard (10.0.100.10)<br/>MQTT local + regles ventilació (>31ºC)"]
    end

    Client --> Internet
    Internet ==>|HTTPS (443) només des d'IPs autoritzades| FW
    FW -->|Port 443/80| DMZ_Web
    DMZ_Web ==>|NOMÉS SQL:3306 i LDAPS:636/389| Srv_Serveis
    DMZ_Web -.->|BLOQUEJAT TOTA LA RESTA: DROP| LAN_Net

    Granja1_Sim -->|Dades de camp| Granja1_Srv
    Granja1_Srv ==>|Túnel WireGuard VPN (10.0.100.0/24)| VPN_Srv
    VPN_Srv ==>|NOMÉS MQTT:1883/8883| Srv_Serveis
    VPN_Srv -.->|BLOQUEJAT ACCÉS A BD I LDAP: DROP| LAN_Net
```

---

## 2. Pla d'Adreçament, Xarxes i Màquines Virtuals

Totes les 5 màquines virtuals de serveis comparteixen el mateix sistema operatiu base: **Ubuntu Server 24.04 LTS** (derivat de la plantilla màster `ubuntu-base` sense escriptori gràfic, usuari administratiu comú `avadmin`, sincronització horària `chrony` i xarxa declarativa amb **Netplan YAML**). El consum total de RAM se situa entre **8 i 10 GB**.

### 2.1. Taula de Correspondència de Xarxes Virtuals

| Zona de Xarxa | Rang de Xarxa | Tipus a VirtualBox | Nom a VirtualBox | Equivalent a VMware | Equips connectats |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Internet / WAN** | `10.0.2.0/24` | Xarxa NAT (*NAT Network*) | `internet-lab` | `NAT` | WAN de `fw-seu`, sortida de `granja1-srv` i `pc-client` |
| **DMZ** | `10.0.10.0/24` | Xarxa interna (*Internal Network*) | `dmz` | `VMnet10` | Interfície DMZ de `fw-seu` i `dmz-web` |
| **LAN seu** | `10.0.20.0/24` | Xarxa interna (*Internal Network*) | `lan-seu` | `VMnet20` | Interfície LAN de `fw-seu`, `srv-serveis` i `srv-backup` |
| **Granja 1** | `10.1.1.0/24` | Xarxa interna (*Internal Network*) | `lan-granja1` | `VMnet30` | `granja1-srv` i `granja1-sim` |
| **Granja 2** *(Variació 4.7)* | `10.1.2.0/24` | Xarxa interna (*Internal Network*) | `lan-granja2` | `VMnet40` | `granja2-srv` i `granja2-sim` |
| **Túnel VPN** | `10.0.100.0/24` | Túnel WireGuard (Virtual) | `wg0` | `wg0` | `fw-seu` (`.1`), `granja1-srv` (`.10` / `.2`), `granja2-srv` (`.20`) |

> [!TIP]
> **Creació de la xarxa NAT a VirtualBox per línia de comandes (PowerShell al Host):**
> ```powershell
> $vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
> & $vbm natnetwork add --netname internet-lab --network 10.0.2.0/24 --enable --dhcp on
> & $vbm list natnetworks
> ```

---

### 2.2. Inventari de Màquines Virtuals

| Màquina Virtual | Rol al Projecte | Sistema Operatiu | Recursos (vCPU / RAM / Disc) | Adaptadors de Xarxa (VirtualBox / VMware) | Adreces IP |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **`pc-client`** | Client contractant que accedeix des d'Internet | Host físic / VM Ubuntu | 1 vCPU / 1 GB / 10 GB | **Adaptador 1:** Xarxa NAT (`internet-lab` / `NAT`) | DHCP (`10.0.2.x`) o IP física |
| **`fw-seu`** | Tallafocs perimetral de 3 potes, NAT i VPN | **OPNsense** (FreeBSD Appliance) | 2 vCPU / 2 GB / 20 GB | **Adaptador 1:** Xarxa NAT (`internet-lab`)<br/>**Adaptador 2:** Xarxa interna (`dmz`)<br/>**Adaptador 3:** Xarxa interna (`lan-seu`) | **WAN:** DHCP (`10.0.2.1` gw)<br/>**DMZ:** `10.0.10.1`<br/>**LAN:** `10.0.20.1`<br/>**VPN:** `10.0.100.1` |
| **`dmz-web`** | Nginx, proxy invers, WAF i relay SMTP | **Ubuntu Server 24.04** (clon) | 1 vCPU / 1 GB / 10 GB | **Adaptador 1:** Xarxa interna (`dmz`) | `10.0.10.10`<br/>(GW: `10.0.10.1`) |
| **`srv-serveis`** | MariaDB 10.11 LTS + Rèplica GTID, Mosquitto, OpenLDAP | **Ubuntu Server 24.04** (clon) + Docker | 2 vCPU / 4 GB / 40 GB | **Adaptador 1:** Xarxa interna (`lan-seu`) | `10.0.20.10`<br/>(GW: `10.0.20.1`) |
| **`srv-backup`** | Servidor de backups dedicat amb cron i 2n disc | **Ubuntu Server 24.04** (clon) | 1 vCPU / 1 GB / 10 GB + 20 GB | **Adaptador 1:** Xarxa interna (`lan-seu`) | `10.0.20.20`<br/>(GW: `10.0.20.1`) |
| **`granja1-srv`**| Gateway Edge: VPN, MQTT local, actuadors | **Ubuntu Server 24.04** (clon) | 1 vCPU / 1 GB / 10 GB | **Adaptador 1:** Xarxa interna (`lan-granja1`)<br/>**Adaptador 2:** Xarxa NAT (`internet-lab`) | **LAN:** `10.1.1.10`<br/>**VPN:** `10.0.100.10` (o `.2`) |
| **`granja1-sim`**| Simulador de sensors ESP32 i silos LoRaWAN | **Ubuntu Server 24.04** (clon) | 1 vCPU / 1 GB / 10 GB | **Adaptador 1:** Xarxa interna (`lan-granja1`) | `10.1.1.20`<br/>(GW: `10.1.1.10`) |

---

## 3. Preparació de la Plantilla Base Comuna (`ubuntu-base`)

Per unificar la gestió i complir l'encàrrec docent, es prepara una única màquina virtual **`ubuntu-base`** (Ubuntu Server 24.04 LTS Live Server amd64):

1. **Instal·lació mínima:** Triar opció *Ubuntu Server (minimized)* durant la instal·lació de Subiquity. Sense entorn gràfic.
2. **Usuari administratiu:** Crear `avadmin` amb permisos `sudo`.
3. **Optimització de memòria RAM (Molt recomanat):**
   ```bash
   # Desinstal·lar snapd per estalviar ~150-200 MB de RAM en cada VM
   sudo systemctl stop snapd.service snapd.socket
   sudo apt purge snapd -y
   sudo rm -rf /var/cache/snapd /snap
   ```
4. **Instal·lació d'eines essencials:**
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo apt install -y vim curl wget ca-certificates gnupg chrony ufw tcpdump dnsutils netcat-openbsd git wireguard-tools
   ```
5. **Sincronització horària:**
   ```bash
   sudo timedatectl set-timezone Europe/Madrid
   sudo systemctl enable --now chrony
   ```
6. **Neteja prèvia al clonatge:**
   ```bash
   # Netejar machine-id i claus SSH per regenerar-les a cada clon
   sudo truncate -s 0 /etc/machine-id
   sudo rm -f /etc/ssh/ssh_host_*
   sudo poweroff
   ```
7. **Després de clonar cada VM:**
   - Canviar el nom d'equip: `sudo hostnamectl set-hostname <nom_vm>`
   - Regenerar claus SSH: `sudo dpkg-reconfigure openssh-server`
   - Configurar la xarxa estàtica amb Netplan a `/etc/netplan/01-netcfg.yaml` i aplicar amb `sudo netplan apply`.

### 3.1. Plantilles Netplan (`/etc/netplan/01-netcfg.yaml`) per a cada VM:

- **Per a `dmz-web` (Interfície DMZ: `10.0.10.10`):**
  ```yaml
  network:
    version: 2
    renderer: networkd
    ethernets:
      enp0s3: # o eth0 segons VirtualBox/VMware
        addresses:
          - 10.0.10.10/24
        routes:
          - to: default
            via: 10.0.10.1
        nameservers:
          addresses: [10.0.10.1, 1.1.1.1]
  ```

- **Per a `srv-serveis` (LAN: `10.0.20.10`):**
  ```yaml
  network:
    version: 2
    renderer: networkd
    ethernets:
      enp0s3:
        addresses:
          - 10.0.20.10/24
        routes:
          - to: default
            via: 10.0.20.1
        nameservers:
          addresses: [10.0.20.1, 1.1.1.1]
  ```

- **Per a `srv-backup` (LAN: `10.0.20.20`):**
  ```yaml
  network:
    version: 2
    renderer: networkd
    ethernets:
      enp0s3:
        addresses:
          - 10.0.20.20/24
        routes:
          - to: default
            via: 10.0.20.1
        nameservers:
          addresses: [10.0.20.1, 1.1.1.1]
  ```

- **Per a `granja1-srv` (Gateway Granja: NIC 1 LAN `10.1.1.10`, NIC 2 NAT WAN):**
  ```yaml
  network:
    version: 2
    renderer: networkd
    ethernets:
      enp0s3: # Connectat a lan-granja1
        addresses:
          - 10.1.1.10/24
      enp0s8: # Connectat a internet-lab
        dhcp4: true
  ```

- **Per a `granja1-sim` (Simulador: `10.1.1.20`):**
  ```yaml
  network:
    version: 2
    renderer: networkd
    ethernets:
      enp0s3:
        addresses:
          - 10.1.1.20/24
        routes:
          - to: default
            via: 10.1.1.10
        nameservers:
          addresses: [10.1.1.10, 1.1.1.1]
  ```


---

## 4. Recorregut Detallat d'una Lectura de Sensor

1. **`granja1-sim` (Simulació de camp):**
   - Simula els microcontroladors ESP32 llegint sensors ambientals per RS485 Modbus i les cèl·lules de pesatge dels silos per LoRaWAN (ChirpStack).
   - Publica la lectura cap al broker MQTT local de `granja1-srv` (`10.1.1.10:1883`).
2. **`granja1-srv` (Edge Computing):**
   - Rep la lectura pel seu broker MQTT local.
   - Avalua immediatament les regles locals dels actuadors: si la temperatura mesurada supera el llindar crític (> 31 ºC), **activa el ventilador localment en < 2 segons** sense dependre de la seu central ni d'Internet.
   - Emmagatzema la lectura al búfer local (*store-and-forward*).
   - Envia el missatge telemètric pel túnel xifrat WireGuard VPN (`10.0.100.0/24`) cap a la seu central.
3. **`fw-seu` (OPNsense):**
   - Rep el paquet a través de la interfície VPN WireGuard.
   - Aplica les regles del tallafocs: **l'únic trànsit permès des de la VPN cap a la LAN és el port del Broker MQTT (`srv-serveis:1883/8883`)**. Qualsevol altre trànsit és bloquejat i registrat.
4. **`srv-serveis` (Nucli Central):**
   - El broker MQTT Mosquitto rep la lectura i el servei d'ingesta la persisteix a la base de dades **MariaDB 10.11 LTS**.
   - Els triggers MariaDB avaluen els llindars i generen les alertes a `alarmes_incidencies` si escau.
   - La base de dades alimenta la rèplica de continuïtat.
   - OpenLDAP manté els comptes d'usuaris i rols per a les autenticacions.
5. **`srv-backup` (Còpies i PRD):**
   - Executa les tasques programades mitjançant `cron` (a les 02:00 AM) connectant-se a `srv-serveis` per extreure el buidatge de la BD (`mariadb-dump`) i LDAP (`slapcat`).
   - Copia els arxius a un segon disc virtual separat muntat a `/mnt/disc-extern-backup/` simulant la ubicació física externa (Estratègia 3-2-1).
6. **`dmz-web` (Accés Client):**
   - El client es connecta des de `pc-client` (o navegador host) per Internet/HTTPS.
   - OPNsense comprova la llista blanca d'IPs de clients contractats.
   - Si és autoritzat, la connexió arriba a `dmz-web`, que passa pel proxy invers Nginx i consulta a `srv-serveis` les dades estrictament necessàries per MariaDB (3306) i LDAP (389/636).

---

## 5. Punts Crítics de Seguretat i Configuració

### 5.1. Regles del Tallafocs OPNsense (`fw-seu`)
- **Aïllament estricte DMZ -> LAN:**
  * La DMZ **mai no pot iniciar connexions cap a la LAN**, excepte allò estrictament necessari:
    - `dmz-web` -> `srv-serveis:3306` (MariaDB)
    - `dmz-web` -> `srv-serveis:389/636` (OpenLDAP / LDAPS)
  * Qualsevol altre intent d'iniciar trànsit cap a la LAN (com ara intents cap a `srv-backup`, SSH, etc.) és **bloquejat i registrat al log**.
- **Aïllament VPN -> LAN:**
  * Des de la VPN (`granja1-srv`) **només es permet trànsit cap al Broker MQTT de `srv-serveis` (port 1883/8883)**. La granja mai té accés a la BD ni a LDAP directament.

### 5.2. Redundància de la Base de Dades (Justificació de disseny — FD01)
- Al laboratori, la rèplica de MariaDB està allotjada com a contenidor secundari dins de `srv-serveis`.
- **Aquesta limitació està documentada formalment:** Si cau el procés o es corrompen les dades, la rèplica protegeix el servei; però si cau la màquina virtual `srv-serveis` sencera, la redundància s'assumeix mitjançant el servidor independent `srv-backup`. En producció real, la rèplica s'allotjaria en una VM pròpia o servidor físic separat.

---

## 6. Procediment per a la Variació Presencial (Granja 2 — Requeriment 4.7)

Durant la defensa o sessió presencial, quan el professor demani afegir una segona granja:

1. **Clonació de les màquines de camp:**
   - Es clona `granja1-srv` com a `granja2-srv`.
   - Es clona `granja1-sim` com a `granja2-sim`.
   - S'assigna una xarxa nova a l'hipervisor: **Granja 2 (`10.1.2.0/24`)** (`lan-granja2` a VirtualBox / `VMnet40` a VMware).
2. **Execució de l'script d'automatització:**
   - Des de consola s'executa l'script:
     ```bash
     cd scripts/automatitzacio-granges
     ./alta_granja.sh -c 1 -n "Granja 2 Urgell" -e "ES252170004" -a "Camí Vell s/n" -p "Bellpuig" -s 2 -u "gestor_granja2" -r "10.1.2.0/24"
     ```
   - L'script en un segon:
     1. Crea l'esquema, naus, sensors i actuadors a MariaDB.
     2. Crea l'usuari gestor a OpenLDAP (`departmentNumber: GRANJA_2`).
     3. Afegeix la regla al tallafocs per autoritzar el nou túnel VPN (`10.0.100.20`).
     4. Genera la configuració local per al gateway clonat.

