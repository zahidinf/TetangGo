-- Migration 000008: Refactor RBAC Roles to 6 canonical roles
-- Roles: ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, TREASURER, SECRETARY, RESIDENT

-- 1. Insert new canonical roles if they do not exist
INSERT INTO roles (name) VALUES 
    ('ADMIN'),
    ('CHAIRPERSON'),
    ('VICE_CHAIRPERSON'),
    ('TREASURER'),
    ('SECRETARY'),
    ('RESIDENT')
ON CONFLICT (name) DO NOTHING;

-- 2. Migrate existing users from 'admin_rt' to 'ADMIN'
UPDATE users 
SET role_id = (SELECT id FROM roles WHERE name = 'ADMIN')
WHERE role_id IN (SELECT id FROM roles WHERE name = 'admin_rt');

-- 3. Migrate existing users from 'warga' to 'RESIDENT'
UPDATE users 
SET role_id = (SELECT id FROM roles WHERE name = 'RESIDENT')
WHERE role_id IN (SELECT id FROM roles WHERE name = 'warga');

-- 4. Delete obsolete roles
DELETE FROM roles WHERE name IN ('admin_rt', 'warga');
