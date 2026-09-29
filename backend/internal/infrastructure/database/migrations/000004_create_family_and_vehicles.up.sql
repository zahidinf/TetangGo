-- Migration 000004: Create family_members and vehicles tables

CREATE TABLE IF NOT EXISTS family_members (
    id SERIAL PRIMARY KEY,
    house_id INT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    relation VARCHAR(30) NOT NULL,
    phone VARCHAR(30),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicles (
    id SERIAL PRIMARY KEY,
    house_id INT NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
    plate_number VARCHAR(30) NOT NULL UNIQUE,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('mobil', 'motor')),
    brand_model VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_family_members_house_id ON family_members(house_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_house_id ON vehicles(house_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate_number ON vehicles(plate_number);
