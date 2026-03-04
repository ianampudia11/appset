-- Migration: Enhanced Subscription Management System
-- This migration adds comprehensive subscription management features while maintaining backward compatibility

-- Create or update subscription_status enum
DO $$
BEGIN
  -- First, create the enum if it doesn't exist (for new installations)
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
    CREATE TYPE subscription_status AS ENUM (
      'active', 'inactive', 'pending', 'cancelled', 'overdue', 'trial',
      'grace_period', 'paused', 'past_due'
    );
  ELSE
    -- If enum exists, add new values if they don't exist (for existing installations)
    IF NOT EXISTS (
      SELECT 1 FROM pg_enum
      WHERE enumlabel = 'grace_period'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'subscription_status')
    ) THEN
      ALTER TYPE subscription_status ADD VALUE 'grace_period';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_enum
      WHERE enumlabel = 'paused'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'subscription_status')
    ) THEN
      ALTER TYPE subscription_status ADD VALUE 'paused';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_enum
      WHERE enumlabel = 'past_due'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'subscription_status')
    ) THEN
      ALTER TYPE subscription_status ADD VALUE 'past_due';
    END IF;
  END IF;
END$$;

-- Update companies table subscription_status constraint to include new values
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'companies_subscription_status_check'
    AND table_name = 'companies'
  ) THEN
    ALTER TABLE companies DROP CONSTRAINT companies_subscription_status_check;
  END IF;

  -- Add updated constraint with new subscription status values
  ALTER TABLE companies ADD CONSTRAINT companies_subscription_status_check
    CHECK (subscription_status IN ('active', 'inactive', 'pending', 'cancelled', 'overdue', 'trial', 'grace_period', 'paused', 'past_due'));
END$$;

-- Add new fields to companies table for enhanced subscription management
ALTER TABLE companies ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS billing_cycle_anchor TIMESTAMP;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS grace_period_end TIMESTAMP;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS pause_start_date TIMESTAMP;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS pause_end_date TIMESTAMP;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS auto_renewal BOOLEAN DEFAULT TRUE;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS dunning_attempts INTEGER DEFAULT 0;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS last_dunning_attempt TIMESTAMP;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS subscription_metadata JSONB DEFAULT '{}';

-- Add new fields to plans table for enhanced features
ALTER TABLE plans ADD COLUMN IF NOT EXISTS billing_interval TEXT DEFAULT 'month' CHECK (billing_interval IN ('month', 'year', 'quarter'));
ALTER TABLE plans ADD COLUMN IF NOT EXISTS grace_period_days INTEGER DEFAULT 3;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS max_dunning_attempts INTEGER DEFAULT 3;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS soft_limit_percentage INTEGER DEFAULT 80;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS allow_pausing BOOLEAN DEFAULT TRUE;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS pause_max_days INTEGER DEFAULT 90;

