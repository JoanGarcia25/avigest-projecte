-- =============================================================================
-- AviGest S.L. — Triggers i Procediments Emmagatzemats (MariaDB 10.11 LTS)
-- Fitxer: bd/sql/02_triggers_procedures.sql / docker/initdb/02_triggers_procedures.sql
-- Descripció: Automatització de termòstat (R5), alertes crítiques (R7),
--             procediments d'alta atòmica (R4.7), resolució i traçabilitat JSON.
-- Mòdul: ASIX - Projecte (Requeriments R3, R4, R5, R7 i Requeriment 4.3)
-- =============================================================================

USE avigest_db;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 0. GESTIÓ DE SESSIÓ MULTITENANT (Requeriment R3)
-- Permet a les sessions de consulta i aplicació fixar el context de tenant.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_set_tenant//
CREATE PROCEDURE sp_set_tenant(
    IN p_id_client INT,
    IN p_id_granja INT
)
BEGIN
    SET @app_current_tenant_id = p_id_client;
    SET @app_current_granja_id = p_id_granja;
END//

DROP PROCEDURE IF EXISTS sp_reset_tenant//
CREATE PROCEDURE sp_reset_tenant()
BEGIN
    SET @app_current_tenant_id = NULL;
    SET @app_current_granja_id = NULL;
END//

