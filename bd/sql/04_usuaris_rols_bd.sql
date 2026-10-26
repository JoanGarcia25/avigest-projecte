-- =============================================================================
-- AviGest S.L. — Gestió d'Usuaris, Rols i Permisos SQL a PostgreSQL 16
-- Fitxer: bd/sql/04_usuaris_rols_bd.sql / docker/initdb/04_usuaris_rols_bd.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3: Gestió d'usuaris i rols coherents)
-- Responsable: Mariam / Joan
--
-- Descripció:
-- Aplica el principi de mínim privilegi (Least Privilege) a nivell de PostgreSQL 16.
-- =============================================================================

-- Concedir connexió i ús de l'esquema públic
GRANT CONNECT ON DATABASE avigest_db TO PUBLIC;
GRANT USAGE ON SCHEMA public TO PUBLIC;

-- -----------------------------------------------------------------------------
-- 1. USUARI / ROL DE L'APLICACIÓ CENTRAL I PORTAL WEB (avigest_app)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_app') THEN
        CREATE ROLE avigest_app WITH LOGIN PASSWORD 'avigest_secret_2026';
    END IF;
END $$;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO avigest_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO avigest_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO avigest_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO avigest_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO avigest_app;

-- -----------------------------------------------------------------------------
-- 2. USUARI / ROL DE TELEMETRIA IOT (avigest_iot)
-- NOMÉS té permís per fer INSERT de lectures i lectura de sensors actius.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_iot') THEN
        CREATE ROLE avigest_iot WITH LOGIN PASSWORD 'iot_ingest_pass_2026';
    END IF;
END $$;

GRANT INSERT ON lectures_sensors TO avigest_iot;
GRANT USAGE, SELECT ON SEQUENCE lectures_sensors_id_lectura_seq TO avigest_iot;
GRANT SELECT (id_sensor, id_nau, actiu) ON sensors TO avigest_iot;

-- -----------------------------------------------------------------------------
-- 3. USUARI / ROL DE CONSULTA I AUDITORIA (avigest_consulta)
-- Només lectura sobre vistes estadístiques i lots de criança.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_consulta') THEN
        CREATE ROLE avigest_consulta WITH LOGIN PASSWORD 'consulta_pass_2026';
    END IF;
END $$;

GRANT SELECT ON v_estat_actual_naus TO avigest_consulta;
GRANT SELECT ON v_alarmes_actives TO avigest_consulta;
GRANT SELECT ON lots_crianca TO avigest_consulta;

-- -----------------------------------------------------------------------------
-- 4. USUARI / ROL DEDICAT DE CÒPIES DE SEGURETAT (avigest_backup)
-- Utilitzat pel servidor de còpies dedicat srv-backup (10.0.20.20)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_backup') THEN
        CREATE ROLE avigest_backup WITH LOGIN PASSWORD 'backup_secret_pass_2026';
    END IF;
END $$;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO avigest_backup;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO avigest_backup;
