-- Migration: Remove 360Dialog and Twilio WhatsApp Channel Types
-- This migration safely removes the whatsapp_twilio and whatsapp_360dialog channel types
-- and cleans up related database objects including dialog_360_clients and dialog_360_channels tables

DO $$
DECLARE
  affected_rows integer;
BEGIN
  RAISE NOTICE 'Starting migration to remove 360Dialog and Twilio WhatsApp channels...';
  
  -- Step 1: Delete channel_connections with whatsapp_twilio or whatsapp_360dialog channel types
  -- This will cascade to remove related conversations and messages
  RAISE NOTICE 'Deleting channel connections with whatsapp_twilio or whatsapp_360dialog channel types...';
  
  DELETE FROM channel_connections 
  WHERE channel_type IN ('whatsapp_twilio', 'whatsapp_360dialog');
  
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RAISE NOTICE 'Deleted % channel connections', affected_rows;
  
  -- Step 2: Drop dialog_360_channels table (with CASCADE to remove dependencies)
  RAISE NOTICE 'Dropping dialog_360_channels table...';
  
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'dialog_360_channels'
  ) THEN
    DROP TABLE IF EXISTS dialog_360_channels CASCADE;
    RAISE NOTICE 'dialog_360_channels table dropped successfully';
  ELSE
    RAISE NOTICE 'dialog_360_channels table does not exist, skipping';
  END IF;
  
  -- Step 3: Drop dialog_360_clients table (with CASCADE to remove dependencies)
  RAISE NOTICE 'Dropping dialog_360_clients table...';
  
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'dialog_360_clients'
  ) THEN
    DROP TABLE IF EXISTS dialog_360_clients CASCADE;
    RAISE NOTICE 'dialog_360_clients table dropped successfully';
  ELSE
    RAISE NOTICE 'dialog_360_clients table does not exist, skipping';
  END IF;
  
  -- Step 4: Delete partner_configurations records where provider = '360dialog'
  RAISE NOTICE 'Deleting partner_configurations with provider = ''360dialog''...';
  
  DELETE FROM partner_configurations 
  WHERE provider = '360dialog';
  
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RAISE NOTICE 'Deleted % partner_configurations records', affected_rows;
  
  -- Step 5: Update partner_configurations provider check constraint
  -- Remove '360dialog' from the allowed providers
  RAISE NOTICE 'Updating partner_configurations provider check constraint...';
  
  -- Drop the existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'partner_configurations_provider_check'
  ) THEN
    ALTER TABLE partner_configurations 
    DROP CONSTRAINT partner_configurations_provider_check;
    
    -- Add the new constraint without '360dialog'
    ALTER TABLE partner_configurations 
    ADD CONSTRAINT partner_configurations_provider_check 
    CHECK (provider IN ('meta', 'twilio', 'tiktok'));
    
    RAISE NOTICE 'partner_configurations provider check constraint updated successfully';
  ELSE
    RAISE NOTICE 'partner_configurations_provider_check constraint does not exist, skipping';
  END IF;
  
  RAISE NOTICE 'Migration completed successfully!';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Migration failed: %', SQLERRM;
END$$;

-- Rollback instructions (commented out):
-- To rollback this migration, you would need to:
-- 1. Recreate the dialog_360_clients and dialog_360_channels tables (see migration 008-360dialog-partner-tables.sql)
-- 2. Restore the partner_configurations provider check constraint to include '360dialog'
-- 3. Note: Deleted channel_connections, conversations, and messages cannot be restored without backups

