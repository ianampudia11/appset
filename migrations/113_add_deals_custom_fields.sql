-- Add custom_fields column to deals table
-- This allows storing arbitrary custom field data as JSONB for extensibility

ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS custom_fields JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Create GIN index for efficient JSONB queries on custom fields
CREATE INDEX IF NOT EXISTS idx_deals_custom_fields ON deals USING GIN (custom_fields);

-- Add comment to document the purpose of the field
COMMENT ON COLUMN deals.custom_fields IS 'Stores custom field data as JSONB for extensible deal metadata';

-- Create table for custom fields schema management
CREATE TABLE IF NOT EXISTS company_custom_fields (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  entity TEXT NOT NULL CHECK (entity IN ('deal', 'contact', 'company')),
  field_name TEXT NOT NULL,
  field_type TEXT NOT NULL CHECK (field_type IN ('text', 'number', 'select', 'multi_select', 'date', 'boolean')),
  field_label TEXT NOT NULL,
  options JSONB, -- For select/multi_select: array of {value, label} objects
  required BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(company_id, entity, field_name)
);

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_company_custom_fields_company_entity ON company_custom_fields(company_id, entity);
CREATE INDEX IF NOT EXISTS idx_company_custom_fields_entity ON company_custom_fields(entity);

-- Add comment to document the table
COMMENT ON TABLE company_custom_fields IS 'Stores schema definitions for custom fields per company and entity type';
