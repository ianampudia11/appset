-- Add Meta Partner Configuration Fields Migration
-- This migration adds missing fields to partner_configurations table for Meta WhatsApp integration

-- Add new columns to partner_configurations table
DO $$
BEGIN
  -- Add partner_secret column for storing encrypted app secret
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' 
    AND column_name = 'partner_secret'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN partner_secret TEXT;
    RAISE NOTICE 'Added partner_secret column to partner_configurations table';
  END IF;

  -- Add webhook_verify_token column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' 
    AND column_name = 'webhook_verify_token'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN webhook_verify_token TEXT;
    RAISE NOTICE 'Added webhook_verify_token column to partner_configurations table';
  END IF;

  -- Add access_token column for system user access token
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' 
    AND column_name = 'access_token'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN access_token TEXT;
    RAISE NOTICE 'Added access_token column to partner_configurations table';
  END IF;

  -- Add config_id column for WhatsApp Configuration ID
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' 
    AND column_name = 'config_id'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN config_id TEXT;
    RAISE NOTICE 'Added config_id column to partner_configurations table';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON COLUMN partner_configurations.partner_secret IS 'Encrypted partner secret (e.g., Meta App Secret)';
COMMENT ON COLUMN partner_configurations.webhook_verify_token IS 'Webhook verification token for Meta webhooks';
COMMENT ON COLUMN partner_configurations.access_token IS 'System user access token for Meta API calls';
COMMENT ON COLUMN partner_configurations.config_id IS 'WhatsApp Configuration ID for embedded signup';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- ALTER TABLE partner_configurations DROP COLUMN IF EXISTS partner_secret;
-- ALTER TABLE partner_configurations DROP COLUMN IF EXISTS webhook_verify_token;
-- ALTER TABLE partner_configurations DROP COLUMN IF EXISTS access_token;
-- ALTER TABLE partner_configurations DROP COLUMN IF EXISTS config_id;
