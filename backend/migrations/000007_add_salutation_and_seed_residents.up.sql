-- 1. Tambah kolom salutation jika belum ada
ALTER TABLE users ADD COLUMN IF NOT EXISTS salutation VARCHAR(20) DEFAULT 'Pak';

-- 2. Insert / Pastikan Seluruh Rumah Sesuai PDF Tersedia (Format 2 Digit)
INSERT INTO houses (block, house_number, status) VALUES
-- BLOK B1
('B1', '01', 'milik'),
('B1', '02', 'milik'),
('B1', '03', 'milik'),
('B1', '04', 'milik'),
('B1', '05', 'milik'),
('B1', '06', 'milik'),
('B1', '07', 'milik'),
('B1', '08', 'milik'),
('B1', '09', 'milik'),
('B1', '10', 'milik'),
('B1', '11', 'milik'),
('B1', '12', 'milik'),
('B1', '13', 'milik'),
('B1', '14', 'milik'),
('B1', '15', 'milik'),
('B1', '16', 'milik'),
('B1', '17', 'milik'),
('B1', '20', 'milik'),
('B1', '21', 'milik'),
('B1', '22', 'milik'),
('B1', '23', 'milik'),
('B1', '24', 'milik'),
('B1', '25', 'milik'),
('B1', '26', 'milik'),
('B1', '27', 'milik'),
('B1', '28', 'milik'),
('B1', '29', 'milik'),
('B1', '30', 'milik'),
('B1', '31', 'milik'),
('B1', '32', 'milik'),
('B1', '33', 'milik'),
('B1', '34', 'milik'),
('B1', '35', 'milik'),
('B1', '36', 'milik'),
('B1', '37', 'kosong'),
('B1', '38', 'milik'),

-- BLOK B2
('B2', '02', 'milik'),
('B2', '03', 'milik'),
('B2', '04', 'milik'),
('B2', '05', 'milik'),
('B2', '06', 'milik'),
('B2', '07', 'milik'),
('B2', '08', 'milik'),
('B2', '11', 'milik'),
('B2', '12', 'milik'),
('B2', '12A', 'milik'),
('B2', '17', 'milik'),
('B2', '18', 'milik'),
('B2', '19', 'milik'),
('B2', '20', 'milik'),
('B2', '21', 'milik'),
('B2', '22', 'milik'),
('B2', '23', 'milik'),
('B2', '24', 'milik'),
('B2', '25', 'milik'),
('B2', '26', 'milik'),
('B2', '27', 'milik'),
('B2', '28', 'milik'),
('B2', '29', 'milik'),
('B2', '30', 'milik'),
('B2', '31', 'milik'),

-- BLOK C1
('C1', '05', 'milik'),
('C1', '06', 'milik'),
('C1', '07', 'milik'),
('C1', '09', 'milik'),
('C1', '10', 'milik'),
('C1', '11', 'milik'),
('C1', '12', 'milik'),
('C1', '12A', 'milik'),
('C1', '14', 'milik'),
('C1', '16', 'milik'),
('C1', '24', 'milik'),
('C1', '25', 'milik'),
('C1', '26', 'milik'),
('C1', '28', 'milik'),
('C1', '29', 'milik'),
('C1', '30', 'milik'),
('C1', '31', 'milik'),

-- BLOK A1
('A1', '01', 'milik'),
('A1', '02', 'milik'),
('A1', '03', 'milik'),
('A1', '04', 'milik'),
('A1', '05', 'milik')
ON CONFLICT (block, house_number) DO UPDATE SET status = EXCLUDED.status;

-- 3. Bersihkan data user hasil seed salah sebelumnya (hanya id >= 40 yang tidak berelasi ke transaksi keuangan)
DELETE FROM users WHERE id >= 40
  AND NOT EXISTS (SELECT 1 FROM cash_transactions ct WHERE ct.created_by = users.id)
  AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.user_id = users.id OR p.verified_by = users.id);

-- 4. Update data Farhan (id 8 / B1/36) agar memiliki salutation Pak
UPDATE users SET salutation = 'Pak', name = 'Farhan' WHERE email = 'farhan@tetanggo.id';

-- 5. Insert Seluruh Warga Sesuai Lampiran PDF
DO $$
DECLARE
    def_pwd VARCHAR(255) := '$2a$10$j8.7j3v5Ocf4mC7uM9WnXeD1r7y8W4qP3h4Q1m5c7Z0l2s8G4x3K6'; -- password123
    warga_role_id INT;
