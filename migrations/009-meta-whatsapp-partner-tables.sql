-- Meta WhatsApp Business API Partner Tables Migration
-- This migration creates tables for Meta WhatsApp Business API Partner management

-- Create meta_whatsapp_clients table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'meta_whatsapp_clients'
  ) THEN
    RAISE NOTICE 'Creating meta_whatsapp_clients table...';
    
    CREATE TABLE meta_whatsapp_clients (
      id SERIAL PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      business_account_id TEXT NOT NULL UNIQUE, -- Meta Business Account ID
      business_account_name TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
      onboarded_at TIMESTAMP DEFAULT NOW(),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes
    CREATE INDEX idx_meta_whatsapp_clients_company_id ON meta_whatsapp_clients(company_id);
    CREATE INDEX idx_meta_whatsapp_clients_business_account_id ON meta_whatsapp_clients(business_account_id);
    CREATE INDEX idx_meta_whatsapp_clients_status ON meta_whatsapp_clients(status);
    
    RAISE NOTICE 'meta_whatsapp_clients table created successfully';
  ELSE
    RAISE NOTICE 'meta_whatsapp_clients table already exists, skipping creation';
  END IF;
END$$;

-- Create meta_whatsapp_phone_numbers table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'meta_whatsapp_phone_numbers'
  ) THEN
    RAISE NOTICE 'Creating meta_whatsapp_phone_numbers table...';
    
    CREATE TABLE meta_whatsapp_phone_numbers (
      id SERIAL PRIMARY KEY,
      client_id INTEGER NOT NULL REFERENCES meta_whatsapp_clients(id) ON DELETE CASCADE,
      phone_number_id TEXT NOT NULL UNIQUE, -- Meta Phone Number ID
      phone_number TEXT NOT NULL,
      display_name TEXT,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'unverified', 'suspended')),
      quality_rating TEXT CHECK (quality_rating IN ('green', 'yellow', 'red')),
      messaging_limit INTEGER,
      access_token TEXT, -- Phone number specific access token
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes
    CREATE INDEX idx_meta_whatsapp_phone_numbers_client_id ON meta_whatsapp_phone_numbers(client_id);
    CREATE INDEX idx_meta_whatsapp_phone_numbers_phone_number_id ON meta_whatsapp_phone_numbers(phone_number_id);
    CREATE INDEX idx_meta_whatsapp_phone_numbers_phone_number ON meta_whatsapp_phone_numbers(phone_number);
    CREATE INDEX idx_meta_whatsapp_phone_numbers_status ON meta_whatsapp_phone_numbers(status);
    
    RAISE NOTICE 'meta_whatsapp_phone_numbers table created successfully';
  ELSE
    RAISE NOTICE 'meta_whatsapp_phone_numbers table already exists, skipping creation';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON TABLE meta_whatsapp_clients IS 'Company business accounts managed through Meta WhatsApp Business API Tech Provider';
COMMENT ON COLUMN meta_whatsapp_clients.company_id IS 'Reference to the company that owns this business account';
COMMENT ON COLUMN meta_whatsapp_clients.business_account_id IS 'Unique Meta Business Account ID';
COMMENT ON COLUMN meta_whatsapp_clients.business_account_name IS 'Display name for the business account';
COMMENT ON COLUMN meta_whatsapp_clients.status IS 'Current status of the business account';
COMMENT ON COLUMN meta_whatsapp_clients.onboarded_at IS 'When the business account was onboarded through embedded signup';

COMMENT ON TABLE meta_whatsapp_phone_numbers IS 'WhatsApp phone numbers under Meta business accounts';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.client_id IS 'Reference to the parent Meta WhatsApp client';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.phone_number_id IS 'Unique Meta Phone Number ID';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.phone_number IS 'WhatsApp phone number';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.display_name IS 'Display name for the phone number';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.status IS 'Current verification status of the phone number';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.quality_rating IS 'WhatsApp quality rating (green/yellow/red)';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.messaging_limit IS 'Current messaging limit for this phone number';
COMMENT ON COLUMN meta_whatsapp_phone_numbers.access_token IS 'Phone number specific access token for API calls';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS meta_whatsapp_phone_numbers CASCADE;
-- DROP TABLE IF EXISTS meta_whatsapp_clients CASCADE;
