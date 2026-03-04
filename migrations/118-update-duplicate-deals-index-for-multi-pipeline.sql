-- Migration: Update duplicate deals index to support multi-pipeline
-- This migration drops the old unique index that prevented multiple active deals per contact company-wide
-- and replaces it with a partial unique index that includes pipeline_id, allowing multiple active deals
-- per contact as long as they are in different pipelines

-- Drop the old unique index
DROP INDEX IF EXISTS idx_unique_active_contact_deal;

-- Create a new partial unique index that includes pipeline_id
-- This ensures only one active deal per contact per company per pipeline
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_contact_deal_pipeline
ON deals (company_id, contact_id, pipeline_id)
WHERE status = 'active';

-- Update the deals table comment to reflect the new constraint
COMMENT ON TABLE deals IS
'Stores deal information with unique constraint preventing multiple active deals per contact per company per pipeline';

-- Update the index comment to document the new constraint
COMMENT ON INDEX idx_unique_active_contact_deal_pipeline IS
'Ensures only one active deal per contact per company per pipeline to prevent duplicates within the same pipeline';
