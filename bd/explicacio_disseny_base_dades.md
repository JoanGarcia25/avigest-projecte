# Arquitectura i Justificació del Disseny de la Base de Dades — AviGest S.L.

**Fitxer:** `bd/explicacio_disseny_base_dades.md`  
**Mòdul:** M12 - Projecte d'Administració de Sistemes Informàtics en Xarxa (ASIX)  
**SGBD:** MariaDB 10.11 LTS amb Replicació GTID i Aïllament Multitenant (InnoDB)  
**Autors:** Mariam Solano (Base de Dades, IoT i Automatització) i Joan Garcia (Xarxes, Sistemes i Seguretat)  
**Data:** Novembre de 2026  

---

## 1. Introducció i Objectius de Disseny

El sistema **AviGest S.L.** és una plataforma centralitzada de serveis al núvol (SaaS) dissenyada per a la integració, gestió telemètrica, control ambiental autònom i seguiment productiu d'explotacions avícoles multiclient.

El disseny de la base de dades relacional a **MariaDB 10.11 LTS** respon a quatre grans requeriments arquitectònics:
1. **Modelatge de Domini Avícola Real (3FN):** Separació nítida entre la infraestructura física (granges, naus), els equips de control (sensors, actuadors), el cicle biològic animal (lots de criança d'engreix) i la telemetria.
2. **Dualitat Transaccional vs. Sèrie Temporal (Time-Series):** Convivència d'entitats mestres d'alta consistència ACID amb taules d'ingesta d'alt volum (lectures MQTT) optimitzades per a escriptura ràpida amb motor InnoDB.
3. **Smart Database i Seguretat Autònoma:** Execució de lògica de termòstat i alertes crítiques en temps real mitjançant triggers i procediments MariaDB (`trg_control_llindars_sensor`), garantint temps de resposta de microsegons davant cops de calor sense dependre de la latència de serveis web externs.
4. **Aïllament Multitenant Transparent (Requeriment R3):** Privadesa estricta entre diferents empreses integradores mitjançant vistes segures de tenant (`v_tenant_*`) i variables de sessió (`@app_current_tenant_id`), impedint fugues d'informació entre clients.

---

## 2. Per què exactament 10 Taules? Justificació Entitat per Entitat

El model s'estructura en exactament **10 taules**, dividides lògicament en quatre capes funcionals. Aquest nombre és el resultat d'un procés de normalització en Tercera Forma Normal (3FN), evitant tant la desnormalització amb redundància com la sobreenginyeria innecessària.

```mermaid
graph TD
    subgraph Capa 1: Infraestructura Física i Clients
        C["1. clients"] --> G["2. granges"]
        G --> N["3. naus"]
    end

    subgraph Capa 2: Gestió Zootècnica
        N --> L["4. lots_crianca"]
    end

    subgraph Capa 3: IoT, Telemetria i Automatització
        N --> S["5. sensors"]
        N --> A["6. actuadors"]
        S --> LS["7. lectures_sensors"]
        A --> RA["8. registre_actuacions"]
        S -.->|dispara| RA
    end

    subgraph Capa 4: Seguretat, Alertes i Auditoria
        N --> AL["9. alarmes_incidencies"]
        S -.->|genera| AL
        AU["10. auditoria_canvis"]
    end

    style C fill:#e1f5fe,stroke:#0288d1
    style G fill:#e1f5fe,stroke:#0288d1
    style N fill:#e1f5fe,stroke:#0288d1
    style L fill:#e8f5e9,stroke:#388e3c
    style S fill:#fff3e0,stroke:#f57c00
    style A fill:#fff3e0,stroke:#f57c00
    style LS fill:#fffde7,stroke:#fbc02d
    style RA fill:#fffde7,stroke:#fbc02d
    style AL fill:#ffebee,stroke:#d32f2f
    style AU fill:#f3e5f5,stroke:#7b1fa2
```

---

### Capa 1: Estructura Organitzativa i Física

#### Taula 1: `clients` (Requeriment R1)
* **Què representa:** L'empresa ramadera o integradora jurídica que contracta la plataforma AviGest (ex: *AgroPonent S.L.* o *Avícola del Segrià S.A.*).
* **Per què és una taula independent:** Una integradora posseeix o té sota contracte desenes d'explotacions ramaderes. Si fusionéssim `clients` amb `granges`, el NIF, la raó social, el telèfon i el correu de contacte es repetirien a cada granja, violant la Segona Forma Normal (2FN) i generant anomalies de modificació si l'empresa canvia de seu social o de telèfon.

#### Taula 2: `granges` (Requeriments R1 i R3)
* **Què representa:** L'explotació ramadera física concreta, identificada pel seu codi oficial REGA/explotació ramadera (`ES...`) i la seva ubicació geogràfica (adreça i municipi).
* **Per què és una taula independent:** Separa la personalitat jurídica (`clients`) de la ubicació territorial. Una granja pertany a un únic client (`id_client` és clau forana `ON DELETE RESTRICT`). Aquesta taula constitueix el **pivot fonamental de l'aïllament multitenant (R3)**: tant l'arbre LDAP (`businessCategory`, `departmentNumber`) com les consultes s'articulen al voltant d'aquesta divisió.

#### Taula 3: `naus` (Requeriment R2)
* **Què representa:** Cadascun dels pavellons industrials d'engreix físics que formen la granja. Emmagatzema les dimensions estructurals (`longitud_metres`, `amplada_metres`) i la capacitat màxima de càrrega animal (`capacitat_aus`, ex: 12.000 o 20.000 aus).
* **Per què és una taula independent:** En avicultura intensiva, les granges no són espais unitaris diàfans; estan formades per diverses naus (entre 1 i 10+) que operen de forma totalment independent. La temperatura, el cicle de criança i els equips de ventilació es gestionen **a nivell de nau**, mai a nivell global de granja. Disposa d'una clau única composta `uq_granja_codinau (id_granja, codi_nau)` per garantir que el codi `NAU-01` sigui únic dins de cada granja però reutilitzable entre explotacions.

---

### Capa 2: Gestió Zootècnica i Cicle de Vida Productiu

#### Taula 4: `lots_crianca` (Requeriment R6)
* **Què representa:** El cicle biològic d'engreix d'una tongada de pollastres (~45 dies), des de la recepció de pollets d'un dia de vida fins al buidat sanitari i transport a l'escorxador.
* **Per què és una taula independent de `naus`:** Una nau és un actiu immoble permanent amb una vida útil de dècades. En canvi, un lot és un esdeveniment biològic temporal amb data d'inici i de final. Al llarg d'un any, una nau allotja entre 5 i 6 lots consecutius (amb períodes de buit sanitari de 10 a 14 dies entre ells). Unir nau i lot faria impossible guardar l'històric d'explotació o comparar l'evolució entre tongades d'estiu i d'hivern.
* **Per què conté mètriques de rendiment (`num_baixes`, `pes_mitja_kg`, `pinso_consumit_kg`):** Permet calcular els dos indicadors clau de rendibilitat avícola:
  1. **Percentatge de mortalitat:** $\frac{\text{baixes}}{\text{aus inicials}} \times 100$.
  2. **Índex de Conversió Alimentària (ICA / FCR):** $\text{ICA} = \frac{\text{kg pinso consumits}}{\text{kg carn produïts}}$.

---

### Capa 3: Sensòrica, Telemetria i Control Automatitzat (IoT Engine)

#### Taula 5: `sensors` (Requeriment R4 i 4.8)
* **Què representa:** El catàleg d'instruments de mesura instal·lats a cada nau: tipus (`temperatura`, `humitat`, `co2`, `pes_silo`, `llum`, `consum_aigua`, `amoniac`), tecnologia de comunicació (`RS485` Modbus RTU per a l'interior cablejat, `LoRaWAN` per a silos exteriors sense fil), unitat i llindars de treball (`llindar_minim`, `llindar_maxim`).
* **Per què és independent de `lectures_sensors`:** Aplica la 3FN estricta. El tipus de sensor, la tecnologia, la unitat de mesura i els llindars d'alarma són metadades estàtiques del dispositiu. Si aquestes dades es guardessin a cada lectura periòdica de camp, la base de dades patiria un malbaratament massiu d'emmagatzematge.

