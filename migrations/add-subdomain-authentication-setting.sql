-- Migration: Add subdomain authentication setting
-- This migration adds the subdomain authentication feature toggle to app settings

-- Insert the subdomain authentication setting (disabled by default)
INSERT INTO app_settings (key, value, created_at, updated_at)
VALUES (
  'subdomain_authentication',
  'false',
  NOW(),
  NOW()
)
ON CONFLICT (key) DO UPDATE SET updated_at = NOW();

-- Add a comment to document the setting
COMMENT ON TABLE app_settings IS 'Global application settings including feature toggles';
