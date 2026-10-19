# Arquitectura de Seguretat Perimetral, DMZ i Tallafocs — AviGest S.L.

**Mòdul:** ASIX - Projecte (Requeriment 4.4)  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Objectius de Seguretat Perimetral
Segons l'enunciat obligatori (Requeriment 4.4):
1. **DMZ a la seu central (no a les granges):** Allotja els serveis accessibles des de l'exterior (portal web d'accés i API d'ingesta).
2. **Accés restringit per llista blanca:** Només es permet la connexió dels ordinadors concrets de les empreses que han contractat el servei (clients autoritzats) i del personal tècnic d'AviGest.
3. **Aïllament de la xarxa de dades interna:** La base de dades MariaDB i el directori OpenLDAP mai no estan exposats directament a la WAN ni a Internet.

---

## 2. Model de Seguretat en Tres Zones

```mermaid
flowchart TD
    Internet["Internet (WAN)<br/>Clients i Granges Remotes"]
    
    subgraph TallafocsCentral["Tallafocs Perimetral de la Seu Central (Default Policy: DROP)"]
        direction TB
        FiltreWAN["1. Filtratge per Llista Blanca (Whitelist IP)"]
        FiltreDMZ["2. Control de trànsit DMZ -> LAN Interna"]
    end

    subgraph DMZ["Zona Desmilitaritzada - DMZ (192.168.100.0/24)"]
        WebServer["Nginx Reverse Proxy & Portal Web<br/>Ports: 80 / 443<br/>(Només accessible per IPs autoritzades)"]
        APIGateway["Broker / API d'Ingesta de Sensors<br/>Port: 8883 (MQTTS) / 443"]
    end

    subgraph LAN_Interna["Zona Segura - LAN Interna (192.168.200.0/24)"]
        MariaDB["Base de Dades MariaDB<br/>Port: 3306 (Només escolta a LAN)"]
        OpenLDAP["Directori OpenLDAP<br/>Ports: 389 / 636 (Només escolta a LAN)"]
        Backups["Servidor de Backups / NAS<br/>SSH / Rsync intern"]
    end

    Internet ==>|HTTPS només des d'IPs de clients autoritzats| FiltreWAN
    FiltreWAN --> DMZ
    DMZ ==>|Consultes SQL autoritzades (3306)| MariaDB
    DMZ ==>|Autenticació usuaris (389)| OpenLDAP
    
    Internet -.->|BLOQUEJAT DIRECTE: DROP| LAN_Interna
```

---

## 3. Matriu de Fluxos i Regles de Trànsit

| Zona Origen | Zona Destí | Port / Servei | Política / Condició | Justificació |
| :--- | :--- | :--- | :---: | :--- |
| **WAN (Clients autoritzats)** | **DMZ** | TCP 443 (HTTPS) | **ACCEPT** | Accés al portal web per part dels administradors de client i gestors de granges des de les seves seus. |
| **WAN (Qualsevol altra IP)** | **DMZ** | TCP 443 (HTTPS) | **DROP** | **Requisit d'enunciat:** Només s'admeten ordinadors de les empreses que han contractat el servei. |
| **WAN (Granges IoT autoritzades)** | **DMZ** | TCP 8883 (MQTT xifrat) | **ACCEPT** | Recepció de lectures de telemetria des dels gateways industrials de cada granja. |
| **WAN (Tothom)** | **LAN Interna** | Qualsevol port | **DROP** | Protecció absoluta de la base de dades i usuaris contra atacs d'escaneig o força bruta. |
| **DMZ** | **LAN Interna** | TCP 3306 (MariaDB) | **ACCEPT** | La web necessita consultar i escriure dades a la base de dades central. |
| **DMZ** | **LAN Interna** | TCP 389/636 (LDAP) | **ACCEPT** | La web necessita validar les credencials d'inici de sessió contra el directori central. |
| **DMZ** | **LAN Interna** | Qualsevol altre port | **DROP** | Principi de mínim privilegi: cap altre servei intern és accessible des de la DMZ. |
| **LAN Interna** | **DMZ / WAN** | Connexions noves | **DROP** | Els servidors interns de BD no poden iniciar connexions cap a la DMZ ni cap a l'exterior (excepte sortida DNS/NTP controlada). |
| **Qualsevol** | **Qualsevol** | Paquets invàlids | **DROP** | Mitigació d'atacs de fragments, TCP flags alterades o spoofing d'IPs. |

---

## 4. Implementació de la Llista Blanca (Whitelist)
Les empreses clients registren la seva adreça IP pública estàtica (o xarxa corporativa) en el moment de l'alta del contracte:
- **Client 1 (AgroPonent S.L.):** IP pública `198.51.100.10`
- **Client 2 (Avícola del Segrià S.A.):** IP pública `203.0.113.25`
- **Seu Central AviGest (Oficines/VPN de Suport):** IP pública `198.51.100.5`

Tota connexió provinent d'adreces diferents serà descartada de forma immediata pel tallafocs abans d'arribar al servidor web, complint rigorosament el requeriment 4.4 de l'enunciat.