#### Taula 6: `actuadors` (Requeriment R5)
* **Què representa:** La maquinària electromecànica instal·lada a la nau per alterar el clima o alimentar els animals (`ventilador`, `calefactor`, `il_luminacio`, `menjadora`, `bomba_aigua`, `alarma_sonora`, `nebulitzador`), el seu mode d'operació (`automatic`, `manual`, `aturat`) i el seu estat en temps real (`ON`, `OFF`).
* **Per què és independent de `sensors`:** Separa clarament els **dispositius d'entrada** dels **dispositius de sortida**. La relació entre sensor i actuador no és un cablejat físic 1:1, sinó una regla lògica programada a la base de dades mitjançant triggers.

#### Taula 7: `lectures_sensors` (Requeriments R4 i R5)
* **Què representa:** Sèrie temporal (*Time-Series*) d'altíssim volum on s'enregistren totes les dades telemètriques enviades des del camp a través de la passarel·la MQTT.
* **Per què té un disseny hiperminimalista (`id_sensor`, `valor`, `data_hora`):** En un entorn de producció amb centenars de naus transmetent contínuament, aquesta taula acumula milions de registres. Mantenir una estructura estricta de 3 columnes optimitza la velocitat d'escriptura a disc (`INSERT`), redueix l'espai d'índexs i permet aprofitar al màxim la memòria cau InnoDB de MariaDB.

