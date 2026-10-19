-- =============================================================================
-- AviGest S.L. — Dades de Prova Realistes (Seed Data)
-- Fitxer: bd/sql/03_dades_prova.sql
-- Descripció: 2 clients, 3 granges, naus, lots de criança, sensors, actuadors i lectures.
-- =============================================================================

USE avigest_db;

-- -----------------------------------------------------------------------------
-- 1. Inserció de CLIENTS (Requeriment R1)
-- -----------------------------------------------------------------------------
INSERT INTO clients (id_client, nif, nom_empresa, nom_contacte, telefon, email, actiu) VALUES
(1, 'B25123456', 'AgroPonent S.L.', 'Jaume Balaguer', '660112233', 'jbalaguer@agroponent.cat', TRUE),
(2, 'A25987654', 'Avícola del Segrià S.A.', 'Laura Vidal', '670998877', 'lvidal@avicolasegria.cat', TRUE);

-- -----------------------------------------------------------------------------
-- 2. Inserció de GRANGES (Requeriment R1, R3 - Client 1 té 2 granges, Client 2 en té 1)
-- -----------------------------------------------------------------------------
INSERT INTO granges (id_granja, id_client, nom_granja, codi_explotacio, adreca, poblacio, activa) VALUES
(1, 1, 'Granja Ponent Bellpuig', 'ES250480001', 'Camí de Seana s/n', 'Bellpuig', TRUE),
(2, 1, 'Granja Ponent Mollerussa', 'ES251370002', 'Partida Vinars parc. 12', 'Mollerussa', TRUE),
(3, 2, 'Granja Segrià Alcarràs', 'ES250110003', 'Carretera de Vallmanya km 3', 'Alcarràs', TRUE);

-- -----------------------------------------------------------------------------
-- 3. Inserció de NAUS
-- -----------------------------------------------------------------------------
INSERT INTO naus (id_nau, id_granja, codi_nau, capacitat_aus, superficie_m2) VALUES
-- Bellpuig (2 naus)
(1, 1, 'NAU-01', 12000, 950.00),
(2, 1, 'NAU-02', 12000, 950.00),
-- Mollerussa (1 nau)
(3, 2, 'NAU-01', 10000, 800.00),
-- Alcarràs (2 naus)
(4, 3, 'NAU-01', 15000, 1100.00),
(5, 3, 'NAU-02', 15000, 1100.00);

-- -----------------------------------------------------------------------------
-- 4. Inserció de LOTS DE CRIANÇA (Requeriment R6)
-- -----------------------------------------------------------------------------
INSERT INTO lots_crianca (id_lot, id_nau, codi_lot, quantitat_inicial, quantitat_actual, data_entrada, data_prevista_sortida, estat, observacions) VALUES
(1, 1, 'LOT-2026-BP01', 12000, 11750, '2026-09-25', '2026-11-05', 'ACTIU', 'Raça Ross 308. Baixes dins de la normalitat (2.08%).'),
(2, 2, 'LOT-2026-BP02', 12000, 11920, '2026-10-10', '2026-11-20', 'ACTIU', 'Pollins de 9 dies. Temperatura objectiu: 29ºC.'),
(3, 3, 'LOT-2026-MO01', 10000, 9810, '2026-09-15', '2026-10-28', 'ACTIU', 'Engreix final, consum d aigua elevat.'),
(4, 4, 'LOT-2026-AL01', 15000, 0, '2026-07-01', '2026-08-12', 'FINALITZAT', 'Cicle finalitzat amb èxit. Buidat sanitari completat.');

