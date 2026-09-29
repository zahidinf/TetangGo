-- Seed data for Sprint 0

INSERT INTO roles (name)
VALUES 
    ('admin_rt'),
    ('warga'),
    ('satpam')
ON CONFLICT (name) DO NOTHING;

-- Default Admin RT user
-- Email: admin@tetanggo.id
-- Phone: 081234567890
-- Password: password123 (bcrypt hash: $2a$10$7vFf9cvyK5zV9m1.wS2GgO8U55hVpW9o4gY4mY7K.n8Kx.l7L6Uee or generated at runtime)
INSERT INTO users (name, phone, email, password_hash, role_id, house_id, status, created_at, updated_at)
SELECT 
    'Admin RT TetangGo',
    '081234567890',
    'admin@tetanggo.id',
    '$2b$10$k0nrjojeQDO7GU3aKtN3qOI5/IlyJLLoL2km0qhOuvyoQvUD9xdH.', -- password123
    r.id,
    NULL,
    'active',
    NOW(),
    NOW()
FROM roles r
WHERE r.name = 'admin_rt'
ON CONFLICT (email) DO NOTHING;
