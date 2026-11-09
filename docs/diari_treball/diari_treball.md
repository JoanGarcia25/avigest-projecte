# Diari de Treball — AviGest S.L.

**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Cicle:** CFGS Administració de Sistemes Informàtics en Xarxa (ASIX) — 2n Curs  
**Mòdul:** M12 - Projecte (Bloc lectiu de 6 hores setmanals els dilluns)  
**Equip de treball:**  
- **Joan Garcia** (Infraestructura, Xarxa, Seguretat i Serveis Centralitzats)  
- **Mariam Solano** (Base de Dades, Automatismes, IoT i Scripts)  
**Tutor del Projecte:** Professorat de l'Institut Mollerussa  
**Inici del Projecte:** 14 de setembre de 2026  
**Lliurament Fita E2/E3:** 4 de desembre de 2026  
**Darrera actualització:** Dilluns, 26 d'octubre de 2026  

---

## Metodologia i Context Acadèmic

> [!NOTE]
> El mòdul M12 es desenvolupa exclusivament els **dilluns en sessions de 6 hores lectives** a l'aula/laboratori.
> 
> La planificació oficial de l'enunciat estableix:
> - **Fase 1 (Setembre):** Constitució de l'equip (E0) i Estudi de Necessitats (E1). Tancada i defensada a principis d'octubre.
> - **Fase 2 (Octubre – 4 de Desembre):** Fase de **DISSENY TÈCNIC (E2)** i **Pla d'Intervenció (E3)**. En aquest període no s'espera la implementació final en producció, sinó la recerca d'alternatives, redacció de fitxes de decisió, proves de concepte preliminars (POC), modelatge conceptual/lògic i acords d'arquitectura.

---

## Registre de Sessions Realitzades

### Sessió 1: Dilluns, 14 de setembre de 2026 (6 hores)
**Fita:** Constitució de l'equip i definició de rols (Lliurable E0)

- **Objectiu:** Formalitzar l'equip de treball, definir el cas de negoci d'AviGest S.L. i establir la divisió de tasques de l'enunciat.
- **Treball realitzat:**
  - **Joan:** Recerca prèvia sobre els requeriments d'infraestructura (maquinari de servidor, necessitat de directori centralitzat i seguretat perimetral).
  - **Mariam:** Recerca sobre la normativa de benestar animal en avicultura d'engreix (temperatures recomanades, ventilació, humitat i CO2).
  - **Treball conjunt:** Definició dels àmbits de responsabilitat (Joan: Infraestructura, Xarxa i Seguretat; Mariam: BD, IoT i Automatització). Redacció i tancament del document [E0_divisio_tasques_rols.md](../E0_divisio_tasques_rols.md).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

### Sessió 2: Dilluns, 21 de setembre de 2026 (6 hores)
**Fita:** Elaboració de l'Estudi de Necessitats (Lliurable E1)

- **Objectiu:** Analitzar el sector avícola a les comarques de Lleida (Pla d'Urgell, Urgell, Segrià) i definir les mancances dels sistemes actuals.
- **Treball realitzat:**
  - **Joan:** Anàlisi de la connectivitat a entorns rurals i aïllats (problemes de línies ADSL antigues, cobertura 4G/5G) i estudi de solucions comercials de climatització ramadera.
  - **Mariam:** Anàlisi de necessitats del client: model de negoci basat en integradores avícoles que requereixen centralitzar múltiples granges mantenint un aïllament estricte (*multitenant*).
  - **Treball conjunt:** Redacció de l'abast del projecte, elaboració de la matriu DAFO i disseny del logotip d'AviGest S.L.
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

### Sessió 3: Dilluns, 28 de setembre de 2026 (6 hores)
**Fita:** Tancament de l'E1 i preparació de la defensa oral

- **Objectiu:** Enllestir el document d'Estudi de Necessitats, crear l'estructura del repositori col·laboratiu i preparar les 2 diapositives de la presentació.
- **Treball realitzat:**
  - **Joan:** Inicialització de l'estructura de carpetes del repositori a Git, definició de branques de treball i configuració de fitxers `.gitignore`.
  - **Mariam:** Concreció dels paràmetres ambientals a monitoritzar (temperatura, humitat, CO2 i nivell de sitja) i revisió de l'apartat de viabilitat.
  - **Treball conjunt:** Revisió final i maquetació del document [E1_estudi_necessitats_joangarcia_mariamsolano.pdf](../E1_estudi_necessitats_joangarcia_mariamsolano%20(2).pdf) i elaboració de les 2 diapositives resum (*què hem comparat / què farem*).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

### Sessió 4: Dilluns, 5 d'octubre de 2026 (6 hores de classe)
**Fita:** Jornada de defenses orals de l'Estudi de Necessitats (Lliurable E1)

- **Objectiu:** Exposició oral formal del projecte davant del professorat/tribunal.
- **Desglossament exacte del temps de la sessió:**
  - **1 h 30 min (Preparació i assaig):** Ajust de les 2 diapositives resum, assaig del discurs i coordinació del torn de paraula entre en Joan i la Mariam just abans de presentar.
  - **10 minuts (Defensa oral):** Exposició davant del tribunal explicant la idea d'AviGest S.L., la comparativa de mercat i el model multiclient, seguit del torn de preguntes del professor.
  - **Resta de la sessió:** Assistència a l'aula com a oients a les exposicions de la resta de grups del curs durant el bloc de classe. No es va fer cap altra tasca tècnica d'E2.
- **Dedicació:** 1 h 40 min de treball directe per a la defensa d'AviGest (dins de la jornada lectiva de 6h a l'aula).

