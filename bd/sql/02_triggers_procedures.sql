-- =============================================================================
-- AviGest S.L. — Triggers, Procediments Emmagatzemats i Vistes Operatives
-- Fitxer: bd/sql/02_triggers_procedures.sql / docker/initdb/02_triggers_procedures.sql
-- Descripció: Automatització de llindars (R5), alertes (R7), aïllament multitenant (R3)
--             i cicle de vida complet de granges i lots en PL/pgSQL (PostgreSQL 16).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. GESTIÓ DE SESSIÓ MULTITENANT I RLS (Requeriment R3 / E2 Sec. 7.2)
-- Permet als usuaris de consulta i aplicació establir el context de tenant.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sp_set_tenant(p_id_client INT, p_id_granja INT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', p_id_client::TEXT, false);
    IF p_id_granja IS NOT NULL THEN
        PERFORM set_config('app.current_granja_id', p_id_granja::TEXT, false);
    ELSE
        PERFORM set_config('app.current_granja_id', '', false);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sp_reset_tenant()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', '', false);
    PERFORM set_config('app.current_granja_id', '', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcions auxiliars segures per a polítiques RLS i vistes
CREATE OR REPLACE FUNCTION fn_current_tenant_id()
RETURNS INT AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_tenant_id', true), '')::INT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_current_granja_id()
RETURNS INT AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_granja_id', true), '')::INT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 1. FUNCIÓ I TRIGGER: Control automàtic de llindars i actuadors (R5 i R7)
-- Executat automàticament en cada INSERT a lectures_sensors.
-- Declarat amb SECURITY DEFINER perquè el rol d'ingesta 'avigest_iot' pugui
-- actualitzar actuadors i registrar alarmes sense permisos DML directes.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_control_llindars_sensor()
RETURNS TRIGGER AS $$
DECLARE
    v_tipus_sensor VARCHAR(30);
    v_id_nau INT;
    v_llindar_min NUMERIC(6,2);
    v_llindar_max NUMERIC(6,2);
    v_id_actuador_vent INT;
    v_id_actuador_cal INT;
    v_estat_vent VARCHAR(5);
    v_estat_cal VARCHAR(5);
BEGIN
    -- Obtenir tipus i llindars del sensor implicat
    SELECT tipus_sensor, id_nau, llindar_minim, llindar_maxim
    INTO v_tipus_sensor, v_id_nau, v_llindar_min, v_llindar_max
    FROM sensors
    WHERE id_sensor = NEW.id_sensor;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- =========================================================================
    -- CAS A: Sensor de TEMPERATURA (Termòstat automàtic R5)
    -- =========================================================================
    IF v_tipus_sensor = 'temperatura' THEN

        SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
        FROM actuadors
        WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
        LIMIT 1;

        SELECT id_actuador, estat_actual INTO v_id_actuador_cal, v_estat_cal
        FROM actuadors
        WHERE id_nau = v_id_nau AND tipus_actuador = 'calefactor' AND actiu = TRUE
        LIMIT 1;

        -- 1. Temperatura massa alta (> llindar_max, ex: 31ºC)
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ON', 
                        format('Temperatura detectada (%s ºC) supera llindar màxim (%s ºC)', NEW.valor, v_llindar_max),
                        NEW.id_sensor);
            END IF;

            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'OFF', 'Aturada automàtica de calefacció per sobreescalfament', NEW.id_sensor);
            END IF;

            -- Alarma crítica per cop de calor imminent (>= 33.0 ºC)
            IF NEW.valor >= 33.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Cop de calor imminent. Temperatura: %s ºC', NEW.valor));
            END IF;

        -- 2. Temperatura massa baixa (< llindar_min, ex: 20ºC)
        ELSIF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'ON', 
                        format('Temperatura detectada (%s ºC) per sota del llindar mínim (%s ºC)', NEW.valor, v_llindar_min),
                        NEW.id_sensor);
            END IF;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'OFF', 'Aturada de ventilació per baixa temperatura', NEW.id_sensor);
            END IF;

            -- Alarma crítica per risc d'hipotèrmia (<= 16.0 ºC)
            IF NEW.valor <= 16.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Risc d''hipotèrmia severa. Temperatura: %s ºC', NEW.valor));
            END IF;

        -- 3. Temperatura en rang òptim [llindar_min, llindar_max] -> Aturada automàtica
        ELSE
            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'OFF', 'Temperatura normalitzada. Aturada automàtica de ventilació.', NEW.id_sensor);
            END IF;

            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'OFF', 'Temperatura restablerta en rang de confort. Calefacció apagada.', NEW.id_sensor);
            END IF;
        END IF;

    -- =========================================================================
    -- CAS B: Sensor de DIÒXID DE CARBONI (CO2)
    -- =========================================================================
    ELSIF v_tipus_sensor = 'co2' THEN
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
            FROM actuadors
            WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
            LIMIT 1;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ON', format('CO2 elevat (%s ppm): renovació d''aire activada', NEW.valor), NEW.id_sensor);
            END IF;

            IF NEW.valor >= 3000.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Concentració de CO2 perillosa per a les aus (%s ppm)', NEW.valor));
            ELSE
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'avis',
                        format('AVÍS CO2: Llindar de CO2 superat (%s ppm). Ventilació engegada.', NEW.valor));
            END IF;
        END IF;

    -- =========================================================================
    -- CAS C: Sensor de NIVELL / PES DE SILO (LoRaWAN R4)
    -- =========================================================================
    ELSIF v_tipus_sensor = 'pes_silo' THEN
        IF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            IF NEW.valor <= 500.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA SILO: Silo buit o gairebé buit (%s kg)! Risc d''inanició immediata.', NEW.valor));
            ELSE
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'avis',
                        format('AVÍS SILO: Nivell de pinso sota el llindar de seguretat (%s kg). Demanar camió de pinso.', NEW.valor));
            END IF;
        END IF;

    -- =========================================================================
    -- CAS D: Sensor d'HUMITAT RELATIVA (R4)
    -- =========================================================================
    ELSIF v_tipus_sensor = 'humitat' THEN
        IF v_llindar_max IS NOT NULL AND NEW.valor >= 85.0 THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
            VALUES (v_id_nau, NEW.id_sensor, 'avis',
                    format('AVÍS HUMITAT: Humitat relativa perillosa (%s %%) a la nau. Risc de llit humit i fermentació.', NEW.valor));
        ELSIF v_llindar_min IS NOT NULL AND NEW.valor <= 35.0 THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
            VALUES (v_id_nau, NEW.id_sensor, 'avis',
                    format('AVÍS HUMITAT: Ambient excessivament sec (%s %%). Risc d''irritació respiratòria per pols.', NEW.valor));
        END IF;

    -- =========================================================================
    -- CAS E: Sensor d'AMONÍAC (NH3)
    -- =========================================================================
    ELSIF v_tipus_sensor = 'amoniac' THEN
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            IF NEW.valor >= 35.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA AMONÍAC: Concentració d''amoníac letal (%s ppm). Ventilació d''emergència!', NEW.valor));
            ELSE
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'avis',
                        format('AVÍS AMONÍAC: Nivell elevat d''amoníac (%s ppm). Cal reforçar la renovació d''aire.', NEW.valor));
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tg_control_llindars_sensor ON lectures_sensors;
CREATE TRIGGER tg_control_llindars_sensor
AFTER INSERT ON lectures_sensors
FOR EACH ROW
EXECUTE FUNCTION fn_control_llindars_sensor();

