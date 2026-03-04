-- Add custom_fields column to contacts table
-- This allows storing arbitrary custom field data as JSONB for extensibility
-- Same pattern as deals custom_fields

ALTER TABLE contacts 
ADD COLUMN IF NOT EXISTS custom_fields JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Create GIN index for efficient JSONB queries on custom fields
CREATE INDEX IF NOT EXISTS idx_contacts_custom_fields ON contacts USING GIN (custom_fields);

-- Add comment to document the purpose of the field
COMMENT ON COLUMN contacts.custom_fields IS 'Stores custom field data as JSONB for extensible contact metadata';
