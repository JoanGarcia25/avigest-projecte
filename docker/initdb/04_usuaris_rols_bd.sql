-- =============================================================================
-- AviGest S.L. — Gestió d'Usuaris, Rols i Permisos SQL a MariaDB
-- Fitxer: bd/sql/04_usuaris_rols_bd.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3: Gestió d'usuaris i rols coherents)
-- Responsable: Mariam / Joan
--
-- Descripció:
-- Aplica el principi de mínim privilegi (Least Privilege) a nivell de motor SGBD.
-- Diferencia estrictament els permisos per a l'aplicació web, els sensors IoT
-- de camp, els usuaris de consulta i els processos de còpia de seguretat.
-- =============================================================================

USE avigest_db;

-- -----------------------------------------------------------------------------
-- 1. USUARI / ROL DE L'APLICACIÓ CENTRAL I PORTAL WEB (avigest_app)
-- S'utilitza des de la DMZ (servidor web/API). Té permisos DML ordinaris
-- per gestionar clients, naus, cicles, alarmes i executar procediments.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_app'@'%' IDENTIFIED BY 'avigest_secret_2026';

GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.clients TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.granges TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.naus TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.lots_crianca TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.sensors TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.actuadors TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.lectures_sensors TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.registre_actuacions TO 'avigest_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON avigest_db.alarmes_incidencies TO 'avigest_app'@'%';

-- Permís per executar vistes i procediments emmagatzemats (com l'alta de granja)
GRANT SELECT ON avigest_db.v_resum_granges_avigest TO 'avigest_app'@'%';
GRANT SELECT ON avigest_db.v_estat_actual_sensors TO 'avigest_app'@'%';
GRANT EXECUTE ON PROCEDURE avigest_db.sp_alta_granja_completa TO 'avigest_app'@'%';

-- -----------------------------------------------------------------------------
-- 2. USUARI / ROL DE CAMP I TELEMETRIA IOT (avigest_iot)
-- Clau de seguretat: Aquest usuari és el que fan servir els Gateways de granja
-- o microcontroladors ESP32 quan transmeten lectures per xarxa.
-- NOMÉS té permís per fer INSERT de lectures. Mai pot fer DELETE ni DROP,
-- ni accedir a dades privades de clients ni altres granges.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_iot'@'%' IDENTIFIED BY 'iot_ingest_pass_2026';

-- Només pot escriure lectures de sensors
GRANT INSERT ON avigest_db.lectures_sensors TO 'avigest_iot'@'%';
-- Permís de lectura mínima per validar que el sensor existeix i està actiu
GRANT SELECT (id_sensor, id_nau, actiu) ON avigest_db.sensors TO 'avigest_iot'@'%';

-- -----------------------------------------------------------------------------
-- 3. USUARI / ROL DE CONSULTA I AUDITORIA (avigest_consulta)
-- Utilitzat per veterinaris, inspectors o auditories de consum/benestar animal.
-- Només lectura sobre vistes de resum i dades estadístiques.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_consulta'@'%' IDENTIFIED BY 'consulta_pass_2026';

GRANT SELECT ON avigest_db.v_resum_granges_avigest TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_estat_actual_sensors TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.lots_crianca TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.lectures_sensors TO 'avigest_consulta'@'%';

-- -----------------------------------------------------------------------------
-- 4. USUARI PER A CÒPIES DE SEGURETAT (avigest_backup)
-- Utilitzat per l'script backup_avigest.sh des de localhost o xarxa interna.
-- Disposa dels permisos indispensables per a un buidatge coherent amb mariadb-dump.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_backup'@'localhost' IDENTIFIED BY 'backup_secure_pass_2026';
CREATE USER IF NOT EXISTS 'avigest_backup'@'127.0.0.1' IDENTIFIED BY 'backup_secure_pass_2026';

GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, RELOAD ON avigest_db.* TO 'avigest_backup'@'localhost';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, RELOAD ON avigest_db.* TO 'avigest_backup'@'127.0.0.1';

-- -----------------------------------------------------------------------------
-- 5. Aplicar els canvis de privilegis
-- -----------------------------------------------------------------------------
FLUSH PRIVILEGES;
