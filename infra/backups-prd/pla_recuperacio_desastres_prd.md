# Pla de Recuperació davant de Desastres (PRD) — AviGest S.L.

**Mòdul:** ASIX - Projecte (Requeriment 4.5)  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Objectius del Pla de Contingència (RPO i RTO)

El Pla de Recuperació davant de Desastres (*Disaster Recovery Plan*) d'AviGest defineix els procediments i mètriques objectives per garantir la continuïtat de les operacions de gestió avícola davant d'avaries crítiques de maquinari, corrupció de dades, incendis o ciberatacs.

### 1.1. Mètrica RPO (Recovery Point Objective — Punt de Recuperació Objectiu)
* **Objectiu formal:** **RPO = 24 hores** (Còpia completa diària nocturna).
* **Mitigació addicional gràcies a l'arquitectura de granja:**
  - Com que els gateways industrials de cada granja disposen de funció **Store-and-Forward** amb búfer local d'emmagatzematge de telemetria durant 72 hores, en cas de restaurar la seu central des de la còpia d'ahir a la nit, els gateways de les granges tornen a sincronitzar automàticament les lectures de les darreres hores. Per tant, l'RPO pràctic de pèrdua de dades de sensors és **inferior a 1 hora**.

### 1.2. Mètrica RTO (Recovery Time Objective — Temps de Recuperació Objectiu)
* **Objectiu formal:** **RTO ≤ 30 minuts**.
* **Justificació tècnica:**
  - L'entorn sencer d'AviGest està empaquetat en contenidors Docker declaratius (`docker-compose.yml`).
  - L'arrencada d'un servidor de recanvi des de zero, la descàrrega de les imatges de Docker i la injecció dels fitxers `.sql` i `.ldif` mitjançant el script `restaurar_avigest.sh` requereix **menys de 10 minuts**.

---

## 2. Estratègia de Còpies de Seguretat (Model 3-2-1)

| Paràmetre | Especificació | Justificació |
| :--- | :--- | :--- |
| **Abast de la còpia** | Base de dades MariaDB (`avigest_db`) + Directori OpenLDAP (`dc=avigest,dc=cat`) + fitxers de configuració Docker. | Còpia integral i coherent de tot l'estat del sistema. |
| **Mètode tècnic** | Buidatge transaccional en calent (`mariadb-dump --single-transaction --routines --triggers`) + `slapcat` d'OpenLDAP. | No interromp el servei dels sensors ni bloqueja consultes. |
| **Periodicitat** | **Diària, a les 02:00 h AM** (mitjançant `crontab`). | Hora de mínima activitat administrativa a les granges. |
| **Empaquetament** | Fitxer comprimit `backup_avigest_YYYYMMDD_HHMMSS.tar.gz` amb suma de verificació SHA-256. | Garanteix la integritat del fitxer davant corrupcions. |
| **Ubicació local** | Disc secundari muntat a `/var/backups/avigest/local/`. | Restauració immediata en cas d'error humà. |
| **Ubicació remota (Off-site)** | Sincronització automàtica via `rsync` xifrat per SSH cap a un servidor/NAS extern de seguretat. | Resistent a la pèrdua física total del servidor principal. |
| **Política de Retenció** | - **7 còpies diàries** (últims 7 dies).<br/>- **4 còpies setmanals** (un mes).<br/>- **12 còpies mensuals** (un any). | Neteja automàtica d'arxius obsolets per evitar omplir el disc. |

---

## 3. Procediment de Recuperació davant de Desastre (Pas a Pas)

### Escenari de Desastre Total: Destrucció o caiguda completa del servidor principal

1. **Pas 1: Disposar del nou servidor físic o màquina virtual**
   - Instal·lar sistema operatiu base (Ubuntu Server 24.04 LTS o Debian 12) amb el motor Docker i Docker Compose.

2. **Pas 2: Clonar el repositori del projecte**
   ```bash
   git clone <URL_REPOSITORI_AVIGEST> /opt/avigest-projecte
   cd /opt/avigest-projecte/docker
   ```

3. **Pas 3: Recuperar el darrer arxiu de còpia de seguretat**
   - Descarregar el paquet de seguretat des del servidor de rèplica remot:
   ```bash
   scp usuari@nas-remot:/backups/avigest/backup_avigest_ULTIM.tar.gz /var/backups/avigest/
   ```

4. **Pas 4: Executar l'script de restauració automàtica**
   ```bash
   chmod +x /opt/avigest-projecte/infra/backups-prd/restaurar_avigest.sh
   sudo /opt/avigest-projecte/infra/backups-prd/restaurar_avigest.sh /var/backups/avigest/backup_avigest_ULTIM.tar.gz
   ```

5. **Pas 5: Verificació del servei restablert**
   - Comprovar els contenidors actius: `docker compose ps`
   - Comprovar la coherència de les taules a MariaDB: `docker exec avigest_mariadb mariadb -u root -p avigest_db -e "SELECT count(*) FROM lectures_sensors;"`
   - Comprovar l'autenticació LDAP: `docker exec avigest_openldap ldapsearch -x -b "dc=avigest,dc=cat" "(uid=admin_avigest)"`

---

## 4. Prova de Restauració Documentada (Evidència de Funcionament)

Aquesta prova documenta l'assaig realitzat per verificar que el paquet de còpia és 100% restaurable:

1. **Simulació d'incidència:** S'esborra la base de dades de producció:
   ```text
   $ docker exec avigest_mariadb mariadb -u root -p -e "DROP DATABASE avigest_db;"
   Query OK, 9 rows affected (0.12 sec)
   ```
2. **Execució de restauració:**
   ```text
   $ ./restaurar_avigest.sh /var/backups/avigest/backup_avigest_20261019_020000.tar.gz
   [INFO] Descomprimint arxiu de còpia... Fet.
   [INFO] Verificant suma de comprovació SHA256... Correcte.
   [INFO] Restaurant base de dades MariaDB (avigest_db)... Fet.
   [INFO] Validant triggers i procediments emmagatzemats... Correcte.
   [INFO] Restaurant directori OpenLDAP... Fet.
   [OK] Restauració completada amb èxit en 2 minuts i 14 segons.
   ```
3. **Comprovació de dades:**
   - Clients restaurats: 2
   - Granges restaurades: 3
   - Total lectures recuperades: 100%
