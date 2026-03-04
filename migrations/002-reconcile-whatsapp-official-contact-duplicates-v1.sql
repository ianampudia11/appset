-- Migration: Reconcile WhatsApp Official Contact Duplicates
-- Description: Fix duplicate contacts created with inconsistent identifierType values
--              between inbound ('whatsapp') and outbound ('whatsapp_official') flows.
--              This migration merges duplicates and standardizes to 'whatsapp' as the
--              canonical identifierType for WhatsApp Official API contacts.
-- Date: 2025-11-11

BEGIN;

-- Step 1: Create a temporary table to track duplicate contacts
CREATE TEMP TABLE duplicate_whatsapp_contacts AS
SELECT 
    c1.id as whatsapp_id,
    c2.id as whatsapp_official_id,
    c1.phone,
    c1.company_id,
    c1.created_at as whatsapp_created_at,
    c2.created_at as whatsapp_official_created_at
FROM contacts c1
INNER JOIN contacts c2 ON 
    c1.phone = c2.phone 
    AND c1.company_id = c2.company_id
    AND c1.id != c2.id
WHERE 
    c1.identifier_type = 'whatsapp' 
    AND c1.source = 'whatsapp_official'
    AND c2.identifier_type = 'whatsapp_official'
    AND c2.source = 'whatsapp_official';

-- Log the number of duplicates found
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO duplicate_count FROM duplicate_whatsapp_contacts;
    RAISE NOTICE 'Found % duplicate contact pairs to reconcile', duplicate_count;
END $$;

-- Step 2: Update conversations to point to the 'whatsapp' contact (keeping the older one)
UPDATE conversations
SET contact_id = dwc.whatsapp_id
FROM duplicate_whatsapp_contacts dwc
WHERE conversations.contact_id = dwc.whatsapp_official_id
  AND NOT EXISTS (
    -- Avoid creating duplicate conversations for the same contact+channel
    SELECT 1 FROM conversations c2 
    WHERE c2.contact_id = dwc.whatsapp_id 
      AND c2.channel_id = conversations.channel_id
  );

-- Step 3: For conversations that would create duplicates, merge messages into the existing conversation
DO $$
DECLARE
    rec RECORD;
    target_conversation_id INTEGER;
BEGIN
    FOR rec IN 
        SELECT DISTINCT 
            c.id as old_conversation_id,
            c.contact_id as old_contact_id,
            c.channel_id,
            dwc.whatsapp_id as new_contact_id
        FROM conversations c
        INNER JOIN duplicate_whatsapp_contacts dwc ON c.contact_id = dwc.whatsapp_official_id
        WHERE EXISTS (
            SELECT 1 FROM conversations c2 
            WHERE c2.contact_id = dwc.whatsapp_id 
              AND c2.channel_id = c.channel_id
        )
    LOOP
        -- Find the target conversation
        SELECT id INTO target_conversation_id
        FROM conversations
        WHERE contact_id = rec.new_contact_id
          AND channel_id = rec.channel_id
        LIMIT 1;

        -- Move messages from old conversation to target conversation
        UPDATE messages
        SET conversation_id = target_conversation_id
        WHERE conversation_id = rec.old_conversation_id;

        -- Delete the old conversation
        DELETE FROM conversations WHERE id = rec.old_conversation_id;

        RAISE NOTICE 'Merged conversation % into %', rec.old_conversation_id, target_conversation_id;
    END LOOP;
END $$;

-- Step 4: Update campaign_recipients to point to the 'whatsapp' contact
-- Note: campaign_queue references campaign_recipients, which references contacts
UPDATE campaign_recipients
SET contact_id = dwc.whatsapp_id
FROM duplicate_whatsapp_contacts dwc
WHERE campaign_recipients.contact_id = dwc.whatsapp_official_id
  AND NOT EXISTS (
    -- Avoid creating duplicate campaign recipient entries
    SELECT 1 FROM campaign_recipients cr2
    WHERE cr2.campaign_id = campaign_recipients.campaign_id
      AND cr2.contact_id = dwc.whatsapp_id
  );

-- Step 4b: Delete duplicate campaign_recipients that would remain after merge
DELETE FROM campaign_recipients
WHERE contact_id IN (SELECT whatsapp_official_id FROM duplicate_whatsapp_contacts);

