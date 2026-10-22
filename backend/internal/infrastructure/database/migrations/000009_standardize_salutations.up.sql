-- Migration 000009: Standardize Salutations to 'Bapak' and 'Ibu'
-- Rule A: Map Mba, Mbak, Mama, Mamah (case-insensitive, trimmed) to 'Ibu'
-- Rule B: Map all other values (Pak, Bp, Mas, Kak, empty, NULL, unknown) to 'Bapak'

-- 1. Normalize existing 'Ibu' variants
UPDATE users 
SET salutation = 'Ibu'
WHERE TRIM(UPPER(COALESCE(salutation, ''))) IN ('IBU', 'MBA', 'MBAK', 'MAMA', 'MAMAH');

-- 2. Normalize all remaining values to 'Bapak'
UPDATE users 
SET salutation = 'Bapak'
WHERE salutation IS NULL OR TRIM(UPPER(salutation)) NOT IN ('IBU');

-- 3. Update default value on column to 'Bapak'
ALTER TABLE users ALTER COLUMN salutation SET DEFAULT 'Bapak';
