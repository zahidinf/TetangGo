-- Revert Migration 000012: Drop performance indexes

DROP INDEX IF EXISTS idx_bills_period_status;
DROP INDEX IF EXISTS idx_users_status_role;
DROP INDEX IF EXISTS idx_users_house_active;
DROP INDEX IF EXISTS idx_payments_created_at_desc;
DROP INDEX IF EXISTS idx_houses_status;