-- -----------------------------------------------------------------------------
-- 5. Inserció de SENSORS (Requeriment R4, 4.8)
-- -----------------------------------------------------------------------------
INSERT INTO sensors (id_sensor, id_nau, tipus_sensor, tecnologia, model_hardware, llindar_minim, llindar_maxim, actiu) VALUES
-- Nau 1 Bellpuig
(1, 1, 'temperatura', 'RS485', 'Modbus-DHT22-Ind', 20.00, 31.00, TRUE),
(2, 1, 'humitat', 'RS485', 'Modbus-DHT22-Ind', 45.00, 70.00, TRUE),
(3, 1, 'silo_gra', 'LoRaWAN', 'LoRa-WeightScale-Silo', 1500.00, 15000.00, TRUE),
(4, 1, 'consum_aigua', 'RS485', 'PulseMeter-RS485', 100.00, 3500.00, TRUE),

-- Nau 2 Bellpuig
(5, 2, 'temperatura', 'RS485', 'Modbus-DHT22-Ind', 26.00, 33.00, TRUE),
(6, 2, 'humitat', 'RS485', 'Modbus-DHT22-Ind', 50.00, 75.00, TRUE),
(7, 2, 'silo_gra', 'LoRaWAN', 'LoRa-WeightScale-Silo', 1500.00, 15000.00, TRUE),

-- Nau 1 Mollerussa
(8, 3, 'temperatura', 'RS485', 'Modbus-DHT22-Ind', 19.00, 30.00, TRUE),
(9, 3, 'humitat', 'RS485', 'Modbus-DHT22-Ind', 45.00, 70.00, TRUE),
(10, 3, 'silo_gra', 'LoRaWAN', 'LoRa-WeightScale-Silo', 1500.00, 15000.00, TRUE);

-- -----------------------------------------------------------------------------
-- 6. Inserció d'ACTUADORS (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO actuadors (id_actuador, id_nau, tipus_actuador, estat_actual, ubicacio_especifica, actiu) VALUES
-- Nau 1 Bellpuig
(1, 1, 'ventilador', 'OFF', 'Bateria Ventiladors Façana Nord', TRUE),
(2, 1, 'calefactor', 'OFF', 'Canó de combustió estanca GLP', TRUE),
(3, 1, 'dosificador_aliment', 'ON', 'Línia de menjadores automàtiques', TRUE),
(4, 1, 'alarma_acustica', 'OFF', 'Sirena exterior nau', TRUE),

-- Nau 2 Bellpuig
(5, 2, 'ventilador', 'OFF', 'Bateria Ventiladors Façana Nord', TRUE),
(6, 2, 'calefactor', 'OFF', 'Aeroterm radiant', TRUE),

-- Nau 1 Mollerussa
(7, 3, 'ventilador', 'OFF', 'Extractor de túnel', TRUE),
(8, 3, 'calefactor', 'OFF', 'Canó radiant', TRUE);

-- -----------------------------------------------------------------------------
-- 7. Inserció de LECTURES DE SENSORS (Simulació de dades normals)
-- -----------------------------------------------------------------------------
INSERT INTO lectures_sensors (id_sensor, data_hora, valor, unitat) VALUES
-- Bellpuig Nau 1: condicions normals
(1, '2026-10-19 08:00:00', 23.40, 'ºC'),
(2, '2026-10-19 08:00:00', 58.20, '%'),
(3, '2026-10-19 08:00:00', 8400.00, 'kg'),
(4, '2026-10-19 08:00:00', 850.00, 'L'),

(1, '2026-10-19 08:30:00', 24.10, 'ºC'),
(2, '2026-10-19 08:30:00', 57.50, '%'),
(3, '2026-10-19 08:30:00', 8350.00, 'kg'),

(1, '2026-10-19 09:00:00', 25.00, 'ºC'),
(2, '2026-10-19 09:00:00', 56.80, '%'),

-- Bellpuig Nau 2: pollets joves, temperatura més calenta
(5, '2026-10-19 09:00:00', 29.50, 'ºC'),
(6, '2026-10-19 09:00:00', 62.00, '%'),
(7, '2026-10-19 09:00:00', 12500.00, 'kg'),

-- Mollerussa Nau 1
(8, '2026-10-19 09:00:00', 22.80, 'ºC'),
(9, '2026-10-19 09:00:00', 54.00, '%'),
(10, '2026-10-19 09:00:00', 5200.00, 'kg');
