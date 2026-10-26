-- =============================================================================
-- AviGest S.L. — Triggers, Procediments Emmagatzemats i Vistes (PostgreSQL 16)
-- Fitxer: bd/procediments-triggers/02_triggers_procedures.sql / docker/initdb/02_triggers_procedures.sql
-- Descripció: Automatització de llindars (R5), alertes (R7) i procediments PL/pgSQL.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FUNCIÓ I TRIGGER: Control automàtic de llindars i actuadors (R5 i R7)
-- Executat automàticament en cada INSERT a lectures_sensors.
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
    -- Obtenir tipus i llindars del sensor
    SELECT tipus_sensor, id_nau, llindar_minim, llindar_maxim
    INTO v_tipus_sensor, v_id_nau, v_llindar_min, v_llindar_max
    FROM sensors
    WHERE id_sensor = NEW.id_sensor;

    -- =========================================================================
    -- CAS A: Sensor de TEMPERATURA
    -- =========================================================================
    IF v_tipus_sensor = 'temperatura' THEN

        -- Buscar l'actuador ventilador de la mateixa nau
        SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
        FROM actuadors
        WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
        LIMIT 1;

        -- Buscar l'actuador calefactor de la mateixa nau
        SELECT id_actuador, estat_actual INTO v_id_actuador_cal, v_estat_cal
        FROM actuadors
        WHERE id_nau = v_id_nau AND tipus_actuador = 'calefactor' AND actiu = TRUE
        LIMIT 1;

        -- 1. Supera la temperatura màxima permesa (> llindar_max, ex: 31ºC)
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                -- Activar ventilador
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                
                -- Registrar l'acció
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ON', 
                        format('Temperatura detectada (%s ºC) supera llindar màxim (%s ºC)', NEW.valor, v_llindar_max),
                        NEW.id_sensor);
            END IF;

            -- Apagar calefacció si estigués engegada
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'OFF', 'Aturada automàtica per excés de temperatura', NEW.id_sensor);
            END IF;

            -- Generar Alarma si supera un llindar molt perillós (> 33ºC)
            IF NEW.valor >= 33.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Cop de calor imminent. Temperatura: %s ºC', NEW.valor));
            END IF;

        -- 2. Cau per sota de la temperatura mínima (< llindar_min, ex: 20ºC)
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

            IF NEW.valor <= 16.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Hipotèrmia potencial. Temperatura: %s ºC', NEW.valor));
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
                VALUES (v_id_actuador_vent, 'ON', format('CO2 elevat (%s ppm): renovació d''aire d''emergència', NEW.valor), NEW.id_sensor);
            END IF;

            IF NEW.valor >= 3000.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
                VALUES (v_id_nau, NEW.id_sensor, 'critic',
                        format('ALERTA CRÍTICA: Concentració de CO2 perillosa (%s ppm)', NEW.valor));
            END IF;
        END IF;

    -- =========================================================================
    -- CAS C: Sensor de NIVELL / PES DE SILO (LoRaWAN)
    -- =========================================================================
    ELSIF v_tipus_sensor = 'pes_silo' THEN
        IF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge)
            VALUES (v_id_nau, NEW.id_sensor, 'avis',
                    format('AVÍS SILO: Nivell de pinso crític (%s kg). Cal comanda immediata.', NEW.valor));
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tg_control_llindars_sensor ON lectures_sensors;
CREATE TRIGGER tg_control_llindars_sensor
AFTER INSERT ON lectures_sensors
FOR EACH ROW
EXECUTE FUNCTION fn_control_llindars_sensor();

-- -----------------------------------------------------------------------------
-- 2. PROCEDIMENT EMMAGATZEMAT: sp_alta_granja_completa (Requeriment 4.7)
-- Provisió atòmica d'una nova granja amb les seves naus, sensors i actuadors.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_alta_granja_completa(
    p_id_client INT,
    p_nom_granja VARCHAR(100),
    p_codi_explotacio VARCHAR(30),
    p_adreca VARCHAR(150),
    p_poblacio VARCHAR(100),
    p_num_naus INT
)
RETURNS INT AS $$
DECLARE
    v_id_granja INT;
    v_id_nau INT;
    v_i INT;
    v_codi_nau VARCHAR(20);
