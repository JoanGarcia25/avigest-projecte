-- =============================================================================
-- AviGest S.L. — Vistes i Consultes Comparatives d'Explotació (MariaDB 10.11 LTS)
-- Fitxer: bd/sql/05_vistes_consultes_comparatives.sql / docker/initdb/05_vistes_consultes_comparatives.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3 i Requeriments Funcionals R3, R4, R6, R7)
-- Responsable: Mariam (Base de Dades, IoT i Automatització)
-- =============================================================================

USE avigest_db;

-- -----------------------------------------------------------------------------
-- 1. VISTA: Comparativa de Rendiment, Mortalitat i ICA de Lots de Criança (R6)
-- Avaluació d'eficiència zootècnica, mortalitat i índex de conversió alimentària.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_comparativa_lots_rendiment AS
SELECT 
    c.id_client,
    c.nom_empresa,
    g.id_granja,
    g.nom_granja,
    n.id_nau,
    n.codi_nau,
    n.capacitat_aus,
    l.id_lot,
    l.codi_lot,
    l.data_entrada,
    l.data_sortida_prevista,
    l.data_sortida_real,
    l.num_aus_inicials,
    l.num_baixes,
    (l.num_aus_inicials - l.num_baixes) AS num_aus_finals_estimades,
    ROUND((l.num_baixes / NULLIF(l.num_aus_inicials, 0) * 100), 2) AS percentatge_mortalitat,
    DATEDIFF(COALESCE(l.data_sortida_real, CURRENT_DATE), l.data_entrada) AS dies_de_cicle,
    l.pes_mitja_kg,
    l.pinso_consumit_kg,
    ROUND(((l.num_aus_inicials - l.num_baixes) * l.pes_mitja_kg), 2) AS kg_carn_produits,
    ROUND((l.pinso_consumit_kg / NULLIF((l.num_aus_inicials - l.num_baixes) * l.pes_mitja_kg, 0)), 2) AS index_conversio_alimentaria_ica,
    l.estat AS estat_lot
FROM lots_crianca l
JOIN naus n ON l.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
ORDER BY l.data_entrada DESC;

-- -----------------------------------------------------------------------------
-- 2. VISTA: Resum Diari i Mitjanes de Telemetria per Nau (R4)
-- Agrupació estadística per dia per avaluar condicions climàtiques i estrès tèrmic.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_resum_diari_climatic AS
SELECT 
    c.id_client,
    c.nom_empresa,
    g.nom_granja,
    n.codi_nau,
    s.tipus_sensor,
    DATE(ls.data_hora) AS data_lectura,
    ROUND(AVG(ls.valor), 2) AS valor_mitja,
    ROUND(MIN(ls.valor), 2) AS valor_minim,
    ROUND(MAX(ls.valor), 2) AS valor_maxim,
    s.unitat_mesura,
    COUNT(ls.id_lectura) AS total_lectures,
    COUNT(DISTINCT a.id_alarma) AS total_alarmes_dia
FROM lectures_sensors ls
JOIN sensors s ON ls.id_sensor = s.id_sensor
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
LEFT JOIN alarmes_incidencies a 
       ON a.id_nau = n.id_nau 
      AND a.id_sensor = s.id_sensor 
      AND DATE(a.data_generacio) = DATE(ls.data_hora)
GROUP BY c.id_client, c.nom_empresa, g.nom_granja, n.id_nau, n.codi_nau, s.id_sensor, s.tipus_sensor, s.unitat_mesura, DATE(ls.data_hora)
ORDER BY data_lectura DESC, g.nom_granja, n.codi_nau;

-- -----------------------------------------------------------------------------
-- 3. VISTA: Monitoratge i Estat de Silos de Gra (R4 i R7)
-- Control del pes de pinso romanent per anticipar comandes logístiques de cooperativa.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_estat_silos_gra AS
SELECT 
    c.id_client,
    c.nom_empresa,
    g.nom_granja,
    n.codi_nau,
    s.codi_sensor AS sensor_silo,
    ls.valor AS kg_actuals,
    s.llindar_minim AS llindar_seguretat_kg,
    ls.data_hora AS darrera_lectura,
    CASE 
        WHEN ls.valor <= 500.0 THEN 'CRÍTIC: Silo buit. Inanició imminent!'
        WHEN ls.valor <= s.llindar_minim THEN 'AVÍS: Demanar pinso urgentment'
        WHEN ls.valor <= (s.llindar_minim * 1.3) THEN 'ATENCIÓ: Nivell baix'
        ELSE 'ÒPTIM'
    END AS diagnostic_estoc
FROM sensors s
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
JOIN lectures_sensors ls ON ls.id_sensor = s.id_sensor
WHERE s.tipus_sensor = 'pes_silo'
  AND ls.id_lectura = (
      SELECT MAX(ls_int.id_lectura)
      FROM lectures_sensors ls_int
      WHERE ls_int.id_sensor = s.id_sensor
  );

-- -----------------------------------------------------------------------------
-- 4. VISTA: Panell Executiu Global per a Direcció i Operacions
-- KPIs en temps real d'infraestructura, aus actives i alarmes no resoltes.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_panell_executiu_global AS
SELECT 
    (SELECT COUNT(*) FROM clients WHERE actiu = TRUE) AS total_clients_actius,
    (SELECT COUNT(*) FROM granges WHERE activa = TRUE) AS total_granges_actives,
    (SELECT COUNT(*) FROM naus WHERE activa = TRUE) AS total_naus_operatives,
    (SELECT COALESCE(SUM(num_aus_inicials - num_baixes), 0) FROM lots_crianca WHERE estat = 'en_curs') AS total_aus_en_criança,
    (SELECT COUNT(*) FROM sensors WHERE actiu = TRUE) AS total_sensors_connectats,
    (SELECT COUNT(*) FROM alarmes_incidencies WHERE resolta = FALSE) AS total_incidencies_pendents,
    (SELECT COUNT(*) FROM alarmes_incidencies WHERE resolta = FALSE AND nivell_gravetat = 'critic') AS alertes_critiques_urgents;

-- Concedir permisos de consulta a avigest_consulta sobre les vistes
GRANT SELECT ON avigest_db.v_comparativa_lots_rendiment TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_resum_diari_climatic TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_estat_silos_gra TO 'avigest_consulta'@'%';
GRANT SELECT ON avigest_db.v_panell_executiu_global TO 'avigest_consulta'@'%';

FLUSH PRIVILEGES;
