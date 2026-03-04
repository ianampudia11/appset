-- Migration: Add Zoho Calendar tokens table
-- This migration adds support for Zoho Calendar integration alongside existing Google Calendar integration

-- Create zoho_calendar_tokens table
CREATE TABLE IF NOT EXISTS zoho_calendar_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_type TEXT,
  expires_in INTEGER,
  scope TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, company_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_zoho_calendar_tokens_user_company ON zoho_calendar_tokens(user_id, company_id);
CREATE INDEX IF NOT EXISTS idx_zoho_calendar_tokens_company ON zoho_calendar_tokens(company_id);

-- Add comments for documentation
COMMENT ON TABLE zoho_calendar_tokens IS 'Stores OAuth tokens for Zoho Calendar integration per user and company';
COMMENT ON COLUMN zoho_calendar_tokens.user_id IS 'Reference to the user who authenticated with Zoho Calendar';
COMMENT ON COLUMN zoho_calendar_tokens.company_id IS 'Reference to the company the user belongs to';
COMMENT ON COLUMN zoho_calendar_tokens.access_token IS 'Zoho OAuth access token for API calls';
COMMENT ON COLUMN zoho_calendar_tokens.refresh_token IS 'Zoho OAuth refresh token for token renewal';
COMMENT ON COLUMN zoho_calendar_tokens.token_type IS 'Type of token (usually "bearer")';
COMMENT ON COLUMN zoho_calendar_tokens.expires_in IS 'Token expiry time in seconds';
COMMENT ON COLUMN zoho_calendar_tokens.scope IS 'OAuth scopes granted for this token';
