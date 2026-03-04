-- Optimize recurring daily campaigns with composite indexes and statistics
-- This migration adds indexes to improve query performance for company-grouped campaign processing

-- Add composite index for efficient company-grouped queries
-- This partial index will speed up the company-grouped query significantly
CREATE INDEX IF NOT EXISTS idx_campaigns_company_type_status 
  ON campaigns(company_id, campaign_type, status) 
  WHERE campaign_type = 'recurring_daily' AND status = 'scheduled';

-- Add index for campaign recipients status updates
-- This will optimize the recipient reset query in the scheduler
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_campaign_status 
  ON campaign_recipients(campaign_id, status);

-- Add index for campaign queue processing
-- This will help the queue service check completion faster
CREATE INDEX IF NOT EXISTS idx_campaign_queue_campaign_status 
  ON campaign_queue(campaign_id, status);

-- Update statistics to ensure the query planner has up-to-date information
ANALYZE campaigns;
ANALYZE campaign_recipients;
ANALYZE campaign_queue;

