-- Migration 000011 Down: Revert cash payment method and integrity constraints

DROP INDEX IF EXISTS idx_payments_unique_pending_bill;
DROP INDEX IF EXISTS idx_payments_unique_approved_bill;
ALTER TABLE payments ALTER COLUMN proof_image_url SET NOT NULL;
ALTER TABLE payments DROP COLUMN IF EXISTS payment_method;
