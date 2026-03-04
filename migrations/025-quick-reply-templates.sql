-- Migration: Quick Reply Templates System
-- Description: Add quick reply templates functionality for faster message responses
-- Date: 2025-08-03

-- Create quick_reply_templates table
CREATE TABLE IF NOT EXISTS "quick_reply_templates" (
  "id" SERIAL PRIMARY KEY,
  "company_id" INTEGER NOT NULL REFERENCES "companies"("id") ON DELETE CASCADE,
  "created_by_id" INTEGER NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  
  -- Template content
  "name" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "category" TEXT DEFAULT 'general',
  
  -- Variable tracking
  "variables" JSONB DEFAULT '[]'::jsonb,
  
  -- Template settings
  "is_active" BOOLEAN DEFAULT TRUE,
  "usage_count" INTEGER DEFAULT 0,
  "sort_order" INTEGER DEFAULT 0,
  
  -- Timestamps
  "created_at" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_company_id" ON "quick_reply_templates"("company_id");
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_created_by" ON "quick_reply_templates"("created_by_id");
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_category" ON "quick_reply_templates"("category");
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_active" ON "quick_reply_templates"("is_active");
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_sort_order" ON "quick_reply_templates"("sort_order");
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_usage_count" ON "quick_reply_templates"("usage_count");

-- Add compound index for company-scoped queries
CREATE INDEX IF NOT EXISTS "idx_quick_reply_templates_company_active" ON "quick_reply_templates"("company_id", "is_active");

-- Add comments for documentation
COMMENT ON TABLE "quick_reply_templates" IS 'Quick reply templates for faster message responses with variable substitution';
COMMENT ON COLUMN "quick_reply_templates"."variables" IS 'Array of variable names used in the template content (e.g., ["contact.name", "date.today"])';
COMMENT ON COLUMN "quick_reply_templates"."content" IS 'Template content with variables in {{variable}} format';
COMMENT ON COLUMN "quick_reply_templates"."category" IS 'Template category for organization (e.g., greeting, follow-up, information)';
COMMENT ON COLUMN "quick_reply_templates"."usage_count" IS 'Number of times this template has been used';
COMMENT ON COLUMN "quick_reply_templates"."sort_order" IS 'Display order for templates within a company';

-- Insert default quick reply templates for existing companies
INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Welcome Message' as name,
  'Hi {{contact.name}}! Welcome to our service. How can I help you today?' as content,
  'greeting' as category,
  '["contact.name"]'::jsonb as variables,
  1 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;

INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Thank You' as name,
  'Thank you for contacting us, {{contact.name}}. We appreciate your business!' as content,
  'general' as category,
  '["contact.name"]'::jsonb as variables,
  2 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;

INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Business Hours' as name,
  'Our business hours are Monday-Friday 9AM-5PM. We''ll get back to you during business hours.' as content,
  'information' as category,
  '[]'::jsonb as variables,
  3 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;

INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Follow Up' as name,
  'Hi {{contact.name}}, I wanted to follow up on our conversation. Do you have any questions?' as content,
  'follow-up' as category,
  '["contact.name"]'::jsonb as variables,
  4 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;

INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Appointment Confirmation' as name,
  'Hi {{contact.name}}, this is to confirm your appointment on {{date.today}}. Please let us know if you need to reschedule.' as content,
  'appointment' as category,
  '["contact.name", "date.today"]'::jsonb as variables,
  5 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;

INSERT INTO "quick_reply_templates" ("company_id", "created_by_id", "name", "content", "category", "variables", "sort_order")
SELECT
  c.id as company_id,
  u.id as created_by_id,
  'Contact Information' as name,
  'You can reach us at {{contact.phone}} or email us at support@company.com. We''re here to help!' as content,
  'information' as category,
  '["contact.phone"]'::jsonb as variables,
  6 as sort_order
FROM "companies" c
JOIN LATERAL (
  SELECT u.id
  FROM "users" u
  WHERE u.company_id = c.id
  AND u.role IN ('admin', 'super_admin')
  ORDER BY u.created_at ASC
  LIMIT 1
) u ON true
WHERE c.active = true
ON CONFLICT DO NOTHING;