---

### Dilluns, 12 d'octubre de 2026 — FESTIU
> [!IMPORTANT]
> **Festa Nacional (El Pilar) — No hi va haver classe lectiva presencial (0 hores).**

---

### Sessió 5: Dilluns, 19 d'octubre de 2026 (6 hores)
**Fita:** Investigació de solucions, primeres proves de concepte (POC) i acords de disseny

- **Objectiu:** Aprofundir en les fitxes de decisió, fer proves tècniques preliminars de laboratori i consensuar el model conceptual de dades i usuaris.
- **Treball realitzat durant les 6 hores:**
  - **Joan (3h):**
    - Redacció de l'esborrany de la fitxa [FD02_ldap.md](../fitxes_decisio/FD02_ldap.md): comparació d'OpenLDAP vs Samba 4 (consum de RAM, facilitat d'automatització amb LDIF i compliment dels 4 rols d'usuaris requerits).
    - Investigació sobre la segmentació perimetral: esquema de DMZ per aïllar la base de dades d'Internet ([FD03_tallafocs_dmz.md](../fitxes_decisio/FD03_tallafocs_dmz.md)).
    - Estudi de maquinari de servidor central per a entorns virtualitzats (necessitat de discs RAID i doble font d'alimentació).
  - **Mariam (3h):**
    - Redacció de l'esborrany de la fitxa [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md): comparació inicial de SGBD.
    - Proves de concepte SQL en local: definició conceptual de les primeres entitats (clients, granges, naus, sensors i actuadors).
    - Investigació sobre protocols de comunicació de camp: avantatges de cablejar RS485 a l'interior de les naus vs LoRaWAN per a sitges exteriors ([FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md)).
  - **Treball conjunt (3h):**
    - Debat i acord clau sobre l'**aïllament multiclient**: hem acordat fer servir l'atribut LDAP `businessCategory: CLIENT_<ID>` vinculat directament amb la clau forana `id_client` a la base de dades.
    - Definició de l'estructura del document [E2_document_disseny_tecnic.md](../E2_disseny_tecnic/E2_document_disseny_tecnic.md).
    - Redacció i posada al dia d'aquest [diari_treball.md](diari_treball.md).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

### Sessió 6: Dilluns, 26 d'octubre de 2026 (6 hores — AVUI)
**Fita:** Consens de la topologia multi-VM, homogeneïtzació a Ubuntu Server 24.04 LTS i avanç de l'E3

- **Objectiu:** Reestructurar l'entorn de màquines virtuals per reflectir una infraestructura industrial realista, professional i 100% defensable davant del tribunal, consolidant les 6 VMs especialitzades, aplicant el consell docent d'homogeneïtat i avançant el pla d'intervenció.
- **Treball realitzat durant les 6 hores:**
  - **Treball conjunt (Consens de l'esquema de VMs i homogeneïtat de sistemes):**
    - Arran de la recomanació explícita del professor a l'aula de **no barrejar distribucions Linux** per evitar problemes de connectivitat, s'adopta formalment **Ubuntu Server 24.04 LTS** com a distribució única per a totes les màquines de serveis mitjançant la plantilla clonable `ubuntu-base` amb xarxa declarativa **Netplan (YAML)**.
    - Es manté **OPNsense** com a appliance de seguretat dedicat de 3 potes per a la seu central.
    - S'acorda l'esquema final de màquines virtuals:
      * `pc-client`: Client extern / navegador de prova del client contractant (Host físic / NAT).
      * `fw-seu`: Tallafocs perimetral OPNsense de 3 interfícies físiques (WAN, DMZ `10.0.10.0/24`, LAN `10.0.20.0/24`) i servidor VPN WireGuard (`10.0.100.0/24`).
      * `dmz-web`: DMZ (`10.0.10.10`, Ubuntu 24.04) amb proxy invers Nginx, WAF i relay SMTP, accessible només per llista blanca d'IPs.
      * `srv-serveis`: LAN (`10.0.20.10`, Ubuntu 24.04) amb Docker Engine: MariaDB 10.11 LTS + Rèplica GTID, Broker MQTT Mosquitto i OpenLDAP.
      * `srv-backup`: LAN (`10.0.20.20`, Ubuntu 24.04) VM dedicada de còpies amb cron nocturn i segon disc virtual simulat (/mnt).
      * `granja1-srv`: Camp (`10.1.1.10`, Ubuntu 24.04 / VPN WireGuard `10.0.100.10`) amb MQTT local, regles d'actuadors (>31ºC), búfer store-and-forward i client VPN.
      * `granja1-sim`: Camp (`10.1.1.20`, Ubuntu 24.04) simulador d'ESP32 per RS485 Modbus i silos per LoRaWAN ChirpStack.
  - **Joan:**
    - Elaboració de la documentació de desplegament de màquines virtuals i pujada de les guies de referència a `docs/Guies_MV/` ([Guia del laboratori virtual d'AviGest.pdf](../Guies_MV/Guia%20del%20laboratori%20virtual%20d’AviGest.pdf) i [guia_desplegament_maquines_virtuals.md](../guia_desplegament_maquines_virtuals.md) amb les configuracions de Netplan YAML).
    - Disseny i documentació de les regles de tallafocs OPNsense a [disseny_dmz_seguretat.md](../../infra/dmz-tallafocs/disseny_dmz_seguretat.md) i [firewall_regles.sh](../../infra/dmz-tallafocs/firewall_regles.sh), amb aïllament estricte DMZ -> LAN (només TCP 3306 i LDAPS permesos) i pas de VPN WireGuard a Broker MQTT.
    - Configuració del servidor dedicat `srv-backup` i del pla de recuperació PRD amb el segon disc virtual simulat ([pla_recuperacio_desastres_prd.md](../../infra/backups-prd/pla_recuperacio_desastres_prd.md)).
  - **Mariam:**
    - Migració completa de la base de dades a **MariaDB 10.11 LTS**: conversió de taules DDL InnoDB, triggers de termòstat automàtic en MariaDB SQL i procediments d'alta atòmica de granges.
    - Desenvolupament de les 4 vistes i consultes comparatives de negoci ([05_vistes_consultes_comparatives.sql](../../bd/sql/05_vistes_consultes_comparatives.sql)).
    - Redacció i estructuració del lliurable [E3_pla_intervencio.md](../E3_pla_intervencio/E3_pla_intervencio.md): pressupostos CapEx/OpEx, matriu d'acompliment de fites amb dates reals i cronograma d'intervenció a camp.
    - Actualització de [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md) documentant formalment la limitació de la rèplica de BD en contenidor dins de `srv-serveis` i la seva mitigació mitjançant `srv-backup`.
    - Adaptació de l'script d'automatització [alta_granja.sh](../../scripts/automatitzacio-granges/alta_granja.sh) per a la variació de la Granja 2 (`10.1.2.0/24`).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

### Sessió 7: Dilluns, 2 de novembre de 2026 (6 hores)
**Fita:** Validació de la Base de Dades a Docker, Resolució de Bugs de Vistes i Ingesta IoT

- **Objectiu:** Posar en funcionament el contenidor `mariadb:10.11` a Docker, verificar l'execució atòmica dels 5 scripts d'`initdb/`, depurar la lògica SQL i alinear el disseny amb la nova Guia de Lliuraments E2-E3 facilitada pel professorat.
- **Treball realitzat:**
  - **Joan:** Verificació de les regles de tallafocs i aïllament de zones; assistència en el diagrama d'entitat-relació i coordinació de la traçabilitat de la xarxa DMZ cap a MariaDB.
  - **Mariam:**
    - Desplegament de `avigest_mariadb` a Docker Compose.
    - Detecció i correcció d'un error de subconsulta no agrupada (`ERROR: subquery uses ungrouped column`) a la vista comparativa `v_resum_diari_climatic`, refactoritzant-la amb un `LEFT JOIN` directe net.
    - Verificació de les 10 taules en 3FN, de les 6 vistes de negoci i validació del trigger `trg_control_llindars_sensor` davant d'una inserció d'estrès tèrmic (35.0 ºC), registrant l'encesa del ventilador a `registre_actuacions` i l'alerta crítica a `alarmes_incidencies`.
    - Incorporació a l'E2 del catàleg traçable de requeriments funcionals R1–R7, justificació formal de la normalització 3FN i taula de freqüències de mostreig IoT (30s clima, 15m sitges).
    - Actualització de les seccions de fonts bibliogràfiques a les 5 fitxes de decisió tècnica (FD01 a FD05).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

## Taula Resum d'Hores Lectives Dedicades

| Sessió | Data | Fase / Fita | Hores Joan | Hores Mariam | Total Sessió |
| :---: | :---: | :--- | :--- :---: | :---: | :---: |
| **S1** | Dilluns 14/09/2026 | Constitució equip i rols (E0) | 6 h | 6 h | **12 h** |
| **S2** | Dilluns 21/09/2026 | Estudi de necessitats i mercat (E1) | 6 h | 6 h | **12 h** |
| **S3** | Dilluns 28/09/2026 | Tancament E1 i preparació diapositives | 6 h | 6 h | **12 h** |
| **S4** | Dilluns 05/10/2026 | Defenses orals E1 (1h 30m prep + 10m defensa + torns companys) | 6 h | 6 h | **12 h** |
| — | Dilluns 12/10/2026 | *FESTIU (Festa Nacional — Sense classe)* | 0 h | 0 h | **0 h** |
| **S5** | Dilluns 19/10/2026 | Investigació, proves de concepte i acords E2 | 6 h | 6 h | **12 h** |
| **S6** | Dilluns 26/10/2026 | Multi-VM (Ubuntu 24.04 + OPNsense), MariaDB 10.11 LTS i avanç E3 | 6 h | 6 h | **12 h** |
| **S7** | Dilluns 02/11/2026 | Validació MariaDB 10.11 Docker, triggers i adaptació guia E2-E3 | 6 h | 6 h | **12 h** |
| **TOTAL** | *(Fins al 02/11)* | **7 dilluns lectius x 6 hores** | **42 h** | **42 h** | **84 h** |

---

## Planificació de Properes Sessions (Camí cap al 4 de Desembre)

D'acord amb el ritme lectiu de 6 hores setmanals, el pla de treball per a les properes sessions de dilluns fins a la data límit oficial de lliurament (4 de desembre) és el següent:

```mermaid
gantt
    title Pla de treball Fase de Disseny (E2 i E3)
    dateFormat  YYYY-MM-DD
    axisFormat  %d/%m
    section Sessions Realitzades
    S1 E0 Constitució        :done, 2026-09-14, 1d
    S2 E1 Treball necessitats :done, 2026-09-21, 1d
    S3 E1 Tancament           :done, 2026-09-28, 1d
    S4 Defenses orals E1      :done, 2026-10-05, 1d
    S5 Investigació i POCs    :done, 2026-10-19, 1d
    S6 Multi-VM i avanç E3    :done, 2026-10-26, 1d
    section Sessions Planificades
    S7 Disseny Xarxa/DMZ i DDL final   :2026-11-02, 1d
    S8 Lògica Triggers i Arbre LDAP     :2026-11-09, 1d
    S9 IoT Edge, Backups i PRD          :2026-11-16, 1d
    S10 Assaig Variació i Tancament E3  :2026-11-23, 1d
    S11 Integració final E2/E3          :2026-11-30, 1d
    Lliurament oficial E2 i E3          :milestone, 2026-12-04, 0d
```

### Detall de les properes sessions lectives:

1. **Sessió 7 (Dilluns, 2 de novembre):**
   - **Joan:** Implementació de la configuració d'interfícies i regles a l'entorn virtual d'OPNsense (`fw-seu`) i proves d'aïllament DMZ.
   - **Mariam:** Validació de la ingesta de dades a MariaDB 10.11 LTS a través del broker MQTT central.

2. **Sessió 8 (Dilluns, 9 de novembre):**
   - **Joan:** Desplegament de l'arbre LDAP a `srv-serveis` i validació d'autenticació per a usuaris de granja i de seu central.
   - **Mariam:** Proves d'estrès dels triggers MariaDB davant d'incidències tèrmiques amb el simulador IoT.

3. **Sessió 9 (Dilluns, 16 de novembre):**
   - **Joan:** Proves de còpia i restauració amb `srv-backup` i validació del segon disc simulat (RTO < 30 min).
   - **Mariam:** Prova de buffer Store-and-Forward a `granja1-srv` davant de desconnexió intencionada del túnel VPN.

4. **Sessió 10 (Dilluns, 23 de novembre):**
   - **Treball conjunt:** Assaig de l'script d'alta ràpida de la Granja 2 (`alta_granja.sh`) per a la prova de variació presencial.
   - Revisió econòmica final i ajust de fites del document **E3 (Pla d'Intervenció i Pressupostos)** avançat a la Sessió 6.

5. **Sessió 11 (Dilluns, 30 de novembre):**
   - **Treball conjunt:** Maquetació, revisió creuada final d'estil i coherència de l'E2 i l'E3, i generació dels PDFs definitius.

6. **Divendres, 4 de desembre de 2026:**
   - **Lliurament oficial dels documents E2 (Disseny Tècnic) i E3 (Pla d'Intervenció) al campus virtual.**

