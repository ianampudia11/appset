-- Add recurring_daily to campaign_type CHECK constraint
-- This migration adds support for recurring daily campaigns that can be sent at multiple times per day

-- Drop the existing CHECK constraint if it exists
ALTER TABLE campaigns DROP CONSTRAINT IF EXISTS campaigns_campaign_type_check;

-- Add new CHECK constraint that includes 'recurring_daily'
ALTER TABLE campaigns ADD CONSTRAINT campaigns_campaign_type_check 
  CHECK (campaign_type IN ('immediate', 'scheduled', 'drip', 'recurring_daily'));

-- Add comment to dripSettings column to indicate it stores recurring_daily settings as well
COMMENT ON COLUMN campaigns.drip_settings IS 'Stores drip campaign settings or recurring_daily settings (sendTimes, offDays, timezone, startDate, endDate)';

-- Index for querying recurring daily campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_type_status ON campaigns(campaign_type, status) WHERE campaign_type = 'recurring_daily';

