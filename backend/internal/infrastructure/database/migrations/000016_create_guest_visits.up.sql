-- Migration 000016: Create Guest Visits and Audit Logs for US-5.2
CREATE TABLE IF NOT EXISTS guest_visits (
    id SERIAL PRIMARY KEY,
    invitation_id INT NOT NULL REFERENCES guest_invitations(id) ON DELETE RESTRICT,
    check_in_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    check_in_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    check_out_at TIMESTAMP WITH TIME ZONE,
    check_out_by INT REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'CHECKED_IN' CHECK (status IN ('CHECKED_IN', 'CHECKED_OUT')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_guest_visits_invitation ON guest_visits(invitation_id);
CREATE INDEX IF NOT EXISTS idx_guest_visits_status ON guest_visits(status);
CREATE INDEX IF NOT EXISTS idx_guest_visits_check_in_at ON guest_visits(check_in_at DESC);

-- Unique index to prevent multiple active check-ins for the same invitation
CREATE UNIQUE INDEX IF NOT EXISTS idx_guest_visits_unique_active_invitation 
ON guest_visits(invitation_id) 
WHERE status = 'CHECKED_IN';

-- Audit logs for security gate operations
CREATE TABLE IF NOT EXISTS guest_visit_audit_logs (
    id SERIAL PRIMARY KEY,
    visit_id INT REFERENCES guest_visits(id) ON DELETE CASCADE,
    invitation_id INT REFERENCES guest_invitations(id) ON DELETE CASCADE,
    actor_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    actor_role VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL, -- VERIFY, CHECK_IN, CHECK_OUT, REJECTED
    status VARCHAR(30) NOT NULL, -- SUCCESS, FAILED
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_guest_audit_visit ON guest_visit_audit_logs(visit_id);
CREATE INDEX IF NOT EXISTS idx_guest_audit_invitation ON guest_visit_audit_logs(invitation_id);
CREATE INDEX IF NOT EXISTS idx_guest_audit_created ON guest_visit_audit_logs(created_at DESC);
