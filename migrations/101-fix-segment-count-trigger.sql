-- Fix segment contact count trigger
-- The original trigger was incorrectly counting ALL active contacts instead of evaluating segment criteria
-- This migration disables the trigger and relies on the application layer to calculate counts correctly

-- Drop the problematic trigger
DROP TRIGGER IF EXISTS trigger_update_segment_count ON contacts;

-- Drop the function (optional, but cleaner)
DROP FUNCTION IF EXISTS update_segment_count();

-- Note: Segment contact counts are now calculated correctly by the application layer
-- in CampaignService.calculateSegmentContactCount() which properly evaluates segment criteria

