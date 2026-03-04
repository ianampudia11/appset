-- Migration: Add Meta Configuration Enhancements
-- This migration adds new fields to support enhanced Meta Partner Configuration features
-- including webhook auto-configuration, health monitoring, and coexistence mode support

-- Add new fields to partner_configurations table
DO $$
BEGIN
  -- Add coexistence_mode
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'coexistence_mode'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN coexistence_mode BOOLEAN DEFAULT false;
    RAISE NOTICE 'Added coexistence_mode column to partner_configurations';
  END IF;

  -- Add webhook_subscription_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'webhook_subscription_status'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN webhook_subscription_status TEXT;
    RAISE NOTICE 'Added webhook_subscription_status column to partner_configurations';
  END IF;

  -- Add last_validated_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'last_validated_at'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN last_validated_at TIMESTAMP;
    RAISE NOTICE 'Added last_validated_at column to partner_configurations';
  END IF;

  -- Add validation_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'validation_status'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN validation_status TEXT;
    RAISE NOTICE 'Added validation_status column to partner_configurations';
  END IF;

  -- Add usage_count
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'usage_count'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN usage_count INTEGER DEFAULT 0;
    RAISE NOTICE 'Added usage_count column to partner_configurations';
  END IF;

  -- Add last_used_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'last_used_at'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN last_used_at TIMESTAMP;
    RAISE NOTICE 'Added last_used_at column to partner_configurations';
  END IF;

  -- Add api_version
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'api_version'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN api_version TEXT;
    RAISE NOTICE 'Added api_version column to partner_configurations';
  END IF;

  -- Add webhook_field_subscriptions
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'webhook_field_subscriptions'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN webhook_field_subscriptions JSONB;
    RAISE NOTICE 'Added webhook_field_subscriptions column to partner_configurations';
  END IF;

  -- Add health_check_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'partner_configurations' AND column_name = 'health_check_status'
  ) THEN
    ALTER TABLE partner_configurations ADD COLUMN health_check_status JSONB;
    RAISE NOTICE 'Added health_check_status column to partner_configurations';
  END IF;
END$$;

-- Add new fields to meta_whatsapp_clients table
DO $$
BEGIN
  -- Add onboarding_state
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'onboarding_state'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN onboarding_state TEXT;
    RAISE NOTICE 'Added onboarding_state column to meta_whatsapp_clients';
  END IF;

  -- Add webhook_configured_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'webhook_configured_at'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN webhook_configured_at TIMESTAMP;
    RAISE NOTICE 'Added webhook_configured_at column to meta_whatsapp_clients';
  END IF;

  -- Add coexistence_mode
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'coexistence_mode'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN coexistence_mode BOOLEAN DEFAULT false;
    RAISE NOTICE 'Added coexistence_mode column to meta_whatsapp_clients';
  END IF;

  -- Add configuration_errors
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'configuration_errors'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN configuration_errors JSONB;
    RAISE NOTICE 'Added configuration_errors column to meta_whatsapp_clients';
  END IF;

  -- Add last_health_check_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'last_health_check_at'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN last_health_check_at TIMESTAMP;
    RAISE NOTICE 'Added last_health_check_at column to meta_whatsapp_clients';
  END IF;

  -- Add health_check_status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_clients' AND column_name = 'health_check_status'
  ) THEN
    ALTER TABLE meta_whatsapp_clients ADD COLUMN health_check_status TEXT;
    RAISE NOTICE 'Added health_check_status column to meta_whatsapp_clients';
  END IF;
END$$;

