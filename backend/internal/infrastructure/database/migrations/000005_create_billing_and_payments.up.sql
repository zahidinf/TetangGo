-- Migration 000005: Create payment_settings, bills, and payments tables

CREATE TABLE IF NOT EXISTS payment_settings (
    id SERIAL PRIMARY KEY,
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    account_holder VARCHAR(150) NOT NULL,
    monthly_fee NUMERIC(12,2) NOT NULL DEFAULT 100000.00,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bills (
    id SERIAL PRIMARY KEY,
    house_id INT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
    billing_period VARCHAR(10) NOT NULL, -- format 'YYYY-MM'
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'unpaid', -- 'unpaid', 'pending_verification', 'paid', 'rejected'
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_house_billing_period UNIQUE(house_id, billing_period)
);

CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    sender_bank VARCHAR(100),
    sender_name VARCHAR(150),
    amount_paid NUMERIC(12,2) NOT NULL,
    proof_image_url VARCHAR(255) NOT NULL,
    notes TEXT,
    rejection_reason TEXT,
    verified_by INT REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bills_house_id ON bills(house_id);
CREATE INDEX IF NOT EXISTS idx_bills_period ON bills(billing_period);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);
CREATE INDEX IF NOT EXISTS idx_payments_bill_id ON payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);

-- Seed default payment settings if not exists
INSERT INTO payment_settings (bank_name, account_number, account_holder, monthly_fee)
SELECT 'BCA', '8830192831', 'Kas RT 05 RW 01', 100000.00
WHERE NOT EXISTS (SELECT 1 FROM payment_settings);
