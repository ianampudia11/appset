-- Migration: Add WhatsApp channel type columns
-- Description: Add whatsapp_channel_type column to campaigns and campaign_templates tables
-- to distinguish between official WhatsApp Business API and unofficial channels

-- Add whatsapp_channel_type column to campaigns table
ALTER TABLE campaigns 
ADD COLUMN whatsapp_channel_type TEXT CHECK (whatsapp_channel_type IN ('official', 'unofficial')) DEFAULT 'unofficial';

-- Add whatsapp_channel_type column to campaign_templates table
ALTER TABLE campaign_templates
ADD COLUMN whatsapp_channel_type TEXT CHECK (whatsapp_channel_type IN ('official', 'unofficial')) DEFAULT 'unofficial';

-- Add WhatsApp Business API template fields to campaign_templates table
ALTER TABLE campaign_templates
ADD COLUMN whatsapp_template_category TEXT CHECK (whatsapp_template_category IN ('marketing', 'utility', 'authentication'));

ALTER TABLE campaign_templates
ADD COLUMN whatsapp_template_status TEXT CHECK (whatsapp_template_status IN ('pending', 'approved', 'rejected', 'disabled')) DEFAULT 'pending';

ALTER TABLE campaign_templates
ADD COLUMN whatsapp_template_id TEXT;

ALTER TABLE campaign_templates
ADD COLUMN whatsapp_template_name TEXT;

ALTER TABLE campaign_templates
ADD COLUMN whatsapp_template_language TEXT DEFAULT 'en';

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_campaigns_whatsapp_channel_type ON campaigns(whatsapp_channel_type);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_whatsapp_channel_type ON campaign_templates(whatsapp_channel_type);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_whatsapp_template_category ON campaign_templates(whatsapp_template_category);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_whatsapp_template_status ON campaign_templates(whatsapp_template_status);

-- Update existing records to set appropriate channel type based on existing data
-- This assumes existing campaigns are unofficial unless they have specific indicators
UPDATE campaigns 
SET whatsapp_channel_type = 'unofficial' 
WHERE whatsapp_channel_type IS NULL;

UPDATE campaign_templates 
SET whatsapp_channel_type = 'unofficial' 
WHERE whatsapp_channel_type IS NULL;

-- Make the columns NOT NULL after setting default values
ALTER TABLE campaigns 
ALTER COLUMN whatsapp_channel_type SET NOT NULL;

-- Note: campaign_templates whatsapp_channel_type can remain nullable for flexibility