-- Create subscription_events table for audit trail
CREATE TABLE IF NOT EXISTS subscription_events (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_data JSONB NOT NULL DEFAULT '{}',
  previous_status TEXT,
  new_status TEXT,
  triggered_by TEXT, -- 'system', 'admin', 'customer', 'payment_failed', etc.
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create subscription_usage_tracking table
CREATE TABLE IF NOT EXISTS subscription_usage_tracking (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  metric_name TEXT NOT NULL, -- 'users', 'contacts', 'channels', 'flows', 'campaigns', 'messages'
  current_usage INTEGER NOT NULL DEFAULT 0,
  limit_value INTEGER NOT NULL,
  soft_limit_reached BOOLEAN DEFAULT FALSE,
  hard_limit_reached BOOLEAN DEFAULT FALSE,
  last_warning_sent TIMESTAMP,
  reset_period TEXT DEFAULT 'monthly', -- 'monthly', 'daily', 'never'
  last_reset TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(company_id, metric_name)
);

-- Create dunning_management table
CREATE TABLE IF NOT EXISTS dunning_management (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  payment_transaction_id INTEGER REFERENCES payment_transactions(id),
  attempt_number INTEGER NOT NULL DEFAULT 1,
  attempt_date TIMESTAMP NOT NULL DEFAULT NOW(),
  attempt_type TEXT NOT NULL, -- 'email', 'webhook', 'manual'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'failed', 'bounced'
  response_data JSONB,
  next_attempt_date TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create subscription_plan_changes table for proration tracking
CREATE TABLE IF NOT EXISTS subscription_plan_changes (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  from_plan_id INTEGER REFERENCES plans(id),
  to_plan_id INTEGER NOT NULL REFERENCES plans(id),
  change_type TEXT NOT NULL, -- 'upgrade', 'downgrade', 'change'
  effective_date TIMESTAMP NOT NULL DEFAULT NOW(),
  proration_amount NUMERIC(10, 2) DEFAULT 0,
  proration_days INTEGER DEFAULT 0,
  billing_cycle_reset BOOLEAN DEFAULT FALSE,
  change_reason TEXT, -- 'customer_request', 'admin_action', 'auto_downgrade'
  processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create subscription_notifications table
CREATE TABLE IF NOT EXISTS subscription_notifications (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL, -- 'trial_expiring', 'payment_failed', 'usage_warning', 'subscription_renewed'
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'failed', 'cancelled'
  scheduled_for TIMESTAMP NOT NULL,
  sent_at TIMESTAMP,
  notification_data JSONB NOT NULL DEFAULT '{}',
  delivery_method TEXT DEFAULT 'email', -- 'email', 'webhook', 'in_app'
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Update payment_transactions table to support recurring billing
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS subscription_period_start TIMESTAMP;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS subscription_period_end TIMESTAMP;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS proration_amount NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS dunning_attempt INTEGER DEFAULT 0;

-- Add moyasar to payment_method enum if enum exists and value doesn't exist
DO $$
BEGIN
  -- Only try to add to enum if the enum type exists
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_enum
      WHERE enumlabel = 'moyasar'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')
    ) THEN
      ALTER TYPE payment_method ADD VALUE 'moyasar';
    END IF;
  END IF;
END$$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_companies_stripe_customer_id ON companies(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_companies_stripe_subscription_id ON companies(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_companies_subscription_status ON companies(subscription_status);
CREATE INDEX IF NOT EXISTS idx_companies_subscription_end_date ON companies(subscription_end_date);
CREATE INDEX IF NOT EXISTS idx_companies_grace_period_end ON companies(grace_period_end);

CREATE INDEX IF NOT EXISTS idx_subscription_events_company_id ON subscription_events(company_id);
CREATE INDEX IF NOT EXISTS idx_subscription_events_event_type ON subscription_events(event_type);
CREATE INDEX IF NOT EXISTS idx_subscription_events_created_at ON subscription_events(created_at);

CREATE INDEX IF NOT EXISTS idx_usage_tracking_company_id ON subscription_usage_tracking(company_id);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_metric_name ON subscription_usage_tracking(metric_name);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_soft_limit ON subscription_usage_tracking(soft_limit_reached);
CREATE INDEX IF NOT EXISTS idx_usage_tracking_hard_limit ON subscription_usage_tracking(hard_limit_reached);

CREATE INDEX IF NOT EXISTS idx_dunning_company_id ON dunning_management(company_id);
CREATE INDEX IF NOT EXISTS idx_dunning_next_attempt ON dunning_management(next_attempt_date);
CREATE INDEX IF NOT EXISTS idx_dunning_status ON dunning_management(status);

CREATE INDEX IF NOT EXISTS idx_plan_changes_company_id ON subscription_plan_changes(company_id);
CREATE INDEX IF NOT EXISTS idx_plan_changes_effective_date ON subscription_plan_changes(effective_date);
CREATE INDEX IF NOT EXISTS idx_plan_changes_processed ON subscription_plan_changes(processed);

CREATE INDEX IF NOT EXISTS idx_notifications_company_id ON subscription_notifications(company_id);
CREATE INDEX IF NOT EXISTS idx_notifications_scheduled_for ON subscription_notifications(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON subscription_notifications(status);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_recurring ON payment_transactions(is_recurring);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_period ON payment_transactions(subscription_period_start, subscription_period_end);

-- Add comments for documentation
COMMENT ON TABLE subscription_events IS 'Audit trail for all subscription-related events';
COMMENT ON TABLE subscription_usage_tracking IS 'Real-time usage tracking with soft/hard limits';
COMMENT ON TABLE dunning_management IS 'Failed payment retry and recovery management';
COMMENT ON TABLE subscription_plan_changes IS 'Plan change history with proration calculations';
COMMENT ON TABLE subscription_notifications IS 'Scheduled notification system for subscription events';

COMMENT ON COLUMN companies.stripe_customer_id IS 'Stripe customer ID for recurring billing';
COMMENT ON COLUMN companies.stripe_subscription_id IS 'Stripe subscription ID for automatic renewals';
COMMENT ON COLUMN companies.billing_cycle_anchor IS 'Fixed date for billing cycle alignment';
COMMENT ON COLUMN companies.grace_period_end IS 'End date for grace period after subscription expiry';
COMMENT ON COLUMN companies.auto_renewal IS 'Whether subscription should auto-renew';
COMMENT ON COLUMN companies.dunning_attempts IS 'Number of failed payment retry attempts';

COMMENT ON COLUMN plans.billing_interval IS 'Billing frequency: month, year, or quarter';
COMMENT ON COLUMN plans.grace_period_days IS 'Days of grace period after subscription expires';
COMMENT ON COLUMN plans.max_dunning_attempts IS 'Maximum failed payment retry attempts';
COMMENT ON COLUMN plans.soft_limit_percentage IS 'Percentage of limit to trigger soft warnings';
COMMENT ON COLUMN plans.allow_pausing IS 'Whether this plan allows subscription pausing';
COMMENT ON COLUMN plans.pause_max_days IS 'Maximum days a subscription can be paused';
