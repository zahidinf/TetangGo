DROP INDEX IF EXISTS idx_complaints_status_created;
DROP INDEX IF EXISTS idx_complaints_assigned_officer;
DROP INDEX IF EXISTS idx_complaint_assign_officer_user;
DROP INDEX IF EXISTS idx_complaint_assign_complaint;
DROP TABLE IF EXISTS complaint_assignments;
ALTER TABLE complaints DROP COLUMN IF EXISTS assigned_at;
ALTER TABLE complaints DROP COLUMN IF EXISTS assigned_officer_id;
ALTER TABLE complaints DROP COLUMN IF EXISTS assigned_officer;
