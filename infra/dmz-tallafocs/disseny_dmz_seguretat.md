# Arquitectura de Seguretat Perimetral, DMZ i Tallafocs OPNsense (`fw-seu`)

**Mòdul:** ASIX - Projecte (Requeriment 4.4)  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  
**Data:** Actualitzat a 26 d'octubre de 2026  

---

## 1. Topologia de Xarxa en 3 Zones + VPN

El tallafocs perimetral de la seu central s'implementa mitjançant l'appliance virtual **OPNsense** (`fw-seu`), connectat a tres xarxes físicament/lògicament diferenciades i actuant com a servidor per al túnel VPN de les granges:

```mermaid
flowchart TD
    Client["pc-client<br/>(Navegador de prova)"]
    Internet["Internet (NAT de l'hipervisor)"]

    subgraph FW["fw-seu (OPNsense)"]
        direction TB
        WAF_Rules["Regles d'inspecció d'estat (Default DROP)"]
        VPN_Srv["Servidor VPN (10.0.100.0/24)"]
    end

    subgraph DMZ_Net["DMZ (10.0.10.0/24)"]
        DMZ_Web["dmz-web<br/>Nginx + proxy invers<br/>WAF i relay SMTP"]
    end

    subgraph LAN_Net["LAN seu (10.0.20.0/24)"]
        Srv_Serveis["srv-serveis<br/>Docker: OpenLDAP<br/>PostgreSQL + rèplica<br/>Broker MQTT"]
        Srv_Backup["srv-backup<br/>Còpies amb cron<br/>Disc extern simulat"]
    end

    subgraph Granja1_Net["Granja 1 (10.1.1.0/24)"]
        Granja1_Sim["granja1-sim<br/>Sensors ESP32 simulats<br/>RS485 (Modbus)<br/>LoRaWAN (ChirpStack)"]
        Granja1_Srv["granja1-srv<br/>Client VPN i MQTT local<br/>Regles dels actuadors<br/>Buffer de dades"]
    end

    Client --> Internet
    Internet ==>|Trànsit WAN només des d'IPs de clients| FW
    FW -->|Port 443/80| DMZ_Web
    DMZ_Web ==>|NOMÉS SQL:5432 i LDAP:389| Srv_Serveis
    DMZ_Web -.->|BLOQUEJAT TOTA LA RESTA: DROP| LAN_Net

    Granja1_Sim -->|Dades de camp| Granja1_Srv
    Granja1_Srv ==>|Túnel VPN (10.0.100.0/24)| VPN_Srv
    VPN_Srv ==>|NOMÉS MQTT:1883/8883| Srv_Serveis
    VPN_Srv -.->|BLOQUEJAT ACCÉS A BD I LDAP: DROP| LAN_Net
```

---

## 2. Mapa d'Adreçament IP del Sistema

| Màquina Virtual | Zona de Xarxa | Adreça IP / Rang | Serveis que allotja |
| :--- | :--- | :--- | :--- |
| **`pc-client`** | Internet (Ext.) | IP assignada per NAT | Navegador web de prova de l'empresa client contractant. |
| **`fw-seu` (WAN)** | Internet | IP NAT WAN | Interfície pública d'OPNsense (accés web per als clients). |
| **`fw-seu` (DMZ)** | DMZ | `10.0.10.1/24` | Gateway perimetral per a la xarxa DMZ. |
| **`fw-seu` (LAN)** | LAN seu | `10.0.20.1/24` | Gateway de seguretat per a la xarxa interna de serveis. |
| **`fw-seu` (VPN)** | VPN Server | `10.0.100.1/24` | Pila de terminació de túnels VPN de les granges remotes. |
| **`dmz-web`** | DMZ | `10.0.10.10/24` | Proxy invers Nginx, WAF, Portal Web i Relay SMTP. |
| **`srv-serveis`** | LAN seu | `10.0.20.10/24` | PostgreSQL (5432), OpenLDAP (389/636) i Broker MQTT (1883/8883). |
| **`srv-backup`** | LAN seu | `10.0.20.20/24` | Servidor de backups amb cron i segon disc virtual muntat. |
| **`granja1-srv`** | Granja 1 | `10.1.1.10/24` (i IP VPN `10.0.100.10`) | Client VPN, MQTT local, regles d'actuadors i buffer. |
| **`granja1-sim`** | Granja 1 | `10.1.1.20/24` | Simulador ESP32, bus RS485 Modbus i servidor ChirpStack LoRa. |
| *`granja2-srv` / `sim`* | *Granja 2 (Variació)* | *`10.1.2.0/24`* | *Granja addicional creada per a la variació del requeriment 4.7.* |

