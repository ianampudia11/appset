-- Migration: Add Webhook Trigger Infrastructure
-- Description: Enable webhook triggers for flows with filtering, contact mapping, and response configuration

-- Create webhook trigger status enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'webhook_trigger_log_status') THEN
        CREATE TYPE webhook_trigger_log_status AS ENUM (
          'received',
          'filtered',
          'triggered',
          'failed'
        );
    END IF;
END $$;

-- Create webhook_triggers table
CREATE TABLE IF NOT EXISTS webhook_triggers (
  id SERIAL PRIMARY KEY,
  flow_id INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  webhook_token TEXT NOT NULL UNIQUE,
  custom_path TEXT UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  filter_conditions JSONB NOT NULL DEFAULT '[]',
  contact_mapping JSONB NOT NULL DEFAULT '{}',
  response_config JSONB NOT NULL DEFAULT '{"statusCode":200,"mode":"async","bodyTemplate":"","headers":{}}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for webhook_triggers
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_flow_id ON webhook_triggers(flow_id);
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_company_id ON webhook_triggers(company_id);
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_token ON webhook_triggers(webhook_token);
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_custom_path ON webhook_triggers(custom_path) WHERE custom_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_active ON webhook_triggers(is_active);

-- Create webhook_trigger_logs table
CREATE TABLE IF NOT EXISTS webhook_trigger_logs (
  id SERIAL PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  trigger_id INTEGER REFERENCES webhook_triggers(id) ON DELETE CASCADE,
  flow_id INTEGER REFERENCES flows(id),
  execution_id TEXT,
  payload JSONB NOT NULL,
  headers JSONB DEFAULT '{}',
  query_params JSONB DEFAULT '{}',
  status webhook_trigger_log_status NOT NULL,
  filter_result JSONB,
  contact_id INTEGER REFERENCES contacts(id),
  conversation_id INTEGER REFERENCES conversations(id),
  response_status INTEGER,
  response_body TEXT,
  error_message TEXT,
  ip_address TEXT,
  user_agent TEXT,
  processing_time_ms INTEGER,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for webhook_trigger_logs
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_trigger_id ON webhook_trigger_logs(trigger_id);
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_flow_id ON webhook_trigger_logs(flow_id);
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_execution_id ON webhook_trigger_logs(execution_id);
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_status ON webhook_trigger_logs(status);
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_created_at ON webhook_trigger_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_webhook_trigger_logs_request_id ON webhook_trigger_logs(request_id);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_webhook_triggers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_webhook_triggers_updated_at
    BEFORE UPDATE ON webhook_triggers
    FOR EACH ROW
    EXECUTE PROCEDURE update_webhook_triggers_updated_at();

-- Add comments for documentation
COMMENT ON TABLE webhook_triggers IS 'Stores webhook trigger configurations for flows with filtering and contact mapping';
COMMENT ON TABLE webhook_trigger_logs IS 'Audit trail for all incoming webhook requests and their processing results';

COMMENT ON COLUMN webhook_triggers.webhook_token IS 'Unique security token for webhook URL authentication';
COMMENT ON COLUMN webhook_triggers.custom_path IS 'Optional custom webhook path (e.g., /webhook/shopify-orders)';
COMMENT ON COLUMN webhook_triggers.filter_conditions IS 'Array of filter conditions to evaluate against incoming payload';
COMMENT ON COLUMN webhook_triggers.contact_mapping IS 'Configuration for how to map webhook payload to contacts';
COMMENT ON COLUMN webhook_triggers.response_config IS 'Configuration for webhook response (status, body, headers, mode)';

COMMENT ON COLUMN webhook_trigger_logs.request_id IS 'Unique identifier for tracking this webhook request';
COMMENT ON COLUMN webhook_trigger_logs.filter_result IS 'Detailed results of filter condition evaluation';
COMMENT ON COLUMN webhook_trigger_logs.processing_time_ms IS 'Time taken to process the webhook request in milliseconds';
