-- Migration: Fix subscription renewal data consistency
-- This migration addresses the critical bug where existing deployments show incorrect renewal dialogs
-- while fresh installations work correctly. The issue is caused by NULL values in subscription fields
-- that were added in later migrations but not properly initialized for existing companies.

-- Step 1: Identify and fix NULL subscription_status values
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Update NULL subscription_status to proper defaults based on company state
    UPDATE companies 
    SET subscription_status = CASE
        -- If company has an active subscription end date in the future, mark as active
        WHEN subscription_end_date IS NOT NULL AND subscription_end_date > NOW() THEN 'active'
        -- If company is in trial period, mark as trial
        WHEN is_in_trial = true AND trial_end_date IS NOT NULL AND trial_end_date > NOW() THEN 'trial'
        -- If company has expired subscription but no grace period set, mark as expired
        WHEN subscription_end_date IS NOT NULL AND subscription_end_date <= NOW() AND grace_period_end IS NULL THEN 'inactive'
        -- If company has expired subscription with grace period, check if still in grace
        WHEN subscription_end_date IS NOT NULL AND subscription_end_date <= NOW() AND grace_period_end IS NOT NULL THEN
            CASE WHEN grace_period_end > NOW() THEN 'grace_period' ELSE 'inactive' END
        -- Default case for companies without subscription data
        ELSE 'inactive'
    END
    WHERE subscription_status IS NULL;
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Fixed % companies with NULL subscription_status', affected_count;
END$$;

-- Step 2: Initialize missing grace_period_end for companies that should have it
DO $$
DECLARE
    affected_count INTEGER;
    default_grace_days INTEGER := 15; -- PowerChat's 15-day grace period
BEGIN
    -- Add grace period end date for companies with expired subscriptions but no grace period set
    UPDATE companies 
    SET grace_period_end = subscription_end_date + INTERVAL '15 days',
        subscription_status = 'grace_period'
    WHERE subscription_end_date IS NOT NULL 
      AND subscription_end_date <= NOW() 
      AND grace_period_end IS NULL
      AND subscription_status IN ('active', 'inactive', 'expired')
      AND (subscription_end_date + INTERVAL '15 days') > NOW(); -- Only if still within grace period
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Added grace period for % companies', affected_count;
END$$;

-- Step 3: Fix companies with expired grace periods
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Mark companies as inactive if their grace period has expired
    UPDATE companies 
    SET subscription_status = 'inactive'
    WHERE grace_period_end IS NOT NULL 
      AND grace_period_end <= NOW() 
      AND subscription_status = 'grace_period';
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Marked % companies as inactive (grace period expired)', affected_count;
END$$;

-- Step 4: Initialize auto_renewal field for existing companies
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Set auto_renewal to false for existing companies (conservative approach)
    -- New companies will get true by default from schema
    UPDATE companies 
    SET auto_renewal = false
    WHERE auto_renewal IS NULL;
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Initialized auto_renewal for % companies', affected_count;
END$$;

-- Step 5: Clean up inconsistent subscription data
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Fix companies marked as 'trial' but without proper trial dates
    UPDATE companies 
    SET subscription_status = 'inactive',
        is_in_trial = false
    WHERE subscription_status = 'trial' 
      AND (trial_end_date IS NULL OR trial_end_date <= NOW())
      AND (subscription_end_date IS NULL OR subscription_end_date <= NOW());
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Fixed % companies with inconsistent trial status', affected_count;
END$$;

-- Step 6: Initialize missing subscription metadata
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Initialize subscription_metadata for companies that don't have it
    UPDATE companies 
    SET subscription_metadata = '{}'::jsonb
    WHERE subscription_metadata IS NULL;
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RAISE NOTICE 'Initialized subscription_metadata for % companies', affected_count;
END$$;

