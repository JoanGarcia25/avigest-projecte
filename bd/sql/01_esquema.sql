-- =============================================================================
-- AviGest S.L. — Esquema de Base de Dades (PostgreSQL 16)
-- Fitxer: bd/sql/01_esquema.sql / docker/initdb/01_esquema.sql
-- Descripció: Creació de taules, claus primàries, foranes, índexs i restriccions.
-- Mòdul: ASIX - Projecte (Requeriments R1 a R7 i Requeriment 4.3)
-- =============================================================================

-- Desactivar/netejar taules existents en ordre invers de dependència
DROP TABLE IF EXISTS auditoria_canvis CASCADE;
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
-- Representa l'empresa o integradora ramadera propietària de les explotacions.
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
-- Cada granja pertany a un únic client (aïllament multitenant per disseny).
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
-- Pavellons físics dins de la granja on s'allotgen els lots d'engreix.
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
-- 4. Taula LOTS_CRIANCA (Requeriment R6)
-- Cicle d'engreix complet (~45 dies) des de l'arribada dels pollets fins a l'escorxador.
-- Permet el seguiment de mortalitat, consum de pinso i càlcul de l'ICA.
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
    pes_mitja_kg NUMERIC(4,2) CHECK (pes_mitja_kg > 0),
    pinso_consumit_kg NUMERIC(10,2) CHECK (pinso_consumit_kg >= 0),
    estat VARCHAR(20) NOT NULL DEFAULT 'en_curs' CHECK (estat IN ('en_curs', 'finalitzat', 'cancel_lat')),
    CONSTRAINT fk_lots_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE RESTRICT
);

-- -----------------------------------------------------------------------------
-- 5. Taula SENSORS (Requeriment R4, 4.8)
-- Dispositius de telemetria ambiental i d'estoc (RS485 Modbus a naus, LoRaWAN a silos).
-- -----------------------------------------------------------------------------
CREATE TABLE sensors (
    id_sensor SERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_sensor VARCHAR(30) NOT NULL UNIQUE,
    tipus_sensor VARCHAR(30) NOT NULL CHECK (tipus_sensor IN ('temperatura', 'humitat', 'co2', 'pes_silo', 'llum', 'consum_aigua', 'amoniac')),
    tecnologia VARCHAR(20) NOT NULL DEFAULT 'RS485' CHECK (tecnologia IN ('RS485', 'LoRaWAN', 'Modbus', 'Analogic', 'Zigbee', 'Virtual')),
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
-- Maquinària de climatització i confort animal (ventiladors, calefactors, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLE actuadors (
    id_actuador SERIAL PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_actuador VARCHAR(30) NOT NULL UNIQUE,
    tipus_actuador VARCHAR(30) NOT NULL CHECK (tipus_actuador IN ('ventilador', 'calefactor', 'il_luminacio', 'menjadora', 'bomba_aigua', 'alarma_sonora', 'nebulitzador')),
    mode_operacio VARCHAR(15) NOT NULL DEFAULT 'automatic' CHECK (mode_operacio IN ('automatic', 'manual', 'aturat')),
    estat_actual VARCHAR(5) NOT NULL DEFAULT 'OFF' CHECK (estat_actual IN ('ON', 'OFF')),
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_actuadors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
);

-- -----------------------------------------------------------------------------
-- 7. Taula LECTURES_SENSORS (Requeriment R4 i R5)
-- Sèrie temporal d'alt volum rebuda del broker MQTT i Edge Computing.
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
-- 8. Taula REGISTRE_ACTUACIONS (Requeriment R5)
-- Registre cronològic d'activacions i desconnexions d'actuadors amb causa auditable.
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
-- Alertes de camp disparades automàticament per triggers PL/pgSQL davant d'anomalies.
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
    observacions_resolucio TEXT,
    CONSTRAINT fk_alarmes_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE,
    CONSTRAINT fk_alarmes_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL
);

-- -----------------------------------------------------------------------------
-- 10. Taula AUDITORIA_CANVIS (Requeriment 4.3 / E2 Sec. 7.2)
-- Registre de traçabilitat de canvis DML (INSERT, UPDATE, DELETE) en taules de gestió.
-- -----------------------------------------------------------------------------
CREATE TABLE auditoria_canvis (
    id_auditoria BIGSERIAL PRIMARY KEY,
    taula VARCHAR(50) NOT NULL,
    operacio VARCHAR(10) NOT NULL CHECK (operacio IN ('INSERT', 'UPDATE', 'DELETE')),
    usuari_bd VARCHAR(50) NOT NULL DEFAULT CURRENT_USER,
    dades_antigues JSONB,
    dades_noves JSONB,
    data_hora TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- Índexs de rendiment per a consultes analítiques i sèries temporals
-- -----------------------------------------------------------------------------
CREATE INDEX idx_granges_client ON granges(id_client);
CREATE INDEX idx_naus_granja ON naus(id_granja);
CREATE INDEX idx_sensors_nau ON sensors(id_nau);
CREATE INDEX idx_actuadors_nau ON actuadors(id_nau);
CREATE INDEX idx_lots_nau_estat ON lots_crianca(id_nau, estat);
CREATE INDEX idx_lectures_sensor_data ON lectures_sensors(id_sensor, data_hora DESC);
CREATE INDEX idx_alarmes_pendents ON alarmes_incidencies(id_nau, resolta);
CREATE INDEX idx_alarmes_gravetat ON alarmes_incidencies(resolta, nivell_gravetat);
CREATE INDEX idx_auditoria_taula_data ON auditoria_canvis(taula, data_hora DESC);