-- -----------------------------------------------------------------------------
-- 1. TRIGGER: Control automàtic de llindars i actuadors (Requeriments R5 i R7)
-- S'executa automàticament en cada INSERT a lectures_sensors.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_control_llindars_sensor//
CREATE TRIGGER trg_control_llindars_sensor
AFTER INSERT ON lectures_sensors
FOR EACH ROW
BEGIN
    DECLARE v_tipus_sensor VARCHAR(30);
    DECLARE v_id_nau INT;
    DECLARE v_llindar_min DECIMAL(6,2);
    DECLARE v_llindar_max DECIMAL(6,2);
    DECLARE v_id_actuador_vent INT DEFAULT NULL;
    DECLARE v_id_actuador_cal INT DEFAULT NULL;
    DECLARE v_estat_vent VARCHAR(5) DEFAULT 'OFF';
    DECLARE v_estat_cal VARCHAR(5) DEFAULT 'OFF';

    -- Obtenir tipus i llindars del sensor
    SELECT tipus_sensor, id_nau, llindar_minim, llindar_maxim
    INTO v_tipus_sensor, v_id_nau, v_llindar_min, v_llindar_max
    FROM sensors
    WHERE id_sensor = NEW.id_sensor;

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
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_vent, 'ON', CONCAT('Temperatura (', NEW.valor, ' ºC) supera llindar màxim (', v_llindar_max, ' ºC)'), NEW.id_sensor, NEW.data_hora);
            END IF;

            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_cal, 'OFF', 'Aturada de seguretat per alta temperatura', NEW.id_sensor, NEW.data_hora);
            END IF;

            -- Alerta crítica: cop de calor (>= 33ºC)
            IF NEW.valor >= 33.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
                VALUES (v_id_nau, NEW.id_sensor, 'critic', CONCAT('ALERTA CRÍTICA: Cop de calor imminent a Nau ', v_id_nau, '. Temperatura: ', NEW.valor, ' ºC (límit legal 33 ºC)'), FALSE, NEW.data_hora);
            ELSE
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
                VALUES (v_id_nau, NEW.id_sensor, 'avis', CONCAT('AVÍS: Temperatura elevada (', NEW.valor, ' ºC). Ventilació d emergència engegada.'), FALSE, NEW.data_hora);
            END IF;

        -- 2. Temperatura massa baixa (< llindar_min, ex: 20ºC)
        ELSEIF v_llindar_min IS NOT NULL AND NEW.valor < v_llindar_min THEN
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_cal, 'ON', CONCAT('Temperatura (', NEW.valor, ' ºC) sota llindar mínim (', v_llindar_min, ' ºC)'), NEW.id_sensor, NEW.data_hora);
            END IF;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_vent, 'OFF', 'Aturada de ventilació per baixa temperatura', NEW.id_sensor, NEW.data_hora);
            END IF;

            IF NEW.valor <= 16.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
                VALUES (v_id_nau, NEW.id_sensor, 'critic', CONCAT('ALERTA CRÍTICA: Risc d hipotèrmia de pollets a Nau ', v_id_nau, '. Temperatura: ', NEW.valor, ' ºC'), FALSE, NEW.data_hora);
            END IF;

        -- 3. Temperatura en rang òptim
        ELSE
            IF v_id_actuador_cal IS NOT NULL AND v_estat_cal = 'ON' THEN
                UPDATE actuadors SET estat_actual = 'OFF' WHERE id_actuador = v_id_actuador_cal;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_cal, 'OFF', 'Temperatura normalitzada dins del rang de confort', NEW.id_sensor, NEW.data_hora);
            END IF;
        END IF;

    -- =========================================================================
    -- CAS B: Sensor de CO2 (Ventilació sanitària per qualitat de l'aire)
    -- =========================================================================
    ELSEIF v_tipus_sensor = 'co2' THEN
        IF v_llindar_max IS NOT NULL AND NEW.valor > v_llindar_max THEN
            SELECT id_actuador, estat_actual INTO v_id_actuador_vent, v_estat_vent
            FROM actuadors
            WHERE id_nau = v_id_nau AND tipus_actuador = 'ventilador' AND actiu = TRUE
            LIMIT 1;

            IF v_id_actuador_vent IS NOT NULL AND v_estat_vent = 'OFF' THEN
                UPDATE actuadors SET estat_actual = 'ON' WHERE id_actuador = v_id_actuador_vent;
                INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora)
                VALUES (v_id_actuador_vent, 'ON', CONCAT('CO2 elevat (', NEW.valor, ' ppm > ', v_llindar_max, ' ppm). Renovació d aire forçada.'), NEW.id_sensor, NEW.data_hora);
            END IF;

            IF NEW.valor >= 3000.0 THEN
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
                VALUES (v_id_nau, NEW.id_sensor, 'critic', CONCAT('ALERTA CRÍTICA CO2: Concentració asfixiant (', NEW.valor, ' ppm) a Nau ', v_id_nau), FALSE, NEW.data_hora);
            ELSE
                INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
                VALUES (v_id_nau, NEW.id_sensor, 'avis', CONCAT('AVÍS CO2: Concentració superior al llindar (', NEW.valor, ' ppm) a Nau ', v_id_nau), FALSE, NEW.data_hora);
            END IF;
        END IF;

    -- =========================================================================
    -- CAS C: Sensor de PES DE SILO (Control d'estoc de pinso Requeriment R4)
    -- =========================================================================
    ELSEIF v_tipus_sensor = 'pes_silo' THEN
        IF NEW.valor <= 500.0 THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
            VALUES (v_id_nau, NEW.id_sensor, 'critic', CONCAT('ALERTA CRÍTICA: Silo pràcticament buit (', NEW.valor, ' kg). Risc d inanició animal!'), FALSE, NEW.data_hora);
        ELSEIF v_llindar_min IS NOT NULL AND NEW.valor <= v_llindar_min THEN
            INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio)
            VALUES (v_id_nau, NEW.id_sensor, 'avis', CONCAT('AVÍS SILO: Nivell de pinso sota el llindar de seguretat (', NEW.valor, ' kg < ', v_llindar_min, ' kg). Sol·licitar camió.'), FALSE, NEW.data_hora);
        END IF;
    END IF;
END//

