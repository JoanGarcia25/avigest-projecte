-- =============================================================================
-- AviGest S.L. — Dades de Prova Realistes (Seed Data per a PostgreSQL 16)
-- Fitxer: bd/sql/03_dades_prova.sql / docker/initdb/03_dades_prova.sql
-- Descripció: 2 clients, 3 granges, 5 naus, lots de criança actius i finalitzats,
--             sensors ambientals i de silo, actuadors, lectures i històric d'alarmes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Inserció de CLIENTS (Requeriment R1 i R3)
-- -----------------------------------------------------------------------------
INSERT INTO clients (id_client, nif, nom_empresa, nom_contacte, telefon, email, actiu) VALUES
(1, 'B25123456', 'AgroPonent S.L.', 'Jaume Balaguer', '660112233', 'jbalaguer@agroponent.cat', TRUE),
(2, 'A25987654', 'Avícola del Segrià S.A.', 'Laura Vidal', '670998877', 'lvidal@avicolasegria.cat', TRUE);

-- -----------------------------------------------------------------------------
-- 2. Inserció de GRANGES (Requeriment R1 i R3)
-- Client 1 té 2 granges (Bellpuig i Mollerussa); Client 2 té 1 granja (Alcarràs).
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
-- Alcarràs (2 naus, Client 2)
(4, 3, 'NAU-01', 15000, 120.00, 15.00),
(5, 3, 'NAU-02', 15000, 120.00, 15.00);

-- -----------------------------------------------------------------------------
-- 4. Inserció de LOTS DE CRIANÇA (Requeriment R6)
-- Inclou cicles actius i un cicle tancat amb càlcul d'ICA i mortalitat real.
-- -----------------------------------------------------------------------------
INSERT INTO lots_crianca (id_lot, id_nau, codi_lot, data_entrada, data_sortida_prevista, data_sortida_real, num_aus_inicials, num_baixes, pes_mitja_kg, pinso_consumit_kg, estat) VALUES
(1, 1, 'LOT-2026-BP01', '2026-09-25', '2026-11-05', NULL,         12000, 250, NULL, NULL,      'en_curs'),
(2, 2, 'LOT-2026-BP02', '2026-10-10', '2026-11-20', NULL,         12000,  80, NULL, NULL,      'en_curs'),
(3, 3, 'LOT-2026-MO01', '2026-09-15', '2026-10-28', NULL,         10000, 190, NULL, NULL,      'en_curs'),
(4, 4, 'LOT-2026-AL01', '2026-07-01', '2026-08-12', '2026-08-11', 15000, 310, 2.45, 61250.00, 'finalitzat'),
(5, 4, 'LOT-2026-AL02', '2026-09-20', '2026-11-04', NULL,         15000, 185, NULL, NULL,      'en_curs'),
(6, 5, 'LOT-2026-AL03', '2026-10-01', '2026-11-15', NULL,         15000,  95, NULL, NULL,      'en_curs');

