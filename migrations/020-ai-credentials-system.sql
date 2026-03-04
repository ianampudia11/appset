-- Migration: AI Credentials Management System
-- Description: Add support for system-wide and company-specific AI credentials
-- Date: 2025-01-03

-- System-wide AI credentials (managed by super admin)
CREATE TABLE IF NOT EXISTS system_ai_credentials (
  id SERIAL PRIMARY KEY,
  provider VARCHAR(50) NOT NULL CHECK (provider IN ('openai', 'anthropic', 'gemini', 'deepseek', 'xai')),
  api_key_encrypted TEXT NOT NULL,
  display_name VARCHAR(100),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  usage_limit_monthly INTEGER, -- Optional monthly usage limit
  usage_count_current INTEGER DEFAULT 0,
  last_validated_at TIMESTAMP,
  validation_status VARCHAR(20) DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'invalid', 'expired')),
  validation_error TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ensure only one default per provider
  UNIQUE(provider, is_default) DEFERRABLE INITIALLY DEFERRED
);

-- Company-specific AI credentials (managed by company admins)
CREATE TABLE IF NOT EXISTS company_ai_credentials (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL CHECK (provider IN ('openai', 'anthropic', 'gemini', 'deepseek', 'xai')),
  api_key_encrypted TEXT NOT NULL,
  display_name VARCHAR(100),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  usage_limit_monthly INTEGER, -- Optional monthly usage limit
  usage_count_current INTEGER DEFAULT 0,
  last_validated_at TIMESTAMP,
  validation_status VARCHAR(20) DEFAULT 'pending' CHECK (validation_status IN ('pending', 'valid', 'invalid', 'expired')),
  validation_error TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ensure unique provider per company (companies can have only one credential per provider)
  UNIQUE(company_id, provider)
);

-- AI credential usage tracking (for billing and analytics)
CREATE TABLE IF NOT EXISTS ai_credential_usage (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  credential_type VARCHAR(20) NOT NULL CHECK (credential_type IN ('system', 'company', 'environment')),
  credential_id INTEGER, -- NULL for environment variables
  provider VARCHAR(50) NOT NULL,
  model VARCHAR(100),
  tokens_input INTEGER DEFAULT 0,
  tokens_output INTEGER DEFAULT 0,
  tokens_total INTEGER DEFAULT 0,
  cost_estimated DECIMAL(10, 6) DEFAULT 0.00, -- Estimated cost in USD
  request_count INTEGER DEFAULT 1,
  conversation_id INTEGER REFERENCES conversations(id) ON DELETE SET NULL,
  flow_id INTEGER REFERENCES flows(id) ON DELETE SET NULL,
  node_id VARCHAR(100), -- Flow node ID that made the request
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- AI credential preferences (per company settings)
CREATE TABLE IF NOT EXISTS company_ai_preferences (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE UNIQUE,
  default_provider VARCHAR(50) DEFAULT 'gemini',
  credential_preference VARCHAR(20) DEFAULT 'system' CHECK (credential_preference IN ('company', 'system', 'auto')),
  -- 'company': Use company credentials only
  -- 'system': Use system credentials only  
  -- 'auto': Try company first, fallback to system
  fallback_enabled BOOLEAN DEFAULT true,
  usage_alerts_enabled BOOLEAN DEFAULT true,
  usage_alert_threshold INTEGER DEFAULT 80, -- Alert at 80% of monthly limit
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_system_ai_credentials_provider ON system_ai_credentials(provider, is_active);
CREATE INDEX IF NOT EXISTS idx_system_ai_credentials_default ON system_ai_credentials(provider, is_default) WHERE is_default = true;
CREATE INDEX IF NOT EXISTS idx_company_ai_credentials_company ON company_ai_credentials(company_id, provider, is_active);
CREATE INDEX IF NOT EXISTS idx_ai_usage_company_date ON ai_credential_usage(company_id, usage_date);
CREATE INDEX IF NOT EXISTS idx_ai_usage_credential ON ai_credential_usage(credential_type, credential_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_provider ON ai_credential_usage(provider, usage_date);
CREATE INDEX IF NOT EXISTS idx_ai_usage_monthly ON ai_credential_usage(company_id, provider, usage_date);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_system_ai_credentials_updated_at 
    BEFORE UPDATE ON system_ai_credentials 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_ai_credentials_updated_at 
    BEFORE UPDATE ON company_ai_credentials 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_company_ai_preferences_updated_at 
    BEFORE UPDATE ON company_ai_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default system preferences for existing companies
INSERT INTO company_ai_preferences (company_id, credential_preference, fallback_enabled)
SELECT id, 'auto', true 
FROM companies 
WHERE id NOT IN (SELECT company_id FROM company_ai_preferences WHERE company_id IS NOT NULL);

-- Add comments for documentation
COMMENT ON TABLE system_ai_credentials IS 'System-wide AI provider credentials managed by super admin';
COMMENT ON TABLE company_ai_credentials IS 'Company-specific AI provider credentials managed by company admins';
COMMENT ON TABLE ai_credential_usage IS 'Tracks AI API usage for billing and analytics';
COMMENT ON TABLE company_ai_preferences IS 'Company preferences for AI credential usage and fallback behavior';

COMMENT ON COLUMN system_ai_credentials.api_key_encrypted IS 'Encrypted API key using application encryption key';
COMMENT ON COLUMN company_ai_credentials.api_key_encrypted IS 'Encrypted API key using application encryption key';
COMMENT ON COLUMN ai_credential_usage.credential_type IS 'Source of credentials: system, company, or environment variable';
COMMENT ON COLUMN company_ai_preferences.credential_preference IS 'Preferred credential source for this company';
