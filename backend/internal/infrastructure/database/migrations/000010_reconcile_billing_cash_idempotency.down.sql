-- Rollback 000010: Drop unique index on bill_id
DROP INDEX IF EXISTS idx_cash_transactions_unique_bill_id;
