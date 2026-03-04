-- Migration: Cleanup Failed Migration Record
-- Description: Remove the failed migration record to allow the fixed migration to run

-- Remove the failed migration record from the migrations table
-- This allows the corrected migration to run properly
DELETE FROM migrations 
WHERE filename = '020-enhance-multi-channel-triggers.sql';

-- Verify cleanup
DO $$
DECLARE
    remaining_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining_count
    FROM migrations 
    WHERE filename = '020-enhance-multi-channel-triggers.sql';
    
    IF remaining_count = 0 THEN
        RAISE NOTICE 'Failed migration record cleaned up successfully.';
    ELSE
        RAISE NOTICE 'Warning: Failed migration record still exists.';
    END IF;
END $$;
