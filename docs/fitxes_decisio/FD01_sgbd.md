# Fitxa de Decisió Tècnica — FD01: Sistema Gestor de Base de Dades (SGBD)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.3 i 4.6)  
**Data:** Actualitzat a novembre de 2026  
**Responsable:** Mariam / Joan  

---

## 1. Descripció de la necessitat
El sistema centralitzat d'AviGest a `srv-serveis` requereix un SGBD relacional robust per emmagatzemar:
- Dades estructurades de clients, granges, naus i cicles de criança (model multitenant).
- Sèries temporals de lectures IoT d'alta freqüència (temperatura, humitat, CO2, nivell de silos).
- Triggers per al control automàtic d'actuadors i generació immediata d'alarmes.
- Suport natiu de **rèplica de dades** per garantir la redundància i alta disponibilitat (Requeriment 4.6).

---

## 2. Alternatives avaluades

### Alternativa 1: MariaDB (10.11 LTS) — (Escollida)
* **Descripció:** SGBD relacional de referència al cicle de CFGS ASIX (M02 Bases de Dades), de codi obert i totalment compatible amb l'ecosistema Linux de producció.
* **Pros:**
  - **Estàndard docent i tecnològic ASIX:** És el motor oficial utilitzat als mòduls de bases de dades i administració de servidors a l'Institut Mollerussa.
  - **Rendiment transaccional InnoDB:** Motor d'emmagatzematge ACID amb bloqueig per fila, claus foranes estrictes i integritat referencial en cascada.
  - **Automatismes procedimentals complets:** Suport natiu de triggers (`BEFORE`/`AFTER INSERT/UPDATE/DELETE`), procediments emmagatzemats amb gestió de transaccions i funcions definides per l'usuari.
  - **Suport JSON nadiu:** Permet registrar instantànies d'auditoria DML amb `JSON_OBJECT()` sense necessitat d'extensions externes.
  - **Replicació d'alta fiabilitat (GTID):** Replicació binlog primary-replica mitjançant identificadors de transacció globals (*Global Transaction IDs*).
  - **Lleuger i eficient:** Consum òptim de memòria RAM a la màquina virtual `srv-serveis`.
* **Contres:**
  - L'aïllament multitenant s'implementa mitjançant vistes segures i variables de sessió en comptes de RLS integrat al motor.

### Alternativa 2: PostgreSQL 16 (Descartada)
* **Descripció:** SGBD relacional avançat d'objectes.
* **Motiu de descart:** Tot i la seva potència, introdueix complexitats de sintaxi i administració innecessàries que s'aparten de l'estàndard docent del cicle ASIX (on tot l'aprenentatge i eines es fonamenten en MariaDB/MySQL).

### Alternativa 3: SQLite3 (Descartada)
* **Descripció:** Base de dades embeguda en fitxer local.
* **Motiu de descart:** Inadequada per a la seu central amb múltiples connexions concurrents d'ingesta IoT i usuaris de consulta.

---

## 3. Decisió presa
**S'escull MariaDB 10.11 LTS amb motor InnoDB i suport de rèplica.**

### Justificació:
1. **Coherència formativa i de projecte:** MariaDB és el motor de base de dades vehicular d'ASIX. Tota la infraestructura, scripts d'ingesta i eines de còpia (`mariadb-dump`) són directament defensables davant del tribunal.
2. **Capacitat d'ingesta IoT i triggers:** Els triggers InnoDB gestionen eficaçment les alertes i activació de ventiladors en temps real.
3. **Redundància i Rèplica (Requeriment 4.6):**
   > **Nota d'arquitectura sobre la Rèplica de Base de Dades:**  
   > En el laboratori virtual, la rèplica de MariaDB està configurada com a contenidor secundari dins de la màquina virtual `srv-serveis` (port 3307).  
   > Protegeix el servei davant la caiguda del procés primari mitjançant replicació GTID.  
   > La protecció davant la caiguda física de la VM o pèrdua de disc queda coberta pel servidor dedicat independent **`srv-backup`** (`10.0.20.20`), amb còpies transaccionals comprimides i segon disc virtual muntat (RTO < 30 minuts).

---

## 4. Mètode de verificació
- **Desplegament en Docker:** Contenidor `mariadb:10.11` a la màquina `srv-serveis` (LAN: `10.0.20.0/24`, port `3306`).
- **Validació de triggers:** Inserció d'una lectura de temperatura a `lectures_sensors` disparant automàticament l'activació de ventilador a `actuadors` i la inserció d'alarma a `alarmes_incidencies`.
- **Rèplica GTID:** Comprovació amb `SHOW SLAVE STATUS\G` al contenidor `avigest_mariadb_replica` (verificant `Slave_IO_Running: Yes` i `Slave_SQL_Running: Yes`).
- **Aïllament Multitenant:** Connexió amb l'usuari `avigest_consulta`, execució de `CALL sp_set_tenant(1, NULL)` i comprovació que només es visualitzen les granges del Client 1 a `v_tenant_granges`.
- **Ingesta MQTT:** Publicació al topic `avigest/granja1/telemetria/temperatura` i comprovació de la nova fila persistida a `lectures_sensors`.

---

## 5. Fonts consultades
- Documentació oficial de MariaDB 10.11 LTS: *Setting Up Replication with GTID* — [https://mariadb.com/kb/en/gtid/](https://mariadb.com/kb/en/gtid/)
- Documentació oficial de MariaDB: *InnoDB Storage Engine Overview* — [https://mariadb.com/kb/en/innodb/](https://mariadb.com/kb/en/innodb/)
- Currículum oficial del Cicle Formatiu de Grau Superior ASIX (Departament d'Educació de la Generalitat de Catalunya) — Mòdul M02 Bases de Dades.
- Imatge oficial de MariaDB a Docker Hub: [https://hub.docker.com/_/mariadb](https://hub.docker.com/_/mariadb)
