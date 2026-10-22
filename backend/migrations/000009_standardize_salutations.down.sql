-- Rollback 000009: Standardize Salutations
ALTER TABLE users ALTER COLUMN salutation SET DEFAULT 'Pak';