BEGIN
    SELECT id INTO warga_role_id FROM roles WHERE name='warga' LIMIT 1;

    -- =========================================================================
    -- PENGHUNI BLOK B1 (Halaman 1 PDF)
    -- =========================================================================
    INSERT INTO users (name, salutation, email, password_hash, role_id, house_id, phone, status, ownership_status, created_at, updated_at) VALUES
    ('Boni', 'Pak', 'boni@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='01' LIMIT 1), '081210000001', 'active', 'pemilik', NOW(), NOW()),
    ('Edi D', 'Pak', 'edi.b102@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='02' LIMIT 1), '081210000002', 'active', 'pemilik', NOW(), NOW()),
    ('Derry', 'Pak', 'derry@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='03' LIMIT 1), '081210000003', 'active', 'pemilik', NOW(), NOW()),
    ('Andre', 'Pak', 'andre@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='04' LIMIT 1), '081210000004', 'active', 'pemilik', NOW(), NOW()),
    ('Haji', 'Ibu', 'haji@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='05' LIMIT 1), '081210000005', 'active', 'pemilik', NOW(), NOW()),
    ('Hanafi', 'Pak', 'hanafi@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='06' LIMIT 1), '081210000006', 'active', 'pemilik', NOW(), NOW()),
    ('Ayu', 'Ibu', 'ayu.b107@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='07' LIMIT 1), '081210000007', 'active', 'pemilik', NOW(), NOW()),
    ('Erwin', 'Pak', 'erwin@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='08' LIMIT 1), '081210000008', 'active', 'pemilik', NOW(), NOW()),
    ('Daniel', 'Pak', 'daniel@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='09' LIMIT 1), '081210000009', 'active', 'pemilik', NOW(), NOW()),
    ('Wahid', 'Pak', 'wahid@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='10' LIMIT 1), '081210000010', 'active', 'pemilik', NOW(), NOW()),
    ('Rizki', 'Mama', 'rizki@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='11' LIMIT 1), '081210000011', 'active', 'pemilik', NOW(), NOW()),
    ('Irvan', 'Pak', 'irvan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='12' LIMIT 1), '081210000012', 'active', 'pemilik', NOW(), NOW()),
    ('Martha', 'Pak', 'martha@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='13' LIMIT 1), '081210000013', 'active', 'pemilik', NOW(), NOW()),
    ('Wahyu', 'Pak', 'wahyu@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='14' LIMIT 1), '081210000014', 'active', 'pemilik', NOW(), NOW()),
    ('Ica', 'Mba', 'ica@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='15' LIMIT 1), '081210000015', 'active', 'pemilik', NOW(), NOW()),
    ('Ikbal', 'Pak', 'ikbal@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='16' LIMIT 1), '081210000016', 'active', 'pemilik', NOW(), NOW()),
    ('Ade', 'Pak', 'ade.b117@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='17' LIMIT 1), '081210000017', 'active', 'pemilik', NOW(), NOW()),
    ('Dela', 'Mba', 'dela@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='20' LIMIT 1), '081210000018', 'active', 'pemilik', NOW(), NOW()),
    ('Zola', 'Pak', 'zola@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='21' LIMIT 1), '081210000019', 'active', 'pemilik', NOW(), NOW()),
    ('Rico', 'Pak', 'rico@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='22' LIMIT 1), '081210000020', 'active', 'pemilik', NOW(), NOW()),
    ('Bagyo', 'Pak', 'bagyo@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='23' LIMIT 1), '081210000021', 'active', 'pemilik', NOW(), NOW()),
    ('Puput', 'Ibu', 'puput@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='24' LIMIT 1), '081210000022', 'active', 'pemilik', NOW(), NOW()),
    ('Aan', 'Pak', 'aan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='25' LIMIT 1), '081210000023', 'active', 'pemilik', NOW(), NOW()),
    ('Deni', 'Pak', 'deni.b126@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='26' LIMIT 1), '081210000024', 'active', 'pemilik', NOW(), NOW()),
    ('Darman', 'Pak', 'darman@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='27' LIMIT 1), '081210000025', 'active', 'pemilik', NOW(), NOW()),
    ('Imam', 'Pak', 'imam@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='28' LIMIT 1), '081210000026', 'active', 'pemilik', NOW(), NOW()),
    ('Husni', 'Pak', 'husni@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='29' LIMIT 1), '081210000027', 'active', 'pemilik', NOW(), NOW()),
    ('Andi', 'Pak', 'andi@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='30' LIMIT 1), '081210000028', 'active', 'pemilik', NOW(), NOW()),
    ('Destri', 'Pak', 'destri@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='31' LIMIT 1), '081210000029', 'active', 'pemilik', NOW(), NOW()),
    ('Ardian', 'Pak', 'ardian@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='32' LIMIT 1), '081210000030', 'active', 'pemilik', NOW(), NOW()),
    ('Aang', 'Pak', 'aang@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='33' LIMIT 1), '081210000031', 'active', 'pemilik', NOW(), NOW()),
    ('Mei', 'Pak', 'mei@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='34' LIMIT 1), '081210000032', 'active', 'pemilik', NOW(), NOW()),
    ('Akbar', 'Pak', 'akbar@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='35' LIMIT 1), '081210000033', 'active', 'pemilik', NOW(), NOW()),
    ('Alvin', 'Pak', 'alvin@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B1' AND house_number='38' LIMIT 1), '081210000035', 'active', 'pemilik', NOW(), NOW())
    ON CONFLICT (email) DO NOTHING;

    -- =========================================================================
    -- PENGHUNI BLOK B2 (Halaman 2 PDF)
    -- =========================================================================
    INSERT INTO users (name, salutation, email, password_hash, role_id, house_id, phone, status, ownership_status, created_at, updated_at) VALUES
    ('Lukman', 'Pak', 'lukman@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='02' LIMIT 1), '081210000036', 'active', 'pemilik', NOW(), NOW()),
    ('Nur', 'Pak', 'nur@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='03' LIMIT 1), '081210000037', 'active', 'pemilik', NOW(), NOW()),
    ('Didit', 'Pak', 'didit@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='04' LIMIT 1), '081210000038', 'active', 'pemilik', NOW(), NOW()),
    ('Adhitya', 'Pak', 'adhitya@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='05' LIMIT 1), '081210000039', 'active', 'pemilik', NOW(), NOW()),
    ('Sarif', 'Pak', 'sarif@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='06' LIMIT 1), '081210000040', 'active', 'pemilik', NOW(), NOW()),
    ('Purwo', 'Pak', 'purwo@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='07' LIMIT 1), '081210000041', 'active', 'pemilik', NOW(), NOW()),
    ('Rosi', 'Ibu', 'rosi@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='08' LIMIT 1), '081210000042', 'active', 'pemilik', NOW(), NOW()),
    ('Saad', 'Pak', 'saad@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='11' LIMIT 1), '081210000043', 'active', 'pemilik', NOW(), NOW()),
    ('Hendrik', 'Pak', 'hendrik@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='12' LIMIT 1), '081210000044', 'active', 'pemilik', NOW(), NOW()),
    ('Arif', 'Pak', 'arif@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='12A' LIMIT 1), '081210000045', 'active', 'pemilik', NOW(), NOW()),
    ('Juan', 'Pak', 'juan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='17' LIMIT 1), '081210000046', 'active', 'pemilik', NOW(), NOW()),
    ('Yani', '', 'yani@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='18' LIMIT 1), '081210000047', 'active', 'pemilik', NOW(), NOW()),
    ('Emma', 'Ibu', 'emma@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='19' LIMIT 1), '081210000048', 'active', 'pemilik', NOW(), NOW()),
    ('Juanda', 'Pak', 'juanda@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='20' LIMIT 1), '081210000049', 'active', 'pemilik', NOW(), NOW()),
    ('Ripto', 'Pak', 'ripto@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='21' LIMIT 1), '081210000050', 'active', 'pemilik', NOW(), NOW()),
    ('Marlon', 'Pak', 'marlon@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='22' LIMIT 1), '081210000051', 'active', 'pemilik', NOW(), NOW()),
    ('Edi Santoso', 'Pak', 'edi.b223@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='23' LIMIT 1), '081210000052', 'active', 'pemilik', NOW(), NOW()),
    ('Bari', 'Pak', 'bari@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='24' LIMIT 1), '081210000053', 'active', 'pemilik', NOW(), NOW()),
    ('Maidul', 'Pak', 'maidul@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='25' LIMIT 1), '081210000054', 'active', 'pemilik', NOW(), NOW()),
    ('Awan', 'Pak', 'awan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='26' LIMIT 1), '081210000055', 'active', 'pemilik', NOW(), NOW()),
    ('Ayu', 'Ibu', 'ayu.b227@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='27' LIMIT 1), '081210000056', 'active', 'pemilik', NOW(), NOW()),
    ('Lisa', 'Mba', 'lisa@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='28' LIMIT 1), '081210000057', 'active', 'pemilik', NOW(), NOW()),
    ('Dedi', 'Pak', 'dedi.b229@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='29' LIMIT 1), '081210000058', 'active', 'pemilik', NOW(), NOW()),
    ('Yudi', 'Pak', 'yudi@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='30' LIMIT 1), '081210000059', 'active', 'pemilik', NOW(), NOW()),
    ('Dian', 'Ibu', 'dian@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='B2' AND house_number='31' LIMIT 1), '081210000060', 'active', 'pemilik', NOW(), NOW())
    ON CONFLICT (email) DO NOTHING;

    -- =========================================================================
    -- PENGHUNI BLOK C1 (Halaman 3 PDF)
    -- =========================================================================
    INSERT INTO users (name, salutation, email, password_hash, role_id, house_id, phone, status, ownership_status, created_at, updated_at) VALUES
    ('Ficky', 'Pak', 'ficky@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='05' LIMIT 1), '081210000061', 'active', 'pemilik', NOW(), NOW()),
    ('Syamsul', 'Ibu', 'syamsul@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='06' LIMIT 1), '081210000062', 'active', 'pemilik', NOW(), NOW()),
    ('Endro', 'Pak', 'endro@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='07' LIMIT 1), '081210000063', 'active', 'pemilik', NOW(), NOW()),
    ('Lucas', 'Pak', 'lucas@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='09' LIMIT 1), '081210000064', 'active', 'pemilik', NOW(), NOW()),
    ('Syarif Tualeka', 'Pak', 'syarif@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='10' LIMIT 1), '081210000065', 'active', 'pemilik', NOW(), NOW()),
    ('Ade', 'Pak', 'ade.c111@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='11' LIMIT 1), '081210000066', 'active', 'pemilik', NOW(), NOW()),
    ('Agung', 'Pak', 'agung@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='12' LIMIT 1), '081210000067', 'active', 'pemilik', NOW(), NOW()),
    ('Adi', 'Pak', 'adi@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='12A' LIMIT 1), '081210000068', 'active', 'pemilik', NOW(), NOW()),
    ('Rama', 'Pak', 'rama@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='14' LIMIT 1), '081210000069', 'active', 'pemilik', NOW(), NOW()),
    ('Tomy', 'Pak', 'tomy@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='16' LIMIT 1), '081210000070', 'active', 'pemilik', NOW(), NOW()),
    ('Coy', 'Pak', 'coy@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='24' LIMIT 1), '081210000071', 'active', 'pemilik', NOW(), NOW()),
    ('Sugeng', 'Pak', 'sugeng@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='25' LIMIT 1), '081210000072', 'active', 'pemilik', NOW(), NOW()),
    ('Dimas', 'Pak', 'dimas@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='26' LIMIT 1), '081210000073', 'active', 'pemilik', NOW(), NOW()),
    ('Wawan', 'Pak', 'wawan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='28' LIMIT 1), '081210000074', 'active', 'pemilik', NOW(), NOW()),
    ('Dedi Kumis', 'Pak', 'dedi.c129@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='29' LIMIT 1), '081210000075', 'active', 'pemilik', NOW(), NOW()),
    ('Yusuf', 'Pak', 'yusuf@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='30' LIMIT 1), '081210000076', 'active', 'pemilik', NOW(), NOW()),
    ('Aliyanto', 'Pak', 'aliyanto@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='C1' AND house_number='31' LIMIT 1), '081210000077', 'active', 'pemilik', NOW(), NOW())
    ON CONFLICT (email) DO NOTHING;

    -- =========================================================================
    -- PENGHUNI BLOK A1 (Halaman 3 PDF)
    -- =========================================================================
    INSERT INTO users (name, salutation, email, password_hash, role_id, house_id, phone, status, ownership_status, created_at, updated_at) VALUES
    ('Ridwan', 'Pak', 'ridwan@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='A1' AND house_number='01' LIMIT 1), '081210000078', 'active', 'pemilik', NOW(), NOW()),
    ('Sakta', 'Pak', 'sakta@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='A1' AND house_number='02' LIMIT 1), '081210000079', 'active', 'pemilik', NOW(), NOW()),
    ('Deni', 'Pak', 'deni.a103@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='A1' AND house_number='03' LIMIT 1), '081210000080', 'active', 'pemilik', NOW(), NOW()),
    ('Otoy', 'Pak', 'otoy@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='A1' AND house_number='04' LIMIT 1), '081210000081', 'active', 'pemilik', NOW(), NOW()),
    ('Item', 'Pak', 'item@tetanggo.id', def_pwd, warga_role_id, (SELECT id FROM houses WHERE block='A1' AND house_number='05' LIMIT 1), '081210000082', 'active', 'pemilik', NOW(), NOW())
    ON CONFLICT (email) DO NOTHING;
END $$;
