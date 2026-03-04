-- Migration: Add Moyasar payment method to payment_transactions table
-- This migration updates the payment_method constraint to include 'moyasar'

DO $$
BEGIN
  RAISE NOTICE 'Starting migration to add Moyasar payment method...';

  -- Drop the existing constraint
  ALTER TABLE payment_transactions 
  DROP CONSTRAINT IF EXISTS payment_transactions_payment_method_check;

  -- Add the new constraint with Moyasar included
  ALTER TABLE payment_transactions 
  ADD CONSTRAINT payment_transactions_payment_method_check 
  CHECK (payment_method IN ('stripe', 'mercadopago', 'paypal', 'moyasar', 'bank_transfer', 'other'));

  RAISE NOTICE 'Successfully added Moyasar to payment_method constraint';

  -- Verify the constraint was added correctly
  IF EXISTS (
    SELECT 1 
    FROM information_schema.check_constraints 
    WHERE constraint_name = 'payment_transactions_payment_method_check'
    AND check_clause LIKE '%moyasar%'
  ) THEN
    RAISE NOTICE 'Constraint verification successful - Moyasar is now allowed';
  ELSE
    RAISE EXCEPTION 'Constraint verification failed - Moyasar may not be properly added';
  END IF;

  RAISE NOTICE 'Migration completed successfully';

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Migration failed: %', SQLERRM;
END $$;
