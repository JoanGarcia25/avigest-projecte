-- =============================================================================
-- AviGest S.L. — Triggers, Procediments Emmagatzemats i Vistes
-- Fitxer: bd/procediments-triggers/02_triggers_procedures.sql
-- Descripció: Automatització de llindars (R5), alertes (R7) i procediments.
-- =============================================================================

USE avigest_db;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- 1. TRIGGER: Control automàtic de llindars i activació d'actuadors (R5 i R7)
-- Es dispara immediatament després d'inserir qualsevol lectura d'un sensor.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tg_control_llindars_sensor$$

CREATE TRIGGER tg_control_llindars_sensor
AFTER INSERT ON lectures_sensors
FOR EACH ROW
BEGIN
    DECLARE v_tipus_sensor VARCHAR(30);
    DECLARE v_id_nau INT;
    DECLARE v_llindar_min DECIMAL(6,2);
    DECLARE v_llindar_max DECIMAL(6,2);
    DECLARE v_id_actuador_vent INT;
    DECLARE v_id_actuador_cal INT;
    DECLARE v_estat_vent VARCHAR(5);
    DECLARE v_estat_cal VARCHAR(5);

    -- Obtenir dades del sensor que ha enviat la lectura
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

        -- Supera la temperatura màxima permesa -> Engegar ventiladors
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                -- 1. Actualitzar estat de l'actuador a ON
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                
                -- 2. Registrar l'acció a la taula d'actuacions
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ACTIVAR', CONCAT('Temperatura crítica: ', NEW.valor, ' ºC supera límit ', v_llindar_max, ' ºC'), NEW.id_sensor);
            END IF;

            -- Generar Alarma d'Incidència
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'CRITICAL', 'Sobreescalfament a la nau',
                    CONCAT('Temperatura mesurada: ', NEW.valor, ' ºC (Màxim admès: ', v_llindar_max, ' ºC). Ventiladors activats.'));

        -- Temperatura per sota del mínim -> Engegar calefacció i apagar ventiladors
        ELSEIF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'ACTIVAR', CONCAT('Temperatura baixa: ', NEW.valor, ' ºC per sota del mínim ', v_llindar_min, ' ºC'), NEW.id_sensor);
            END IF;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'DESACTIVAR', 'Aturada per temperatura baixa', NEW.id_sensor);
            END IF;

            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'WARNING', 'Temperatura baixa a la nau',
                    CONCAT('Temperatura mesurada: ', NEW.valor, ' ºC (Mínim admès: ', v_llindar_min, ' ºC). Calefacció activada.'));

        -- Temperatura normalitzada -> Apagar ventiladors i calefactors si estaven encesos
        ELSE
            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'DESACTIVAR', 'Temperatura restablerta dins dels paràmetres normals', NEW.id_sensor);
            END IF;

            -- Millora: Apagar calefactors si la temperatura ja no és baixa
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_cal, 'DESACTIVAR', 'Temperatura restablerta dins dels paràmetres normals. Calefacció ja no necessària.', NEW.id_sensor);
            END IF;
        END IF;

    -- =========================================================================
    -- CAS B: Sensor d'HUMITAT
    -- =========================================================================
    ELSEIF v_tipus_sensor = 'humitat' THEN
        -- Humitat per sobre del llindar màxim -> Alarma WARNING
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            -- Engegar ventiladors per extreure humitat excessiva
            SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
            FROM actuadors
            WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
            LIMIT 1;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ACTIVAR', CONCAT('Humitat excessiva: ', NEW.valor, ' % supera límit ', v_llindar_max, ' %'), NEW.id_sensor);
            END IF;

            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'WARNING', 'Humitat excessiva a la nau',
                    CONCAT('Humitat mesurada: ', NEW.valor, ' % (Màxim admès: ', v_llindar_max, ' %). Ventilació activada per reduir la condensació.'));

        -- Humitat per sota del llindar mínim -> Alarma INFO
        ELSEIF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'INFO', 'Humitat baixa a la nau',
                    CONCAT('Humitat mesurada: ', NEW.valor, ' % (Mínim recomanat: ', v_llindar_min, ' %). Considerar humidificació o reducció de ventilació.'));
        END IF;

    -- =========================================================================
    -- CAS C: Sensor de CO2 (Qualitat de l'aire)
    -- =========================================================================
    ELSEIF v_tipus_sensor = 'co2' THEN
        -- CO2 per sobre del llindar màxim -> Alarma CRITICAL i engegar ventiladors
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
            FROM actuadors
            WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
            LIMIT 1;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id)
                VALUES (v_id_actuador_vent, 'ACTIVAR', CONCAT('CO2 perillós: ', NEW.valor, ' ppm supera límit ', v_llindar_max, ' ppm'), NEW.id_sensor);
            END IF;

            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'CRITICAL', 'Nivell de CO2 perillós a la nau',
                    CONCAT('CO2 mesurat: ', NEW.valor, ' ppm (Màxim admès: ', v_llindar_max, ' ppm). Ventilació d''emergència activada. Risc per al benestar animal.'));
        END IF;

    -- =========================================================================
    -- CAS D: Sensor de SILO DE GRA / PINSO
    -- =========================================================================
    ELSEIF v_tipus_sensor = 'silo_gra' THEN
        -- Si el nivell del silo cau per sota del mínim establert (ex: 1500 kg)
        IF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_criticitat, titol, descripcio)
            VALUES (v_id_nau, NEW.id_sensor, 'WARNING', 'Nivell crític de pinso al silo',
                    CONCAT('El silo de pinso està al límit: ', NEW.valor, ' kg restants (Llindar mínim: ', v_llindar_min, ' kg). Sol·licitar càrrega.'));
        END IF;
    END IF;

