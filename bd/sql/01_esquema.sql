-- =============================================================================
-- AviGest S.L. — Esquema de Base de Dades (PostgreSQL 16)
-- Fitxer: bd/sql/01_esquema.sql / docker/initdb/01_esquema.sql
-- Descripció: Creació de taules, claus primàries, foranes, índexs i restriccions.
-- =============================================================================

-- Desactivar/netejar taules existents si escau
DROP TABLE IF EXISTS alarmes_incidencies CASCADE;
DROP TABLE IF EXISTS registre_actuacions CASCADE;
DROP TABLE IF EXISTS lectures_sensors CASCADE;
DROP TABLE IF EXISTS actuadors CASCADE;
DROP TABLE IF EXISTS sensors CASCADE;
DROP TABLE IF EXISTS lots_crianca CASCADE;
DROP TABLE IF EXISTS naus CASCADE;
DROP TABLE IF EXISTS granges CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

-- -----------------------------------------------------------------------------
-- 1. Taula CLIENTS (Requeriment R1)
-- Representa l'empresa o integradora propietària de les explotacions.
-- -----------------------------------------------------------------------------
CREATE TABLE clients (
    id_client SERIAL PRIMARY KEY,
    nif VARCHAR(20) NOT NULL UNIQUE,
    nom_empresa VARCHAR(100) NOT NULL,
    nom_contacte VARCHAR(100),
    telefon VARCHAR(20),
    email VARCHAR(100) NOT NULL,
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. Taula GRANGES (Requeriment R1 i R3)
-- Cada granja pertany a un únic client (aïllament multitenant).
-- -----------------------------------------------------------------------------
CREATE TABLE granges (
    id_granja SERIAL PRIMARY KEY,
    id_client INT NOT NULL,
    nom_granja VARCHAR(100) NOT NULL,
    codi_explotacio VARCHAR(30) NOT NULL UNIQUE,
    adreca VARCHAR(150),
    poblacio VARCHAR(100),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_granges_client FOREIGN KEY (id_client)
        REFERENCES clients(id_client) ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- 3. Taula NAUS
-- Pavellons físics on s'engreixen els pollastres.
-- -----------------------------------------------------------------------------
CREATE TABLE naus (
    id_nau SERIAL PRIMARY KEY,
    id_granja INT NOT NULL,
    codi_nau VARCHAR(20) NOT NULL,
    capacitat_aus INT NOT NULL CHECK (capacitat_aus > 0),
    longitud_metres NUMERIC(6,2),
    amplada_metres NUMERIC(6,2),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_naus_granja FOREIGN KEY (id_granja)
        REFERENCES granges(id_granja) ON DELETE CASCADE,
    CONSTRAINT uq_granja_codinau UNIQUE (id_granja, codi_nau)
);

-- -----------------------------------------------------------------------------
-- 4. Taula LOTS_CRIANCA
-- Seguiment de cada cicle d'engreix des de l'entrada fins a l'escorxador (~45 dies).
-- -----------------------------------------------------------------------------
CREATE TABLE lots_crianca (
    id_lot SERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_lot VARCHAR(50) NOT NULL UNIQUE,
    data_entrada DATE NOT NULL,
    data_sortida_prevista DATE NOT NULL,
    data_sortida_real DATE,
    num_aus_inicials INT NOT NULL CHECK (num_aus_inicials > 0),
    num_baixes INT NOT NULL DEFAULT 0 CHECK (num_baixes >= 0),
    estat VARCHAR(20) NOT NULL DEFAULT 'en_curs' CHECK (estat IN ('en_curs', 'finalitzat', 'cancel_lat')),
    CONSTRAINT fk_lots_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- 5. Taula SENSORS (Requeriment R4)
-- Dispositius de telemetria (temperatura, humitat per RS485 o silos per LoRaWAN).
-- -----------------------------------------------------------------------------
CREATE TABLE sensors (
    id_sensor SERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_sensor VARCHAR(30) NOT NULL UNIQUE,
    tipus_sensor VARCHAR(30) NOT NULL CHECK (tipus_sensor IN ('temperatura', 'humitat', 'co2', 'pes_silo', 'llum', 'consum_aigua')),
    tecnologia VARCHAR(20) NOT NULL DEFAULT 'RS485' CHECK (tecnologia IN ('RS485', 'LoRaWAN', 'Modbus', 'Analogic')),
    unitat_mesura VARCHAR(15) NOT NULL,
    llindar_minim NUMERIC(6,2),
    llindar_maxim NUMERIC(6,2),
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sensors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 6. Taula ACTUADORS (Requeriment R5)
-- Màquines controlades (ventiladors, calefactors, línies d'alimentació).
-- -----------------------------------------------------------------------------
CREATE TABLE actuadors (
    id_actuador SERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_actuador VARCHAR(30) NOT NULL UNIQUE,
    tipus_actuador VARCHAR(30) NOT NULL CHECK (tipus_actuador IN ('ventilador', 'calefactor', 'il_luminacio', 'menjadora', 'bomba_aigua')),
    mode_operacio VARCHAR(15) NOT NULL DEFAULT 'automatic' CHECK (mode_operacio IN ('automatic', 'manual', 'aturat')),
    estat_actual VARCHAR(5) NOT NULL DEFAULT 'OFF' CHECK (estat_actual IN ('ON', 'OFF')),
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_actuadors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 7. Taula LECTURES_SENSORS (Requeriment R4 i R5)
-- Sèrie temporal amb totes les dades recollides de camp via MQTT.
-- -----------------------------------------------------------------------------
CREATE TABLE lectures_sensors (
    id_lectura BIGSERIAL PRIMARY KEY,
    id_sensor INT NOT NULL,
    valor NUMERIC(8,2) NOT NULL,
    data_hora TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lectures_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 8. Taula REGISTRE_ACTUACIONS
-- Històric d'activacions i aturades d'actuadors, amb motiu i disparador.
-- -----------------------------------------------------------------------------
CREATE TABLE registre_actuacions (
    id_registre BIGSERIAL PRIMARY KEY,
    id_actuador INT NOT NULL,
    accio VARCHAR(10) NOT NULL CHECK (accio IN ('ON', 'OFF')),
    motiu VARCHAR(255) NOT NULL,
    disparat_per_sensor_id INT,
    data_hora TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reg_actuador FOREIGN KEY (id_actuador)
        REFERENCES actuadors(id_actuador) ON DELETE CASCADE,
    CONSTRAINT fk_reg_sensor FOREIGN KEY (disparat_per_sensor_id)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL
);

-- -----------------------------------------------------------------------------
-- 9. Taula ALARMES_INCIDENCIES (Requeriment R7)
-- Incidències crítiques disparades automàticament per triggers PL/pgSQL.
-- -----------------------------------------------------------------------------
CREATE TABLE alarmes_incidencies (
    id_alarma BIGSERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    id_sensor INT,
    nivell_gravetat VARCHAR(15) NOT NULL CHECK (nivell_gravetat IN ('info', 'avis', 'critic')),
    missatge VARCHAR(255) NOT NULL,
    resolta BOOLEAN NOT NULL DEFAULT FALSE,
    data_generacio TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_resolucio TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_alarmes_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE,
    CONSTRAINT fk_alarmes_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL
);

-- -----------------------------------------------------------------------------
-- Índexs de rendiment per a consultes i sèries temporals
-- -----------------------------------------------------------------------------
CREATE INDEX idx_granges_client ON granges(id_client);
CREATE INDEX idx_naus_granja ON naus(id_granja);
CREATE INDEX idx_sensors_nau ON sensors(id_nau);
CREATE INDEX idx_actuadors_nau ON actuadors(id_nau);
CREATE INDEX idx_lectures_sensor_data ON lectures_sensors(id_sensor, data_hora DESC);
CREATE INDEX idx_alarmes_pendents ON alarmes_incidencies(id_nau, resolta);
