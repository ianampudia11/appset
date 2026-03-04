-- Add connectionId field to campaign_templates table
ALTER TABLE campaign_templates 
ADD COLUMN IF NOT EXISTS connection_id INTEGER REFERENCES channel_connections(id);

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_campaign_templates_connection_id ON campaign_templates(connection_id);

-- Add comment
COMMENT ON COLUMN campaign_templates.connection_id IS 'WhatsApp connection used to create and submit this template';