-- -----------------------------------------------------------------------------
-- 2. FUNCIÓ I TRIGGERS D'AUDITORIA DML (Requeriment 4.3 / E2 Sec. 7.2)
-- Traçabilitat transparent i immutable sobre entitats de configuració.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auditoria_canvis()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_noves)
        VALUES (TG_TABLE_NAME, TG_OP, CURRENT_USER, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves)
        VALUES (TG_TABLE_NAME, TG_OP, CURRENT_USER, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues)
        VALUES (TG_TABLE_NAME, TG_OP, CURRENT_USER, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tg_auditoria_clients ON clients;
CREATE TRIGGER tg_auditoria_clients AFTER INSERT OR UPDATE OR DELETE ON clients
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

DROP TRIGGER IF EXISTS tg_auditoria_granges ON granges;
CREATE TRIGGER tg_auditoria_granges AFTER INSERT OR UPDATE OR DELETE ON granges
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

DROP TRIGGER IF EXISTS tg_auditoria_naus ON naus;
CREATE TRIGGER tg_auditoria_naus AFTER INSERT OR UPDATE OR DELETE ON naus
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

DROP TRIGGER IF EXISTS tg_auditoria_lots ON lots_crianca;
CREATE TRIGGER tg_auditoria_lots AFTER INSERT OR UPDATE OR DELETE ON lots_crianca
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

DROP TRIGGER IF EXISTS tg_auditoria_sensors ON sensors;
CREATE TRIGGER tg_auditoria_sensors AFTER INSERT OR UPDATE OR DELETE ON sensors
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

DROP TRIGGER IF EXISTS tg_auditoria_actuadors ON actuadors;
CREATE TRIGGER tg_auditoria_actuadors AFTER INSERT OR UPDATE OR DELETE ON actuadors
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_canvis();

-- -----------------------------------------------------------------------------
-- 3. PROCEDIMENT EMMAGATZEMAT: sp_alta_granja_completa (Requeriment 4.7)
-- Provisió atòmica d'una nova explotació amb les seves naus, sensors i actuadors.
-- Cridat automàticament des de l'script bash 'alta_granja.sh'.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_alta_granja_completa(
    p_id_client INT,
    p_nom_granja VARCHAR(100),
    p_codi_explotacio VARCHAR(30),
    p_adreca VARCHAR(150),
    p_poblacio VARCHAR(100),
    p_num_naus INT DEFAULT 2
)
RETURNS INT AS $$
DECLARE
    v_id_granja INT;
    v_id_nau INT;
    v_i INT;
    v_codi_nau VARCHAR(20);
