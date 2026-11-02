-- =============================================================================
-- AviGest S.L. — Gestió d'Usuaris, Rols i Permisos SQL a PostgreSQL 16
-- Fitxer: bd/sql/04_usuaris_rols_bd.sql / docker/initdb/04_usuaris_rols_bd.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3: Gestió d'usuaris i rols coherents)
-- Responsable: Mariam / Joan
--
-- Descripció:
-- Aplica el principi de mínim privilegi (Least Privilege) i aïllament multitenant (R3)
-- mitjançant Row-Level Security (RLS) nadiu a PostgreSQL 16.
-- =============================================================================

-- Concedir connexió a la base de dades i resolució d'esquema públic
GRANT CONNECT ON DATABASE avigest_db TO PUBLIC;
GRANT USAGE ON SCHEMA public TO PUBLIC;

-- -----------------------------------------------------------------------------
-- 1. USUARI / ROL DE L'APLICACIÓ CENTRAL I PORTAL WEB (avigest_app)
-- Rol d'administració i gestió global de la plataforma AviGest.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_app') THEN
        CREATE ROLE avigest_app WITH LOGIN PASSWORD 'avigest_secret_2026';
    END IF;
END $$;

ALTER ROLE avigest_app BYPASSRLS;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO avigest_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO avigest_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO avigest_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO avigest_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO avigest_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO avigest_app;

-- -----------------------------------------------------------------------------
-- 2. USUARI / ROL DE TELEMETRIA IOT (avigest_iot)
-- Utilitzat pel contenidor d'ingesta MQTT (mqtt_a_postgres.py).
-- NOMÉS té permís per fer INSERT de lectures i consultar identificadors de sensors.
-- Té BYPASSRLS per poder ingerir dades de qualsevol granja sense restricció de sessió.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_iot') THEN
        CREATE ROLE avigest_iot WITH LOGIN PASSWORD 'iot_ingest_pass_2026';
    END IF;
END $$;

ALTER ROLE avigest_iot BYPASSRLS;
GRANT INSERT ON lectures_sensors TO avigest_iot;
GRANT USAGE, SELECT ON SEQUENCE lectures_sensors_id_lectura_seq TO avigest_iot;
GRANT SELECT (id_sensor, id_nau, actiu) ON sensors TO avigest_iot;

-- -----------------------------------------------------------------------------
-- 3. USUARI / ROL DEDICAT DE CÒPIES DE SEGURETAT (avigest_backup)
-- Utilitzat pel servidor de còpies dedicat srv-backup (10.0.20.20) mitjançant pg_dump.
-- Disposa de BYPASSRLS per poder bolcar totes les dades del clúster complet.
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_backup') THEN
        CREATE ROLE avigest_backup WITH LOGIN PASSWORD 'backup_secret_pass_2026';
    END IF;
END $$;

ALTER ROLE avigest_backup BYPASSRLS;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO avigest_backup;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO avigest_backup;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO avigest_backup;

-- -----------------------------------------------------------------------------
-- 4. USUARI / ROL DE CONSULTA MULTITENANT (avigest_consulta)
-- Utilitzat per consultors, veterinaris i clients finals.
-- Està estrictament sotmès a Row-Level Security (RLS). Sense executar prèviament
-- `SELECT sp_set_tenant(client_id)` o `SELECT sp_set_tenant(client_id, granja_id)`
-- NO veu cap fila de dades de cap explotació (aïllament total R3 per defecte).
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'avigest_consulta') THEN
        CREATE ROLE avigest_consulta WITH LOGIN PASSWORD 'consulta_pass_2026';
    END IF;
END $$;

ALTER ROLE avigest_consulta NOBYPASSRLS;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO avigest_consulta;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO avigest_consulta;

GRANT EXECUTE ON FUNCTION sp_set_tenant(INT, INT) TO avigest_consulta;
GRANT EXECUTE ON FUNCTION sp_reset_tenant() TO avigest_consulta;
GRANT EXECUTE ON FUNCTION fn_current_tenant_id() TO avigest_consulta;
GRANT EXECUTE ON FUNCTION fn_current_granja_id() TO avigest_consulta;

-- -----------------------------------------------------------------------------
-- 5. CONFIGURACIÓ DE ROW-LEVEL SECURITY (RLS) MULTITENANT (Requeriment R3)
-- -----------------------------------------------------------------------------