#### Taula 8: `registre_actuacions` (Requeriment R5)
* **Què representa:** El registre cronològic de caixa negra de cada commutació d'actuador (`ON` o `OFF`), indicant el motiu textual de l'acció i el sensor concret que l'ha disparada.

---

### Capa 4: Gestió d'Incidències, Seguretat i Auditoria

#### Taula 9: `alarmes_incidencies` (Requeriment R7)
* **Què representa:** Les incidències crítiques i avisos disparats de forma autònoma quan es detecten anomalies perilloses (cop de calor $\ge 33^\circ\text{C}$, risc d'hipotèrmia $\le 16^\circ\text{C}$, concentració perillosa de $\text{CO}_2 \ge 3000\text{ ppm}$, silo buit $\le 500\text{ kg}$).
* **Cicle de vida:** Té un flux de resolució (`resolta = FALSE` $\rightarrow$ `resolta = TRUE`, `data_resolucio`, `observacions_resolucio`) gestionat mitjançant el procediment `sp_resoldre_alarma()`.

#### Taula 10: `auditoria_canvis` (Requeriment 4.3 / E2 Secció 7.2)
* **Què representa:** Pista d'auditoria immutable (*Change Data Capture*) que registra operacions DML (`INSERT`, `UPDATE`, `DELETE`) sobre les taules mestres de configuració (`clients`, `granges`, `naus`, `lots_crianca`, `sensors`, `actuadors`).
* **Per què s'utilitza JSON (`dades_antigues`, `dades_noves`):** Permet capturar l'estat complet de qualsevol fila abans i després de la modificació mitjançant `JSON_OBJECT()` sense necessitat de crear taules duplicades. Registra a més l'usuari SQL connectat (`CURRENT_USER()`) i la marca de temps.

---

## 3. Integritat Referencial i Estratègies d'Esborrat (Foreign Keys)

L'esquema aplica regles estrictes de claus foranes InnoDB:

| Relació Clau Forana | Estratègia | Justificació Tècnica i de Negoci |
| :--- | :---: | :--- |
| `granges` $\rightarrow$ `clients` | **`ON DELETE RESTRICT`** | Impedeix esborrar accidentalment una empresa client si té granges actives assignades. |
| `naus` $\rightarrow$ `granges` | **`ON DELETE CASCADE`** | Si s'elimina una granja de prova, s'eliminen automàticament les seves naus associades. |
| `lots_crianca` $\rightarrow$ `naus` | **`ON DELETE RESTRICT`** | Protecció legal sanitària: **mai** es pot esborrar una nau si conté l'històric de cicles d'engreix (traçabilitat alimentària UE). |
| `sensors` $\rightarrow$ `naus` | **`ON DELETE CASCADE`** | Els sensors pertanyen a l'estructura física de la nau. |
| `actuadors` $\rightarrow$ `naus` | **`ON DELETE CASCADE`** | Els actuadors pertanyen a l'estructura física de la nau. |
| `lectures_sensors` $\rightarrow$ `sensors` | **`ON DELETE CASCADE`** | Si s'elimina un sensor de test, s'esborren les seves lectures vinculades. |
| `registre_actuacions` $\rightarrow$ `sensors` | **`ON DELETE SET NULL`** | Si es canvia o substitueix un sensor físic avariat, **no es perd l'històric** d'activacions passades de ventiladors. |
| `alarmes_incidencies` $\rightarrow$ `sensors` | **`ON DELETE SET NULL`** | Preserva la traçabilitat de la incidència històrica encara que la sonda física hagi estat donada de baixa. |

---

## 4. Lògica Procedural MariaDB: Smart Database vs. Lògica d'Aplicació

A AviGest, la base de dades és un **motor actiu d'automatització**:

### 4.1. Termòstat Automàtic en Temps Real (`trg_control_llindars_sensor`)
En avicultura intensiva a l'estiu a les comarques de Lleida, un cop de calor a la nau pot elevar la temperatura per sobre dels $34^\circ\text{C}$.
* **Execució en microsegons:** En el moment que el servei MQTT fa l'`INSERT` a `lectures_sensors`, el trigger s'executa immediatament al motor InnoDB:
  - Si $T > 31^\circ\text{C}$: commuta `actuadors.estat_actual = 'ON'`, apaga calefacció i insereix registre d'actuació. Si $T \ge 33^\circ\text{C}$, genera alarma crítica.
  - Si $T < 20^\circ\text{C}$: commuta calefacció a `ON` i apaga ventilació. Si $T \le 16^\circ\text{C}$, genera alarma crítica per hipotèrmia.
  - Si $20^\circ\text{C} \le T \le 31^\circ\text{C}$: apaga ventiladors i calefactors per estalvi energètic.
  - Cobreix també renovació d'aire per $\text{CO}_2$ ($> 2500\text{ ppm}$) i silos buits ($\le 500\text{ kg}$).

### 4.2. Provisió Atòmica d'Infraestructura (`sp_alta_granja_completa`)
Invocat directament des de l'script d'automatització bash [`alta_granja.sh`](file:///c:/avigest-projecte/scripts/automatitzacio-granges/alta_granja.sh):
* Dins d'una **única transacció ACID** (`START TRANSACTION ... COMMIT`), crea la granja, les naus, els 4 sensors estàndard i els actuadors bàsics.
* Si qualsevol pas falla, el gestor d'errors executa un `ROLLBACK` total.

---

## 5. Aïllament Multitenant Transparent (Requeriment R3)

L'aïllament multitenant a MariaDB s'aconsegueix mitjançant el conjunt de **vistes segures parametritzades** (`v_tenant_*`) i les variables de sessió `@app_current_tenant_id` i `@app_current_granja_id`:

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuari / Veterinari
    participant MDB as MariaDB 10.11
    participant V as Vistes Tenant (v_tenant_*)
    participant T as Taules InnoDB

    U->>MDB: Connexió amb usuari 'avigest_consulta'
    U->>MDB: CALL sp_set_tenant(1, NULL); (AgroPonent)
    Note over MDB: Estableix @app_current_tenant_id = 1
    U->>MDB: SELECT * FROM v_tenant_granges;
    MDB->>V: Avalua condició id_client = 1
    V->>T: Executa SELECT filtrat
    T-->>U: Retorna només: Bellpuig i Mollerussa (Client 1)
```

---

## 6. Usuaris SQL de Mínim Privilegi (Least Privilege - Requeriment 4.3)

S'han separat estrictament les funcions del sistema en 4 usuaris SQL independents:

```mermaid
graph TD
    subgraph Servidor MariaDB 10.11
        APP["avigest_app<br/>(Administració / Portal Web)"]
        IOT["avigest_iot<br/>(Ingesta MQTT mqtt_a_mariadb.py)"]
        BAK["avigest_backup<br/>(mariadb-dump srv-backup)"]
        CON["avigest_consulta<br/>(Clients / Auditors / Vistes Tenant)"]
    end

    APP -->|ALL PRIVILEGES| ALL[Totes les taules i procediments]
    IOT -->|Només INSERT| LS[lectures_sensors]
    IOT -->|Només SELECT| S_ID[sensors: id_sensor, llindars]
    BAK -->|Només SELECT + LOCK| DUMP[Bolcat complet de suport]
    CON -->|SELECT filtrat| VIEWS[v_tenant_* i vistes analítiques]
```

1. **`avigest_app`:** Usuari de gestió global del portal central i aplicació.
2. **`avigest_iot`:** Utilitzat exclusivament pel servei d'ingesta MQTT (`mqtt_a_mariadb.py`). Només pot fer `INSERT` a `lectures_sensors` i `SELECT` a identificadors de sensors.
3. **`avigest_backup`:** Utilitzat pel servidor dedicat `srv-backup` (`10.0.20.20`) mitjançant `mariadb-dump`. Disposa de permisos de lectura transaccional (`--single-transaction`).
4. **`avigest_consulta`:** Usuari limitat per a veterinaris, auditors i clients. Només pot consultar les vistes aïllades de tenant i executar `sp_set_tenant()`.

---

## 7. Consultes i Vistes Comparatives de Negoci (Requeriment 4.3)

El fitxer [`05_vistes_consultes_comparatives.sql`](file:///c:/avigest-projecte/bd/sql/05_vistes_consultes_comparatives.sql) proporciona les 4 eines analítiques clau del negoci:

1. **`v_comparativa_lots_rendiment` (R6):** Compara mortalitat, durada del cicle amb `DATEDIFF`, quilos totals de carn produïts i l'Índex de Conversió Alimentària (ICA).
2. **`v_resum_diari_climatic` (R4):** Agrupa diàriament el valor mitjà, mínim i màxim de cada variable ambiental juntament amb el recompte d'alarmes per nau.
3. **`v_estat_silos_gra` (R4 i R7):** Monitoratge d'estoc de pinso als silos amb diagnòstics preventius (`ÒPTIM`, `ATENCIÓ: Nivell baix`, `AVÍS: Demanar pinso urgentment`, `CRÍTIC: Silo buit`).
4. **`v_panell_executiu_global` (R1 i R3):** Panell executiu que mostra a la direcció el recompte de granges actives, naus en producció, aus en criança i alertes crítiques pendents.

---

## 8. Matriu de Traçabilitat de Requeriments Oficials

| Requeriment Oficial | Descripció de l'Enunciat | Taules, Triggers o Procediments Implicats | Fitxer SQL de Referència |
| :--- | :--- | :--- | :--- |
| **R1** | Gestió de dades de granges i clients | `clients`, `granges` | [`01_esquema.sql`](file:///c:/avigest-projecte/bd/sql/01_esquema.sql) |
| **R2** | Dades individuals per nau (dimensions, capacitat) | `naus` (clau única composta `id_granja, codi_nau`) | [`01_esquema.sql`](file:///c:/avigest-projecte/bd/sql/01_esquema.sql) |
| **R3** | Aïllament de dades multitenant i privadesa | Vistes `v_tenant_*`, `sp_set_tenant()`, `sp_reset_tenant()` | [`04_usuaris_rols_bd.sql`](file:///c:/avigest-projecte/bd/sql/04_usuaris_rols_bd.sql) |
| **R4** | Telemetria ambiental i control de silos | `sensors` (RS485/LoRaWAN), `lectures_sensors`, `v_estat_silos_gra` | [`01_esquema.sql`](file:///c:/avigest-projecte/bd/sql/01_esquema.sql) i [`05_vistes_consultes_comparatives.sql`](file:///c:/avigest-projecte/bd/sql/05_vistes_consultes_comparatives.sql) |
| **R5** | Automatització d'actuadors (termòstat) | `actuadors`, `registre_actuacions`, trigger `trg_control_llindars_sensor` | [`02_triggers_procedures.sql`](file:///c:/avigest-projecte/bd/sql/02_triggers_procedures.sql) |
| **R6** | Cicle de vida de lots i indicadors de rendiment | `lots_crianca`, vista `v_comparativa_lots_rendiment` (ICA) | [`01_esquema.sql`](file:///c:/avigest-projecte/bd/sql/01_esquema.sql) i [`05_vistes_consultes_comparatives.sql`](file:///c:/avigest-projecte/bd/sql/05_vistes_consultes_comparatives.sql) |
| **R7** | Gestió d'alertes i incidències | `alarmes_incidencies`, trigger `trg_control_llindars_sensor`, `sp_resoldre_alarma()` | [`02_triggers_procedures.sql`](file:///c:/avigest-projecte/bd/sql/02_triggers_procedures.sql) |
| **4.3** | Base de dades centralitzada, rols i vistes | 4 usuaris de mínim privilegi, rèplica MariaDB, triggers d'auditoria JSON, 4 vistes de negoci | [`00_replicacio.sql`](file:///c:/avigest-projecte/docker/initdb/00_replicacio.sql), [`04_usuaris_rols_bd.sql`](file:///c:/avigest-projecte/bd/sql/04_usuaris_rols_bd.sql), [`05_vistes_consultes_comparatives.sql`](file:///c:/avigest-projecte/bd/sql/05_vistes_consultes_comparatives.sql) |
| **4.7** | Automatització de creació de noves granges | Procediment atòmic `sp_alta_granja_completa()` vinculat amb `alta_granja.sh` | [`02_triggers_procedures.sql`](file:///c:/avigest-projecte/bd/sql/02_triggers_procedures.sql) i [`alta_granja.sh`](file:///c:/avigest-projecte/scripts/automatitzacio-granges/alta_granja.sh) |
