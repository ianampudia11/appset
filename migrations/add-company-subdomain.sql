-- Migration: Add subdomain column to companies table
-- This migration adds the subdomain field to support subdomain-based page access

-- Add subdomain column to companies table
ALTER TABLE companies ADD COLUMN IF NOT EXISTS subdomain TEXT;

-- Create unique index on subdomain
CREATE UNIQUE INDEX IF NOT EXISTS idx_companies_subdomain ON companies(subdomain);

-- Update existing companies to have subdomains based on their slug
UPDATE companies 
SET subdomain = slug 
WHERE subdomain IS NULL AND slug IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN companies.subdomain IS 'Unique subdomain for company-specific page access (e.g., company.powerchat.net)';