-- Add new fields to meta_whatsapp_phone_numbers table
DO $$
BEGIN
  -- Add webhook_subscription_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_phone_numbers' AND column_name = 'webhook_subscription_id'
  ) THEN
    ALTER TABLE meta_whatsapp_phone_numbers ADD COLUMN webhook_subscription_id TEXT;
    RAISE NOTICE 'Added webhook_subscription_id column to meta_whatsapp_phone_numbers';
  END IF;

  -- Add last_webhook_received_at
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_phone_numbers' AND column_name = 'last_webhook_received_at'
  ) THEN
    ALTER TABLE meta_whatsapp_phone_numbers ADD COLUMN last_webhook_received_at TIMESTAMP;
    RAISE NOTICE 'Added last_webhook_received_at column to meta_whatsapp_phone_numbers';
  END IF;

  -- Add webhook_error_count
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_phone_numbers' AND column_name = 'webhook_error_count'
  ) THEN
    ALTER TABLE meta_whatsapp_phone_numbers ADD COLUMN webhook_error_count INTEGER DEFAULT 0;
    RAISE NOTICE 'Added webhook_error_count column to meta_whatsapp_phone_numbers';
  END IF;

  -- Add last_webhook_error
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_phone_numbers' AND column_name = 'last_webhook_error'
  ) THEN
    ALTER TABLE meta_whatsapp_phone_numbers ADD COLUMN last_webhook_error TEXT;
    RAISE NOTICE 'Added last_webhook_error column to meta_whatsapp_phone_numbers';
  END IF;

  -- Add throughput_limit
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'meta_whatsapp_phone_numbers' AND column_name = 'throughput_limit'
  ) THEN
    ALTER TABLE meta_whatsapp_phone_numbers ADD COLUMN throughput_limit INTEGER;
    RAISE NOTICE 'Added throughput_limit column to meta_whatsapp_phone_numbers';
  END IF;
END$$;

-- Create indexes for performance
DO $$
BEGIN
  -- Index on partner_configurations for health checks
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_partner_configurations_last_validated_at'
  ) THEN
    CREATE INDEX idx_partner_configurations_last_validated_at ON partner_configurations(last_validated_at);
    RAISE NOTICE 'Created index on partner_configurations.last_validated_at';
  END IF;

  -- Index on meta_whatsapp_clients for onboarding state
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_meta_whatsapp_clients_onboarding_state'
  ) THEN
    CREATE INDEX idx_meta_whatsapp_clients_onboarding_state ON meta_whatsapp_clients(onboarding_state);
    RAISE NOTICE 'Created index on meta_whatsapp_clients.onboarding_state';
  END IF;

  -- Index on meta_whatsapp_phone_numbers for webhook tracking
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_meta_whatsapp_phone_numbers_webhook_subscription_id'
  ) THEN
    CREATE INDEX idx_meta_whatsapp_phone_numbers_webhook_subscription_id ON meta_whatsapp_phone_numbers(webhook_subscription_id);
    RAISE NOTICE 'Created index on meta_whatsapp_phone_numbers.webhook_subscription_id';
  END IF;
END$$;

-- Rollback statements (for reference, commented out)
/*
-- Rollback partner_configurations fields
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS coexistence_mode;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS webhook_subscription_status;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS last_validated_at;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS validation_status;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS usage_count;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS last_used_at;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS api_version;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS webhook_field_subscriptions;
ALTER TABLE partner_configurations DROP COLUMN IF EXISTS health_check_status;

-- Rollback meta_whatsapp_clients fields
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS onboarding_state;
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS webhook_configured_at;
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS coexistence_mode;
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS configuration_errors;
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS last_health_check_at;
ALTER TABLE meta_whatsapp_clients DROP COLUMN IF EXISTS health_check_status;

-- Rollback meta_whatsapp_phone_numbers fields
ALTER TABLE meta_whatsapp_phone_numbers DROP COLUMN IF EXISTS webhook_subscription_id;
ALTER TABLE meta_whatsapp_phone_numbers DROP COLUMN IF EXISTS last_webhook_received_at;
ALTER TABLE meta_whatsapp_phone_numbers DROP COLUMN IF EXISTS webhook_error_count;
ALTER TABLE meta_whatsapp_phone_numbers DROP COLUMN IF EXISTS last_webhook_error;
ALTER TABLE meta_whatsapp_phone_numbers DROP COLUMN IF EXISTS throughput_limit;

-- Rollback indexes
DROP INDEX IF EXISTS idx_partner_configurations_last_validated_at;
DROP INDEX IF EXISTS idx_meta_whatsapp_clients_onboarding_state;
DROP INDEX IF EXISTS idx_meta_whatsapp_phone_numbers_webhook_subscription_id;
*/