---

## 3. Matriu de Regles de Tallafocs Documentades i Justificades (Requeriment 4.4)

Totes les regles segueixen el principi de mínim privilegi amb política per defecte **`DROP`** a totes les interfícies:

### 3.1. Interfície WAN (Internet)
| Origen | Destí | Port / Protocol | Acció | Justificació Tècnica |
| :--- | :--- | :--- | :---: | :--- |
| **Alias `CLIENTS_AUTORITZATS`** (`pc-client`) | `dmz-web` (`10.0.10.10`) | TCP 443 (HTTPS) / TCP 80 (HTTP) | **PASS** | Permet als clients contractats accedir al portal web d'administració de les seves granges. |
| **Qualsevol altra IP d'Internet** | Qualsevol | Qualsevol | **BLOCK / DROP** | Compliment estricte del requeriment: només es permet l'accés a les IPs de les empreses que han contractat el servei. |
| **IPs de les Granges (`granja1-srv`)** | `fw-seu` (WAN) | UDP 1194 (OpenVPN) o 51820 (WireGuard) | **PASS** | Permet l'establiment del túnel VPN xifrat des de la granja fins al tallafocs central. |

### 3.2. Interfície DMZ (`10.0.10.0/24`)
> **Regla Crítica de Seguretat:** La DMZ no pot iniciar connexions cap a la LAN, excepte els ports estrictament necessaris per a l'aplicació.

| Origen | Destí | Port / Protocol | Acció | Justificació Tècnica |
| :--- | :--- | :--- | :---: | :--- |
| `dmz-web` (`10.0.10.10`) | `srv-serveis` (`10.0.20.10`) | TCP 5432 (PostgreSQL) | **PASS** | El portal web allotjat a la DMZ necessita consultar dades de clients i granges. |
| `dmz-web` (`10.0.10.10`) | `srv-serveis` (`10.0.20.10`) | TCP 389 / 636 (OpenLDAP) | **PASS** | El portal web necessita validar les credencials d'inici de sessió dels usuaris contra el directori central. |
| `dmz-web` (`10.0.10.10`) | **LAN seu (`10.0.20.0/24`)** | **Qualsevol altre port** | **BLOCK / DROP** | **Aïllament fonamental:** Si el servidor web de la DMZ és vulnerat, l'atacant té completament prohibit escanejar o connectar-se a `srv-backup`, accedir per SSH a `srv-serveis` o atacar altres serveis interns. |
| `dmz-web` (`10.0.10.10`) | WAN (Internet) | TCP 25 / 587 (SMTP) | **PASS** | Sortida controlada per a l'enviament de correus d'alarma (Relay SMTP). |

### 3.3. Interfície VPN (`10.0.100.0/24`)
| Origen | Destí | Port / Protocol | Acció | Justificació Tècnica |
| :--- | :--- | :--- | :---: | :--- |
| `granja1-srv` (`10.0.100.10`) | `srv-serveis` (`10.0.20.10`) | TCP 1883 / 8883 (Broker MQTT) | **PASS** | La granja només necessita publicar les lectures telemètriques al broker MQTT de la seu. |
| `granja1-srv` (`10.0.100.10`) | **LAN seu (`10.0.20.0/24`)** | **Qualsevol altre port** | **BLOCK / DROP** | Els equips de les granges tenen expressament prohibit connectar-se directament a la base de dades, a LDAP o al servidor de còpies de seguretat. |

### 3.4. Interfície LAN (`10.0.20.0/24`)
| Origen | Destí | Port / Protocol | Acció | Justificació Tècnica |
| :--- | :--- | :--- | :---: | :--- |
| `srv-backup` (`10.0.20.20`) | `srv-serveis` (`10.0.20.10`) | TCP 5432 (PostgreSQL) i TCP 389/636 (LDAP) | **PASS** | `srv-backup` necessita extreure els buidatges transaccionals per a les còpies de seguretat nocturnes. |
| `srv-serveis` / `srv-backup` | WAN (Internet) | TCP 80, 443 / UDP 123 (NTP) | **PASS** | Actualitzacions oficials de paquets i sincronització horària de rellotge (NTP). |
