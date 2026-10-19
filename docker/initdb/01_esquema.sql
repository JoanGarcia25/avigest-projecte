-- =============================================================================
-- AviGest S.L. — Esquema de Base de Dades (MariaDB 10.11+)
-- Fitxer: bd/sql/01_esquema.sql
-- Descripció: Creació de taules, claus primàries, foranes i índexs.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS avigest_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE avigest_db;

-- Desactivar temporalment la comprovació de claus foranes per a un drop net
SET FOREIGN_KEY_CHECKS = 0;
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
-- -----------------------------------------------------------------------------
CREATE TABLE clients (
    id_client INT AUTO_INCREMENT PRIMARY KEY,
    nif VARCHAR(20) NOT NULL UNIQUE,
    nom_empresa VARCHAR(100) NOT NULL,
    nom_contacte VARCHAR(100),
    telefon VARCHAR(20),
    email VARCHAR(100) NOT NULL,
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. Taula GRANGES (Requeriment R1, R3 - Multi-tenant)
-- -----------------------------------------------------------------------------
CREATE TABLE granges (
    id_granja INT AUTO_INCREMENT PRIMARY KEY,
    id_client INT NOT NULL,
    nom_granja VARCHAR(100) NOT NULL,
    codi_explotacio VARCHAR(50) NOT NULL UNIQUE,
    adreca VARCHAR(150),
    poblacio VARCHAR(80),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    data_alta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_granges_client FOREIGN KEY (id_client)
        REFERENCES clients(id_client) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 3. Taula NAUS
-- -----------------------------------------------------------------------------
CREATE TABLE naus (
    id_nau INT AUTO_INCREMENT PRIMARY KEY,
    id_granja INT NOT NULL,
    codi_nau VARCHAR(20) NOT NULL,
    capacitat_aus INT NOT NULL DEFAULT 10000,
    superficie_m2 DECIMAL(8,2) DEFAULT 800.00,
    CONSTRAINT fk_naus_granja FOREIGN KEY (id_granja)
        REFERENCES granges(id_granja) ON DELETE CASCADE,
    CONSTRAINT uk_nau_per_granja UNIQUE (id_granja, codi_nau)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 4. Taula LOTS_CRIANCA (Requeriment R6 - Històric de cicles de pollastres)
-- -----------------------------------------------------------------------------
CREATE TABLE lots_crianca (
    id_lot INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    codi_lot VARCHAR(50) NOT NULL UNIQUE,
    quantitat_inicial INT NOT NULL,
    quantitat_actual INT NOT NULL,
    data_entrada DATE NOT NULL,
    data_prevista_sortida DATE,
    estat ENUM('ACTIU', 'FINALITZAT', 'CANCEL·LAT') NOT NULL DEFAULT 'ACTIU',
    observacions TEXT,
    CONSTRAINT fk_lots_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 5. Taula SENSORS (Requeriment R4, 4.8)
-- -----------------------------------------------------------------------------
CREATE TABLE sensors (
    id_sensor INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    tipus_sensor ENUM('temperatura', 'humitat', 'silo_gra', 'consum_aigua', 'consum_pinso', 'co2') NOT NULL,
    tecnologia ENUM('LoRaWAN', 'RS485') NOT NULL,
    model_hardware VARCHAR(80) DEFAULT 'ESP32-SensorKit',
    llindar_minim DECIMAL(6,2) NULL,
    llindar_maxim DECIMAL(6,2) NULL,
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_sensors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 6. Taula ACTUADORS (Requeriment R5)
-- -----------------------------------------------------------------------------
CREATE TABLE actuadors (
    id_actuador INT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    tipus_actuador ENUM('ventilador', 'calefactor', 'dosificador_aliment', 'alarma_acustica') NOT NULL,
    estat_actual ENUM('OFF', 'ON') NOT NULL DEFAULT 'OFF',
    ubicacio_especifica VARCHAR(100),
    actiu BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_actuadors_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 7. Taula LECTURES_SENSORS (Requeriment R4)
-- -----------------------------------------------------------------------------
CREATE TABLE lectures_sensors (
    id_lectura BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_sensor INT NOT NULL,
    data_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valor DECIMAL(8,2) NOT NULL,
    unitat VARCHAR(10) NOT NULL,
    CONSTRAINT fk_lectures_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Índexs per a agilitzar consultes de lectures per sensor i temps
CREATE INDEX idx_lectures_sensor_temps ON lectures_sensors (id_sensor, data_hora DESC);

-- -----------------------------------------------------------------------------
-- 8. Taula REGISTRE_ACTUACIONS (Requeriment R5 - Traçabilitat d'actuadors)
-- -----------------------------------------------------------------------------
CREATE TABLE registre_actuacions (
    id_actuacio BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_actuador INT NOT NULL,
    data_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    accio ENUM('ACTIVAR', 'DESACTIVAR') NOT NULL,
    motiu VARCHAR(255) NOT NULL,
    disparat_per_sensor_id INT NULL,
    CONSTRAINT fk_reg_actuador FOREIGN KEY (id_actuador)
        REFERENCES actuadors(id_actuador) ON DELETE CASCADE,
    CONSTRAINT fk_reg_sensor FOREIGN KEY (disparat_per_sensor_id)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 9. Taula ALARMES_INCIDENCIES (Requeriment R7)
-- -----------------------------------------------------------------------------
CREATE TABLE alarmes_incidencies (
    id_alarma BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_nau INT NOT NULL,
    id_sensor INT NULL,
    data_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    nivell_criticitat ENUM('INFO', 'WARNING', 'CRITICAL') NOT NULL DEFAULT 'WARNING',
    titol VARCHAR(100) NOT NULL,
    descripcio TEXT,
    resolta BOOLEAN NOT NULL DEFAULT FALSE,
    data_resolucio TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_alarmes_nau FOREIGN KEY (id_nau)
        REFERENCES naus(id_nau) ON DELETE CASCADE,
    CONSTRAINT fk_alarmes_sensor FOREIGN KEY (id_sensor)
        REFERENCES sensors(id_sensor) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_alarmes_resolta ON alarmes_incidencies (resolta, data_hora DESC);
