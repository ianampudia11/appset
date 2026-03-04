-- Fix Meta WhatsApp Phone Numbers Quality Rating Constraint
-- This migration updates the quality_rating CHECK constraint to include 'UNKNOWN' 
-- as a valid value, aligning with Meta's official WhatsApp Business API specification.
-- 'UNKNOWN' indicates a pending quality score for newly created phone numbers/templates.

-- According to Meta's official documentation, quality_rating has four valid values:
-- - GREEN: High quality
-- - YELLOW: Medium quality  
-- - RED: Low quality
-- - UNKNOWN: Quality score pending (for newly created phone numbers/templates)

DO $$
BEGIN
  -- Check if the constraint exists and drop it
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'meta_whatsapp_phone_numbers_quality_rating_check' 
    AND table_name = 'meta_whatsapp_phone_numbers'
  ) THEN
    RAISE NOTICE 'Dropping existing quality_rating check constraint...';
    ALTER TABLE meta_whatsapp_phone_numbers 
      DROP CONSTRAINT meta_whatsapp_phone_numbers_quality_rating_check;
  END IF;

  -- Add new constraint with UNKNOWN included and both uppercase/lowercase variants
  -- This handles both database convention (lowercase) and Meta API responses (uppercase)
  RAISE NOTICE 'Adding new quality_rating check constraint with UNKNOWN support...';
  ALTER TABLE meta_whatsapp_phone_numbers 
    ADD CONSTRAINT meta_whatsapp_phone_numbers_quality_rating_check 
    CHECK (quality_rating IN ('green', 'yellow', 'red', 'UNKNOWN', 'GREEN', 'YELLOW', 'RED', 'unknown'));
  
  RAISE NOTICE 'Quality rating constraint updated successfully';
END $$;

-- Update the column comment to reflect the new valid values
COMMENT ON COLUMN meta_whatsapp_phone_numbers.quality_rating IS 
  'WhatsApp quality rating (green/yellow/red/UNKNOWN). UNKNOWN indicates pending quality score for newly created phone numbers.';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- ALTER TABLE meta_whatsapp_phone_numbers DROP CONSTRAINT IF EXISTS meta_whatsapp_phone_numbers_quality_rating_check;
-- ALTER TABLE meta_whatsapp_phone_numbers ADD CONSTRAINT meta_whatsapp_phone_numbers_quality_rating_check 
--   CHECK (quality_rating IN ('green', 'yellow', 'red'));

