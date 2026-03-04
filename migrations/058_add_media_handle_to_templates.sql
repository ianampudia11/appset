-- Add media_handle column to store WhatsApp media handle for template media
ALTER TABLE campaign_templates 
ADD COLUMN IF NOT EXISTS media_handle TEXT;

-- Add comment
COMMENT ON COLUMN campaign_templates.media_handle IS 'WhatsApp media handle for template media (uploaded during template creation)';

