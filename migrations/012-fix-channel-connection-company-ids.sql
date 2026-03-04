-- Migration: Fix missing companyId values in channel_connections table
-- This migration updates channel connections that have null companyId values
-- by setting them to match their owner's companyId

DO $$
DECLARE
  updated_count INTEGER;
  remaining_null_count INTEGER;
BEGIN
  RAISE NOTICE 'Starting migration to fix missing companyId values in channel_connections...';

  -- Update channel_connections where companyId is null
  -- Set companyId to match the user's companyId
  UPDATE channel_connections
  SET company_id = users.company_id,
      updated_at = NOW()
  FROM users
  WHERE channel_connections.user_id = users.id
    AND channel_connections.company_id IS NULL
    AND users.company_id IS NOT NULL;

  -- Get count of updated records
  GET DIAGNOSTICS updated_count = ROW_COUNT;

  RAISE NOTICE 'Updated % channel connections with missing companyId values', updated_count;

  -- Report any remaining connections with null companyId
  SELECT COUNT(*) INTO remaining_null_count
  FROM channel_connections
  WHERE company_id IS NULL;

  IF remaining_null_count > 0 THEN
    RAISE WARNING 'Warning: % channel connections still have null companyId values. These may need manual review.', remaining_null_count;
  ELSE
    RAISE NOTICE 'All channel connections now have valid companyId values';
  END IF;

  RAISE NOTICE 'Migration completed successfully';

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Migration failed: %', SQLERRM;
END $$;
