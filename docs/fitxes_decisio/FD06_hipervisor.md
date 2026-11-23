# Fitxa de Decisió Tècnica — FD06: Hipervisor de Virtualització per al Laboratori del Projecte

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.0 i Entorn de Desplegament de Proves)  
**Data:** 23 de novembre de 2026  
**Responsable:** Joan Garcia (Àrea d'Infraestructura, Xarxa i Virtualització) / Mariam Solano  

---

## 1. Descripció de la necessitat

Per al disseny i la posterior fase d'execució i defensa del projecte AviGest S.L., cal desplegar un laboratori virtual complex compost per **6 màquines virtuals especialitzades** interconnectades entre si (`fw-seu` amb OPNsense, `dmz-web`, `srv-serveis`, `srv-backup`, `granja1-srv` i `granja1-sim` amb Ubuntu Server 24.04 LTS), més una màquina client de proves (`pc-client`).

L'elecció de l'eina de virtualització (hipervisor tipus 2) ha de complir els següents criteris clau:
1. **Llicència i cost (100% Gratuït):** No pot dependre de períodes de prova (trials de 30 dies), ni de llicències de pagament que bloquegin el projecte durant el curs.
2. **Segmentació de xarxes sense privilegis d'administrador:** Capacitat de crear interfícies de xarxa aïllades privades (DMZ `10.0.10.0/24`, LAN seu `10.0.20.0/24`, LAN granja `10.1.1.0/24`) directament sobre els ordinadors de l'aula de l'institut, sense requerir permisos d'administrador local del sistema operatiu amfitrió (host).
3. **Multiplataforma:** Funcionament homogeni sobre equips Windows de l'institut i sistemes personals GNU/Linux o macOS dels alumnes.
4. **Automatització i compatibilitat:** Suport d'eines de control per línia de comandes per automatitzar la clonació de màquines i la configuració d'adaptadors de xarxa.

---

## 2. Alternatives avaluades

### Alternativa 1: Oracle VM VirtualBox 7.x (Escollida)
* **Descripció:** Hipervisor tipus 2 de codi obert desenvolupat per Oracle sota llicència GNU GPL v2.
* **Pros:**
  - **100% Gratuït i Lliure:** No requereix cap registre, ni pagament de llicència ni subscripció.
  - **Xarxa Interna (`Internal Network / intnet`):** Permet crear xarxes aïllades simplement assignant un nom lògic a la interfície (`dmz`, `lan-seu`, `lan-granja1`). **No requereix permisos d'administrador al PC amfitrió**, la qual cosa és fonamental per treballar als ordinadors de l'aula de l'Institut Mollerussa.
  - **Control per línia de comandes (`VBoxManage`):** Permet crear xarxes NAT, gestionar adaptadors, fer instantànies (*snapshots*) i clonar plantilles de manera declarativa mitjançant scripts de PowerShell o Bash.
  - **Portabilitat estàndard:** Suport natiu d'exportació i importació de conjunts de màquines en format OVF/OVA.
* **Contres:**
  - Menor acceleració gràfica 3D respecte a VMware (incoherent per al nostre cas d'ús, ja que totes les nostres VMs són servidors headless sense escriptori gràfic).

### Alternativa 2: VMware Workstation Pro / Player
* **Descripció:** Hipervisor tipus 2 comercial de Broadcom.
* **Pros:**
  - Molt bon rendiment d'emulació i àmplia implantació històrica.
* **Contres:**
  - **Bloqueig per permisos d'administrador a l'aula:** Per crear xarxes virtuals personalitzades aïllades (com `VMnet10` o `VMnet20`), requereix executar l'eina *Virtual Network Editor* (`vmnetcfg.exe`), la qual **exigeix permisos d'administrador local al Windows host**. Als PCs de l'institut, els usuaris no tenen aquests permisos, provocant el bloqueig de les pràctiques.
  - Incertesa sobre la política de llicències comercials i canvis continus de la plataforma de Broadcom.

### Alternativa 3: Proxmox VE / KVM (Hipervisor Bare-Metal Tipus 1)
* **Descripció:** Distribució de codi obert basada en Debian per a virtualització de servidors dedicats amb KVM i contenidors LXC.
* **Pros:**
  - Rendiment natiu de nivell de producció sense sistema operatiu amfitrió intermedi.
* **Contres:**
  - Requereix un servidor físic dedicat en exclusiva per instal·lar-hi el sistema base.
  - Inviable per a l'ús diari a les aules d'informàtica de l'institut, on els ordinadors tenen arrencada dual o Windows corporatiu amb protecció de disc.

---

## 3. Decisió presa

**S'escull Oracle VM VirtualBox com a hipervisor 100% oficial i únic per a la implantació del laboratori virtual d'AviGest.**

### Justificació tècnica de la decisió:
1. **Garantia de funcionament a l'aula:** El mode *Internal Network* de VirtualBox és l'únic que garanteix que els alumnes puguin aïllar la DMZ de la LAN i de la granja sense dependre de permisos d'administració de la xarxa del centre educatiu.
2. **Criteri econòmic (Cost 0 €):** S'alinea estrictament amb la filosofia de programari lliure del projecte (Ubuntu, MariaDB, OPNsense, OpenLDAP), assegurant que qualsevol membre de l'equip o el tribunal pugui clonar i arrencar l'entorn sense comprar cap llicència.
3. **Automatització declarativa:** L'eina `VBoxManage` permet configurar les 3 interfícies d'OPNsense i la xarxa NAT de sortida a Internet amb scripts unificats documentats a la [guia_desplegament_maquines_virtuals.md](../Guies_MV/guia_desplegament_maquines_virtuals.md).

---

## 4. Mètode de verificació

- **Configuració de xarxes aïllades:**
  - Creació de la xarxa NAT `internet-lab` (`10.0.2.0/24`) amb suport DHCP per a la WAN.
  - Creació de la xarxa interna `dmz` per a la connexió entre `fw-seu` i `dmz-web`.
  - Creació de la xarxa interna `lan-seu` per a la connexió entre `fw-seu`, `srv-serveis` i `srv-backup`.
  - Creació de la xarxa interna `lan-granja1` per a la connexió entre `granja1-srv` i `granja1-sim`.
- **Comprovació d'aïllament:** Verificació mitjançant comandes `ping` que les xarxes internes no tenen comunicació creuada directa excepte a través de l'encaminament del tallafocs OPNsense.

---

## 5. Fonts consultades

1. **Oracle Corporation (2024):** *Oracle VM VirtualBox® User Manual — Chapter 6: Virtual Networking*. [https://www.virtualbox.org/manual/ch06.html](https://www.virtualbox.org/manual/ch06.html)
2. **Broadcom / VMware (2024):** *VMware Workstation Pro Documentation & Virtual Network Architecture*. [https://docs.vmware.com/](https://docs.vmware.com/)
3. **Free Software Foundation (FSF):** *GNU General Public License v2 (GPLv2) for VirtualBox Base Package*. [https://www.gnu.org/licenses/old-licenses/gpl-2.0.html](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
