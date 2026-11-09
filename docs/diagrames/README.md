# 📊 Diagrames i Esquemes Oficials — AviGest S.L.

En aquesta carpeta es troben els fitxers font vectorials en format estàndard **Draw.io / diagrams.net** (`.drawio`) llestos per obrir, editar i exportar com a imatges (PNG/SVG/PDF) per a la memòria del projecte:

---

## 1. [Esquema de Topologia de Xarxa i Màquines Virtuals](esquema_xarxa_vms.drawio)
* **Fitxer:** [`docs/diagrames/esquema_xarxa_vms.drawio`](esquema_xarxa_vms.drawio)
* **Contingut detallat:**
  * **Zona Exterior (WAN / NAT `10.0.2.0/24`):** Equip client `pc-client`, núvol NAT de VirtualBox/VMware i passarel·la VPN WireGuard (UDP 51820).
  * **Seu Central AviGest (CPD):**
    * Tallafocs perimetral 3 potes `fw-seu` (OPNsense) amb política estricta *Default DROP*.
    * Zona Desmilitaritzada (DMZ) amb `dmz-web` (`10.0.10.10`, Nginx Reverse Proxy).
    * Xarxa Interna (LAN Seu `10.0.20.0/24`) amb el node Docker `srv-serveis` (`10.0.20.10`) i el servidor de còpies dedicat `srv-backup` (`10.0.20.20`) amb el segon disc simulat.
  * **Granja 1 Pilot (`10.1.1.0/24`):** Gateway industrial Advantech `granja1-srv` (Edge Computing i buffer Store-and-Forward) i màquina de sensors `granja1-sim`.
  * **Granja 2 (Variació 4.7):** Subxarxa `10.1.2.0/24` per a l'alta ràpida amb `alta_granja.sh`.
  * **Fluxos de seguretat:** Fletxes amb codificació de colors (verd = permès amb port explícit; vermell/gris = bloquejos DROP).

---

## 2. [Esquema de l'Arquitectura i Flux de Dades IoT End-to-End](esquema_flux_iot.drawio)
* **Fitxer:** [`docs/diagrames/esquema_flux_iot.drawio`](esquema_flux_iot.drawio)
* **Contingut detallat en 5 capes:**
  1. **Capa 1 (Sensòrica i Camp):** Sondes SHT30 (Temp/Humitat cada 30s), sensor CO2 Senseair S8 (cada 60s), kits de pesatge de sitges (LoRaWAN cada 15 min) i actuadors (ventiladors/calefactors).
  2. **Capa 2 (Transmissió de Camp):** Bus sèrie diferencial RS485 Modbus RTU (interior de naus) vs xarxa de ràdio LoRaWAN 868 MHz amb gateway Dragino LPS8N (silos exteriors).
  3. **Capa 3 (Edge Computing a `granja1-srv`):** Broker MQTT local, **bucle autònom d'actuació immediata** sobre relés si $T > 31^\circ\text{C}$ (independent d'Internet) i cua de retenció *Store-and-Forward* (fins a 72h).
  4. **Capa 4 (Transport Segur WAN):** Router 4G amb doble SIM, túnel WireGuard VPN i filtre OPNsense (només port MQTT 1883 autoritzat).
  5. **Capa 5 (Seu Central i BD PostgreSQL 16):** Ingestor central, triggers PL/pgSQL d'alarma crítica ($T \ge 33^\circ\text{C}$ o $CO_2 > 3.000\text{ ppm}$) i vistes comparatives de negoci amb seguretat RLS.

---

## 3. [Esquema de l'Arbre Organitzatiu OpenLDAP (DIT)](esquema_ldap.drawio)
* **Fitxer:** [`docs/diagrames/esquema_ldap.drawio`](esquema_ldap.drawio)
* **Contingut detallat:**
  * **Arrel:** `dc=avigest,dc=cat`.
  * **Branca AviGest (`ou=avigest`):** Administrador global (`admin_joan`) i suport tècnic.
  * **Branca Grups (`ou=groups`):** Els 4 rols de seguretat `posixGroup` (`AdminsAviGest`, `AdminsClient`, `GestorsGranja`, `UsuarisConsulta`).
  * **Branca Clients Multitenant (`ou=clients`):** Empreses integradores separades (`ou=AgroPonent` amb ID 1, `ou=AvicolaSegria` amb ID 2).
  * **Sub-branques de Granges:** `ou=Granja_Bellpuig`, `ou=Granja_Alcarras` i usuaris associats amb `departmentNumber: GRANJA_<ID>`.
  * **Mecanisme RLS:** Explicació visual de com els atributs LDAP mapegen directament a la funció `sp_set_tenant()` de PostgreSQL per garantir l'aïllament matemàtic de dades entre granges.

---

### Com obrir i exportar els diagrames?
1. Obriu el navegador web i aneu a **[app.diagrams.net](https://app.diagrams.net)** (Draw.io gratuït).
2. Feu clic a **"Open Existing Diagram"** (Obrir diagrama existent) i seleccioneu qualsevol dels fitxers `.drawio` d'aquesta carpeta.
3. Podeu retocar colors, mides o afegir textos si voleu.
4. Per guardar la imatge: aneu a **Fitxer $\rightarrow$ Exporta com $\rightarrow$ PNG** (o PDF/SVG) i marqueu una resolució de 300 DPI per a màxima qualitat a la memòria impresa.

