-- Migration: Add unique constraints to prevent contact duplicates
-- This ensures that within a company, contacts cannot have duplicate phone numbers or emails

-- First, let's identify and merge any existing duplicates before adding constraints
-- This is a data cleanup step

-- Create a temporary table to track contacts that need to be merged
CREATE TEMP TABLE contact_duplicates AS
WITH phone_duplicates AS (
  SELECT 
    phone,
    company_id,
    MIN(id) as keep_id,
    ARRAY_AGG(id ORDER BY created_at) as all_ids
  FROM contacts 
  WHERE phone IS NOT NULL 
    AND phone != '' 
    AND is_active = true
  GROUP BY phone, company_id 
  HAVING COUNT(*) > 1
),
email_duplicates AS (
  SELECT 
    email,
    company_id,
    MIN(id) as keep_id,
    ARRAY_AGG(id ORDER BY created_at) as all_ids
  FROM contacts 
  WHERE email IS NOT NULL 
    AND email != '' 
    AND is_active = true
  GROUP BY email, company_id 
  HAVING COUNT(*) > 1
)
SELECT 
  'phone' as duplicate_type,
  phone as duplicate_value,
  company_id,
  keep_id,
  all_ids
FROM phone_duplicates
UNION ALL
SELECT 
  'email' as duplicate_type,
  email as duplicate_value,
  company_id,
  keep_id,
  all_ids
FROM email_duplicates;

-- Update conversations to point to the contact we're keeping
UPDATE conversations 
SET contact_id = cd.keep_id
FROM contact_duplicates cd
WHERE conversations.contact_id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND conversations.contact_id != cd.keep_id;

-- Update messages to point to the contact we're keeping
UPDATE messages 
SET sender_id = cd.keep_id
FROM contact_duplicates cd
WHERE messages.sender_id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND messages.sender_id != cd.keep_id
  AND messages.sender_type = 'contact';

-- Update campaign recipients to point to the contact we're keeping
UPDATE campaign_recipients 
SET contact_id = cd.keep_id
FROM contact_duplicates cd
WHERE campaign_recipients.contact_id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND campaign_recipients.contact_id != cd.keep_id;

-- Update deals to point to the contact we're keeping
UPDATE deals 
SET contact_id = cd.keep_id
FROM contact_duplicates cd
WHERE deals.contact_id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND deals.contact_id != cd.keep_id;

-- Update group participants to point to the contact we're keeping
UPDATE group_participants 
SET contact_id = cd.keep_id
FROM contact_duplicates cd
WHERE group_participants.contact_id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND group_participants.contact_id != cd.keep_id;

-- Soft delete the duplicate contacts (mark as inactive instead of hard delete)
UPDATE contacts 
SET is_active = false, 
    updated_at = NOW(),
    name = name || ' (DUPLICATE - MERGED)'
FROM contact_duplicates cd
WHERE contacts.id = ANY(cd.all_ids[2:]) -- Skip the first ID (keep_id)
  AND contacts.id != cd.keep_id;

-- Now add the unique constraints to prevent future duplicates
-- Unique constraint for phone within company (only for active contacts)
CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_unique_phone_company
ON contacts (company_id, phone)
WHERE phone IS NOT NULL AND phone != '' AND is_active = true;

-- Unique constraint for email within company (only for active contacts)
CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_unique_email_company
ON contacts (company_id, email)
WHERE email IS NOT NULL AND email != '' AND is_active = true;

-- Unique constraint for identifier within company (only for active contacts)
CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_unique_identifier_company
ON contacts (company_id, identifier, identifier_type)
WHERE identifier IS NOT NULL AND identifier != '' AND is_active = true;

-- Add a comment to document the constraints
COMMENT ON INDEX idx_contacts_unique_phone_company IS 'Ensures unique phone numbers per company for active contacts';
COMMENT ON INDEX idx_contacts_unique_email_company IS 'Ensures unique email addresses per company for active contacts';
COMMENT ON INDEX idx_contacts_unique_identifier_company IS 'Ensures unique identifiers per company and type for active contacts';
