-- Partner Configurations Migration
-- This migration creates the partner_configurations table for platform-wide partner API credentials

-- Create partner_configurations table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'partner_configurations'
  ) THEN
    RAISE NOTICE 'Creating partner_configurations table...';
    
    CREATE TABLE partner_configurations (
      id SERIAL PRIMARY KEY,
      provider TEXT NOT NULL UNIQUE CHECK (provider IN ('360dialog', 'meta', 'twilio')),
      partner_api_key TEXT NOT NULL, -- Encrypted partner API key or App ID
      partner_secret TEXT, -- Encrypted partner secret (for Meta App Secret)
      partner_id TEXT NOT NULL, -- Partner ID or Business Manager ID
      webhook_verify_token TEXT, -- For webhook verification (Meta)
      access_token TEXT, -- System user access token (Meta)
      partner_webhook_url TEXT NOT NULL, -- Partner-level webhook URL
      redirect_url TEXT NOT NULL, -- Callback/redirect URL for onboarding
      public_profile JSONB DEFAULT '{}', -- Company name, logo, etc. for onboarding
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes for better performance
    CREATE INDEX idx_partner_configurations_provider ON partner_configurations(provider);
    CREATE INDEX idx_partner_configurations_active ON partner_configurations(is_active);
    
    RAISE NOTICE 'partner_configurations table created successfully';
  ELSE
    RAISE NOTICE 'partner_configurations table already exists, skipping creation';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON TABLE partner_configurations IS 'Platform-wide partner API configurations for SaaS integrations';
COMMENT ON COLUMN partner_configurations.provider IS 'Partner provider name (360dialog, meta, twilio)';
COMMENT ON COLUMN partner_configurations.partner_api_key IS 'Encrypted partner API key or App ID';
COMMENT ON COLUMN partner_configurations.partner_secret IS 'Encrypted partner secret (for Meta App Secret)';
COMMENT ON COLUMN partner_configurations.partner_id IS 'Partner ID or Business Manager ID';
COMMENT ON COLUMN partner_configurations.webhook_verify_token IS 'Webhook verification token (primarily for Meta)';
COMMENT ON COLUMN partner_configurations.access_token IS 'System user access token (primarily for Meta)';
COMMENT ON COLUMN partner_configurations.partner_webhook_url IS 'Partner-level webhook URL for events';
COMMENT ON COLUMN partner_configurations.redirect_url IS 'Callback/redirect URL for onboarding flows';
COMMENT ON COLUMN partner_configurations.public_profile IS 'JSON object with company name, logo, etc. for onboarding';
COMMENT ON COLUMN partner_configurations.is_active IS 'Whether this partner configuration is active';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS partner_configurations CASCADE;
