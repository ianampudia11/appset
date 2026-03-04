-- Migration: Fix subscription status constraint
-- This migration updates the companies table constraint to include new subscription status values

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
    
  RAISE NOTICE 'Successfully updated companies subscription_status constraint';
END$$;
