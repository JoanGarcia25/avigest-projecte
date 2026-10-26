-- =============================================================================
-- AviGest S.L. — Dades de Prova Realistes (Seed Data per a PostgreSQL 16)
-- Fitxer: bd/sql/03_dades_prova.sql / docker/initdb/03_dades_prova.sql
-- Descripció: 2 clients, 3 granges, naus, lots de criança, sensors, actuadors i lectures.
-- =============================================================================

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
INSERT INTO naus (id_nau, id_granja, codi_nau, capacitat_aus, longitud_metres, amplada_metres) VALUES
-- Bellpuig (2 naus)
(1, 1, 'NAU-01', 12000, 100.00, 14.00),
(2, 1, 'NAU-02', 12000, 100.00, 14.00),
-- Mollerussa (1 nau)
(3, 2, 'NAU-01', 10000, 80.00, 12.50),
-- Alcarràs (2 naus)
(4, 3, 'NAU-01', 15000, 120.00, 15.00),
(5, 3, 'NAU-02', 15000, 120.00, 15.00);

-- -----------------------------------------------------------------------------
-- 4. Inserció de LOTS DE CRIANÇA (Requeriment R6)
-- -----------------------------------------------------------------------------
INSERT INTO lots_crianca (id_lot, id_nau, codi_lot, data_entrada, data_sortida_prevista, num_aus_inicials, num_baixes, estat) VALUES
(1, 1, 'LOT-2026-BP01', '2026-09-25', '2026-11-05', 12000, 250, 'en_curs'),
(2, 2, 'LOT-2026-BP02', '2026-10-10', '2026-11-20', 12000, 80, 'en_curs'),
(3, 3, 'LOT-2026-MO01', '2026-09-15', '2026-10-28', 10000, 190, 'en_curs'),
(4, 4, 'LOT-2026-AL01', '2026-07-01', '2026-08-12', 15000, 310, 'finalitzat');

-- -----------------------------------------------------------------------------
-- 5. Inserció de SENSORS (Requeriment R4, 4.8)
-- -----------------------------------------------------------------------------
INSERT INTO sensors (id_sensor, id_nau, codi_sensor, tipus_sensor, tecnologia, unitat_mesura, llindar_minim, llindar_maxim, actiu) VALUES
-- Nau 1 Bellpuig
(1, 1, 'TEMP-01-NAU01', 'temperatura',   'RS485',   'ºC',  20.00, 31.00, TRUE),
(2, 1, 'HUM-01-NAU01',  'humitat',       'RS485',   '%',   45.00, 70.00, TRUE),
(3, 1, 'SILO-01-NAU01', 'pes_silo',      'LoRaWAN', 'kg',  1000.00, NULL, TRUE),
(4, 1, 'CO2-01-NAU01',  'co2',           'RS485',   'ppm', NULL, 2500.00, TRUE),

-- Nau 2 Bellpuig
(5, 2, 'TEMP-01-NAU02', 'temperatura',   'RS485',   'ºC',  26.00, 33.00, TRUE),
(6, 2, 'HUM-01-NAU02',  'humitat',       'RS485',   '%',   50.00, 75.00, TRUE),
(7, 2, 'SILO-01-NAU02', 'pes_silo',      'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 1 Mollerussa
(8, 3, 'TEMP-02-NAU01', 'temperatura',   'RS485',   'ºC',  19.00, 30.00, TRUE),
(9, 3, 'HUM-02-NAU01',  'humitat',       'RS485',   '%',   45.00, 70.00, TRUE),
(10, 3, 'SILO-02-NAU01', 'pes_silo',     'LoRaWAN', 'kg',  1000.00, NULL, TRUE);

-- -----------------------------------------------------------------------------
-- 6. Inserció d'ACTUADORS (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO actuadors (id_actuador, id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual, actiu) VALUES
-- Nau 1 Bellpuig
(1, 1, 'VENT-01-NAU01', 'ventilador', 'automatic', 'OFF', TRUE),
(2, 1, 'CALEF-01-NAU01', 'calefactor', 'automatic', 'OFF', TRUE),
(3, 1, 'LLUM-01-NAU01', 'il_luminacio', 'automatic', 'ON', TRUE),

-- Nau 2 Bellpuig
(4, 2, 'VENT-01-NAU02', 'ventilador', 'automatic', 'OFF', TRUE),
(5, 2, 'CALEF-01-NAU02', 'calefactor', 'automatic', 'OFF', TRUE),

-- Nau 1 Mollerussa
(6, 3, 'VENT-02-NAU01', 'ventilador', 'automatic', 'OFF', TRUE),
(7, 3, 'CALEF-02-NAU01', 'calefactor', 'automatic', 'OFF', TRUE);

-- -----------------------------------------------------------------------------
-- 7. Inserció de LECTURES DE SENSORS (Simulació de dades inicials)
-- -----------------------------------------------------------------------------
INSERT INTO lectures_sensors (id_sensor, data_hora, valor) VALUES
-- Bellpuig Nau 1: condicions normals
(1, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 23.40),
(2, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 58.20),
(3, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 8400.00),

(1, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 24.10),
(2, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 57.50),
(3, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 8350.00),

(1, CURRENT_TIMESTAMP, 25.00),
(2, CURRENT_TIMESTAMP, 56.80),

-- Bellpuig Nau 2: pollets joves
(5, CURRENT_TIMESTAMP, 29.50),
(6, CURRENT_TIMESTAMP, 62.00),
(7, CURRENT_TIMESTAMP, 12500.00),

-- Mollerussa Nau 1
(8, CURRENT_TIMESTAMP, 22.80),
(9, CURRENT_TIMESTAMP, 54.00),
(10, CURRENT_TIMESTAMP, 5200.00);

-- -----------------------------------------------------------------------------
-- 8. Sincronització de les seqüències de claus primàries (PostgreSQL)
-- -----------------------------------------------------------------------------
SELECT setval('clients_id_client_seq', (SELECT MAX(id_client) FROM clients));
SELECT setval('granges_id_granja_seq', (SELECT MAX(id_granja) FROM granges));
SELECT setval('naus_id_nau_seq', (SELECT MAX(id_nau) FROM naus));
SELECT setval('lots_crianca_id_lot_seq', (SELECT MAX(id_lot) FROM lots_crianca));
SELECT setval('sensors_id_sensor_seq', (SELECT MAX(id_sensor) FROM sensors));
SELECT setval('actuadors_id_actuador_seq', (SELECT MAX(id_actuador) FROM actuadors));
