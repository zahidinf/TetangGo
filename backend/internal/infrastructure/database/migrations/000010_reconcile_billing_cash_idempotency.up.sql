-- Migration 000010: Fix duplicate cash transaction for rejected payment reconciliation and add idempotency constraint

-- 1. Safely remove historical duplicate cash_transaction created for bill 30 when its previous payment was rejected
-- Bill 30 only had 1 approved payment (id 4), but had 2 income records (id 2 & 3). ID 2 was recorded on rejected payment verification.
DELETE FROM cash_transactions
WHERE id = 2
  AND bill_id = 30
  AND EXISTS (SELECT 1 FROM cash_transactions WHERE id = 3 AND bill_id = 30);

-- 2. Add UNIQUE constraint to cash_transactions(bill_id) for valid bill associations so a bill can NEVER have multiple income entries
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_transactions_unique_bill_id 
ON cash_transactions(bill_id) 
WHERE bill_id IS NOT NULL;
