-- Migration 000019: Create Complaint Assignments and Officer columns for US-5.4

-- 1. Alter complaints table to add assignment tracking fields
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_officer VARCHAR(150);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_officer_id INT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP WITH TIME ZONE;

-- 2. Create complaint_assignments table for audit and history tracking
CREATE TABLE IF NOT EXISTS complaint_assignments (
    id SERIAL PRIMARY KEY,
    complaint_id INT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    officer_name VARCHAR(150) NOT NULL,
    officer_user_id INT REFERENCES users(id) ON DELETE SET NULL,
    assigned_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    notes TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_complaint_assign_complaint ON complaint_assignments(complaint_id, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaint_assign_officer_user ON complaint_assignments(officer_user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_assigned_officer ON complaints(assigned_officer);
CREATE INDEX IF NOT EXISTS idx_complaints_status_created ON complaints(status, created_at DESC);
