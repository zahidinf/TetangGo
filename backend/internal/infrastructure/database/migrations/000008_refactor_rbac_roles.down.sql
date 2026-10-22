-- Migration 000008 Down: Revert RBAC Roles to legacy roles
INSERT INTO roles (name) VALUES ('admin_rt'), ('warga') ON CONFLICT (name) DO NOTHING;

UPDATE users 
SET role_id = (SELECT id FROM roles WHERE name = 'admin_rt')
WHERE role_id IN (SELECT id FROM roles WHERE name = 'ADMIN');

UPDATE users 
SET role_id = (SELECT id FROM roles WHERE name = 'warga')
WHERE role_id IN (SELECT id FROM roles WHERE name IN ('RESIDENT', 'CHAIRPERSON', 'VICE_CHAIRPERSON', 'TREASURER', 'SECRETARY'));

DELETE FROM roles WHERE name IN ('ADMIN', 'CHAIRPERSON', 'VICE_CHAIRPERSON', 'TREASURER', 'SECRETARY', 'RESIDENT');
