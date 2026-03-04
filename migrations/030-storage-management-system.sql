-- Migration 030: Add storage and data limits to plans and usage tracking to companies
-- Date: 2024-12-25
-- Description: Adds comprehensive storage management fields to support data usage tracking and limits

-- Add storage and data limit fields to plans table
ALTER TABLE plans 
ADD COLUMN IF NOT EXISTS storage_limit INTEGER DEFAULT 1024,
ADD COLUMN IF NOT EXISTS bandwidth_limit INTEGER DEFAULT 10240,
ADD COLUMN IF NOT EXISTS file_upload_limit INTEGER DEFAULT 25,
ADD COLUMN IF NOT EXISTS total_files_limit INTEGER DEFAULT 1000;

-- Add usage tracking fields to companies table
ALTER TABLE companies 
ADD COLUMN IF NOT EXISTS current_storage_used INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_bandwidth_used INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS files_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_usage_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add comments for documentation
COMMENT ON COLUMN plans.storage_limit IS 'Storage limit in MB';
COMMENT ON COLUMN plans.bandwidth_limit IS 'Monthly bandwidth limit in MB';
COMMENT ON COLUMN plans.file_upload_limit IS 'Maximum file size per upload in MB';
COMMENT ON COLUMN plans.total_files_limit IS 'Maximum number of files allowed';

COMMENT ON COLUMN companies.current_storage_used IS 'Current storage used in MB';
COMMENT ON COLUMN companies.current_bandwidth_used IS 'Current monthly bandwidth used in MB';
COMMENT ON COLUMN companies.files_count IS 'Current number of files';
COMMENT ON COLUMN companies.last_usage_update IS 'Last time usage was updated';

-- Update existing plans with default storage limits based on their tier
-- This is a one-time update for existing plans
UPDATE plans 
SET 
  storage_limit = CASE 
    WHEN LOWER(name) LIKE '%free%' OR LOWER(name) LIKE '%basic%' THEN 512
    WHEN LOWER(name) LIKE '%pro%' OR LOWER(name) LIKE '%professional%' THEN 2048
    WHEN LOWER(name) LIKE '%enterprise%' OR LOWER(name) LIKE '%premium%' THEN 10240
    ELSE 1024
  END,
  bandwidth_limit = CASE 
    WHEN LOWER(name) LIKE '%free%' OR LOWER(name) LIKE '%basic%' THEN 5120
    WHEN LOWER(name) LIKE '%pro%' OR LOWER(name) LIKE '%professional%' THEN 20480
    WHEN LOWER(name) LIKE '%enterprise%' OR LOWER(name) LIKE '%premium%' THEN 102400
    ELSE 10240
  END,
  file_upload_limit = CASE 
    WHEN LOWER(name) LIKE '%free%' OR LOWER(name) LIKE '%basic%' THEN 10
    WHEN LOWER(name) LIKE '%pro%' OR LOWER(name) LIKE '%professional%' THEN 50
    WHEN LOWER(name) LIKE '%enterprise%' OR LOWER(name) LIKE '%premium%' THEN 100
    ELSE 25
  END,
  total_files_limit = CASE 
    WHEN LOWER(name) LIKE '%free%' OR LOWER(name) LIKE '%basic%' THEN 500
    WHEN LOWER(name) LIKE '%pro%' OR LOWER(name) LIKE '%professional%' THEN 2000
    WHEN LOWER(name) LIKE '%enterprise%' OR LOWER(name) LIKE '%premium%' THEN 10000
    ELSE 1000
  END
WHERE storage_limit IS NULL OR storage_limit = 1024; -- Only update if not already customized

-- Create an index on companies usage fields for better query performance
CREATE INDEX IF NOT EXISTS idx_companies_usage ON companies(current_storage_used, current_bandwidth_used, files_count);
CREATE INDEX IF NOT EXISTS idx_companies_last_usage_update ON companies(last_usage_update);

-- Create a view for easy usage monitoring (optional)
CREATE OR REPLACE VIEW company_usage_overview AS
SELECT 
  c.id as company_id,
  c.name as company_name,
  c.current_storage_used,
  c.current_bandwidth_used,
  c.files_count,
  c.last_usage_update,
  p.name as plan_name,
  p.storage_limit,
  p.bandwidth_limit,
  p.file_upload_limit,
  p.total_files_limit,
  -- Calculate usage percentages
  CASE 
    WHEN p.storage_limit > 0 THEN ROUND((c.current_storage_used::DECIMAL / p.storage_limit) * 100, 2)
    ELSE 0 
  END as storage_percentage,
  CASE 
    WHEN p.bandwidth_limit > 0 THEN ROUND((c.current_bandwidth_used::DECIMAL / p.bandwidth_limit) * 100, 2)
    ELSE 0 
  END as bandwidth_percentage,
  CASE 
    WHEN p.total_files_limit > 0 THEN ROUND((c.files_count::DECIMAL / p.total_files_limit) * 100, 2)
    ELSE 0 
  END as files_percentage,
  -- Status flags
  CASE 
    WHEN p.storage_limit > 0 AND (c.current_storage_used::DECIMAL / p.storage_limit) >= 0.8 THEN true
    ELSE false 
  END as storage_near_limit,
  CASE 
    WHEN p.bandwidth_limit > 0 AND (c.current_bandwidth_used::DECIMAL / p.bandwidth_limit) >= 0.8 THEN true
    ELSE false 
  END as bandwidth_near_limit,
  CASE 
    WHEN p.total_files_limit > 0 AND (c.files_count::DECIMAL / p.total_files_limit) >= 0.8 THEN true
    ELSE false 
  END as files_near_limit,
  CASE 
    WHEN p.storage_limit > 0 AND c.current_storage_used >= p.storage_limit THEN true
    ELSE false 
  END as storage_exceeded,
  CASE 
    WHEN p.bandwidth_limit > 0 AND c.current_bandwidth_used >= p.bandwidth_limit THEN true
    ELSE false 
  END as bandwidth_exceeded,
  CASE 
    WHEN p.total_files_limit > 0 AND c.files_count >= p.total_files_limit THEN true
    ELSE false 
  END as files_exceeded
FROM companies c
LEFT JOIN plans p ON c.plan_id = p.id
WHERE c.active = true;

-- Add a trigger to automatically update last_usage_update when usage fields change
CREATE OR REPLACE FUNCTION update_usage_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.current_storage_used IS DISTINCT FROM NEW.current_storage_used OR
      OLD.current_bandwidth_used IS DISTINCT FROM NEW.current_bandwidth_used OR
      OLD.files_count IS DISTINCT FROM NEW.files_count) THEN
    NEW.last_usage_update = CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_usage_timestamp
  BEFORE UPDATE ON companies
  FOR EACH ROW
  EXECUTE FUNCTION update_usage_timestamp();
