-- Migration 000006: Create cash_transactions and announcements tables

CREATE TABLE IF NOT EXISTS cash_transactions (
    id SERIAL PRIMARY KEY,
    type VARCHAR(10) NOT NULL, -- 'income' atau 'expense'
    category VARCHAR(50) NOT NULL, -- 'iuran', 'donasi', 'kebersihan', 'keamanan', 'perbaikan_fasilitas', 'kegiatan_sosial', 'operasional', 'lainnya'
    amount NUMERIC(12,2) NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    proof_image_url VARCHAR(255),
    bill_id INT REFERENCES bills(id) ON DELETE SET NULL,
    created_by INT REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cash_transactions_type ON cash_transactions(type);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_category ON cash_transactions(category);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_date ON cash_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_bill_id ON cash_transactions(bill_id);

CREATE TABLE IF NOT EXISTS announcements (
    id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(20) NOT NULL DEFAULT 'biasa', -- 'biasa', 'penting', 'darurat'
    image_url VARCHAR(255),
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    author_id INT REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_announcements_pinned ON announcements(is_pinned);
CREATE INDEX IF NOT EXISTS idx_announcements_created_at ON announcements(created_at);
CREATE INDEX IF NOT EXISTS idx_announcements_category ON announcements(category);

-- Populate existing paid bills to cash_transactions non-destructively
INSERT INTO cash_transactions (type, category, amount, transaction_date, description, bill_id, created_by, created_at)
SELECT 
    'income', 
    'iuran', 
    b.amount, 
    DATE(COALESCE(p.verified_at, b.updated_at, CURRENT_DATE)),
    'Iuran IPL Blok ' || h.block || ' No. ' || h.house_number || ' (' || b.billing_period || ')',
    b.id,
    COALESCE(p.verified_by, (SELECT id FROM users WHERE role_id = (SELECT id FROM roles WHERE name = 'admin_rt' LIMIT 1) LIMIT 1)),
    COALESCE(p.verified_at, b.updated_at, CURRENT_TIMESTAMP)
FROM bills b
JOIN houses h ON b.house_id = h.id
LEFT JOIN payments p ON p.bill_id = b.id
WHERE b.status = 'paid'
  AND NOT EXISTS (SELECT 1 FROM cash_transactions ct WHERE ct.bill_id = b.id);
