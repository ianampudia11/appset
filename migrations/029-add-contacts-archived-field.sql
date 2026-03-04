-- Add isArchived field to contacts table
-- This allows contacts to be archived (hidden from main view) while preserving all data

ALTER TABLE contacts 
ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE;

-- Create index for efficient filtering of archived/non-archived contacts
CREATE INDEX idx_contacts_is_archived ON contacts(is_archived);

-- Create composite index for company filtering with archive status
CREATE INDEX idx_contacts_company_archived ON contacts(company_id, is_archived);

-- Add comment to document the purpose of the field
COMMENT ON COLUMN contacts.is_archived IS 'Indicates if the contact is archived (hidden from main view but data preserved)';
