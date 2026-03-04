-- Add missing columns to companies table to match schema
-- This migration ensures the companies table has all columns defined in the schema

DO $$ 
BEGIN
    -- Add subdomain column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'subdomain'
    ) THEN
        ALTER TABLE companies ADD COLUMN subdomain TEXT UNIQUE;
        RAISE NOTICE 'Added subdomain column to companies table';
    END IF;

    -- Add register_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'register_number'
    ) THEN
        ALTER TABLE companies ADD COLUMN register_number TEXT;
        RAISE NOTICE 'Added register_number column to companies table';
    END IF;

    -- Add company_email column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'company_email'
    ) THEN
        ALTER TABLE companies ADD COLUMN company_email TEXT;
        RAISE NOTICE 'Added company_email column to companies table';
    END IF;

    -- Add contact_person column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'contact_person'
    ) THEN
        ALTER TABLE companies ADD COLUMN contact_person TEXT;
        RAISE NOTICE 'Added contact_person column to companies table';
    END IF;

    -- Add iban column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'iban'
    ) THEN
        ALTER TABLE companies ADD COLUMN iban TEXT;
        RAISE NOTICE 'Added iban column to companies table';
    END IF;

    -- Add stripe_customer_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'stripe_customer_id'
    ) THEN
        ALTER TABLE companies ADD COLUMN stripe_customer_id TEXT;
        RAISE NOTICE 'Added stripe_customer_id column to companies table';
    END IF;

    -- Add stripe_subscription_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'stripe_subscription_id'
    ) THEN
        ALTER TABLE companies ADD COLUMN stripe_subscription_id TEXT;
        RAISE NOTICE 'Added stripe_subscription_id column to companies table';
    END IF;

    -- Add billing_cycle_anchor column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'billing_cycle_anchor'
    ) THEN
        ALTER TABLE companies ADD COLUMN billing_cycle_anchor TIMESTAMP;
        RAISE NOTICE 'Added billing_cycle_anchor column to companies table';
    END IF;

    -- Add grace_period_end column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'grace_period_end'
    ) THEN
        ALTER TABLE companies ADD COLUMN grace_period_end TIMESTAMP;
        RAISE NOTICE 'Added grace_period_end column to companies table';
    END IF;

    -- Add pause_start_date column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'pause_start_date'
    ) THEN
        ALTER TABLE companies ADD COLUMN pause_start_date TIMESTAMP;
        RAISE NOTICE 'Added pause_start_date column to companies table';
    END IF;

    -- Add pause_end_date column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'pause_end_date'
    ) THEN
        ALTER TABLE companies ADD COLUMN pause_end_date TIMESTAMP;
        RAISE NOTICE 'Added pause_end_date column to companies table';
    END IF;

    -- Add auto_renewal column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'auto_renewal'
    ) THEN
        ALTER TABLE companies ADD COLUMN auto_renewal BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added auto_renewal column to companies table';
    END IF;

    -- Add dunning_attempts column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'dunning_attempts'
    ) THEN
        ALTER TABLE companies ADD COLUMN dunning_attempts INTEGER DEFAULT 0;
        RAISE NOTICE 'Added dunning_attempts column to companies table';
    END IF;

    -- Add last_dunning_attempt column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'last_dunning_attempt'
    ) THEN
        ALTER TABLE companies ADD COLUMN last_dunning_attempt TIMESTAMP;
        RAISE NOTICE 'Added last_dunning_attempt column to companies table';
    END IF;

    -- Add subscription_metadata column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'subscription_metadata'
    ) THEN
        ALTER TABLE companies ADD COLUMN subscription_metadata JSONB DEFAULT '{}';
        RAISE NOTICE 'Added subscription_metadata column to companies table';
    END IF;

    -- Add current_storage_used column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'current_storage_used'
    ) THEN
        ALTER TABLE companies ADD COLUMN current_storage_used INTEGER DEFAULT 0;
        RAISE NOTICE 'Added current_storage_used column to companies table';
    END IF;

    -- Add current_bandwidth_used column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'current_bandwidth_used'
    ) THEN
        ALTER TABLE companies ADD COLUMN current_bandwidth_used INTEGER DEFAULT 0;
        RAISE NOTICE 'Added current_bandwidth_used column to companies table';
    END IF;

    -- Add files_count column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'files_count'
    ) THEN
        ALTER TABLE companies ADD COLUMN files_count INTEGER DEFAULT 0;
        RAISE NOTICE 'Added files_count column to companies table';
    END IF;

    -- Add last_usage_update column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'last_usage_update'
    ) THEN
        ALTER TABLE companies ADD COLUMN last_usage_update TIMESTAMP DEFAULT NOW();
        RAISE NOTICE 'Added last_usage_update column to companies table';
    END IF;

END $$;

-- Update subscription_status constraint to include new values
DO $$
BEGIN
    -- Drop the old constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'companies_subscription_status_check'
    ) THEN
        ALTER TABLE companies DROP CONSTRAINT companies_subscription_status_check;
    END IF;
    
    -- Add the updated constraint
    ALTER TABLE companies ADD CONSTRAINT companies_subscription_status_check 
    CHECK (subscription_status IN ('active', 'inactive', 'pending', 'cancelled', 'overdue', 'trial', 'grace_period', 'paused', 'past_due'));
    
    RAISE NOTICE 'Updated subscription_status constraint';
END $$;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_companies_subdomain ON companies(subdomain);
CREATE INDEX IF NOT EXISTS idx_companies_stripe_customer_id ON companies(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_companies_subscription_status ON companies(subscription_status);

-- Add comments for documentation
COMMENT ON COLUMN companies.register_number IS 'Company registration number';
COMMENT ON COLUMN companies.company_email IS 'Official company email address';
COMMENT ON COLUMN companies.contact_person IS 'Primary contact person for the company';
COMMENT ON COLUMN companies.iban IS 'International Bank Account Number for billing';
COMMENT ON COLUMN companies.current_storage_used IS 'Current storage usage in MB';
COMMENT ON COLUMN companies.current_bandwidth_used IS 'Monthly bandwidth usage in MB';
COMMENT ON COLUMN companies.files_count IS 'Current number of files stored';
