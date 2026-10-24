-- Migration 000012: Add performance indexes for dashboard queries, house lookups, and recent activities

CREATE INDEX IF NOT EXISTS idx_bills_period_status ON bills(billing_period, status);
CREATE INDEX IF NOT EXISTS idx_users_status_role ON users(status, role_id);
CREATE INDEX IF NOT EXISTS idx_users_house_active ON users(house_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_payments_created_at_desc ON payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_houses_status ON houses(status);
