-- Revert Migration 000013: Drop Security and Incident Foundation

DROP TABLE IF EXISTS incident_logs;
DROP TABLE IF EXISTS incidents;
DROP TABLE IF EXISTS security_assignments;
ALTER TABLE houses DROP COLUMN IF EXISTS neighborhood_id;
DROP TABLE IF EXISTS neighborhoods;
