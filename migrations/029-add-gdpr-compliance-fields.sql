-- GDPR compliance fields for TikTok user deletion and data retention
-- Tracks deletion/anonymization timestamps and context for compliance auditing

-- Contacts: deletion and anonymization tracking
ALTER TABLE contacts
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS anonymized_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS deletion_reason TEXT,
  ADD COLUMN IF NOT EXISTS deletion_metadata JSONB;

COMMENT ON COLUMN contacts.deleted_at IS 'GDPR: When TikTok user deletion or retention policy was applied';
COMMENT ON COLUMN contacts.anonymized_at IS 'GDPR: When contact PII was anonymized';
COMMENT ON COLUMN contacts.deletion_reason IS 'GDPR: Reason e.g. tiktok_user_deletion, gdpr_request, retention_policy';
COMMENT ON COLUMN contacts.deletion_metadata IS 'GDPR: Context (platform, user_id, webhook timestamp)';

CREATE INDEX IF NOT EXISTS idx_contacts_deleted_at ON contacts(deleted_at);
CREATE INDEX IF NOT EXISTS idx_contacts_anonymized_at ON contacts(anonymized_at);

-- Messages: anonymization tracking
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS anonymized_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS anonymization_reason TEXT;

COMMENT ON COLUMN messages.anonymized_at IS 'GDPR: When message content was anonymized (e.g. user deletion)';
COMMENT ON COLUMN messages.anonymization_reason IS 'GDPR: Reason e.g. tiktok_user_deletion';

CREATE INDEX IF NOT EXISTS idx_messages_anonymized_at ON messages(anonymized_at);
