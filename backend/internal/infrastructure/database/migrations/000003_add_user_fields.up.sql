-- Migration 000003: Add extra user fields for Sprint 1

ALTER TABLE users ADD COLUMN IF NOT EXISTS ownership_status VARCHAR(30) DEFAULT 'pemilik';
ALTER TABLE users ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo_url VARCHAR(255);

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_check;
ALTER TABLE users ADD CONSTRAINT users_status_check CHECK (status IN ('pending_verification', 'active', 'rejected', 'inactive'));