-- Step 7: Add NOT NULL constraints for critical fields (after data cleanup)
DO $$
BEGIN
    -- Make subscription_status NOT NULL with proper default
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'subscription_status' AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE companies ALTER COLUMN subscription_status SET DEFAULT 'inactive';
        ALTER TABLE companies ALTER COLUMN subscription_status SET NOT NULL;
        RAISE NOTICE 'Made subscription_status NOT NULL with default';
    END IF;
    
    -- Make auto_renewal NOT NULL with proper default
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'auto_renewal' AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE companies ALTER COLUMN auto_renewal SET DEFAULT true;
        ALTER TABLE companies ALTER COLUMN auto_renewal SET NOT NULL;
        RAISE NOTICE 'Made auto_renewal NOT NULL with default';
    END IF;
    
    -- Make subscription_metadata NOT NULL with proper default
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'companies' AND column_name = 'subscription_metadata' AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE companies ALTER COLUMN subscription_metadata SET DEFAULT '{}'::jsonb;
        ALTER TABLE companies ALTER COLUMN subscription_metadata SET NOT NULL;
        RAISE NOTICE 'Made subscription_metadata NOT NULL with default';
    END IF;
END$$;

-- Step 8: Create validation function to prevent future inconsistencies
CREATE OR REPLACE FUNCTION validate_subscription_consistency()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure subscription_status is never NULL
    IF NEW.subscription_status IS NULL THEN
        NEW.subscription_status := 'inactive';
    END IF;
    
    -- Ensure auto_renewal is never NULL
    IF NEW.auto_renewal IS NULL THEN
        NEW.auto_renewal := true;
    END IF;
    
    -- Ensure subscription_metadata is never NULL
    IF NEW.subscription_metadata IS NULL THEN
        NEW.subscription_metadata := '{}'::jsonb;
    END IF;
    
    -- Auto-set grace period for expired subscriptions
    IF NEW.subscription_end_date IS NOT NULL 
       AND NEW.subscription_end_date <= NOW() 
       AND OLD.subscription_end_date IS DISTINCT FROM NEW.subscription_end_date
       AND NEW.grace_period_end IS NULL THEN
        NEW.grace_period_end := NEW.subscription_end_date + INTERVAL '15 days';
        NEW.subscription_status := 'grace_period';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to maintain consistency
DROP TRIGGER IF EXISTS subscription_consistency_trigger ON companies;
CREATE TRIGGER subscription_consistency_trigger
    BEFORE INSERT OR UPDATE ON companies
    FOR EACH ROW
    EXECUTE FUNCTION validate_subscription_consistency();

-- Step 9: Create data validation report
DO $$
DECLARE
    total_companies INTEGER;
    active_companies INTEGER;
    trial_companies INTEGER;
    grace_companies INTEGER;
    inactive_companies INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_companies FROM companies;
    SELECT COUNT(*) INTO active_companies FROM companies WHERE subscription_status = 'active';
    SELECT COUNT(*) INTO trial_companies FROM companies WHERE subscription_status = 'trial';
    SELECT COUNT(*) INTO grace_companies FROM companies WHERE subscription_status = 'grace_period';
    SELECT COUNT(*) INTO inactive_companies FROM companies WHERE subscription_status = 'inactive';
    
    RAISE NOTICE '=== SUBSCRIPTION DATA CONSISTENCY REPORT ===';
    RAISE NOTICE 'Total companies: %', total_companies;
    RAISE NOTICE 'Active subscriptions: %', active_companies;
    RAISE NOTICE 'Trial subscriptions: %', trial_companies;
    RAISE NOTICE 'Grace period subscriptions: %', grace_companies;
    RAISE NOTICE 'Inactive subscriptions: %', inactive_companies;
    RAISE NOTICE '=== END REPORT ===';
END$$;

-- Final notice
DO $$
BEGIN
    RAISE NOTICE 'Subscription renewal data consistency migration completed successfully!';
    RAISE NOTICE 'This migration fixes the critical bug where existing deployments showed incorrect renewal dialogs.';
    RAISE NOTICE 'All companies now have consistent subscription status data matching fresh installation behavior.';
END$$;
