-- Migration: Follow-up Timezone Optimization
-- Adds essential performance indexes for the follow-up scheduling system
-- Addresses timing issues identified in the Follow-up Node

-- Drop existing conflicting index if it exists
DROP INDEX IF EXISTS idx_follow_up_schedules_processing;

-- Add essential performance index for efficient follow-up execution queries
-- This index covers the most common query pattern: status + scheduled_for
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_execution 
ON follow_up_schedules (status, scheduled_for) 
WHERE status = 'scheduled';

-- Add index for timezone-based queries and debugging
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_timezone 
ON follow_up_schedules (timezone, scheduled_for, status) 
WHERE status IN ('scheduled', 'sent', 'failed');

-- Add index for company-specific follow-up queries
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_company_execution 
ON follow_up_schedules (company_id, status, scheduled_for) 
WHERE status = 'scheduled';

-- Add index for execution log queries
CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_schedule 
ON follow_up_execution_log (schedule_id, executed_at DESC);

-- Add comment explaining the timezone handling approach
COMMENT ON COLUMN follow_up_schedules.scheduled_for IS 
'UTC timestamp for when the follow-up should execute. Always stored in UTC regardless of user timezone.';

COMMENT ON COLUMN follow_up_schedules.timezone IS 
'IANA timezone identifier (e.g., America/New_York) used for display and specific datetime conversion.';

-- Create a simple log table for migration tracking if it doesn't exist
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    migration_name TEXT NOT NULL,
    executed_at TIMESTAMP DEFAULT NOW(),
    description TEXT
);

-- Log the migration completion
INSERT INTO migration_log (migration_name, description) VALUES (
    '005-follow-up-timezone-optimization',
    'Added essential performance indexes for follow-up scheduling system. Fixes critical timing issues in Follow-up Node execution.'
);
