-- Migration 000017 Down
ALTER TABLE guest_invitations 
DROP CONSTRAINT IF EXISTS guest_invitations_status_check;

ALTER TABLE guest_invitations 
ADD CONSTRAINT guest_invitations_status_check 
CHECK (status IN ('ACTIVE', 'USED', 'CANCELLED', 'EXPIRED'));