BEGIN
    -- 1. Inserir Granja
    INSERT INTO granges (id_client, nom_granja, codi_explotacio, adreca, poblacio)
    VALUES (p_id_client, p_nom_granja, p_codi_explotacio, p_adreca, p_poblacio)
    RETURNING id_granja INTO v_id_granja;

    -- 2. Bucle per crear cadascuna de les naus sol·licitades
    FOR v_i IN 1..p_num_naus LOOP
        v_codi_nau := format('NAU-%s', lpad(v_i::text, 2, '0'));

        INSERT INTO naus (id_granja, codi_nau, capacitat_aus, longitud_metres, amplada_metres)
        VALUES (v_id_granja, v_codi_nau, 20000, 100.00, 15.00)
        RETURNING id_nau INTO v_id_nau;

        -- Inserir sensors estàndard per a la nau
        INSERT INTO sensors (id_nau, codi_sensor, tipus_sensor, tecnologia, unitat_mesura, llindar_minim, llindar_maxim) VALUES
        (v_id_nau, format('TEMP-%s-%s', v_id_granja, v_codi_nau), 'temperatura', 'RS485', 'ºC', 20.00, 31.00),
        (v_id_nau, format('HUM-%s-%s', v_id_granja, v_codi_nau),  'humitat',     'RS485', '%',  45.00, 70.00),
        (v_id_nau, format('CO2-%s-%s', v_id_granja, v_codi_nau),  'co2',         'RS485', 'ppm', NULL, 2500.00),
        (v_id_nau, format('SILO-%s-%s', v_id_granja, v_codi_nau), 'pes_silo',    'LoRaWAN', 'kg', 1000.00, NULL);

        -- Inserir actuadors estàndard per a la nau
        INSERT INTO actuadors (id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual) VALUES
        (v_id_nau, format('VENT-%s-%s', v_id_granja, v_codi_nau), 'ventilador', 'automatic', 'OFF'),
        (v_id_nau, format('CALEF-%s-%s', v_id_granja, v_codi_nau), 'calefactor', 'automatic', 'OFF'),
        (v_id_nau, format('LLUM-%s-%s', v_id_granja, v_codi_nau), 'il_luminacio', 'automatic', 'ON');
    END LOOP;

    RETURN v_id_granja;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 3. VISTES D'INFORMACIÓ I MONITORITZACIÓ (Requeriment 4.extra)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_estat_actual_naus AS
SELECT 
    c.id_client,
    c.nom_empresa,
    g.id_granja,
    g.nom_granja,
    n.id_nau,
    n.codi_nau,
    (SELECT ls.valor FROM lectures_sensors ls 
     JOIN sensors s ON ls.id_sensor = s.id_sensor 
     WHERE s.id_nau = n.id_nau AND s.tipus_sensor = 'temperatura' 
     ORDER BY ls.data_hora DESC LIMIT 1) AS darrera_temperatura,
    (SELECT ls.valor FROM lectures_sensors ls 
     JOIN sensors s ON ls.id_sensor = s.id_sensor 
     WHERE s.id_nau = n.id_nau AND s.tipus_sensor = 'humitat' 
     ORDER BY ls.data_hora DESC LIMIT 1) AS darrera_humitat,
    (SELECT a.estat_actual FROM actuadors a 
     WHERE a.id_nau = n.id_nau AND a.tipus_actuador = 'ventilador' LIMIT 1) AS estat_ventilador,
    (SELECT COUNT(*) FROM alarmes_incidencies al 
     WHERE al.id_nau = n.id_nau AND al.resolta = FALSE) AS alarmes_pendents
FROM clients c
JOIN granges g ON c.id_client = g.id_client
JOIN naus n ON g.id_granja = n.id_granja
WHERE g.activa = TRUE AND n.activa = TRUE;

CREATE OR REPLACE VIEW v_alarmes_actives AS
SELECT 
    a.id_alarma,
    c.nom_empresa,
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
ORDER BY a.data_generacio DESC;