END$$

-- -----------------------------------------------------------------------------
-- 2. PROCEDIMENT EMMAGATZEMAT: sp_alta_granja_completa
-- Crea una granja, les seves naus i auto-provisiona els sensors i actuadors bàsics.
-- Aquest procediment serà utilitzat pel script d'automatització (Requeriment 4.7).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_alta_granja_completa$$

CREATE PROCEDURE sp_alta_granja_completa (
    IN p_id_client INT,
    IN p_nom_granja VARCHAR(100),
    IN p_codi_explotacio VARCHAR(50),
    IN p_adreca VARCHAR(150),
    IN p_poblacio VARCHAR(80),
    IN p_num_naus INT,
    OUT p_id_granja_creada INT
)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_id_nau_creada INT;
    DECLARE v_codi_nau VARCHAR(20);

    -- Validació d'entrada: Comprovar que el client existeix
    IF NOT EXISTS (SELECT 1 FROM clients WHERE id_client = p_id_client) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error sp_alta_granja_completa: El client especificat no existeix a la base de dades.';
    END IF;

    -- Validació d'entrada: Comprovar que el codi d'explotació no estigui duplicat
    IF EXISTS (SELECT 1 FROM granges WHERE codi_explotacio = p_codi_explotacio) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error sp_alta_granja_completa: Ja existeix una granja amb aquest codi d''explotació.';
    END IF;

    -- 1. Inserir la nova granja
    INSERT INTO granges (id_client, nom_granja, codi_explotacio, adreca, poblacio, activa)
    VALUES (p_id_client, p_nom_granja, p_codi_explotacio, p_adreca, p_poblacio, TRUE);

    SET p_id_granja_creada = LAST_INSERT_ID();

    -- 2. Iterar i crear les naus sol·licitades amb el seu equipament per defecte
    WHILE i <= p_num_naus DO
        SET v_codi_nau = CONCAT('NAU-', LPAD(i, 2, '0'));

        INSERT INTO naus (id_granja, codi_nau, capacitat_aus, superficie_m2)
        VALUES (p_id_granja_creada, v_codi_nau, 12000, 950.00);

        SET v_id_nau_creada = LAST_INSERT_ID();

        -- Provisionar sensors estàndard a la nau:
        -- - Sensor de temperatura (RS485): Min 20ºC, Max 31ºC
        INSERT INTO sensors (id_nau, tipus_sensor, tecnologia, model_hardware, llindar_minim, llindar_maxim)
        VALUES (v_id_nau_creada, 'temperatura', 'RS485', 'Modbus-Temp-DHT', 20.00, 31.00);

        -- - Sensor d'humitat (RS485): Min 45%, Max 70%
        INSERT INTO sensors (id_nau, tipus_sensor, tecnologia, model_hardware, llindar_minim, llindar_maxim)
        VALUES (v_id_nau_creada, 'humitat', 'RS485', 'Modbus-Hum-DHT', 45.00, 70.00);

        -- - Sensor de CO2 (RS485): Max 3000 ppm
        INSERT INTO sensors (id_nau, tipus_sensor, tecnologia, model_hardware, llindar_minim, llindar_maxim)
        VALUES (v_id_nau_creada, 'co2', 'RS485', 'Modbus-CO2-SenseAir', NULL, 3000.00);

        -- - Sensor de silo exterior (LoRaWAN): Min 1500 kg
        INSERT INTO sensors (id_nau, tipus_sensor, tecnologia, model_hardware, llindar_minim, llindar_maxim)
        VALUES (v_id_nau_creada, 'silo_gra', 'LoRaWAN', 'LoRa-WeightScale-Silo', 1500.00, 15000.00);

        -- Provisionar actuadors estàndard a la nau:
        -- - Ventilador principal d'extracció
        INSERT INTO actuadors (id_nau, tipus_actuador, estat_actual, ubicacio_especifica)
        VALUES (v_id_nau_creada, 'ventilador', 'OFF', 'Façana Nord - Extractor 1');

        -- - Sistema de calefacció per biomassa/gas
        INSERT INTO actuadors (id_nau, tipus_actuador, estat_actual, ubicacio_especifica)
        VALUES (v_id_nau_creada, 'calefactor', 'OFF', 'Canonada radiant central');

        SET i = i + 1;
    END WHILE;

