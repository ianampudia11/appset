-- Migration: Add AI Token Billing Support to Plans
-- This migration adds AI token usage limits and billing configuration to the plans system

-- Add AI token billing fields to plans table
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_tokens_included INTEGER DEFAULT 0;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_tokens_monthly_limit INTEGER DEFAULT NULL; -- NULL = unlimited
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_tokens_daily_limit INTEGER DEFAULT NULL; -- NULL = unlimited
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_overage_enabled BOOLEAN DEFAULT false;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_overage_rate DECIMAL(10, 6) DEFAULT 0.000000; -- Cost per token for overages
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_overage_block_enabled BOOLEAN DEFAULT false; -- Block usage when limit exceeded
ALTER TABLE plans ADD COLUMN IF NOT EXISTS ai_billing_enabled BOOLEAN DEFAULT false; -- Enable AI billing for this plan

-- Create plan AI provider configurations table for provider-specific limits and pricing
CREATE TABLE IF NOT EXISTS plan_ai_provider_configs (
  id SERIAL PRIMARY KEY,
  plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL, -- 'openai', 'anthropic', 'gemini', etc.
  
  -- Token limits per provider
  tokens_monthly_limit INTEGER DEFAULT NULL, -- NULL = use plan default
  tokens_daily_limit INTEGER DEFAULT NULL, -- NULL = use plan default
  
  -- Custom pricing per provider (overrides system pricing)
  custom_pricing_enabled BOOLEAN DEFAULT false,
  input_token_rate DECIMAL(10, 8) DEFAULT NULL, -- Cost per input token
  output_token_rate DECIMAL(10, 8) DEFAULT NULL, -- Cost per output token
  
  -- Provider-specific settings
  enabled BOOLEAN DEFAULT true,
  priority INTEGER DEFAULT 0, -- For ordering providers in UI
  
  -- Metadata for additional provider-specific settings
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ensure unique provider per plan
  UNIQUE(plan_id, provider)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_plan_ai_provider_configs_plan_id ON plan_ai_provider_configs(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_ai_provider_configs_provider ON plan_ai_provider_configs(provider);

-- Create plan AI usage limits table for tracking monthly/daily usage per plan
CREATE TABLE IF NOT EXISTS plan_ai_usage_tracking (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL,
  
  -- Usage tracking
  tokens_used_monthly INTEGER DEFAULT 0,
  tokens_used_daily INTEGER DEFAULT 0,
  requests_monthly INTEGER DEFAULT 0,
  requests_daily INTEGER DEFAULT 0,
  cost_monthly DECIMAL(10, 6) DEFAULT 0.000000,
  cost_daily DECIMAL(10, 6) DEFAULT 0.000000,
  
  -- Overage tracking
  overage_tokens_monthly INTEGER DEFAULT 0,
  overage_cost_monthly DECIMAL(10, 6) DEFAULT 0.000000,
  
  -- Tracking period
  usage_month INTEGER NOT NULL, -- 1-12
  usage_year INTEGER NOT NULL,
  usage_date DATE NOT NULL, -- For daily tracking
  
  -- Status flags
  monthly_limit_reached BOOLEAN DEFAULT false,
  daily_limit_reached BOOLEAN DEFAULT false,
  monthly_warning_sent BOOLEAN DEFAULT false,
  daily_warning_sent BOOLEAN DEFAULT false,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ensure unique tracking per company/plan/provider/period
  UNIQUE(company_id, plan_id, provider, usage_year, usage_month, usage_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_plan_ai_usage_tracking_company_id ON plan_ai_usage_tracking(company_id);
CREATE INDEX IF NOT EXISTS idx_plan_ai_usage_tracking_plan_id ON plan_ai_usage_tracking(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_ai_usage_tracking_provider ON plan_ai_usage_tracking(provider);
CREATE INDEX IF NOT EXISTS idx_plan_ai_usage_tracking_date ON plan_ai_usage_tracking(usage_date);
CREATE INDEX IF NOT EXISTS idx_plan_ai_usage_tracking_month_year ON plan_ai_usage_tracking(usage_year, usage_month);

-- Create plan AI billing events table for tracking billing events and overages
CREATE TABLE IF NOT EXISTS plan_ai_billing_events (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL,
  
  -- Event details
  event_type VARCHAR(50) NOT NULL, -- 'overage', 'limit_warning', 'limit_exceeded', 'billing_cycle'
  event_data JSONB NOT NULL DEFAULT '{}',
  
  -- Billing information
  tokens_consumed INTEGER DEFAULT 0,
  cost_amount DECIMAL(10, 6) DEFAULT 0.000000,
  billing_period_start DATE,
  billing_period_end DATE,
  
  -- Processing status
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMP,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Metadata for additional event-specific data
  metadata JSONB DEFAULT '{}'
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_plan_ai_billing_events_company_id ON plan_ai_billing_events(company_id);
CREATE INDEX IF NOT EXISTS idx_plan_ai_billing_events_plan_id ON plan_ai_billing_events(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_ai_billing_events_type ON plan_ai_billing_events(event_type);
CREATE INDEX IF NOT EXISTS idx_plan_ai_billing_events_processed ON plan_ai_billing_events(processed);
CREATE INDEX IF NOT EXISTS idx_plan_ai_billing_events_created_at ON plan_ai_billing_events(created_at);

-- Add comments for documentation
COMMENT ON COLUMN plans.ai_tokens_included IS 'Number of AI tokens included in the base plan price';
COMMENT ON COLUMN plans.ai_tokens_monthly_limit IS 'Maximum AI tokens allowed per month (NULL = unlimited)';
COMMENT ON COLUMN plans.ai_tokens_daily_limit IS 'Maximum AI tokens allowed per day (NULL = unlimited)';
COMMENT ON COLUMN plans.ai_overage_enabled IS 'Whether overage billing is enabled for this plan';
COMMENT ON COLUMN plans.ai_overage_rate IS 'Cost per token for usage beyond included tokens';
COMMENT ON COLUMN plans.ai_overage_block_enabled IS 'Whether to block AI usage when limits are exceeded';
COMMENT ON COLUMN plans.ai_billing_enabled IS 'Whether AI billing features are enabled for this plan';

COMMENT ON TABLE plan_ai_provider_configs IS 'Provider-specific AI configuration and pricing for plans';
COMMENT ON TABLE plan_ai_usage_tracking IS 'Tracks AI token usage against plan limits for billing';
COMMENT ON TABLE plan_ai_billing_events IS 'Records AI billing events and overage charges';
