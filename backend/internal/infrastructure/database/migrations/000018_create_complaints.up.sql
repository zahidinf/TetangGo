-- Migration 000018: Create Complaints Table for US-5.3
CREATE TABLE IF NOT EXISTS complaints (
    id SERIAL PRIMARY KEY,
    ticket_number VARCHAR(64) UNIQUE NOT NULL,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    house_id INT NOT NULL REFERENCES houses(id) ON DELETE RESTRICT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Lampu Jalan', 'Sampah', 'Ketertiban', 'Jalanan')),
    photo_url TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'Menunggu' CHECK (status IN ('Menunggu', 'Diproses', 'Selesai', 'Ditolak')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_complaints_user ON complaints(user_id, status);
CREATE INDEX IF NOT EXISTS idx_complaints_house ON complaints(house_id);
CREATE INDEX IF NOT EXISTS idx_complaints_ticket ON complaints(ticket_number);
CREATE INDEX IF NOT EXISTS idx_complaints_category ON complaints(category);
CREATE INDEX IF NOT EXISTS idx_complaints_created ON complaints(created_at DESC);
