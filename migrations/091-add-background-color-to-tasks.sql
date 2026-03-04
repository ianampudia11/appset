-- Migration: Add background_color column to contact_tasks table
-- Description: Add background color support for task customization

-- Add background_color column to contact_tasks table
ALTER TABLE contact_tasks 
ADD COLUMN IF NOT EXISTS background_color VARCHAR(7) DEFAULT '#ffffff';

-- Add comment to document the column
COMMENT ON COLUMN contact_tasks.background_color IS 'Hex color code for task background (e.g., #ffffff, #ff0000)';

-- Update existing tasks to have default white background if they don't have one
UPDATE contact_tasks 
SET background_color = '#ffffff' 
WHERE background_color IS NULL;
