# Fitxa de Decisió Tècnica — FD03: Solució de Tallafocs Perimetral i Seguretat DMZ

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriments 4.1, 4.4 i 4.6)  
**Data:** Actualitzat a 26 d'octubre de 2026  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Descripció de la necessitat
La seu central d'AviGest conté dades crítiques i privades de múltiples clients. L'enunciat exigeix:
- El disseny i implementació d'una **Zona Desmilitaritzada (DMZ)** a la seu central per allotjar els serveis públics exposats (`dmz-web`: portal web d'accés, proxy invers Nginx, WAF i relay SMTP).
- **Accés restringit perimetralment:** Només s'ha de permetre la connexió d'ordinadors o empreses concretes contractants del servei (llista blanca d'adreces IP autoritzades).
- Protecció absoluta de la xarxa interna (LAN: `10.0.20.0/24`), evitant qualsevol accés directe des d'Internet.
- Gestió de la **VPN (`10.0.100.0/24`)** per a la connexió segura de les granges remotes.
- Regles de tallafocs documentades, justificades i amb política de tall per defecte (*Default DROP*).

---

## 2. Alternatives avaluades

### Alternativa 1: Appliance Virtual de Seguretat OPNsense (`fw-seu`) (Escollida)
* **Descripció:** Sistema operatiu FreeBSD dedicat a l'encaminament i tallafocs perimetral, amb suport multi-interfície natiu, servidor VPN i gestió centralitzada.
* **Pros:**
  - **Arquitectura de 3 potes nativa:** Gestió transparent de 3 interfícies físiques/virtuals:
    * WAN (Internet / NAT de l'hipervisor)
    * DMZ (`10.0.10.0/24`)
    * LAN seu (`10.0.20.0/24`)
  - **Servidor VPN integrat (`10.0.100.0/24`):** Permet autenticar i xifrar els túnels que provenen de `granja1-srv` (i futures granges).
  - **Control d'accés perimetral granular:** Permet crear *Aliases* per a la llista blanca de clients contractats des d'Internet i aplicar la regla crítica: **la DMZ no pot iniciar connexions cap a la LAN excepte a ports estrictament autoritzats**.
  - **Eina gràfica i diagnòstic:** Quadre de comandament complet, gràfiques de trànsit en temps real i registre detallat de paquets descartats (*live log*), ideal per a la defensa presencial davant del tribunal.
* **Contres:**
  - Requereix una màquina virtual dedicada amb 3 o 4 interfícies de xarxa virtuals a VMware.

### Alternativa 2: Tallafocs natiu Linux pur (`iptables` / `nftables` / `UFW`)
* **Descripció:** Filtratge de paquets basat en scripts a la màquina amfitriona.
* **Pros:**
  - Molt lleuger en memòria RAM.
* **Contres:**
  - Configurar un servidor VPN complet (OpenVPN/WireGuard) juntament amb l'encaminament NAT de 3 zones mitjançant scripts de Bash manuals augmenta el risc d'error de configuració durant una sessió en directe.
  - No disposa de quadre de comandament visual per monitoritzar les connexions en viu durant la presentació oral.

---

## 3. Decisió presa
**S'escull OPNsense com a tallafocs dedicat (`fw-seu`).**

### Justificació de les regles clau de tallafocs:
1. **Regla WAN -> DMZ:** Només es permet el trànsit HTTPS (443) i HTTP (80) provinent de l'adreça IP pública de `pc-client` (o clients contractats) cap a `dmz-web`. Tota la resta és **DROP**.
2. **Regla DMZ -> LAN (Aïllament estricte):** **La DMZ té expressament denegada la capacitat d'iniciar connexions cap a la LAN**, amb les úniques excepcions imprescindibles per al servei:
   - Cap a `srv-serveis`: Port 5432 (PostgreSQL) per consultar la BD.
   - Cap a `srv-serveis`: Port 389/636 (OpenLDAP) per autenticar usuaris.
   - Qualsevol altra connexió iniciada des de la DMZ cap a la LAN és bloquejada i registrada (*Default DROP*).
3. **Regla VPN (`10.0.100.0/24`) -> LAN:** El tràfic provinent de `granja1-srv` **només pot accedir a `srv-serveis` a través del port MQTT (1883/8883)**. La granja mai no té accés directe a la BD ni a LDAP.

---

## 4. Mètode de verificació
- **Inspecció de regles a la GUI d'OPNsense:** Comprovació de les regles a les pestanyes WAN, DMZ, LAN i OpenVPN.
- **Prova de trànsit creuat:** Comprovació amb `curl` i `nc` que `dmz-web` no pot obrir connexions arbitràries cap a `srv-backup` ni ports no autoritzats de `srv-serveis`.
- **Validació de túnel VPN:** Connexió satisfactòria des de `granja1-srv` i comprovació del handshake a OPNsense.
