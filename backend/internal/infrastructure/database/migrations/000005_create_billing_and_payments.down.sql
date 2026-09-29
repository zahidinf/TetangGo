-- Migration 000005 DOWN: Drop payments, bills, payment_settings tables

DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS bills CASCADE;
DROP TABLE IF EXISTS payment_settings CASCADE;
