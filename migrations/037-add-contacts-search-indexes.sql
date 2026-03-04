-- Migration: Add indexes for better contacts search performance
-- This migration adds indexes to improve the performance of the contacts without conversations search

-- Add index for contacts search by name (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_contacts_name_lower 
ON contacts (LOWER(name)) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add index for contacts search by email (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_contacts_email_lower 
ON contacts (LOWER(email)) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add index for contacts search by phone
CREATE INDEX IF NOT EXISTS idx_contacts_phone 
ON contacts (phone) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add index for contacts search by company (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_contacts_company_lower 
ON contacts (LOWER(company)) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add index for contacts search by identifier
CREATE INDEX IF NOT EXISTS idx_contacts_identifier 
ON contacts (identifier) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add composite index for the main query (contacts without conversations)
CREATE INDEX IF NOT EXISTS idx_contacts_without_conversations 
ON contacts (company_id, is_active, identifier_type, created_at DESC) 
WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Add index on conversations.contact_id for the LEFT JOIN
CREATE INDEX IF NOT EXISTS idx_conversations_contact_id 
ON conversations (contact_id) 
WHERE contact_id IS NOT NULL;

-- Add GIN index for full-text search on name and company (optional, for advanced search)
-- Uncomment if you want to enable full-text search capabilities
-- CREATE INDEX IF NOT EXISTS idx_contacts_fulltext_search 
-- ON contacts USING gin(to_tsvector('english', COALESCE(name, '') || ' ' || COALESCE(company, ''))) 
-- WHERE is_active = true AND identifier_type IS NOT NULL AND identifier_type != 'email';

-- Analyze tables to update statistics after creating indexes
ANALYZE contacts;
ANALYZE conversations;
