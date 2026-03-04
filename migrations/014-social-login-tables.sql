-- Migration 014: Social Login Tables
-- This migration adds tables for social login functionality

-- Create user_social_accounts table to link users with their social accounts
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_social_accounts') THEN
    
    CREATE TABLE user_social_accounts (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      provider TEXT NOT NULL CHECK (provider IN ('google', 'facebook', 'apple')),
      provider_user_id TEXT NOT NULL, -- The user ID from the social provider
      provider_email TEXT, -- Email from the social provider
      provider_name TEXT, -- Full name from the social provider
      provider_avatar_url TEXT, -- Avatar URL from the social provider
      access_token TEXT, -- OAuth access token (encrypted)
      refresh_token TEXT, -- OAuth refresh token (encrypted)
      token_expires_at TIMESTAMP, -- When the access token expires
      provider_data JSONB DEFAULT '{}', -- Additional provider-specific data
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      
      -- Ensure one account per provider per user
      UNIQUE(user_id, provider),
      -- Ensure one provider account per provider user ID
      UNIQUE(provider, provider_user_id)
    );

    -- Create indexes for better performance
    CREATE INDEX idx_user_social_accounts_user_id ON user_social_accounts(user_id);
    CREATE INDEX idx_user_social_accounts_provider ON user_social_accounts(provider);
    CREATE INDEX idx_user_social_accounts_provider_user_id ON user_social_accounts(provider_user_id);
    CREATE INDEX idx_user_social_accounts_provider_email ON user_social_accounts(provider_email);
    
    RAISE NOTICE 'user_social_accounts table created successfully';
  ELSE
    RAISE NOTICE 'user_social_accounts table already exists, skipping creation';
  END IF;
END$$;

-- Insert default social login configuration settings into app_settings
DO $$
BEGIN
  -- Google OAuth configuration
  IF NOT EXISTS (SELECT 1 FROM app_settings WHERE key = 'social_login_google') THEN
    INSERT INTO app_settings (key, value) VALUES (
      'social_login_google',
      '{
        "enabled": false,
        "client_id": "",
        "client_secret": "",
        "callback_url": "/api/auth/google/callback"
      }'::jsonb
    );
    RAISE NOTICE 'Google OAuth configuration added to app_settings';
  END IF;

  -- Facebook OAuth configuration
  IF NOT EXISTS (SELECT 1 FROM app_settings WHERE key = 'social_login_facebook') THEN
    INSERT INTO app_settings (key, value) VALUES (
      'social_login_facebook',
      '{
        "enabled": false,
        "app_id": "",
        "app_secret": "",
        "callback_url": "/api/auth/facebook/callback"
      }'::jsonb
    );
    RAISE NOTICE 'Facebook OAuth configuration added to app_settings';
  END IF;

  -- Apple OAuth configuration
  IF NOT EXISTS (SELECT 1 FROM app_settings WHERE key = 'social_login_apple') THEN
    INSERT INTO app_settings (key, value) VALUES (
      'social_login_apple',
      '{
        "enabled": false,
        "client_id": "",
        "team_id": "",
        "key_id": "",
        "private_key": "",
        "callback_url": "/api/auth/apple/callback"
      }'::jsonb
    );
    RAISE NOTICE 'Apple OAuth configuration added to app_settings';
  END IF;
END$$;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_social_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trigger_update_user_social_accounts_updated_at') THEN
    CREATE TRIGGER trigger_update_user_social_accounts_updated_at
      BEFORE UPDATE ON user_social_accounts
      FOR EACH ROW
      EXECUTE FUNCTION update_user_social_accounts_updated_at();
    RAISE NOTICE 'Trigger for user_social_accounts updated_at created successfully';
  END IF;
END$$;