-- Activació d'RLS a totes les taules mestres i transaccionals
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE granges ENABLE ROW LEVEL SECURITY;
ALTER TABLE naus ENABLE ROW LEVEL SECURITY;
ALTER TABLE lots_crianca ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE actuadors ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures_sensors ENABLE ROW LEVEL SECURITY;
ALTER TABLE registre_actuacions ENABLE ROW LEVEL SECURITY;
ALTER TABLE alarmes_incidencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria_canvis ENABLE ROW LEVEL SECURITY;

-- 5.1. Polítiques RLS per a CLIENTS
DROP POLICY IF EXISTS rls_clients_consulta ON clients;
CREATE POLICY rls_clients_consulta ON clients
FOR SELECT TO avigest_consulta
USING (
    fn_current_tenant_id() IS NOT NULL 
    AND id_client = fn_current_tenant_id()
);

-- 5.2. Polítiques RLS per a GRANGES (Aïllament per client o granja concreta)
DROP POLICY IF EXISTS rls_granges_consulta ON granges;
CREATE POLICY rls_granges_consulta ON granges
FOR SELECT TO avigest_consulta
USING (
    fn_current_tenant_id() IS NOT NULL 
    AND id_client = fn_current_tenant_id()
    AND (fn_current_granja_id() IS NULL OR id_granja = fn_current_granja_id())
);

-- 5.3. Polítiques RLS per a NAUS
DROP POLICY IF EXISTS rls_naus_consulta ON naus;
CREATE POLICY rls_naus_consulta ON naus
FOR SELECT TO avigest_consulta
USING (
    id_granja IN (
        SELECT g.id_granja FROM granges g
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.4. Polítiques RLS per a LOTS DE CRIANÇA
DROP POLICY IF EXISTS rls_lots_consulta ON lots_crianca;
CREATE POLICY rls_lots_consulta ON lots_crianca
FOR SELECT TO avigest_consulta
USING (
    id_nau IN (
        SELECT n.id_nau FROM naus n
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.5. Polítiques RLS per a SENSORS
DROP POLICY IF EXISTS rls_sensors_consulta ON sensors;
CREATE POLICY rls_sensors_consulta ON sensors
FOR SELECT TO avigest_consulta
USING (
    id_nau IN (
        SELECT n.id_nau FROM naus n
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.6. Polítiques RLS per a ACTUADORS
DROP POLICY IF EXISTS rls_actuadors_consulta ON actuadors;
CREATE POLICY rls_actuadors_consulta ON actuadors
FOR SELECT TO avigest_consulta
USING (
    id_nau IN (
        SELECT n.id_nau FROM naus n
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.7. Polítiques RLS per a LECTURES DE SENSORS
DROP POLICY IF EXISTS rls_lectures_consulta ON lectures_sensors;
CREATE POLICY rls_lectures_consulta ON lectures_sensors
FOR SELECT TO avigest_consulta
USING (
    id_sensor IN (
        SELECT s.id_sensor FROM sensors s
        JOIN naus n ON s.id_nau = n.id_nau
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.8. Polítiques RLS per a REGISTRE D'ACTUACIONS
DROP POLICY IF EXISTS rls_registre_actuacions_consulta ON registre_actuacions;
CREATE POLICY rls_registre_actuacions_consulta ON registre_actuacions
FOR SELECT TO avigest_consulta
USING (
    id_actuador IN (
        SELECT a.id_actuador FROM actuadors a
        JOIN naus n ON a.id_nau = n.id_nau
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.9. Polítiques RLS per a ALARMES I INCIDÈNCIES
DROP POLICY IF EXISTS rls_alarmes_consulta ON alarmes_incidencies;
CREATE POLICY rls_alarmes_consulta ON alarmes_incidencies
FOR SELECT TO avigest_consulta
USING (
    id_nau IN (
        SELECT n.id_nau FROM naus n
        JOIN granges g ON n.id_granja = g.id_granja
        WHERE g.id_client = fn_current_tenant_id()
          AND (fn_current_granja_id() IS NULL OR g.id_granja = fn_current_granja_id())
    )
);

-- 5.10. Polítiques RLS per a AUDITORIA DE CANVIS (Restringit només a administradors)
DROP POLICY IF EXISTS rls_auditoria_consulta ON auditoria_canvis;
CREATE POLICY rls_auditoria_consulta ON auditoria_canvis
FOR SELECT TO avigest_consulta
USING (FALSE);
