-- Rollback salutation and seeded residents
ALTER TABLE users DROP COLUMN IF EXISTS salutation;
