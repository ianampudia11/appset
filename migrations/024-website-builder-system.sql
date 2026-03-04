-- Migration: Website Builder System
-- Description: Add tables for website builder functionality with GrapeJS integration
-- Date: 2025-07-30

-- Create website templates table first (since websites will reference it)
CREATE TABLE IF NOT EXISTS "website_templates" (
  "id" SERIAL PRIMARY KEY,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "category" TEXT DEFAULT 'general',
  
  -- Template preview
  "preview_image" TEXT,
  "preview_url" TEXT,
  
  -- GrapeJS template data
  "grapes_data" JSONB NOT NULL DEFAULT '{}',
  "grapes_html" TEXT,
  "grapes_css" TEXT,
  "grapes_js" TEXT,
  
  -- Template metadata
  "is_active" BOOLEAN DEFAULT TRUE,
  "is_premium" BOOLEAN DEFAULT FALSE,
  "tags" TEXT[],
  
  -- Usage tracking
  "usage_count" INTEGER DEFAULT 0,
  
  "created_by_id" INTEGER NOT NULL REFERENCES "users"("id"),
  "created_at" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create websites table
CREATE TABLE IF NOT EXISTS "websites" (
  "id" SERIAL PRIMARY KEY,
  "title" TEXT NOT NULL,
  "slug" TEXT NOT NULL UNIQUE,
  "description" TEXT,
  "meta_title" TEXT,
  "meta_description" TEXT,
  "meta_keywords" TEXT,

  -- GrapeJS content storage
  "grapes_data" JSONB NOT NULL DEFAULT '{}',
  "grapes_html" TEXT,
  "grapes_css" TEXT,
  "grapes_js" TEXT,

  -- Website settings
  "favicon" TEXT,
  "custom_css" TEXT,
  "custom_js" TEXT,
  "custom_head" TEXT,

  -- Publishing and status
  "status" TEXT NOT NULL DEFAULT 'draft' CHECK ("status" IN ('draft', 'published', 'archived')),
  "published_at" TIMESTAMP,

  -- SEO and analytics
  "google_analytics_id" TEXT,
  "facebook_pixel_id" TEXT,

  -- Template and theme
  "template_id" INTEGER REFERENCES "website_templates"("id"),
  "theme" TEXT DEFAULT 'default',

  -- Metadata
  "created_by_id" INTEGER NOT NULL REFERENCES "users"("id"),
  "created_at" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create website assets table
CREATE TABLE IF NOT EXISTS "website_assets" (
  "id" SERIAL PRIMARY KEY,
  "website_id" INTEGER NOT NULL REFERENCES "websites"("id") ON DELETE CASCADE,
  
  -- Asset information
  "filename" TEXT NOT NULL,
  "original_name" TEXT NOT NULL,
  "mime_type" TEXT NOT NULL,
  "size" INTEGER NOT NULL,
  
  -- Asset storage
  "path" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  
  -- Asset metadata
  "alt" TEXT,
  "title" TEXT,
  
  -- Asset type and usage
  "asset_type" TEXT NOT NULL CHECK ("asset_type" IN ('image', 'video', 'audio', 'document', 'font', 'icon')),
  
  "created_at" TIMESTAMP NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS "idx_websites_slug" ON "websites"("slug");
CREATE INDEX IF NOT EXISTS "idx_websites_status" ON "websites"("status");
CREATE INDEX IF NOT EXISTS "idx_websites_created_by" ON "websites"("created_by_id");
CREATE INDEX IF NOT EXISTS "idx_websites_published_at" ON "websites"("published_at");

CREATE INDEX IF NOT EXISTS "idx_website_templates_category" ON "website_templates"("category");
CREATE INDEX IF NOT EXISTS "idx_website_templates_active" ON "website_templates"("is_active");
CREATE INDEX IF NOT EXISTS "idx_website_templates_created_by" ON "website_templates"("created_by_id");

CREATE INDEX IF NOT EXISTS "idx_website_assets_website_id" ON "website_assets"("website_id");
CREATE INDEX IF NOT EXISTS "idx_website_assets_type" ON "website_assets"("asset_type");

-- Add comments for documentation
COMMENT ON TABLE "websites" IS 'Main websites table for website builder functionality';
COMMENT ON TABLE "website_templates" IS 'Reusable website templates for quick website creation';
COMMENT ON TABLE "website_assets" IS 'Assets (images, files, etc.) associated with websites';

COMMENT ON COLUMN "websites"."grapes_data" IS 'GrapeJS editor data in JSON format';
COMMENT ON COLUMN "websites"."grapes_html" IS 'Generated HTML from GrapeJS editor';
COMMENT ON COLUMN "websites"."grapes_css" IS 'Generated CSS from GrapeJS editor';
COMMENT ON COLUMN "websites"."grapes_js" IS 'Generated JavaScript from GrapeJS editor';

-- Insert some default website templates
INSERT INTO "website_templates" ("name", "description", "category", "grapes_data", "grapes_html", "grapes_css", "created_by_id", "is_active")
SELECT 
  'Blank Template',
  'A blank template to start from scratch',
  'general',
  '{"pages": [{"frames": [{"component": {"type": "wrapper", "components": [{"type": "text", "content": "Welcome to your new website!"}]}}]}]}',
  '<div>Welcome to your new website!</div>',
  'body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }',
  u.id,
  true
FROM "users" u 
WHERE u."is_super_admin" = true 
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO "website_templates" ("name", "description", "category", "grapes_data", "grapes_html", "grapes_css", "created_by_id", "is_active")
SELECT 
  'Landing Page Template',
  'A simple landing page template with hero section',
  'landing',
  '{"pages": [{"frames": [{"component": {"type": "wrapper", "components": [{"type": "text", "content": "<h1>Your Amazing Product</h1><p>Transform your business with our innovative solution.</p><button>Get Started</button>"}]}}]}]}',
  '<div style="text-align: center; padding: 50px;"><h1>Your Amazing Product</h1><p>Transform your business with our innovative solution.</p><button style="background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer;">Get Started</button></div>',
  'body { font-family: Arial, sans-serif; margin: 0; } h1 { color: #333; } button:hover { background: #0056b3; }',
  u.id,
  true
FROM "users" u 
WHERE u."is_super_admin" = true 
LIMIT 1
ON CONFLICT DO NOTHING;