-- -----------------------------------------------------------------------------
-- 2. PROCEDIMENT EMMAGATZEMAT: Alta Atòmica d'una Granja Completa (R4.7)
-- Crea la granja, les seves naus i el parc base de sensors i actuadors en una
-- única transacció ACID garantida.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_alta_granja_completa//
CREATE PROCEDURE sp_alta_granja_completa(
    IN p_id_client INT,
    IN p_nom_granja VARCHAR(100),
    IN p_codi_explotacio VARCHAR(30),
    IN p_adreca VARCHAR(150),
    IN p_poblacio VARCHAR(100),
    IN p_num_naus INT,
    OUT p_id_granja_nova INT
)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_id_nau_creada INT;
    DECLARE v_codi_nau VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Validar que el client existeix i està actiu
    IF NOT EXISTS (SELECT 1 FROM clients WHERE id_client = p_id_client AND actiu = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El client especificat no existeix o està desactivat.';
    END IF;

    -- 2. Inserir la nova granja
    INSERT INTO granges (id_client, nom_granja, codi_explotacio, adreca, poblacio, activa)
    VALUES (p_id_client, p_nom_granja, p_codi_explotacio, p_adreca, p_poblacio, TRUE);

    SET p_id_granja_nova = LAST_INSERT_ID();

    -- 3. Crear les naus i dispositius base
    WHILE v_i <= p_num_naus DO
        SET v_codi_nau = CONCAT('NAU-', LPAD(v_i, 2, '0'));

        INSERT INTO naus (id_granja, codi_nau, capacitat_aus, longitud_metres, amplada_metres, activa)
        VALUES (p_id_granja_nova, v_codi_nau, 12000, 100.00, 14.00, TRUE);

        SET v_id_nau_creada = LAST_INSERT_ID();

        -- Sensors bàsics de la nau
        INSERT INTO sensors (id_nau, codi_sensor, tipus_sensor, tecnologia, unitat_mesura, llindar_minim, llindar_maxim, actiu)
        VALUES
        (v_id_nau_creada, CONCAT('TEMP-G', p_id_granja_nova, '-N', v_i), 'temperatura', 'RS485', 'ºC', 20.00, 31.00, TRUE),
        (v_id_nau_creada, CONCAT('HUM-G', p_id_granja_nova, '-N', v_i),  'humitat',     'RS485', '%',  45.00, 70.00, TRUE),
        (v_id_nau_creada, CONCAT('SILO-G', p_id_granja_nova, '-N', v_i), 'pes_silo',    'LoRaWAN', 'kg', 1000.00, NULL, TRUE),
        (v_id_nau_creada, CONCAT('CO2-G', p_id_granja_nova, '-N', v_i),  'co2',         'RS485', 'ppm', NULL, 2500.00, TRUE);

        -- Actuadors bàsics de la nau
        INSERT INTO actuadors (id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual, actiu)
        VALUES
        (v_id_nau_creada, CONCAT('VENT-G', p_id_granja_nova, '-N', v_i), 'ventilador', 'automatic', 'OFF', TRUE),
        (v_id_nau_creada, CONCAT('CALEF-G', p_id_granja_nova, '-N', v_i), 'calefactor', 'automatic', 'OFF', TRUE);

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
END//

-- -----------------------------------------------------------------------------
-- 3. PROCEDIMENT EMMAGATZEMAT: Resolució d'Incidències (Requeriment R7)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_resoldre_alarma//
CREATE PROCEDURE sp_resoldre_alarma(
    IN p_id_alarma BIGINT,
    IN p_observacions TEXT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM alarmes_incidencies WHERE id_alarma = p_id_alarma) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La incidència indicada no existeix.';
    END IF;

    UPDATE alarmes_incidencies
    SET resolta = TRUE,
        data_resolucio = CURRENT_TIMESTAMP,
        observacions_resolucio = p_observacions
    WHERE id_alarma = p_id_alarma;
END//

-- -----------------------------------------------------------------------------
-- 4. TRIGGERS D'AUDITORIA DML (Requeriment 4.3 - Taula immutable en JSON)
-- Traçabilitat transparent d'operacions INSERT, UPDATE i DELETE sobre taules mestres.
-- -----------------------------------------------------------------------------

-- Auditoria CLIENTS
DROP TRIGGER IF EXISTS trg_audit_clients_insert//
CREATE TRIGGER trg_audit_clients_insert AFTER INSERT ON clients FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('clients', 'INSERT', CURRENT_USER(), NULL,
            JSON_OBJECT('id_client', NEW.id_client, 'nif', NEW.nif, 'nom_empresa', NEW.nom_empresa, 'email', NEW.email, 'actiu', NEW.actiu),
            CURRENT_TIMESTAMP);
END//

DROP TRIGGER IF EXISTS trg_audit_clients_update//
CREATE TRIGGER trg_audit_clients_update AFTER UPDATE ON clients FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('clients', 'UPDATE', CURRENT_USER(),
            JSON_OBJECT('id_client', OLD.id_client, 'nif', OLD.nif, 'nom_empresa', OLD.nom_empresa, 'email', OLD.email, 'actiu', OLD.actiu),
            JSON_OBJECT('id_client', NEW.id_client, 'nif', NEW.nif, 'nom_empresa', NEW.nom_empresa, 'email', NEW.email, 'actiu', NEW.actiu),
            CURRENT_TIMESTAMP);
END//

DROP TRIGGER IF EXISTS trg_audit_clients_delete//
CREATE TRIGGER trg_audit_clients_delete AFTER DELETE ON clients FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('clients', 'DELETE', CURRENT_USER(),
            JSON_OBJECT('id_client', OLD.id_client, 'nif', OLD.nif, 'nom_empresa', OLD.nom_empresa, 'email', OLD.email, 'actiu', OLD.actiu),
            NULL,
            CURRENT_TIMESTAMP);
END//

-- Auditoria GRANGES
DROP TRIGGER IF EXISTS trg_audit_granges_insert//
CREATE TRIGGER trg_audit_granges_insert AFTER INSERT ON granges FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('granges', 'INSERT', CURRENT_USER(), NULL,
            JSON_OBJECT('id_granja', NEW.id_granja, 'id_client', NEW.id_client, 'nom_granja', NEW.nom_granja, 'codi_explotacio', NEW.codi_explotacio, 'activa', NEW.activa),
            CURRENT_TIMESTAMP);
END//

DROP TRIGGER IF EXISTS trg_audit_granges_update//
CREATE TRIGGER trg_audit_granges_update AFTER UPDATE ON granges FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('granges', 'UPDATE', CURRENT_USER(),
            JSON_OBJECT('id_granja', OLD.id_granja, 'id_client', OLD.id_client, 'nom_granja', OLD.nom_granja, 'codi_explotacio', OLD.codi_explotacio, 'activa', OLD.activa),
            JSON_OBJECT('id_granja', NEW.id_granja, 'id_client', NEW.id_client, 'nom_granja', NEW.nom_granja, 'codi_explotacio', NEW.codi_explotacio, 'activa', NEW.activa),
            CURRENT_TIMESTAMP);
END//

DROP TRIGGER IF EXISTS trg_audit_granges_delete//
CREATE TRIGGER trg_audit_granges_delete AFTER DELETE ON granges FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('granges', 'DELETE', CURRENT_USER(),
            JSON_OBJECT('id_granja', OLD.id_granja, 'id_client', OLD.id_client, 'nom_granja', OLD.nom_granja, 'codi_explotacio', OLD.codi_explotacio, 'activa', OLD.activa),
            NULL,
            CURRENT_TIMESTAMP);
END//

-- Auditoria LOTS_CRIANCA
DROP TRIGGER IF EXISTS trg_audit_lots_update//
CREATE TRIGGER trg_audit_lots_update AFTER UPDATE ON lots_crianca FOR EACH ROW
BEGIN
    INSERT INTO auditoria_canvis (taula, operacio, usuari_bd, dades_antigues, dades_noves, data_hora)
    VALUES ('lots_crianca', 'UPDATE', CURRENT_USER(),
            JSON_OBJECT('id_lot', OLD.id_lot, 'codi_lot', OLD.codi_lot, 'num_baixes', OLD.num_baixes, 'pes_mitja_kg', OLD.pes_mitja_kg, 'pinso_consumit_kg', OLD.pinso_consumit_kg, 'estat', OLD.estat),
            JSON_OBJECT('id_lot', NEW.id_lot, 'codi_lot', NEW.codi_lot, 'num_baixes', NEW.num_baixes, 'pes_mitja_kg', NEW.pes_mitja_kg, 'pinso_consumit_kg', NEW.pinso_consumit_kg, 'estat', NEW.estat),
            CURRENT_TIMESTAMP);
END//

DELIMITER ;