BEGIN
    -- Validació bàsica
    IF p_id_client IS NULL OR NOT EXISTS (SELECT 1 FROM clients WHERE id_client = p_id_client) THEN
        RAISE EXCEPTION 'El client amb ID % no existeix.', p_id_client;
    END IF;

    IF p_num_naus < 1 OR p_num_naus > 20 THEN
        RAISE EXCEPTION 'El nombre de naus ha d''estar entre 1 i 20 (rebut: %).', p_num_naus;
    END IF;

    -- 1. Inserir Granja
    INSERT INTO granges (id_client, nom_granja, codi_explotacio, adreca, poblacio)
    VALUES (p_id_client, p_nom_granja, p_codi_explotacio, p_adreca, p_poblacio)
    RETURNING id_granja INTO v_id_granja;

    -- 2. Bucle per crear cadascuna de les naus sol·licitades
    FOR v_i IN 1..p_num_naus LOOP
        v_codi_nau := format('NAU-%s', lpad(v_i::text, 2, '0'));

        INSERT INTO naus (id_granja, codi_nau, capacitat_aus, longitud_metres, amplada_metres)
        VALUES (v_id_granja, v_codi_nau, 15000, 100.00, 14.00)
        RETURNING id_nau INTO v_id_nau;

        -- Sensors estàndard de la nau (RS485 + LoRaWAN)
        INSERT INTO sensors (id_nau, codi_sensor, tipus_sensor, tecnologia, unitat_mesura, llindar_minim, llindar_maxim) VALUES
        (v_id_nau, format('TEMP-%s-%s', v_id_granja, v_codi_nau), 'temperatura', 'RS485',   'ºC',  20.00, 31.00),
        (v_id_nau, format('HUM-%s-%s', v_id_granja, v_codi_nau),  'humitat',     'RS485',   '%',   45.00, 70.00),
        (v_id_nau, format('CO2-%s-%s', v_id_granja, v_codi_nau),  'co2',         'RS485',   'ppm', NULL, 2500.00),
        (v_id_nau, format('SILO-%s-%s', v_id_granja, v_codi_nau), 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL);

        -- Actuadors estàndard de la nau
        INSERT INTO actuadors (id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual) VALUES
        (v_id_nau, format('VENT-%s-%s', v_id_granja, v_codi_nau),  'ventilador',   'automatic', 'OFF'),
        (v_id_nau, format('CALEF-%s-%s', v_id_granja, v_codi_nau), 'calefactor',   'automatic', 'OFF'),
        (v_id_nau, format('LLUM-%s-%s', v_id_granja, v_codi_nau),  'il_luminacio', 'automatic', 'ON');
    END LOOP;

    RETURN v_id_granja;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 4. PROCEDIMENTS DE GESTIÓ DE CICLE DE VIDA DE LOTS I ALARMES (R6 i R7)
-- -----------------------------------------------------------------------------

-- Iniciar un nou lot d'engreix en una nau
CREATE OR REPLACE FUNCTION sp_iniciar_lot_crianca(
    p_id_nau INT,
    p_codi_lot VARCHAR(50),
    p_num_aus INT,
    p_dies_cicle INT DEFAULT 45
)
RETURNS INT AS $$
DECLARE
    v_id_lot INT;
BEGIN
    IF EXISTS (SELECT 1 FROM lots_crianca WHERE id_nau = p_id_nau AND estat = 'en_curs') THEN
        RAISE EXCEPTION 'La nau % ja té un lot actiu en curs. Cal finalitzar-lo prèviament.', p_id_nau;
    END IF;

    INSERT INTO lots_crianca (id_nau, codi_lot, data_entrada, data_sortida_prevista, num_aus_inicials, num_baixes, estat)
    VALUES (p_id_nau, p_codi_lot, CURRENT_DATE, CURRENT_DATE + p_dies_cicle, p_num_aus, 0, 'en_curs')
    RETURNING id_lot INTO v_id_lot;

    RETURN v_id_lot;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Registrar baixes acumulades d'un lot
CREATE OR REPLACE FUNCTION sp_registrar_baixes_lot(
    p_id_lot INT,
    p_baixes INT
)
RETURNS INT AS $$
DECLARE
    v_aus_actuals INT;
