-- =============================================================================
-- AviGest S.L. — Dades de Prova Realistes (Seed Data per a MariaDB 10.11 LTS)
-- Fitxer: bd/sql/03_dades_prova.sql / docker/initdb/03_dades_prova.sql
-- Descripció: 2 clients, 3 granges, 5 naus, lots de criança actius i finalitzats,
--             sensors ambientals i de silo, actuadors, lectures i històric d'alarmes.
-- =============================================================================

USE avigest_db;

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
(8,  2, 'CO2-01-NAU02',  'co2',         'RS485',   'ppm', NULL, 2500.00, TRUE),

-- Nau 1 Mollerussa (Client 1)
(9,  3, 'TEMP-02-NAU01', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(10, 3, 'SILO-02-NAU01', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 1 Alcarràs (Client 2)
(11, 4, 'TEMP-03-NAU01', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(12, 4, 'HUM-03-NAU01',  'humitat',     'RS485',   '%',   45.00, 70.00, TRUE),
(13, 4, 'SILO-03-NAU01', 'pes_silo',    'LoRaWAN', 'kg',  1000.00, NULL, TRUE),

-- Nau 2 Alcarràs (Client 2)
(14, 5, 'TEMP-03-NAU02', 'temperatura', 'RS485',   'ºC',  20.00, 31.00, TRUE),
(15, 5, 'CO2-03-NAU02',  'co2',         'RS485',   'ppm', NULL, 2500.00, TRUE);

-- -----------------------------------------------------------------------------
-- 6. Inserció d'ACTUADORS (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO actuadors (id_actuador, id_nau, codi_actuador, tipus_actuador, mode_operacio, estat_actual, actiu) VALUES
-- Nau 1 Bellpuig
(1, 1, 'VENT-01-NAU01',  'ventilador', 'automatic', 'OFF', TRUE),
(2, 1, 'VENT-02-NAU01',  'ventilador', 'automatic', 'OFF', TRUE),
(3, 1, 'CALEF-01-NAU01', 'calefactor', 'automatic', 'OFF', TRUE),

-- Nau 2 Bellpuig
(4, 2, 'VENT-01-NAU02',  'ventilador', 'automatic', 'ON',  TRUE),
(5, 2, 'CALEF-01-NAU02', 'calefactor', 'automatic', 'OFF', TRUE),

-- Nau 1 Mollerussa
(6, 3, 'VENT-01-NAU01',  'ventilador', 'automatic', 'OFF', TRUE),
(7, 3, 'CALEF-01-NAU01', 'calefactor', 'automatic', 'OFF', TRUE),

-- Nau 1 Alcarràs (Client 2)
(8, 4, 'VENT-01-NAU01',  'ventilador', 'automatic', 'OFF', TRUE),
(9, 4, 'CALEF-01-NAU01', 'calefactor', 'automatic', 'OFF', TRUE),

-- Nau 2 Alcarràs (Client 2)
(10, 5, 'VENT-01-NAU02', 'ventilador', 'automatic', 'OFF', TRUE);

-- -----------------------------------------------------------------------------
-- 7. Inserció de LECTURES DE SENSORS (Sèrie temporal simulada)
-- -----------------------------------------------------------------------------
INSERT INTO lectures_sensors (id_sensor, data_hora, valor) VALUES
-- Dades normals a Nau 1 Bellpuig (temp entre 24 i 25.5 ºC)
(1, NOW() - INTERVAL 120 MINUTE, 24.20),
(1, NOW() - INTERVAL 90 MINUTE,  24.80),
(1, NOW() - INTERVAL 60 MINUTE,  25.10),
(1, NOW() - INTERVAL 30 MINUTE,  25.40),
(1, NOW(),                       24.90),

-- Humitat a Nau 1 Bellpuig (55-60%)
(2, NOW() - INTERVAL 60 MINUTE,  58.20),
(2, NOW() - INTERVAL 30 MINUTE,  59.00),
(2, NOW(),                       57.50),

-- Silo a Nau 1 Bellpuig (8.500 kg - Nivell òptim)
(3, NOW() - INTERVAL 12 HOUR,   8750.00),
(3, NOW() - INTERVAL 6 HOUR,    8620.00),
(3, NOW(),                      8500.00),

-- CO2 a Nau 1 Bellpuig (1.100 - 1.300 ppm - Òptim)
(4, NOW() - INTERVAL 60 MINUTE, 1150.00),
(4, NOW(),                      1220.00),

-- Nau 2 Bellpuig: Sobreescalfament simulat (> 31ºC, alarma i ventilador disparat)
(5, NOW() - INTERVAL 45 MINUTE, 29.50),
(5, NOW() - INTERVAL 30 MINUTE, 31.20),
(5, NOW() - INTERVAL 15 MINUTE, 32.80),
(5, NOW(),                       33.40),

-- Nau 1 Mollerussa: Silo sota el llindar de seguretat (890 kg < 1000 kg)
(10, NOW() - INTERVAL 24 HOUR,  1400.00),
(10, NOW() - INTERVAL 12 HOUR,  1100.00),
(10, NOW() - INTERVAL 2 HOUR,    950.00),
(10, NOW(),                      890.00),

-- Nau 1 Alcarràs (Client 2): Telemetria normal
(11, NOW() - INTERVAL 30 MINUTE, 23.80),
(11, NOW(),                      24.10),
(13, NOW(),                     12400.00),

-- Nau 2 Alcarràs (Client 2)
(14, NOW() - INTERVAL 15 MINUTE, 25.10),
(15, NOW(),                      24.90);

-- -----------------------------------------------------------------------------
-- 8. Inserció d'ALARMES I INCIDÈNCIES HISTÒRIQUES (Requeriment R7)
-- -----------------------------------------------------------------------------
INSERT INTO alarmes_incidencies (id_nau, id_sensor, nivell_gravetat, missatge, resolta, data_generacio, data_resolucio, observacions_resolucio) VALUES
-- Alarma resolta passada a Nau 1 Bellpuig
(1, 4, 'avis', 'AVÍS CO2: Concentració de CO2 a 2650 ppm detectada', TRUE,
 NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 3 DAY + INTERVAL 40 MINUTE,
 'Ventilació forçada activada manualment; ambient normalitzat.'),

-- Alarma crítica activa a Nau 2 Bellpuig (cop de calor)
(2, 5, 'critic', 'ALERTA CRÍTICA: Cop de calor imminent. Temperatura: 33.40 ºC', FALSE,
 NOW() - INTERVAL 10 MINUTE, NULL, NULL),

-- Avís de silo actiu a Nau 1 Mollerussa
(3, 10, 'avis', 'AVÍS SILO: Nivell de pinso sota el llindar de seguretat (890.00 kg). Demanar camió de pinso.', FALSE,
 NOW() - INTERVAL 30 MINUTE, NULL, NULL);

-- -----------------------------------------------------------------------------
-- 9. Inserció de REGISTRE D'ACTUACIONS HISTÒRIC (Requeriment R5)
-- -----------------------------------------------------------------------------
INSERT INTO registre_actuacions (id_actuador, accio, motiu, disparat_per_sensor_id, data_hora) VALUES
(4, 'ON', 'Temperatura detectada (31.80 ºC) supera llindar màxim (31.00 ºC)', 5, NOW() - INTERVAL 15 MINUTE),
(1, 'ON', 'Renovació periòdica programada d aire', NULL, NOW() - INTERVAL 2 HOUR),
(1, 'OFF', 'Aturada programada en finalitzar cicle de ventilació', NULL, NOW() - INTERVAL 105 MINUTE);
