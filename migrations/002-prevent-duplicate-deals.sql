-- Migration: Prevent duplicate active deals for the same contact
-- This migration adds a unique constraint to prevent multiple active deals for the same contact within a company

-- First, identify and handle any existing duplicate active deals
-- We'll keep the most recent deal and archive the older ones
WITH duplicate_deals AS (
  SELECT
    id,
    company_id,
    contact_id,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY company_id, contact_id
      ORDER BY created_at DESC
    ) as rn
  FROM deals
  WHERE status = 'active'
),
deals_to_archive AS (
  SELECT id
  FROM duplicate_deals
  WHERE rn > 1
)
UPDATE deals
SET status = 'archived',
    updated_at = NOW()
WHERE id IN (SELECT id FROM deals_to_archive);

-- Add a partial unique index to prevent duplicate active deals
-- This allows multiple deals per contact but only one active deal per contact per company
-- Note: Using regular CREATE INDEX instead of CONCURRENTLY to work with transaction-based migrations
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_contact_deal
ON deals (company_id, contact_id)
WHERE status = 'active';

-- Add an index to improve performance of deal lookups by contact
CREATE INDEX IF NOT EXISTS idx_deals_contact_status_company
ON deals (contact_id, status, company_id, last_activity_at DESC);

-- Add an index to improve performance of deal lookups by phone number
CREATE INDEX IF NOT EXISTS idx_deals_contact_phone_lookup
ON deals (company_id, status, contact_id, id, stage_id, title, value, priority);

-- Update the deals table comment to document the constraint
COMMENT ON TABLE deals IS
'Stores deal information with unique constraint preventing multiple active deals per contact per company';

-- Add a comment to document the constraint
COMMENT ON INDEX idx_unique_active_contact_deal IS
'Ensures only one active deal per contact per company to prevent duplicates';