BEGIN
    IF p_baixes <= 0 THEN
        RAISE EXCEPTION 'El nombre de baixes ha de ser estrictament positiu.';
    END IF;

    UPDATE lots_crianca
    SET num_baixes = num_baixes + p_baixes
    WHERE id_lot = p_id_lot AND estat = 'en_curs'
    RETURNING (num_aus_inicials - num_baixes) INTO v_aus_actuals;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El lot % no existeix o no està en curs.', p_id_lot;
    END IF;

    IF v_aus_actuals < 0 THEN
        RAISE EXCEPTION 'El nombre total de baixes no pot superar les aus inicials del lot.';
    END IF;

    RETURN v_aus_actuals;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Finalitzar un lot d'engreix i calcular mètriques finals
CREATE OR REPLACE FUNCTION sp_finalitzar_lot_crianca(
    p_id_lot INT,
    p_data_sortida DATE DEFAULT CURRENT_DATE,
    p_pes_mitja_kg NUMERIC DEFAULT NULL,
    p_pinso_consumit_kg NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE lots_crianca
    SET estat = 'finalitzat',
        data_sortida_real = p_data_sortida,
        pes_mitja_kg = COALESCE(p_pes_mitja_kg, pes_mitja_kg),
        pinso_consumit_kg = COALESCE(p_pinso_consumit_kg, pinso_consumit_kg)
    WHERE id_lot = p_id_lot;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El lot % no existeix.', p_id_lot;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resoldre una incidència/alarma amb traçabilitat
CREATE OR REPLACE FUNCTION sp_resoldre_alarma(
    p_id_alarma BIGINT,
    p_observacions TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE alarmes_incidencies
    SET resolta = TRUE,
        data_resolucio = CURRENT_TIMESTAMP,
        observacions_resolucio = p_observacions
    WHERE id_alarma = p_id_alarma;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'L''alarma amb ID % no existeix.', p_id_alarma;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 5. VISTES OPERATIVES EN TEMPS REAL (Amb aïllament R3 via security_invoker)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_estat_actual_naus
WITH (security_invoker = true) AS
SELECT 
    c.id_client,
    c.nom_empresa,
    g.id_granja,
    g.nom_granja,
    n.id_nau,
    n.codi_nau,
    n.capacitat_aus,
    (SELECT ls.valor FROM lectures_sensors ls 
     JOIN sensors s ON ls.id_sensor = s.id_sensor 
     WHERE s.id_nau = n.id_nau AND s.tipus_sensor = 'temperatura' 
     ORDER BY ls.data_hora DESC LIMIT 1) AS darrera_temperatura,
    (SELECT ls.valor FROM lectures_sensors ls 
     JOIN sensors s ON ls.id_sensor = s.id_sensor 
     WHERE s.id_nau = n.id_nau AND s.tipus_sensor = 'humitat' 
     ORDER BY ls.data_hora DESC LIMIT 1) AS darrera_humitat,
    (SELECT ls.valor FROM lectures_sensors ls 
     JOIN sensors s ON ls.id_sensor = s.id_sensor 
     WHERE s.id_nau = n.id_nau AND s.tipus_sensor = 'co2' 
     ORDER BY ls.data_hora DESC LIMIT 1) AS darrer_co2,
    (SELECT a.estat_actual FROM actuadors a 
     WHERE a.id_nau = n.id_nau AND a.tipus_actuador = 'ventilador' LIMIT 1) AS estat_ventilador,
    (SELECT a.estat_actual FROM actuadors a 
     WHERE a.id_nau = n.id_nau AND a.tipus_actuador = 'calefactor' LIMIT 1) AS estat_calefactor,
    (SELECT COUNT(*) FROM alarmes_incidencies al 
     WHERE al.id_nau = n.id_nau AND al.resolta = FALSE) AS alarmes_pendents
FROM clients c
JOIN granges g ON c.id_client = g.id_client
JOIN naus n ON g.id_granja = n.id_granja
WHERE g.activa = TRUE AND n.activa = TRUE;

CREATE OR REPLACE VIEW v_alarmes_actives
WITH (security_invoker = true) AS
SELECT 
    a.id_alarma,
    c.id_client,
    c.nom_empresa,
    g.id_granja,
    g.nom_granja,
    n.codi_nau,
    s.tipus_sensor,
    a.nivell_gravetat,
    a.missatge,
    a.data_generacio
FROM alarmes_incidencies a
JOIN naus n ON a.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
LEFT JOIN sensors s ON a.id_sensor = s.id_sensor
WHERE a.resolta = FALSE
ORDER BY 
    CASE a.nivell_gravetat 
        WHEN 'critic' THEN 1 
        WHEN 'avis' THEN 2 
        ELSE 3 
    END,
    a.data_generacio DESC;
