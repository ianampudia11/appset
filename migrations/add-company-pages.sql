-- Migration: Add company pages functionality
-- This migration adds the company_pages table for dynamic page management

-- Create company_pages table
CREATE TABLE IF NOT EXISTS company_pages (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  meta_title VARCHAR(255),
  meta_description TEXT,
  meta_keywords TEXT,
  is_published BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  template VARCHAR(100) DEFAULT 'default',
  custom_css TEXT,
  custom_js TEXT,
  author_id INTEGER REFERENCES users(id),
  published_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Ensure unique slug per company
  CONSTRAINT unique_company_page_slug UNIQUE (company_id, slug)
);

-- Create indexes for better performance
CREATE INDEX idx_company_pages_company_id ON company_pages(company_id);
CREATE INDEX idx_company_pages_slug ON company_pages(slug);
CREATE INDEX idx_company_pages_published ON company_pages(is_published);
CREATE INDEX idx_company_pages_featured ON company_pages(is_featured);
CREATE INDEX idx_company_pages_published_at ON company_pages(published_at);

-- Add comments for documentation
COMMENT ON TABLE company_pages IS 'Company-specific pages for public access (Terms, Privacy Policy, etc.)';
COMMENT ON COLUMN company_pages.company_id IS 'Reference to the company that owns this page';
COMMENT ON COLUMN company_pages.title IS 'Display title of the page';
COMMENT ON COLUMN company_pages.slug IS 'URL-friendly identifier for the page';
COMMENT ON COLUMN company_pages.content IS 'HTML content of the page (from WYSIWYG editor)';
COMMENT ON COLUMN company_pages.meta_title IS 'SEO meta title';
COMMENT ON COLUMN company_pages.meta_description IS 'SEO meta description';
COMMENT ON COLUMN company_pages.meta_keywords IS 'SEO meta keywords';
COMMENT ON COLUMN company_pages.is_published IS 'Whether the page is publicly accessible';
COMMENT ON COLUMN company_pages.is_featured IS 'Whether the page should be featured/highlighted';
COMMENT ON COLUMN company_pages.template IS 'Template to use for rendering the page';
COMMENT ON COLUMN company_pages.custom_css IS 'Custom CSS for the page';
COMMENT ON COLUMN company_pages.custom_js IS 'Custom JavaScript for the page';
COMMENT ON COLUMN company_pages.author_id IS 'User who created/last modified the page';
COMMENT ON COLUMN company_pages.published_at IS 'When the page was first published';

-- Insert some default page templates for common use cases
INSERT INTO company_pages (company_id, title, slug, content, meta_title, meta_description, is_published, template, author_id)
SELECT 
  c.id,
  'Privacy Policy',
  'privacy-policy',
  '<h1>Privacy Policy</h1><p>This is a template privacy policy page. Please customize this content to match your company''s privacy practices.</p><p>Last updated: ' || TO_CHAR(NOW(), 'Month DD, YYYY') || '</p>',
  'Privacy Policy',
  'Our privacy policy explains how we collect, use, and protect your personal information.',
  false, -- Not published by default
  'legal',
  NULL
FROM companies c
WHERE NOT EXISTS (
  SELECT 1 FROM company_pages cp 
  WHERE cp.company_id = c.id AND cp.slug = 'privacy-policy'
);

INSERT INTO company_pages (company_id, title, slug, content, meta_title, meta_description, is_published, template, author_id)
SELECT 
  c.id,
  'Terms of Service',
  'terms-of-service',
  '<h1>Terms of Service</h1><p>This is a template terms of service page. Please customize this content to match your company''s terms and conditions.</p><p>Last updated: ' || TO_CHAR(NOW(), 'Month DD, YYYY') || '</p>',
  'Terms of Service',
  'Our terms of service outline the rules and regulations for using our services.',
  false, -- Not published by default
  'legal',
  NULL
FROM companies c
WHERE NOT EXISTS (
  SELECT 1 FROM company_pages cp 
  WHERE cp.company_id = c.id AND cp.slug = 'terms-of-service'
);

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_company_pages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER trigger_update_company_pages_updated_at
  BEFORE UPDATE ON company_pages
  FOR EACH ROW
  EXECUTE FUNCTION update_company_pages_updated_at();

-- Create a function to set published_at when is_published changes to true
CREATE OR REPLACE FUNCTION set_company_pages_published_at()
RETURNS TRIGGER AS $$
BEGIN
  -- If is_published is being set to true and published_at is null, set it to now
  IF NEW.is_published = true AND OLD.is_published = false AND NEW.published_at IS NULL THEN
    NEW.published_at = NOW();
  END IF;
  
  -- If is_published is being set to false, keep the original published_at
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for published_at
CREATE TRIGGER trigger_set_company_pages_published_at
  BEFORE UPDATE ON company_pages
  FOR EACH ROW
  EXECUTE FUNCTION set_company_pages_published_at();
