-- Migration 000003 Down

ALTER TABLE users DROP COLUMN IF EXISTS ownership_status;
ALTER TABLE users DROP COLUMN IF EXISTS rejection_reason;
ALTER TABLE users DROP COLUMN IF EXISTS profile_photo_url;
