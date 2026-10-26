-- Migration 000017: Allow COMPLETED status for guest invitations (Enhancement US-5.2)
-- Drop existing check constraint and add updated check constraint
ALTER TABLE guest_invitations 
DROP CONSTRAINT IF EXISTS guest_invitations_status_check;

ALTER TABLE guest_invitations 
ADD CONSTRAINT guest_invitations_status_check 
CHECK (status IN ('ACTIVE', 'USED', 'COMPLETED', 'CANCELLED', 'EXPIRED'));
