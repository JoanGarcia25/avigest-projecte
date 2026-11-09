-- =============================================================================
-- AviGest S.L. — Gestió d'Usuaris, Rols i Permisos SQL a MariaDB 10.11 LTS
-- Fitxer: bd/sql/04_usuaris_rols_bd.sql / docker/initdb/04_usuaris_rols_bd.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3: Gestió d'usuaris i rols coherents)
-- Responsable: Mariam / Joan
--
-- Descripció:
-- Aplica el principi de mínim privilegi (Least Privilege) i aïllament multitenant (R3)
-- mitjançant usuaris dedicats i vistes segures de tenant amb variables de sessió.
-- =============================================================================

USE avigest_db;

-- -----------------------------------------------------------------------------
-- 1. USUARI DE L'APLICACIÓ CENTRAL I PORTAL WEB (avigest_app)
-- Gestió global de la plataforma AviGest des de srv-serveis i dmz-web.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_app'@'%' IDENTIFIED BY 'avigest_secret_2026';
CREATE USER IF NOT EXISTS 'avigest_app'@'localhost' IDENTIFIED BY 'avigest_secret_2026';

GRANT ALL PRIVILEGES ON avigest_db.* TO 'avigest_app'@'%';
GRANT ALL PRIVILEGES ON avigest_db.* TO 'avigest_app'@'localhost';

-- -----------------------------------------------------------------------------
-- 2. USUARI DE TELEMETRIA IOT (avigest_iot)
-- Utilitzat pel contenidor d'ingesta MQTT (mqtt_a_mariadb.py).
-- NOMÉS té permís d'INSERT a lectures_sensors i lectura de sensors actius.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_iot'@'%' IDENTIFIED BY 'iot_ingest_pass_2026';
CREATE USER IF NOT EXISTS 'avigest_iot'@'localhost' IDENTIFIED BY 'iot_ingest_pass_2026';

GRANT INSERT, SELECT ON avigest_db.lectures_sensors TO 'avigest_iot'@'%';
GRANT INSERT, SELECT ON avigest_db.lectures_sensors TO 'avigest_iot'@'localhost';

GRANT SELECT (id_sensor, id_nau, actiu, tipus_sensor, llindar_minim, llindar_maxim) ON avigest_db.sensors TO 'avigest_iot'@'%';
GRANT SELECT (id_sensor, id_nau, actiu, tipus_sensor, llindar_minim, llindar_maxim) ON avigest_db.sensors TO 'avigest_iot'@'localhost';

-- Permís per actualitzar actuadors i registrar alertes mitjançant els triggers
GRANT UPDATE (estat_actual) ON avigest_db.actuadors TO 'avigest_iot'@'%';
GRANT INSERT ON avigest_db.registre_actuacions TO 'avigest_iot'@'%';
GRANT INSERT ON avigest_db.alarmes_incidencies TO 'avigest_iot'@'%';

-- -----------------------------------------------------------------------------
-- 3. USUARI DEDICAT DE CÒPIES DE SEGURETAT (avigest_backup)
-- Utilitzat pel servidor de còpies dedicat srv-backup (10.0.20.20) mitjançant mariadb-dump.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_backup'@'%' IDENTIFIED BY 'backup_secret_pass_2026';
CREATE USER IF NOT EXISTS 'avigest_backup'@'localhost' IDENTIFIED BY 'backup_secret_pass_2026';

GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT ON avigest_db.* TO 'avigest_backup'@'%';
GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, EVENT ON avigest_db.* TO 'avigest_backup'@'localhost';

-- -----------------------------------------------------------------------------
-- 4. VISTES D'AÏLLAMENT MULTITENANT (Requeriment R3)
-- A MariaDB, l'aïllament multitenant s'aplica mitjançant vistes parametritzades
-- vinculades a les variables de sessió @app_current_tenant_id i @app_current_granja_id.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_tenant_clients AS
SELECT * FROM clients
WHERE (@app_current_tenant_id IS NULL OR id_client = @app_current_tenant_id);

CREATE OR REPLACE VIEW v_tenant_granges AS
SELECT g.* FROM granges g
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_naus AS
SELECT n.* FROM naus n
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_lots_crianca AS
SELECT l.* FROM lots_crianca l
JOIN naus n ON l.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_sensors AS
SELECT s.* FROM sensors s
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_actuadors AS
SELECT a.* FROM actuadors a
JOIN naus n ON a.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_lectures_sensors AS
SELECT ls.* FROM lectures_sensors ls
JOIN sensors s ON ls.id_sensor = s.id_sensor
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

CREATE OR REPLACE VIEW v_tenant_alarmes_incidencies AS
SELECT al.* FROM alarmes_incidencies al
JOIN naus n ON al.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
WHERE (@app_current_tenant_id IS NULL OR g.id_client = @app_current_tenant_id)
  AND (@app_current_granja_id IS NULL OR g.id_granja = @app_current_granja_id);

-- -----------------------------------------------------------------------------
-- 5. USUARI DE CONSULTA MULTITENANT (avigest_consulta)
-- Utilitzat per veterinaris, tècnics i clients finals.
-- Només pot consultar les vistes aïllades i les vistes analítiques.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'avigest_consulta'@'%' IDENTIFIED BY 'consulta_pass_2026';
CREATE USER IF NOT EXISTS 'avigest_consulta'@'localhost' IDENTIFIED BY 'consulta_pass_2026';

GRANT SELECT ON avigest_db.v_tenant_clients TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_granges TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_naus TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_lots_crianca TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_sensors TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_actuadors TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_lectures_sensors TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_tenant_alarmes_incidencies TO 'avigest_consulta'@'%';

GRANT EXECUTE ON PROCEDURE avigest_db.sp_set_tenant TO 'avigest_consulta'@'%';
GRANT EXECUTE ON PROCEDURE avigest_db.sp_reset_tenant TO 'avigest_consulta'@'%';

FLUSH PRIVILEGES;
