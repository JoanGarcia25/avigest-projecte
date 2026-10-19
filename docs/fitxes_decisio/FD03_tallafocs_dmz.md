# Fitxa de Decisió Tècnica — FD03: Disseny del Tallafocs i Arquitectura DMZ

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriments 4.1, 4.4 i 4.6)  
**Data:** 19 d'octubre de 2026  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Descripció de la necessitat
La seu central d'AviGest conté dades crítiques i privades de múltiples clients. L'enunciat exigeix:
- El disseny i implementació d'una **Zona Desmilitaritzada (DMZ)** a la seu central per allotjar els serveis públics exposats (portal web d'accés).
- **Accés restringit perimetralment:** Només s'ha de permetre la connexió d'ordinadors o empreses concretes contractants del servei (llista blanca d'adreces IP autoritzades).
- Protecció absoluta de la xarxa interna (on s'executen la base de dades MariaDB i el directori OpenLDAP), evitant qualsevol accés directe des d'Internet.
- Regles de tallafocs documentades, justificades i reproduïbles.

---

## 2. Alternatives avaluades

### Alternativa 1: Tallafocs basat en Linux (`iptables` / `nftables` / `UFW`) amb xarxes aïllades (Escollida)
* **Descripció:** Ús del filtre de paquets natiu del kernel de Linux mitjançant un script de regles ben estructurat i modular, combinat amb segmentació de xarxes aïllades (subxarxes IP i bridges de Docker).
* **Pros:**
  - **Simplicitat i control total:** Permet definir amb precisió mil·limètrica cada regla de filtratge d'entrada (*INPUT*), reenviament (*FORWARD*) i sortida (*OUTPUT*).
  - **Control de versions a Git:** L'script bash `firewall_regles.sh` es versiona directament al repositori i es pot auditar línia per línia.
  - **Lleugeresa i repetibilitat:** No consumeix recursos de CPU/RAM addicionals en sistemes virtuals i es pot executar directament tant en un servidor físic com en una màquina de laboratori.
  - **Filtratge IP ràpid:** Permet establir una llista blanca (*whitelist*) d'adreces IP de clients de manera directa amb conjunts d'IPs (`ipset` o cadenes dedicades).
* **Contres:**
  - Requereix comprensió de la sintaxi de línia de comandes per a la seva administració (ideal per al perfil de tècnic de sistemes ASIX).

### Alternativa 2: Màquina Virtual de Tallafocs dedicada (pfSense / OPNsense)
* **Descripció:** Sistema operatiu FreeBSD dedicat a l'encaminament i tallafocs amb interfície gràfica web.
* **Pros:**
  - Interfície gràfica molt visual, quadres de comandament de trànsit i assistents per a VPN (OpenVPN / WireGuard).
* **Contres:**
  - Sobrecàrrega de recursos: requereix una VM amb 2-4 GB de RAM i configuració de múltiples interfícies virtuals (*vSwitches* / targetes en pont).
  - Major risc de bloqueig o pèrdua de connectivitat durant la defensa en directe si una targeta virtual no enllaça correctament.

### Alternativa 3: Aparell de maquinari físic (Appliance Fortinet / Cisco ASA)
* **Descripció:** Dispositiu de seguretat perimetral dedicat.
* **Motiu de descart:** Cost econòmic prohibitiu per a una fase de prototipatge i impossibilitat de clonar-lo en els ordinadors personals dels membres de l'equip.

---

## 3. Decisió presa
**S'escull la implementació de tallafocs mitjançant script estructurat d'IPTABLES / UFW sobre la màquina amfitriona de la seu central.**

### Justificació:
1. **Compliment exacte de l'enunciat:** Aplica una política de tall per defecte (*Default DROP*) per a tot el trànsit no autoritzat, i separa físicament i lògicament la DMZ de la LAN interna.
2. **Defensabilitat davant del tribunal:** Un script net i comentat permet explicar exactament per què s'obre cada port i com es bloqueja l'accés il·legítim a la base de dades.
3. **Facilitat de manteniment:** L'actualització d'una IP autoritzada d'un client es redueix a afegir una línia a l'arxiu de configuració de la seu central.

---

## 4. Mètode de verificació
- **Prova de penetració/escaneig (Nmap):** Verificació que els ports interns de la BD (3306) i LDAP (389/636) estan filtrats (*filtered*) des de la xarxa externa WAN.
- **Prova de llista blanca:** Comprovació que una petició HTTP/HTTPS des d'una IP no autoritzada és descartada silenciosament (*DROP*), mentre que des d'una IP de la llista blanca s'estableix la connexió amb la DMZ.
