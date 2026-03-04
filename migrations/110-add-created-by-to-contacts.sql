-- Add created_by column to contacts table
-- This column will track which user created each contact for proper permission scoping

ALTER TABLE contacts ADD COLUMN created_by INTEGER;

-- Add foreign key constraint to reference users table
ALTER TABLE contacts ADD CONSTRAINT fk_contacts_created_by 
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

-- Add index for better performance on permission-based queries
CREATE INDEX idx_contacts_created_by ON contacts(created_by);

-- Add comment to document the purpose of this column
COMMENT ON COLUMN contacts.created_by IS 'User ID who created this contact (used for permission scoping)';
