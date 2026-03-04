-- Migration: Remove maintenance mode functionality
-- Description: Drop the maintenance_mode table and its associated indexes
-- Date: 2025-01-27

-- Drop indexes first
DROP INDEX IF EXISTS idx_maintenance_mode_enabled;
DROP INDEX IF EXISTS idx_maintenance_mode_created_at;

-- Drop the maintenance_mode table
DROP TABLE IF EXISTS maintenance_mode;

-- Add comment for documentation
COMMENT ON SCHEMA public IS 'Removed maintenance_mode table and related functionality';
