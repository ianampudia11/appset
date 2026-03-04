-- Migration: Add plan duration fields
-- Description: Add billingInterval and customDurationDays fields to plans table

-- First, drop the existing check constraint if it exists
ALTER TABLE plans DROP CONSTRAINT IF EXISTS plans_billing_interval_check;

-- Add new columns to plans table
ALTER TABLE plans 
ADD COLUMN IF NOT EXISTS billing_interval TEXT DEFAULT 'monthly',
ADD COLUMN IF NOT EXISTS custom_duration_days INTEGER;

-- Update existing plans to use new billing interval values
UPDATE plans 
SET billing_interval = CASE 
  WHEN billing_interval = 'month' THEN 'monthly'
  WHEN billing_interval = 'quarter' THEN 'quarterly' 
  WHEN billing_interval = 'year' THEN 'annual'
  ELSE 'monthly'
END
WHERE billing_interval IN ('month', 'quarter', 'year');

-- Set default billing interval for any plans that might not have it set
UPDATE plans 
SET billing_interval = 'monthly' 
WHERE billing_interval IS NULL OR billing_interval = '';

-- Now add the check constraint with the new enum values
ALTER TABLE plans 
ADD CONSTRAINT plans_billing_interval_check 
CHECK (billing_interval IN ('lifetime', 'daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'biennial', 'custom'));

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_plans_billing_interval ON plans(billing_interval);
