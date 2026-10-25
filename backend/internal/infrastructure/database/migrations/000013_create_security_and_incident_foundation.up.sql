-- Migration 000013: Create Security Account, Assignments, Neighborhoods, and Emergency Incidents Foundation

-- 1. Insert SECURITY canonical role
INSERT INTO roles (name) VALUES ('SECURITY') ON CONFLICT (name) DO NOTHING;

-- 2. Neighborhoods (Perumahan / Lingkungan)
CREATE TABLE IF NOT EXISTS neighborhoods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed default neighborhood
INSERT INTO neighborhoods (id, name, code, address)
VALUES (1, 'Lingkungan TetangGo 01', 'RT01-DEFAULT', 'Komplek TetangGo Blok A-B-C')
ON CONFLICT (id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('neighborhoods', 'id'), COALESCE((SELECT MAX(id) FROM neighborhoods), 1));

-- 3. Link houses to neighborhoods (backward compatible, existing houses default to neighborhood 1)
ALTER TABLE houses ADD COLUMN IF NOT EXISTS neighborhood_id INT REFERENCES neighborhoods(id) ON DELETE SET NULL;
UPDATE houses SET neighborhood_id = 1 WHERE neighborhood_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_houses_neighborhood_id ON houses(neighborhood_id);

-- 4. Security Assignments (Penugasan Petugas Keamanan ke Lingkungan/Perumahan)
CREATE TABLE IF NOT EXISTS security_assignments (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    neighborhood_id INT NOT NULL REFERENCES neighborhoods(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    assigned_by INT REFERENCES users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE,
    revoked_by INT REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_security_user_neighborhood UNIQUE (user_id, neighborhood_id)
);

CREATE INDEX IF NOT EXISTS idx_sec_assign_user_active ON security_assignments(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sec_assign_neighborhood_active ON security_assignments(neighborhood_id, is_active);

-- 5. Incidents (Insiden Darurat)
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    category VARCHAR(30) NOT NULL CHECK (category IN ('KEJAHATAN', 'KEBAKARAN', 'MEDIS')),
    reporter_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    house_id INT REFERENCES houses(id) ON DELETE SET NULL,
    neighborhood_id INT NOT NULL REFERENCES neighborhoods(id) ON DELETE RESTRICT,
    title VARCHAR(200),
    description TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_source VARCHAR(50),
    location_accuracy DOUBLE PRECISION,
    reported_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ACKNOWLEDGED', 'RESOLVED', 'CANCELLED', 'REPORTED', 'RESPONDING')),
    assigned_security_id INT REFERENCES users(id) ON DELETE SET NULL,
    handling_started_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_incidents_neighborhood_status ON incidents(neighborhood_id, status);
CREATE INDEX IF NOT EXISTS idx_incidents_reporter ON incidents(reporter_id);
CREATE INDEX IF NOT EXISTS idx_incidents_assigned_sec ON incidents(assigned_security_id);
CREATE INDEX IF NOT EXISTS idx_incidents_reported_at_desc ON incidents(reported_at DESC);

-- 6. Incident Audit Logs
CREATE TABLE IF NOT EXISTS incident_logs (
    id SERIAL PRIMARY KEY,
    incident_id INT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action VARCHAR(50) NOT NULL,
    previous_status VARCHAR(30),
    new_status VARCHAR(30),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_incident_logs_incident_id ON incident_logs(incident_id);
CREATE INDEX IF NOT EXISTS idx_incident_logs_created_at ON incident_logs(created_at DESC);