END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- 3. VISTES ÚTILS PER A CONSULTES I QUADRES DE COMANDAMENT
-- -----------------------------------------------------------------------------

-- Vista 1: Visió global AviGest (resum de totes les granges amb alarmes pendents)
CREATE OR REPLACE VIEW v_resum_granges_avigest AS
SELECT 
    c.id_client,
    c.nom_empresa AS nom_client,
    g.id_granja,
    g.nom_granja,
    g.codi_explotacio,
    g.poblacio,
    COUNT(DISTINCT n.id_nau) AS total_naus,
    IFNULL(SUM(lc.quantitat_actual), 0) AS pollastres_actius,
    (SELECT COUNT(*) FROM alarmes_incidencies ai 
     JOIN naus n2 ON ai.id_nau = n2.id_nau 
     WHERE n2.id_granja = g.id_granja AND ai.resolta = FALSE) AS alarmes_pendents
FROM clients c
JOIN granges g ON c.id_client = g.id_client
LEFT JOIN naus n ON g.id_granja = n.id_granja
LEFT JOIN lots_crianca lc ON n.id_nau = lc.id_nau AND lc.estat = 'ACTIU'
GROUP BY g.id_granja;

-- Vista 2: Monitorització en temps real per nau i sensor
CREATE OR REPLACE VIEW v_estat_actual_sensors AS
SELECT 
    g.id_granja,
    g.nom_granja,
    n.id_nau,
    n.codi_nau,
    s.id_sensor,
    s.tipus_sensor,
    s.tecnologia,
    s.llindar_minim,
    s.llindar_maxim,
    ult.valor AS darrer_valor,
    ult.unitat,
    ult.data_hora AS darrera_lectura
FROM sensors s
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
LEFT JOIN (
    SELECT ls1.id_sensor, ls1.valor, ls1.unitat, ls1.data_hora
    FROM lectures_sensors ls1
    INNER JOIN (
        SELECT id_sensor, MAX(data_hora) AS max_data
        FROM lectures_sensors
        GROUP BY id_sensor
    ) ls2 ON ls1.id_sensor = ls2.id_sensor AND ls1.data_hora = ls2.max_data
) ult ON s.id_sensor = ult.id_sensor;