-- Step 5: Update notes to point to the 'whatsapp' contact (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notes') THEN
        UPDATE notes
        SET contact_id = dwc.whatsapp_id
        FROM duplicate_whatsapp_contacts dwc
        WHERE notes.contact_id = dwc.whatsapp_official_id;

        RAISE NOTICE 'Updated notes references';
    END IF;
END $$;

-- Step 6: Update contact_documents to point to the 'whatsapp' contact (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'contact_documents') THEN
        UPDATE contact_documents
        SET contact_id = dwc.whatsapp_id
        FROM duplicate_whatsapp_contacts dwc
        WHERE contact_documents.contact_id = dwc.whatsapp_official_id;

        RAISE NOTICE 'Updated contact_documents references';
    END IF;
END $$;

-- Step 7: Update contact_appointments to point to the 'whatsapp' contact (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'contact_appointments') THEN
        UPDATE contact_appointments
        SET contact_id = dwc.whatsapp_id
        FROM duplicate_whatsapp_contacts dwc
        WHERE contact_appointments.contact_id = dwc.whatsapp_official_id;

        RAISE NOTICE 'Updated contact_appointments references';
    END IF;
END $$;

-- Step 8: Update contact_tasks to point to the 'whatsapp' contact (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'contact_tasks') THEN
        UPDATE contact_tasks
        SET contact_id = dwc.whatsapp_id
        FROM duplicate_whatsapp_contacts dwc
        WHERE contact_tasks.contact_id = dwc.whatsapp_official_id;

        RAISE NOTICE 'Updated contact_tasks references';
    END IF;
END $$;

-- Step 9: Update contact_audit_logs to point to the 'whatsapp' contact (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'contact_audit_logs') THEN
        UPDATE contact_audit_logs
        SET contact_id = dwc.whatsapp_id
        FROM duplicate_whatsapp_contacts dwc
        WHERE contact_audit_logs.contact_id = dwc.whatsapp_official_id;

        RAISE NOTICE 'Updated contact_audit_logs references';
    END IF;
END $$;

-- Step 10: Merge contact data (keep the most complete information)
UPDATE contacts c
SET
    name = COALESCE(
        NULLIF(c.name, c.phone),  -- If name is same as phone, try to get better name
        NULLIF(c2.name, c2.phone),
        c.name
    ),
    email = COALESCE(c.email, c2.email),
    avatar_url = COALESCE(c.avatar_url, c2.avatar_url),
    company = COALESCE(c.company, c2.company),
    notes = CASE
        WHEN c.notes IS NULL AND c2.notes IS NOT NULL THEN c2.notes
        WHEN c.notes IS NOT NULL AND c2.notes IS NULL THEN c.notes
        WHEN c.notes IS NOT NULL AND c2.notes IS NOT NULL THEN c.notes || E'\n---\n' || c2.notes
        ELSE c.notes
    END,
    -- Merge tags arrays (combine unique tags from both contacts)
    tags = CASE
        WHEN c.tags IS NULL AND c2.tags IS NOT NULL THEN c2.tags
        WHEN c.tags IS NOT NULL AND c2.tags IS NULL THEN c.tags
        WHEN c.tags IS NOT NULL AND c2.tags IS NOT NULL THEN
            ARRAY(SELECT DISTINCT unnest(c.tags || c2.tags))
        ELSE c.tags
    END,
    updated_at = NOW()
FROM duplicate_whatsapp_contacts dwc
INNER JOIN contacts c2 ON c2.id = dwc.whatsapp_official_id
WHERE c.id = dwc.whatsapp_id;

-- Step 11: Delete the duplicate 'whatsapp_official' contacts
DELETE FROM contacts
WHERE id IN (SELECT whatsapp_official_id FROM duplicate_whatsapp_contacts);

-- Step 12: Log the results
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO deleted_count FROM duplicate_whatsapp_contacts;
    RAISE NOTICE 'Successfully reconciled and deleted % duplicate contacts', deleted_count;
END $$;

-- Step 13: Create an index to prevent future duplicates (if not exists)
CREATE INDEX IF NOT EXISTS idx_contacts_phone_company_identifier
ON contacts(phone, company_id, identifier_type)
WHERE phone IS NOT NULL AND identifier_type IS NOT NULL;

-- Step 14: Add a comment to document this migration
COMMENT ON TABLE contacts IS 'Contact records with standardized identifierType: whatsapp for WhatsApp Official API (not whatsapp_official)';

COMMIT;

