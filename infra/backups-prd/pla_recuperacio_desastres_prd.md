# Pla de Recuperació davant de Desastres (PRD) — AviGest S.L.

**Mòdul:** ASIX - Projecte (Requeriment 4.5)  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  
**Entorn:** Màquina virtual dedicada `srv-backup` (`10.0.20.20/24`) a la LAN de la seu central  

---

## 1. Objectius del Pla de Contingència (RPO i RTO)

El Pla de Recuperació davant de Desastres (*Disaster Recovery Plan*) d'AviGest defineix els procediments i mètriques objectives per garantir la continuïtat de les operacions de gestió avícola davant d'avaries crítiques de maquinari, corrupció de dades, incendis o ciberatacs.

### 1.1. Mètrica RPO (Recovery Point Objective — Punt de Recuperació Objectiu)
* **Objectiu formal:** **RPO = 24 hores** (Còpia completa diària nocturna a les 02:00 AM).
* **Mitigació addicional gràcies a l'arquitectura de granja:**
  - Com que el gateway de cada gran (`granja1-srv`) disposa de funció **Store-and-Forward** amb búfer local d'emmagatzematge de telemetria durant 72 hores, en cas de restaurar la seu central des de la còpia d'ahir a la nit, els servidors de les granges tornen a sincronitzar automàticament les lectures de les darreres hores. Per tant, l'RPO pràctic de pèrdua de telemetria és **inferior a 1 hora**.

### 1.2. Mètrica RTO (Recovery Time Objective — Temps de Recuperació Objectiu)
* **Objectiu formal:** **RTO ≤ 30 minuts**.
* **Justificació tècnica:**
  - Els serveis centrals a `srv-serveis` estan empaquetats en contenidors Docker declaratius (`docker-compose.yml`).
  - L'arrencada d'un servidor de recanvi des de zero, la descàrrega de les imatges i la injecció dels fitxers `.sql` (PostgreSQL) i `.ldif` (OpenLDAP) mitjançant l'script `restaurar_avigest.sh` requereix **menys de 10 minuts**.

---

## 2. Estratègia de Còpies de Seguretat (Model 3-2-1)

| Paràmetre | Especificació | Justificació |
| :--- | :--- | :--- |
| **Arquitectura de Servidor** | **VM dedicada `srv-backup` (`10.0.20.20/24`)**. | Aïllament físic/virtual respecte al servidor de producció `srv-serveis`. Si cau la VM de serveis, el backup no queda afectat. |
| **Abast de la còpia** | Base de dades PostgreSQL 16 (`avigest_db`) + Directori OpenLDAP (`dc=avigest,dc=cat`) + arxius de configuració. | Còpia integral i coherent de tot l'estat del sistema. |
| **Mètode tècnic** | Buidatge transaccional en calent (`pg_dump`) + exportació d'arbre OpenLDAP (`ldapsearch`/`slapcat`). | No interromp la recepció de telemetria MQTT ni bloqueja consultes web. |
| **Periodicitat** | **Diària, a les 02:00 h AM** (mitjançant `crontab`). | Hora de mínima activitat administrativa a les granges. |
| **Empaquetament** | Fitxer comprimit `backup_avigest_YYYYMMDD_HHMMSS.tar.gz` amb suma de verificació SHA-256. | Garanteix la integritat del fitxer davant de corrupcions de disc. |
| **Ubicació local** | Disc principal de la VM a `/var/backups/avigest/`. | Restauració immediata en cas d'error humà. |
| **Ubicació externa simulada (Off-site)** | **Segon disc virtual independent** muntat a `/mnt/disc-extern-backup/`. | Simula la còpia a una cabina d'emmagatzematge o disc extern aïllat de la fallada del disc primari. |
| **Política de Retenció** | - **7 còpies diàries** (últims 7 dies).<br/>- **4 còpies setmanals** (un mes).<br/>- **12 còpies mensuals** (un any). | Neteja automàtica d'arxius obsolets per evitar omplir el disc. |

---

## 3. Relació entre la Rèplica de BD i el Servidor de Backup

> **Nota Crítica de Disseny (Avaluació i Tribunal):**  
> Al diagrama d'arquitectura, la rèplica de PostgreSQL està configurada com a contenidor secundari dins de `srv-serveis`. Aquesta rèplica protegeix eficaçment davant de caigudes del servei o bloquejos de processos, però **no representa una redundància real de maquinari si cau la màquina virtual sencera**.  
> Per aquest motiu, la continuïtat del negoci descansa sobre la màquina virtual independent **`srv-backup`**, que extreu periòdicament les dades i les desa en un segon disc virtual extern, garantint la restauració total en menys de 30 minuts.

---

## 4. Procediment de Recuperació davant de Desastre (Pas a Pas)

### Escenari de Desastre Total: Destrucció o caiguda completa de `srv-serveis`

1. **Pas 1: Disposar del nou entorn o recuperar la VM**
   - Tenir la màquina `srv-serveis` operativa amb Docker i Docker Compose.

2. **Pas 2: Clonar el repositori del projecte i arrencar els contenidors buits**
   ```bash
   git clone https://github.com/JoanGarcia25/avigest-projecte.git /opt/avigest-projecte
   cd /opt/avigest-projecte/docker
   docker compose up -d
   ```

3. **Pas 3: Recuperar el paquet de seguretat des del segon disc de `srv-backup`**
   ```bash
   # Copiar des del segon disc extern simulat
   cp /mnt/disc-extern-backup/avigest_backups/backup_avigest_ULTIM.tar.gz /tmp/
   ```

4. **Pas 4: Executar l'script de restauració automàtica**
   ```bash
   chmod +x /opt/avigest-projecte/infra/backups-prd/restaurar_avigest.sh
   sudo /opt/avigest-projecte/infra/backups-prd/restaurar_avigest.sh /tmp/backup_avigest_ULTIM.tar.gz
   ```

5. **Pas 5: Verificació del servei restablert**
   - Comprovar els contenidors actius: `docker compose ps`
   - Comprovar les lectures a PostgreSQL:
     ```bash
     docker exec avigest_postgres psql -U avigest_app -d avigest_db -c "SELECT count(*) FROM lectures_sensors;"
     ```
   - Comprovar l'autenticació LDAP:
     ```bash
     docker exec avigest_openldap ldapsearch -x -b "dc=avigest,dc=cat" "(uid=admin_avigest)"
     ```
