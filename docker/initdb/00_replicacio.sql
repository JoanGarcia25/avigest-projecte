-- =============================================================================
-- AviGest S.L. — Configuració de l'Usuari de Replicació (MariaDB 10.11 LTS)
-- Fitxer: docker/initdb/00_replicacio.sql
-- =============================================================================

CREATE USER IF NOT EXISTS 'replicator'@'%' IDENTIFIED BY 'replicator_pass_2026';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;

