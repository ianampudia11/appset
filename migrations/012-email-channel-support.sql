-- Migration: Add Email Channel Support
-- Description: Add tables and fields to support email channels in PowerChatPlus
-- Date: 2025-01-06

-- Add email-specific fields to messages table
ALTER TABLE messages 
ADD COLUMN email_message_id TEXT,
ADD COLUMN email_in_reply_to TEXT,
ADD COLUMN email_references TEXT,
ADD COLUMN email_subject TEXT,
ADD COLUMN email_from TEXT,
ADD COLUMN email_to TEXT,
ADD COLUMN email_cc TEXT,
ADD COLUMN email_bcc TEXT,
ADD COLUMN email_html TEXT,
ADD COLUMN email_plain_text TEXT,
ADD COLUMN email_headers JSONB;

-- Create index on email_message_id for threading
CREATE INDEX IF NOT EXISTS idx_messages_email_message_id ON messages(email_message_id);
CREATE INDEX IF NOT EXISTS idx_messages_email_in_reply_to ON messages(email_in_reply_to);

-- Create email_attachments table
CREATE TABLE IF NOT EXISTS email_attachments (
  id SERIAL PRIMARY KEY,
  message_id INTEGER NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size INTEGER NOT NULL,
  content_id TEXT, -- For inline attachments
  is_inline BOOLEAN DEFAULT FALSE,
  file_path TEXT NOT NULL, -- Path to stored file
  download_url TEXT, -- Public download URL
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for email_attachments
CREATE INDEX IF NOT EXISTS idx_email_attachments_message_id ON email_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_email_attachments_content_id ON email_attachments(content_id);

-- Create email_configs table
CREATE TABLE IF NOT EXISTS email_configs (
  id SERIAL PRIMARY KEY,
  channel_connection_id INTEGER NOT NULL REFERENCES channel_connections(id) ON DELETE CASCADE,
  
  -- IMAP Configuration
  imap_host TEXT NOT NULL,
  imap_port INTEGER NOT NULL DEFAULT 993,
  imap_secure BOOLEAN DEFAULT TRUE,
  imap_username TEXT NOT NULL,
  imap_password TEXT, -- Encrypted
  
  -- SMTP Configuration  
  smtp_host TEXT NOT NULL,
  smtp_port INTEGER NOT NULL DEFAULT 465,
  smtp_secure BOOLEAN DEFAULT FALSE,
  smtp_username TEXT NOT NULL,
  smtp_password TEXT, -- Encrypted
  
  -- OAuth2 Configuration (for Gmail, Outlook, etc.)
  oauth_provider TEXT, -- 'gmail', 'outlook', 'custom'
  oauth_client_id TEXT,
  oauth_client_secret TEXT, -- Encrypted
  oauth_refresh_token TEXT, -- Encrypted
  oauth_access_token TEXT, -- Encrypted
  oauth_token_expiry TIMESTAMP,
  
  -- Email Settings
  email_address TEXT NOT NULL,
  display_name TEXT,
  signature TEXT,
  sync_folder TEXT DEFAULT 'INBOX',
  sync_frequency INTEGER DEFAULT 60, -- seconds
  max_sync_messages INTEGER DEFAULT 100,
  
  -- Status and Metadata
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'error')),
  last_sync_at TIMESTAMP,
  last_error TEXT,
  connection_data JSONB, -- Additional provider-specific data
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for email_configs
CREATE INDEX IF NOT EXISTS idx_email_configs_channel_connection_id ON email_configs(channel_connection_id);
CREATE INDEX IF NOT EXISTS idx_email_configs_email_address ON email_configs(email_address);
CREATE INDEX IF NOT EXISTS idx_email_configs_status ON email_configs(status);

-- Create unique constraint to prevent duplicate email configs per channel connection
CREATE UNIQUE INDEX IF NOT EXISTS idx_email_configs_unique_channel ON email_configs(channel_connection_id);

-- Add comments for documentation
COMMENT ON TABLE email_attachments IS 'Stores email attachments linked to messages';
COMMENT ON TABLE email_configs IS 'Email channel configuration including IMAP/SMTP and OAuth2 settings';

COMMENT ON COLUMN messages.email_message_id IS 'Email Message-ID header for threading';
COMMENT ON COLUMN messages.email_in_reply_to IS 'In-Reply-To header for email threading';
COMMENT ON COLUMN messages.email_references IS 'References header for email threading';
COMMENT ON COLUMN messages.email_subject IS 'Email subject line';
COMMENT ON COLUMN messages.email_from IS 'From email address';
COMMENT ON COLUMN messages.email_to IS 'To email addresses (JSON array)';
COMMENT ON COLUMN messages.email_cc IS 'CC email addresses (JSON array)';
COMMENT ON COLUMN messages.email_bcc IS 'BCC email addresses (JSON array)';
COMMENT ON COLUMN messages.email_html IS 'HTML content for emails';
COMMENT ON COLUMN messages.email_plain_text IS 'Plain text content for emails';
COMMENT ON COLUMN messages.email_headers IS 'Full email headers as JSON';

COMMENT ON COLUMN email_attachments.content_id IS 'Content-ID for inline attachments (cid:)';
COMMENT ON COLUMN email_attachments.is_inline IS 'Whether attachment is inline (embedded in HTML)';
COMMENT ON COLUMN email_attachments.file_path IS 'Server file path where attachment is stored';
COMMENT ON COLUMN email_attachments.download_url IS 'Public URL for downloading attachment';

COMMENT ON COLUMN email_configs.imap_password IS 'Encrypted IMAP password';
COMMENT ON COLUMN email_configs.smtp_password IS 'Encrypted SMTP password';
COMMENT ON COLUMN email_configs.oauth_client_secret IS 'Encrypted OAuth2 client secret';
COMMENT ON COLUMN email_configs.oauth_refresh_token IS 'Encrypted OAuth2 refresh token';
COMMENT ON COLUMN email_configs.oauth_access_token IS 'Encrypted OAuth2 access token';
COMMENT ON COLUMN email_configs.sync_folder IS 'Email folder to sync (default: INBOX)';
COMMENT ON COLUMN email_configs.sync_frequency IS 'How often to check for new emails (seconds)';
COMMENT ON COLUMN email_configs.max_sync_messages IS 'Maximum messages to sync per check';
COMMENT ON COLUMN email_configs.connection_data IS 'Provider-specific configuration data';
