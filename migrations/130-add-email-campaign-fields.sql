ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS email_subject TEXT;
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS email_provider TEXT
  CHECK (email_provider IN ('smtp', 'ses'));
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS ses_config_id TEXT;
