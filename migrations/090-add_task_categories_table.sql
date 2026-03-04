-- Create task_categories table
CREATE TABLE IF NOT EXISTS task_categories (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  icon TEXT,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_task_categories_company_id ON task_categories(company_id);

-- Add some default categories for existing companies
INSERT INTO task_categories (company_id, name, color, icon)
SELECT 
  id as company_id,
  'General' as name,
  '#6B7280' as color,
  'folder' as icon
FROM companies
ON CONFLICT DO NOTHING;

INSERT INTO task_categories (company_id, name, color, icon)
SELECT 
  id as company_id,
  'Follow-up' as name,
  '#3B82F6' as color,
  'phone' as icon
FROM companies
ON CONFLICT DO NOTHING;

INSERT INTO task_categories (company_id, name, color, icon)
SELECT 
  id as company_id,
  'Meeting' as name,
  '#8B5CF6' as color,
  'calendar' as icon
FROM companies
ON CONFLICT DO NOTHING;

INSERT INTO task_categories (company_id, name, color, icon)
SELECT 
  id as company_id,
  'Support' as name,
  '#10B981' as color,
  'headphones' as icon
FROM companies
ON CONFLICT DO NOTHING;

INSERT INTO task_categories (company_id, name, color, icon)
SELECT 
  id as company_id,
  'Sales' as name,
  '#F59E0B' as color,
  'shopping-cart' as icon
FROM companies
ON CONFLICT DO NOTHING;

