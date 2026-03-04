-- Migration: Add timezone support to follow-up schedules
-- This migration adds timezone field to follow_up_schedules table for accurate scheduling across time zones

-- Add timezone column to follow_up_schedules table
DO $$
BEGIN
  -- Check if timezone column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'follow_up_schedules' 
    AND column_name = 'timezone'
  ) THEN
    RAISE NOTICE 'Adding timezone column to follow_up_schedules table...';
    
    -- Add timezone column with default UTC
    ALTER TABLE follow_up_schedules 
    ADD COLUMN timezone TEXT DEFAULT 'UTC';
    
    -- Add comment for documentation
    COMMENT ON COLUMN follow_up_schedules.timezone IS 'IANA timezone identifier for accurate scheduling (e.g., America/New_York, Europe/London)';
    
    RAISE NOTICE 'Timezone column added successfully';
  ELSE
    RAISE NOTICE 'Timezone column already exists in follow_up_schedules table';
  END IF;
END $$;

-- Update existing records to have UTC timezone if they don't have one
UPDATE follow_up_schedules 
SET timezone = 'UTC' 
WHERE timezone IS NULL;

-- Migration completed successfully
SELECT 'Timezone support added to follow-up schedules successfully' AS result;
