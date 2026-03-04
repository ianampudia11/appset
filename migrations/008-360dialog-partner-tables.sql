-- 360Dialog Partner API Tables Migration
-- This migration creates tables for 360Dialog Partner API client and channel management

-- Create dialog_360_clients table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'dialog_360_clients'
  ) THEN
    RAISE NOTICE 'Creating dialog_360_clients table...';
    
    CREATE TABLE dialog_360_clients (
      id SERIAL PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      client_id TEXT NOT NULL UNIQUE, -- 360Dialog client ID
      client_name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
      onboarded_at TIMESTAMP DEFAULT NOW(),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes
    CREATE INDEX idx_dialog_360_clients_company_id ON dialog_360_clients(company_id);
    CREATE INDEX idx_dialog_360_clients_client_id ON dialog_360_clients(client_id);
    CREATE INDEX idx_dialog_360_clients_status ON dialog_360_clients(status);
    
    RAISE NOTICE 'dialog_360_clients table created successfully';
  ELSE
    RAISE NOTICE 'dialog_360_clients table already exists, skipping creation';
  END IF;
END$$;

-- Create dialog_360_channels table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'dialog_360_channels'
  ) THEN
    RAISE NOTICE 'Creating dialog_360_channels table...';
    
    CREATE TABLE dialog_360_channels (
      id SERIAL PRIMARY KEY,
      client_id INTEGER NOT NULL REFERENCES dialog_360_clients(id) ON DELETE CASCADE,
      channel_id TEXT NOT NULL UNIQUE, -- 360Dialog channel ID
      phone_number TEXT NOT NULL,
      display_name TEXT,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'suspended', 'failed')),
      api_key TEXT, -- Channel-specific API key
      webhook_url TEXT, -- Channel-specific webhook URL
      quality_rating TEXT CHECK (quality_rating IN ('green', 'yellow', 'red')),
      messaging_limit INTEGER,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes
    CREATE INDEX idx_dialog_360_channels_client_id ON dialog_360_channels(client_id);
    CREATE INDEX idx_dialog_360_channels_channel_id ON dialog_360_channels(channel_id);
    CREATE INDEX idx_dialog_360_channels_phone_number ON dialog_360_channels(phone_number);
    CREATE INDEX idx_dialog_360_channels_status ON dialog_360_channels(status);
    
    RAISE NOTICE 'dialog_360_channels table created successfully';
  ELSE
    RAISE NOTICE 'dialog_360_channels table already exists, skipping creation';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON TABLE dialog_360_clients IS 'Company client accounts managed through 360Dialog Partner API';
COMMENT ON COLUMN dialog_360_clients.company_id IS 'Reference to the company that owns this client account';
COMMENT ON COLUMN dialog_360_clients.client_id IS 'Unique 360Dialog client ID';
COMMENT ON COLUMN dialog_360_clients.client_name IS 'Display name for the client account';
COMMENT ON COLUMN dialog_360_clients.status IS 'Current status of the client account';
COMMENT ON COLUMN dialog_360_clients.onboarded_at IS 'When the client was onboarded through Partner API';

COMMENT ON TABLE dialog_360_channels IS 'WhatsApp channels/phone numbers under 360Dialog client accounts';
COMMENT ON COLUMN dialog_360_channels.client_id IS 'Reference to the parent 360Dialog client';
COMMENT ON COLUMN dialog_360_channels.channel_id IS 'Unique 360Dialog channel ID';
COMMENT ON COLUMN dialog_360_channels.phone_number IS 'WhatsApp phone number for this channel';
COMMENT ON COLUMN dialog_360_channels.display_name IS 'Display name for the phone number';
COMMENT ON COLUMN dialog_360_channels.status IS 'Current status of the channel';
COMMENT ON COLUMN dialog_360_channels.api_key IS 'Channel-specific API key for messaging';
COMMENT ON COLUMN dialog_360_channels.webhook_url IS 'Channel-specific webhook URL';
COMMENT ON COLUMN dialog_360_channels.quality_rating IS 'WhatsApp quality rating (green/yellow/red)';
COMMENT ON COLUMN dialog_360_channels.messaging_limit IS 'Current messaging limit for this channel';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS dialog_360_channels CASCADE;
-- DROP TABLE IF EXISTS dialog_360_clients CASCADE;