-- -----------------------------------------------------------------------------
-- 5. Inserció de SENSORS (Requeriment R4, 4.8)
-- -----------------------------------------------------------------------------
INSERT INTO sensors (id_sensor, id_nau, codi_sensor, tipus_sensor, tecnologia, unitat_mesura, llindar_minim, llindar_maxim, actiu) VALUES
-- Nau 1 Bellpuig (Client 1)
(1,  1, 'TEMP-01-NAU01', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(2,  1, 'HUM-01-NAU01',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(3,  1, 'SILO-01-NAU01', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),
(4,  1, 'CO2-01-NAU01',  'co2',         'RS485',   'ppm', NULL, 2500.00, TRUE),

-- Nau 2 Bellpuig (Client 1)
(5,  2, 'TEMP-01-NAU02', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(6,  2, 'HUM-01-NAU02',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(7,  2, 'SILO-01-NAU02', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 1 Mollerussa (Client 1)
(8,  3, 'TEMP-02-NAU01', 'temperatura', 'RS485',   'ºC',  19.00, 30.00, TRUE),
(9,  3, 'HUM-02-NAU01',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(10, 3, 'SILO-02-NAU01', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 1 Alcarràs (Client 2)
(11, 4, 'TEMP-03-NAU01', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(12, 4, 'HUM-03-NAU01',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(13, 4, 'CO2-03-NAU01',  'co2',         'RS485',   'ppm', NULL, 2500.00, TRUE),
(14, 4, 'SILO-03-NAU01', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 2 Alcarràs (Client 2)
(15, 5, 'TEMP-03-NAU02', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(16, 5, 'HUM-03-NAU02',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(17, 5, 'SILO-03-NAU02', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE);

-- -----------------------------------------------------------------------------
-- 6. Inserció d'ACTUADORS (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO actuadors (id_actuador, id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual, actiu) VALUES
-- Nau 1 Bellpuig (Client 1)
(1,  1, 'VENT-01-NAU01',  'ventilador',   'automatic', 'OFF', TRUE),
(2,  1, 'CALEF-01-NAU01', 'calefactor',   'automatic', 'OFF', TRUE),
(3,  1, 'LLUM-01-NAU01',  'il_luminacio', 'automatic', 'ON',  TRUE),

-- Nau 2 Bellpuig (Client 1)
(4,  2, 'VENT-01-NAU02',  'ventilador',   'automatic', 'ON',  TRUE),
(5,  2, 'CALEF-01-NAU02', 'calefactor',   'automatic', 'OFF', TRUE),

-- Nau 1 Mollerussa (Client 1)
(6,  3, 'VENT-02-NAU01',  'ventilador',   'automatic', 'OFF', TRUE),
(7,  3, 'CALEF-02-NAU01', 'calefactor',   'automatic', 'OFF', TRUE),

-- Nau 1 Alcarràs (Client 2)
(8,  4, 'VENT-03-NAU01',  'ventilador',   'automatic', 'OFF', TRUE),
(9,  4, 'CALEF-03-NAU01', 'calefactor',   'automatic', 'OFF', TRUE),
(10, 4, 'LLUM-03-NAU01',  'il_luminacio', 'automatic', 'ON',  TRUE),

-- Nau 2 Alcarràs (Client 2)
(11, 5, 'VENT-03-NAU02',  'ventilador',   'automatic', 'OFF', TRUE),
(12, 5, 'CALEF-03-NAU02', 'calefactor',   'automatic', 'OFF', TRUE);

-- -----------------------------------------------------------------------------
-- 7. Inserció de LECTURES DE SENSORS (Simulació de dades inicials)
-- -----------------------------------------------------------------------------
INSERT INTO lectures_sensors (id_sensor, data_hora, valor) VALUES
-- Bellpuig Nau 1 (Client 1): Condicions estables
(1, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 23.40),
(2, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 58.20),
(3, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 8400.00),
(4, CURRENT_TIMESTAMP - INTERVAL '60 minutes', 1150.00),

(1, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 24.10),
(2, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 57.50),
(3, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 8350.00),
(4, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 1200.00),

(1, CURRENT_TIMESTAMP, 24.80),
(2, CURRENT_TIMESTAMP, 56.80),
(4, CURRENT_TIMESTAMP, 1220.00),

-- Bellpuig Nau 2 (Client 1): Sobretemperatura que activa ventilador
(5, CURRENT_TIMESTAMP - INTERVAL '15 minutes', 31.80),
(6, CURRENT_TIMESTAMP - INTERVAL '15 minutes', 62.00),
(7, CURRENT_TIMESTAMP - INTERVAL '15 minutes', 12500.00),
(5, CURRENT_TIMESTAMP, 33.40),

-- Mollerussa Nau 1 (Client 1): Silo crític sota llindar de 1000 kg
(8,  CURRENT_TIMESTAMP - INTERVAL '30 minutes', 22.80),
(9,  CURRENT_TIMESTAMP - INTERVAL '30 minutes', 54.00),
(10, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 920.00),
(8,  CURRENT_TIMESTAMP, 23.10),
(10, CURRENT_TIMESTAMP, 890.00),

-- Alcarràs Nau 1 (Client 2): Valors òptims
(11, CURRENT_TIMESTAMP - INTERVAL '45 minutes', 23.80),
(12, CURRENT_TIMESTAMP - INTERVAL '45 minutes', 55.00),
(13, CURRENT_TIMESTAMP - INTERVAL '45 minutes', 1100.00),
(14, CURRENT_TIMESTAMP - INTERVAL '45 minutes', 9400.00),
(11, CURRENT_TIMESTAMP, 24.20),
(13, CURRENT_TIMESTAMP, 1150.00),

-- Alcarràs Nau 2 (Client 2): Valors òptims
(15, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 24.50),
(16, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 58.00),
(17, CURRENT_TIMESTAMP - INTERVAL '30 minutes', 11200.00),
(15, CURRENT_TIMESTAMP, 24.90);

-- -----------------------------------------------------------------------------
-- 8. Inserció d'ALARMES I INCIDÈNCIES HISTÒRIQUES (Requeriment R7)
-- -----------------------------------------------------------------------------
INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio, data_resolucio, observacions_resolucio) VALUES
-- Alarma resolta passada a Nau 1 Bellpuig
(1, 4, 'avis', 'AVÍS CO2: Concentració de CO2 a 2650 ppm detectada', TRUE,
 CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '40 minutes',
 'Ventilació forçada activada manualment; ambient normalitzat.'),

-- Alarma crítica activa a Nau 2 Bellpuig (cop de calor)
(2, 5, 'critic', 'ALERTA CRÍTICA: Cop de calor imminent. Temperatura: 33.40 ºC', FALSE,
 CURRENT_TIMESTAMP - INTERVAL '10 minutes', NULL, NULL),

-- Avís de silo actiu a Nau 1 Mollerussa
(3, 10, 'avis', 'AVÍS SILO: Nivell de pinso sota el llindar de seguretat (890.00 kg). Demanar camió de pinso.', FALSE,
 CURRENT_TIMESTAMP - INTERVAL '30 minutes', NULL, NULL);

-- -----------------------------------------------------------------------------
-- 9. Inserció de REGISTRE D'ACTUACIONS HISTÒRIC (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora) VALUES
(4, 'ON', 'Temperatura detectada (31.80 ºC) supera llindar màxim (31.00 ºC)', 5, CURRENT_TIMESTAMP - INTERVAL '15 minutes'),
(1, 'ON', 'Renovació periòdica programada d''aire', NULL, CURRENT_TIMESTAMP - INTERVAL '2 hours'),
(1, 'OFF', 'Aturada programada en finalitzar cicle de ventilació', NULL, CURRENT_TIMESTAMP - INTERVAL '1 hour 45 minutes');

-- -----------------------------------------------------------------------------
-- 10. Sincronització de les seqüències de claus primàries (PostgreSQL)
-- -----------------------------------------------------------------------------
SELECT setval('clients_id_client_seq', COALESCE((SELECT MAX(id_client) FROM clients), 1));
SELECT setval('granges_id_granja_seq', COALESCE((SELECT MAX(id_granja) FROM granges), 1));
SELECT setval('naus_id_nau_seq', COALESCE((SELECT MAX(id_nau) FROM naus), 1));
SELECT setval('lots_crianca_id_lot_seq', COALESCE((SELECT MAX(id_lot) FROM lots_crianca), 1));
SELECT setval('sensors_id_sensor_seq', COALESCE((SELECT MAX(id_sensor) FROM sensors), 1));
SELECT setval('actuadors_id_actuador_seq', COALESCE((SELECT MAX(id_actuador) FROM actuadors), 1));
SELECT setval('lectures_sensors_id_lectura_seq', COALESCE((SELECT MAX(id_lectura) FROM lectures_sensors), 1));
SELECT setval('alarmes_incidencies_id_alarma_seq', COALESCE((SELECT MAX(id_alarma) FROM alarmes_incidencies), 1));
SELECT setval('registre_actuacions_id_registre_seq', COALESCE((SELECT MAX(id_registre) FROM registre_actuacions), 1));
SELECT setval('auditoria_canvis_id_auditoria_seq', COALESCE((SELECT MAX(id_auditoria) FROM auditoria_canvis), 1));
