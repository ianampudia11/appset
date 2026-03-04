-- API Access Enhancements Migration
-- This migration adds webhook support, enhanced permissions, and better tracking

-- Add new columns to api_keys table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_keys' AND column_name = 'webhook_secret'
  ) THEN
    RAISE NOTICE 'Adding webhook_secret column to api_keys...';
    ALTER TABLE api_keys ADD COLUMN webhook_secret TEXT;
    RAISE NOTICE 'webhook_secret column added successfully';
  ELSE
    RAISE NOTICE 'webhook_secret column already exists, skipping';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_keys' AND column_name = 'webhook_events'
  ) THEN
    RAISE NOTICE 'Adding webhook_events column to api_keys...';
    ALTER TABLE api_keys ADD COLUMN webhook_events JSONB DEFAULT '["message.sent", "message.delivered", "message.failed"]';
    RAISE NOTICE 'webhook_events column added successfully';
  ELSE
    RAISE NOTICE 'webhook_events column already exists, skipping';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_keys' AND column_name = 'features'
  ) THEN
    RAISE NOTICE 'Adding features column to api_keys...';
    ALTER TABLE api_keys ADD COLUMN features JSONB DEFAULT '{}';
    RAISE NOTICE 'features column added successfully';
  ELSE
    RAISE NOTICE 'features column already exists, skipping';
  END IF;
END$$;

-- Update default permissions to include new permission types
DO $$
BEGIN
  RAISE NOTICE 'Updating default permissions for existing API keys...';
  UPDATE api_keys 
  SET permissions = permissions || '["messages:send:batch", "messages:send:template", "messages:send:interactive", "conversations:read", "contacts:read"]'::jsonb
  WHERE permissions IS NULL OR permissions = '[]'::jsonb;
  RAISE NOTICE 'Default permissions updated';
END$$;

-- Create api_webhooks table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'api_webhooks'
  ) THEN
    RAISE NOTICE 'Creating api_webhooks table...';
    
    CREATE TABLE api_webhooks (
      id SERIAL PRIMARY KEY,
      api_key_id INTEGER NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
      event_type TEXT NOT NULL, -- message.sent, message.delivered, message.failed, etc.
      payload JSONB NOT NULL, -- webhook payload data
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'retrying')),
      attempt_count INTEGER NOT NULL DEFAULT 0,
      last_attempt_at TIMESTAMP,
      next_retry_at TIMESTAMP,
      response_status INTEGER, -- HTTP status code from webhook endpoint
      response_body TEXT, -- response from webhook endpoint
      error_message TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes for better performance
    CREATE INDEX idx_api_webhooks_api_key_id ON api_webhooks(api_key_id);
    CREATE INDEX idx_api_webhooks_status ON api_webhooks(status);
    CREATE INDEX idx_api_webhooks_next_retry_at ON api_webhooks(next_retry_at);
    CREATE INDEX idx_api_webhooks_created_at ON api_webhooks(created_at);
    CREATE INDEX idx_api_webhooks_event_type ON api_webhooks(event_type);
    
    RAISE NOTICE 'api_webhooks table created successfully';
  ELSE
    RAISE NOTICE 'api_webhooks table already exists, skipping creation';
  END IF;
END$$;

-- Add new columns to api_usage table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_usage' AND column_name = 'message_id'
  ) THEN
    RAISE NOTICE 'Adding message_id column to api_usage...';
    ALTER TABLE api_usage ADD COLUMN message_id INTEGER REFERENCES messages(id) ON DELETE SET NULL;
    CREATE INDEX idx_api_usage_message_id ON api_usage(message_id);
    RAISE NOTICE 'message_id column added successfully';
  ELSE
    RAISE NOTICE 'message_id column already exists, skipping';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_usage' AND column_name = 'webhook_delivered'
  ) THEN
    RAISE NOTICE 'Adding webhook_delivered column to api_usage...';
    ALTER TABLE api_usage ADD COLUMN webhook_delivered BOOLEAN DEFAULT FALSE;
    RAISE NOTICE 'webhook_delivered column added successfully';
  ELSE
    RAISE NOTICE 'webhook_delivered column already exists, skipping';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'api_usage' AND column_name = 'webhook_delivered_at'
  ) THEN
    RAISE NOTICE 'Adding webhook_delivered_at column to api_usage...';
    ALTER TABLE api_usage ADD COLUMN webhook_delivered_at TIMESTAMP;
    RAISE NOTICE 'webhook_delivered_at column added successfully';
  ELSE
    RAISE NOTICE 'webhook_delivered_at column already exists, skipping';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON COLUMN api_keys.webhook_secret IS 'Secret key for webhook signature verification';
COMMENT ON COLUMN api_keys.webhook_events IS 'JSON array of event types that trigger webhooks';
COMMENT ON COLUMN api_keys.features IS 'JSON object to enable/disable specific API features per key';

COMMENT ON TABLE api_webhooks IS 'Webhook delivery tracking for API events';
COMMENT ON COLUMN api_webhooks.api_key_id IS 'Reference to the API key that triggered this webhook';
COMMENT ON COLUMN api_webhooks.event_type IS 'Type of event that triggered the webhook';
COMMENT ON COLUMN api_webhooks.payload IS 'Webhook payload data sent to the endpoint';
COMMENT ON COLUMN api_webhooks.status IS 'Current status of webhook delivery (pending, sent, failed, retrying)';
COMMENT ON COLUMN api_webhooks.attempt_count IS 'Number of delivery attempts made';
COMMENT ON COLUMN api_webhooks.next_retry_at IS 'Timestamp for next retry attempt';
COMMENT ON COLUMN api_webhooks.response_status IS 'HTTP status code received from webhook endpoint';
COMMENT ON COLUMN api_webhooks.response_body IS 'Response body received from webhook endpoint';
COMMENT ON COLUMN api_webhooks.error_message IS 'Error message if webhook delivery failed';

COMMENT ON COLUMN api_usage.message_id IS 'Reference to the message sent via API';
COMMENT ON COLUMN api_usage.webhook_delivered IS 'Whether webhook notification was successfully delivered';
COMMENT ON COLUMN api_usage.webhook_delivered_at IS 'Timestamp when webhook was successfully delivered';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- ALTER TABLE api_usage DROP COLUMN IF EXISTS webhook_delivered_at;
-- ALTER TABLE api_usage DROP COLUMN IF EXISTS webhook_delivered;
-- ALTER TABLE api_usage DROP COLUMN IF EXISTS message_id;
-- DROP TABLE IF EXISTS api_webhooks CASCADE;
-- ALTER TABLE api_keys DROP COLUMN IF EXISTS features;
-- ALTER TABLE api_keys DROP COLUMN IF EXISTS webhook_events;
-- ALTER TABLE api_keys DROP COLUMN IF EXISTS webhook_secret;

