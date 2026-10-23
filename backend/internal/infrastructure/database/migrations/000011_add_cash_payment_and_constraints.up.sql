-- Migration 000011: Add CASH payment method support, make proof_image_url nullable for cash, and add partial unique indexes for payment integrity

-- 1. Add payment_method column with default 'TRANSFER'
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) NOT NULL DEFAULT 'TRANSFER';

-- 2. Allow NULL for proof_image_url since cash payments (direct or resident declaration) do not require bank transfer proof
ALTER TABLE payments ALTER COLUMN proof_image_url DROP NOT NULL;

-- 3. Prevent duplicate approved/paid payments on the same bill at database level
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_unique_approved_bill 
ON payments(bill_id) 
WHERE verified_at IS NOT NULL AND rejection_reason IS NULL;

-- 4. Prevent duplicate pending payments on the same bill at database level
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_unique_pending_bill 
ON payments(bill_id) 
WHERE verified_at IS NULL;
