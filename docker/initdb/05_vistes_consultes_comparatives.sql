-- =============================================================================
-- AviGest S.L. — Vistes i Consultes Comparatives d'Explotació (PostgreSQL 16)
-- Fitxer: docker/initdb/05_vistes_consultes_comparatives.sql
-- Mòdul: ASIX - Projecte (Requeriment 4.3 i Requeriments Funcionals R4, R6, R7)
-- Responsable: Mariam (Base de Dades, IoT i Automatització)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. VISTA: Comparativa de Rendiment i Mortalitat de Lots de Criança (R6)
-- Permet comparar l'eficiència dels cicles entre naus i granges.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_comparativa_lots_rendiment AS
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
    ROUND((l.num_baixes::numeric / NULLIF(l.num_aus_inicials, 0) * 100), 2) AS percentatge_mortalitat,
    CASE 
        WHEN l.data_sortida_real IS NOT NULL THEN (l.data_sortida_real - l.data_entrada)
        ELSE (CURRENT_DATE - l.data_entrada)
    END AS dies_de_cicle,
    l.estat AS estat_lot
FROM lots_crianca l
JOIN naus n ON l.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
ORDER BY l.data_entrada DESC;

-- -----------------------------------------------------------------------------
-- 2. VISTA: Resum Diari i Mitjanes de Telemetria per Nau (R4)
-- Agrupació per dia per avaluar condicions climàtiques i estrès tèrmic.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_resum_diari_climatic AS
SELECT 
    g.nom_granja,
    n.codi_nau,
    s.tipus_sensor,
    DATE(ls.data_hora) AS data_lectura,
    ROUND(AVG(ls.valor), 2) AS valor_mitja,
    ROUND(MIN(ls.valor), 2) AS valor_minim,
    ROUND(MAX(ls.valor), 2) AS valor_maxim,
    s.unitat_mesura,
    COUNT(ls.id_lectura) AS total_lectures,
    (SELECT COUNT(*) 
     FROM alarmes_incidencies a 
     WHERE a.id_nau = n.id_nau 
       AND a.id_sensor = s.id_sensor 
       AND DATE(a.data_generacio) = DATE(ls.data_hora)) AS total_alarmes_dia
FROM lectures_sensors ls
JOIN sensors s ON ls.id_sensor = s.id_sensor
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
GROUP BY g.nom_granja, n.id_nau, n.codi_nau, s.id_sensor, s.tipus_sensor, s.unitat_mesura, DATE(ls.data_hora)
ORDER BY data_lectura DESC, g.nom_granja, n.codi_nau;

-- -----------------------------------------------------------------------------
-- 3. VISTA: Monitoratge i Estat de Silos de Gra (R4 i R7)
-- Control del pes romanent de pinso per anticipar comandes a la cooperativa.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_estat_silos_gra AS
SELECT 
    c.nom_empresa,
    g.nom_granja,
    n.codi_nau,
    s.codi_sensor AS sensor_silo,
    ls.valor AS kg_actuals,
    s.llindar_minim AS llindar_seguretat_kg,
    ls.data_hora AS darrera_lectura,
    CASE 
        WHEN ls.valor <= s.llindar_minim THEN 'CRÍTIC: Demanar pinso immediatament'
        WHEN ls.valor <= (s.llindar_minim * 1.3) THEN 'ATENCIÓ: Nivell baix'
        ELSE 'ÒPTIM'
    END AS diagnostic_estoc
FROM sensors s
JOIN naus n ON s.id_nau = n.id_nau
JOIN granges g ON n.id_granja = g.id_granja
JOIN clients c ON g.id_client = c.id_client
JOIN LATERAL (
    SELECT valor, data_hora 
    FROM lectures_sensors 
    WHERE id_sensor = s.id_sensor 
    ORDER BY data_hora DESC 
    LIMIT 1
) ls ON TRUE
WHERE s.tipus_sensor = 'pes_silo';

-- -----------------------------------------------------------------------------
-- 4. VISTA: Panell Executiu Global per Client i Granja (R3 i R1)
-- Visió sintètica per a la gerència d'AviGest i propietaris de múltiples granges.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_panell_executiu_global AS
SELECT 
    c.id_client,
    c.nom_empresa,
    COUNT(DISTINCT g.id_granja) AS total_granges,
    COUNT(DISTINCT n.id_nau) AS total_naus,
    COALESCE(SUM(n.capacitat_aus), 0) AS capacitat_total_aus,
    COALESCE(SUM(l.num_aus_inicials - l.num_baixes), 0) AS aus_en_produccio,
    (SELECT COUNT(*) 
     FROM alarmes_incidencies al 
     JOIN naus n2 ON al.id_nau = n2.id_nau
     JOIN granges g2 ON n2.id_granja = g2.id_granja
     WHERE g2.id_client = c.id_client AND al.resolta = FALSE) AS alarmes_pendents_resolucio
FROM clients c
LEFT JOIN granges g ON c.id_client = g.id_client AND g.activa = TRUE
LEFT JOIN naus n ON g.id_granja = n.id_granja AND n.activa = TRUE
LEFT JOIN lots_crianca l ON n.id_nau = l.id_nau AND l.estat = 'en_curs'
GROUP BY c.id_client, c.nom_empresa
ORDER BY c.nom_empresa;
