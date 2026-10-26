-- Migration 000015: Create Guest Invitations for US-5.1
CREATE TABLE IF NOT EXISTS guest_invitations (
    id SERIAL PRIMARY KEY,
    invitation_code VARCHAR(64) UNIQUE NOT NULL,
    host_user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    house_id INT NOT NULL REFERENCES houses(id) ON DELETE RESTRICT,
    guest_name VARCHAR(150) NOT NULL,
    visit_type VARCHAR(30) NOT NULL CHECK (visit_type IN ('TAMU', 'KURIR')),
    phone VARCHAR(30),
    notes TEXT,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'USED', 'CANCELLED', 'EXPIRED')),
    qr_payload TEXT NOT NULL,
    qr_token_hash VARCHAR(128) NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancelled_by INT REFERENCES users(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_guest_inv_host ON guest_invitations(host_user_id, status);
CREATE INDEX IF NOT EXISTS idx_guest_inv_house ON guest_invitations(house_id);
CREATE INDEX IF NOT EXISTS idx_guest_inv_code ON guest_invitations(invitation_code);
CREATE INDEX IF NOT EXISTS idx_guest_inv_validity ON guest_invitations(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_guest_inv_status ON guest_invitations(status);
