-- =============================================================================
-- AviGest S.L. — Esquema de Base de Dades (MariaDB 10.11 LTS)
-- Fitxer: bd/sql/01_esquema.sql / docker/initdb/01_esquema.sql
-- Descripció: Creació de base de dades, taules, claus primàries, foranes,
--             índexs i restriccions InnoDB.
-- Mòdul: ASIX - Projecte (Requeriments R1 a R7 i Requeriment 4.3)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS avigest_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE avigest_db;

-- Desactivar verificació de claus foranes durant la neteja inicial
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS auditoria_canvis;
DROP TABLE IF EXISTS alarmes_incidencies;
DROP TABLE IF EXISTS registre_actuacions;
DROP TABLE IF EXISTS lectures_sensors;
DROP TABLE IF EXISTS actuadors;
DROP TABLE IF EXISTS sensors;
DROP TABLE IF EXISTS lots_crianca;
DROP TABLE IF EXISTS naus;
DROP TABLE IF EXISTS granges;
DROP TABLE IF EXISTS clients;

SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- 1. Taula CLIENTS (Requeriment R1)
-- Representa l'empresa o integradora ramadera propietària de les explotacions.
-- -----------------------------------------------------------------------------
CREATE TABLE clients (
    id_client INT AUTO_INCREMENT PRIMARY KEY,
    nif VARCHAR(20) NOT NULL UNIQUE,
    nom_empresa VARCHAR(100) NOT NULL,
    nom_contacte VARCHAR(100) NULL,
    telefon VARCHAR(20) NULL,
    email VARCHAR(100) NOT NULL,
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. Taula GRANGES (Requeriment R1 i R3)
-- Cada granja pertany a un únic client (aïllament multitenant per disseny).
-- -----------------------------------------------------------------------------
CREATE TABLE granges (
    id_granja INT AUTO_INCREMENT PRIMARY KEY,
    id_client INT NOT NULL,
    nom_granja VARCHAR(100) NOT NULL,
    codi_explotacio VARCHAR(30) NOT NULL UNIQUE,
    adreca VARCHAR(150) NULL,
    poblacio VARCHAR(100) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_granges_client FOREIGN KEY (id_client)
        REFERENCES clients(id_client) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 3. Taula NAUS (Requeriment R2 i R6)
-- Pavellons físics dins de la granja on s'allotgen els lots d'engreix.
-- -----------------------------------------------------------------------------
CREATE TABLE naus (
    id_nau INT AUTO_INCREMENT PRIMARY KEY,
    id_granja INT NOT NULL,
    codi_nau VARCHAR(20) NOT NULL,
    capacitat_aus INT NOT NULL CHECK (capacitat_aus > 0),
    longitud_metres DECIMAL(6,2) NULL,
    amplada_metres DECIMAL(6,2) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_naus_granja FOREIGN KEY (id_granja)
        REFERENCES granges(id_granja) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_granja_codinau UNIQUE (id_granja, codi_nau)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4. Taula LOTS_CRIANCA (Requeriment R6)
-- Cicle d'engreix complet (~45 dies) des de l'arribada dels pollets fins a l'escorxador.
-- Permet el seguiment de mortalitat, consum de pinso i càlcul de l'ICA.
-- -----------------------------------------------------------------------------
CREATE TABLE lots_crianca (
    id_lot INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_lot VARCHAR(50) NOT NULL UNIQUE,
    data_entrada DATE NOT NULL,
    data_sortida_prevista DATE NOT NULL,
    data_sortida_real DATE NULL,
    num_aus_inicials INT NOT NULL CHECK (num_aus_inicials > 0),
    num_baixes INT NOT NULL DEFAULT 0 CHECK (num_baixes >= 0),
    pes_mitja_kg DECIMAL(4,2) NULL CHECK (pes_mitja_kg IS NULL OR pes_mitja_kg > 0),
    pinso_consumit_kg DECIMAL(10,2) NULL CHECK (pinso_consumit_kg IS NULL OR pinso_consumit_kg >= 0),
    estat ENUM('en_curs', 'finalitzat', 'cancel_lat') NOT NULL DEFAULT 'en_curs',
    CONSTRAINT fk_lots_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5. Taula SENSORS (Requeriment R4, 4.8)
-- Dispositius de telemetria ambiental i d'estoc (RS485 Modbus a naus, LoRaWAN a silos).
-- -----------------------------------------------------------------------------
CREATE TABLE sensors (
    id_sensor INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_sensor VARCHAR(30) NOT NULL UNIQUE,
    tipus_sensor ENUM('temperatura', 'humitat', 'co2', 'pes_silo', 'llum', 'consum_aigua', 'amoniac') NOT NULL,
    tecnologia ENUM('RS485', 'LoRaWAN', 'Modbus', 'Analogic', 'Zigbee', 'Virtual') NOT NULL DEFAULT 'RS485',
    unitat_mesura VARCHAR(15) NOT NULL,
    llindar_minim DECIMAL(6,2) NULL,
    llindar_maxim DECIMAL(6,2) NULL,
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sensors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 6. Taula ACTUADORS (Requeriment R5)
-- Maquinària de climatització i confort animal (ventiladors, calefactors, etc.).
-- -----------------------------------------------------------------------------
CREATE TABLE actuadors (
    id_actuador INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_actuador VARCHAR(30) NOT NULL UNIQUE,
    tipus_actuador ENUM('ventilador', 'calefactor', 'il_luminacio', 'menjadora', 'bomba_aigua', 'alarma_sonora', 'nebulitzador') NOT NULL,
    mode_operacio ENUM('automatic', 'manual', 'aturat') NOT NULL DEFAULT 'automatic',
    estat_actual ENUM('ON', 'OFF') NOT NULL DEFAULT 'OFF',
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_actuadors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 7. Taula LECTURES_SENSORS (Requeriment R4 i R5)
-- Sèrie temporal d'alt volum rebuda del broker MQTT Mosquitto i Edge Computing.
-- -----------------------------------------------------------------------------
CREATE TABLE lectures_sensors (
    id_lectura BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_sensor INT NOT NULL,
    valor DECIMAL(8,2) NOT NULL,
    data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lectures_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 8. Taula REGISTRE_ACTUACIONS (Requeriment R5)
-- Registre cronològic d'activacions i desconnexions d'actuadors amb causa auditable.
-- -----------------------------------------------------------------------------
CREATE TABLE registre_actuacions (
    id_registre BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_actuador INT NOT NULL,
    accio ENUM('ON', 'OFF') NOT NULL,
    motiu VARCHAR(255) NOT NULL,
    disparat_per_sensor_id INT NULL,
    data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reg_actuador FOREIGN KEY (id_actuador)
        REFERENCES actuadors(id_actuador) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reg_sensor FOREIGN KEY (disparat_per_sensor_id)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 9. Taula ALARMES_INCIDENCIES (Requeriment R7)
-- Alertes de camp disparades automàticament per triggers davant d'anomalies tèrmiques o CO2.
-- -----------------------------------------------------------------------------
CREATE TABLE alarmes_incidencies (
    id_alarma BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    id_sensor INT NULL,
    nivell_gravetat ENUM('info', 'avis', 'critic') NOT NULL,
    missatge VARCHAR(255) NOT NULL,
    resolta BOOLEAN NOT NULL DEFAULT FALSE,
    data_generacio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_resolucio DATETIME NULL,
    observacions_resolucio TEXT NULL,
    CONSTRAINT fk_alarmes_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_alarmes_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 10. Taula AUDITORIA_CANVIS (Requeriment 4.3 / E2 Sec. 7.2)
-- Registre de traçabilitat de canvis DML (INSERT, UPDATE, DELETE) en format JSON.
-- -----------------------------------------------------------------------------
CREATE TABLE auditoria_canvis (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    taula VARCHAR(50) NOT NULL,
    operacio ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    usuari_bd VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
    dades_antigues JSON NULL,
    dades_noves JSON NULL,
    data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
