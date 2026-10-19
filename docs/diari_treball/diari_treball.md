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
**Darrera actualització:** Dilluns, 19 d'octubre de 2026  

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

### Sessió 5: Dilluns, 19 d'octubre de 2026 (6 hores — AVUI)
**Fita:** Investigació de solucions, primeres proves de concepte (POC) i acords de disseny

- **Objectiu:** Aprofundir en les fitxes de decisió, fer proves tècniques preliminars de laboratori i consensuar el model conceptual de dades i usuaris.
- **Treball realitzat durant les 6 hores:**
  - **Joan (3h):**
    - Redacció de l'esborrany de la fitxa [FD02_ldap.md](../fitxes_decisio/FD02_ldap.md): comparació d'OpenLDAP vs Samba 4 (consum de RAM, facilitat d'automatització amb LDIF i compliment dels 4 rols d'usuaris requerits).
    - Investigació sobre la segmentació perimetral: esquema de DMZ per aïllar la base de dades d'Internet ([FD03_tallafocs_dmz.md](../fitxes_decisio/FD03_tallafocs_dmz.md)).
    - Estudi de maquinari de servidor central per a entorns virtualitzats (necessitat de discs RAID i doble font d'alimentació).
  - **Mariam (3h):**
    - Redacció de l'esborrany de la fitxa [FD01_sgbd.md](../fitxes_decisio/FD01_sgbd.md): comparació de MariaDB 10.11 LTS vs PostgreSQL i SQLite (simplicitat, facilitat d'administració i suport natiu de triggers).
    - Proves de concepte SQL en local: definició conceptual de les primeres entitats (clients, granges, naus, sensors i actuadors).
    - Investigació sobre protocols de comunicació de camp: avantatges de cablejar RS485 a l'interior de les naus vs LoRaWAN per a sitges exteriors ([FD05_iot_comunicacions.md](../fitxes_decisio/FD05_iot_comunicacions.md)).
  - **Treball conjunt (3h):**
    - Debat i acord clau sobre l'**aïllament multiclient**: hem acordat fer servir l'atribut LDAP `businessCategory: CLIENT_<ID>` vinculat directament amb la clau forana `id_client` a la base de dades.
    - Definició de l'estructura del document [E2_document_disseny_tecnic.md](../E2_disseny_tecnic/E2_document_disseny_tecnic.md).
    - Redacció i posada al dia d'aquest [diari_treball.md](diari_treball.md).
- **Dedicació:** Joan: 6 h | Mariam: 6 h (Total: 12 h)

---

## Taula Resum d'Hores Lectives Dedicades

| Sessió | Data | Fase / Fita | Hores Joan | Hores Mariam | Total Sessió |
| :---: | :---: | :--- | :---: | :---: | :---: |
| **S1** | Dilluns 14/09/2026 | Constitució equip i rols (E0) | 6 h | 6 h | **12 h** |
| **S2** | Dilluns 21/09/2026 | Estudi de necessitats i mercat (E1) | 6 h | 6 h | **12 h** |
| **S3** | Dilluns 28/09/2026 | Tancament E1 i preparació diapositives | 6 h | 6 h | **12 h** |
| **S4** | Dilluns 05/10/2026 | Defenses orals E1 (1h 30m prep + 10m defensa + torns companys) | 6 h | 6 h | **12 h** |
| — | Dilluns 12/10/2026 | *FESTIU (Festa Nacional — Sense classe)* | 0 h | 0 h | **0 h** |
| **S5** | Dilluns 19/10/2026 | Investigació, proves de concepte i acords E2 | 6 h | 6 h | **12 h** |
| **TOTAL** | *(Fins al 19/10)* | **5 dilluns lectius x 6 hores** | **30 h** | **30 h** | **60 h** |

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
    S5 Investigació i POCs    :active, 2026-10-19, 1d
    section Sessions Planificades
    S6 Fitxes decisió i Model ER       :2026-10-26, 1d
    S7 Disseny Xarxa/DMZ i DDL preliminar :2026-11-02, 1d
    S8 Lògica Triggers i Arbre LDAP     :2026-11-09, 1d
    S9 IoT Edge, Backups i PRD          :2026-11-16, 1d
    S10 Pla Intervenció E3 i Scripts    :2026-11-23, 1d
    S11 Integració final E2/E3          :2026-11-30, 1d
    Lliurament oficial E2 i E3          :milestone, 2026-12-04, 0d
```

### Detall de les properes sessions lectives:

1. **Sessió 6 (Dilluns, 26 d'octubre):**
   - **Joan:** Completar la fitxa FD04 (Còpies de seguretat i PRD: Scripts Bash vs Borg vs Bacula) i dimensionament del maquinari de granges (armaris IP66 i passius *fanless*).
   - **Mariam:** Completar el diagrama conceptual del Model Entitat-Relació a [model_er.md](../../bd/model-er/model_er.md) i documentar la justificació de tipus de dades (BIGINT per a lectures de sensors).

2. **Sessió 7 (Dilluns, 2 de novembre):**
   - **Joan:** Disseny de la topologia de xarxa en 3 zones (WAN / DMZ / LAN) i primer esborrany de la política de tallafocs amb llista blanca de clients.
   - **Mariam:** Redacció de l'esborrany de l'esquema relacional DDL (taules `clients`, `granges`, `naus`, `sensors`, `actuadors`, etc.).

3. **Sessió 8 (Dilluns, 9 de novembre):**
   - **Joan:** Disseny de la jerarquia d'unitats organitzatives a OpenLDAP i definició dels 4 grups d'usuaris (`AdminsAviGest`, `AdminsClient`, `GestorsGranja`, `UsuarisConsulta`).
   - **Mariam:** Disseny dels automatismes a la base de dades: definició teòrica dels llindars ambientals i funcionament del trigger davant d'incidències tèrmiques o d'aire.

4. **Sessió 9 (Dilluns, 16 de novembre):**
   - **Joan:** Disseny de la política de còpies de seguretat 3-2-1 i definició dels objectius de RTO i RPO davant de caigudes.
   - **Mariam:** Disseny de l'arquitectura de comunicacions IoT: flux de dades des de l'ESP32 fins a la central i especificació del maquinari de camp.

5. **Sessió 10 (Dilluns, 23 de novembre):**
   - **Treball conjunt:** Inici del document **E3 (Pla d'Intervenció)**: planificació d'implantació, recursos necessaris, pressupost estimat i cronograma per a la fase d'execució.
   - Disseny del procediment d'alta ràpida de granges (especificació de l'script requerit a la prova presencial).

6. **Sessió 11 (Dilluns, 30 de novembre):**
   - **Treball conjunt:** Integració final de tots els apartats al document mestre [E2_document_disseny_tecnic.md](../E2_disseny_tecnic/E2_document_disseny_tecnic.md), revisió creuada de coherència entre xarxa i base de dades, i maquetació per al lliurament oficial.

7. **Divendres, 4 de desembre de 2026:**
   - **Lliurament oficial dels documents E2 (Disseny Tècnic) i E3 (Pla d'Intervenció).**
