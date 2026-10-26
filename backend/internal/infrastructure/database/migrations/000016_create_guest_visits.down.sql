-- Migration 000016: Drop Guest Visits and Audit Logs
DROP TABLE IF EXISTS guest_visit_audit_logs CASCADE;
DROP TABLE IF EXISTS guest_visits CASCADE;
