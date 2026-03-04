-- Migration: Add Multi-Pipeline Support
-- Description: Converts single-pipeline architecture to multi-pipeline by introducing pipelines table
-- Author: System Migration
-- Date: 2026-01-17

BEGIN;

-- ============================================================================
-- Step 1.1: Create pipelines table
-- ============================================================================
CREATE TABLE IF NOT EXISTS pipelines (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  color TEXT,
  is_default BOOLEAN DEFAULT false,
  is_template BOOLEAN DEFAULT false,
  template_category TEXT,
  order_num INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add constraint to ensure only one default pipeline per company
-- Use a partial unique index instead of a constraint with WHERE clause
CREATE UNIQUE INDEX IF NOT EXISTS unique_default_per_company 
  ON pipelines(company_id) 
  WHERE is_default = true;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_pipelines_company_id ON pipelines(company_id);
CREATE INDEX IF NOT EXISTS idx_pipelines_is_template ON pipelines(is_template);

-- Add table comment
COMMENT ON TABLE pipelines IS 'Stores pipeline configurations for multi-pipeline support';

-- ============================================================================
-- Step 1.2: Add pipeline_id to pipeline_stages table
-- ============================================================================
ALTER TABLE pipeline_stages 
  ADD COLUMN IF NOT EXISTS pipeline_id INTEGER;

-- Add foreign key constraint (will be enabled after data migration)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_pipeline_stages_pipeline'
  ) THEN
    ALTER TABLE pipeline_stages 
      ADD CONSTRAINT fk_pipeline_stages_pipeline 
      FOREIGN KEY (pipeline_id) REFERENCES pipelines(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_pipeline_stages_pipeline_id ON pipeline_stages(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_stages_pipeline_order ON pipeline_stages(pipeline_id, order_num);

-- ============================================================================
-- Step 1.3: Add pipeline_id to deals table
-- ============================================================================
ALTER TABLE deals 
  ADD COLUMN IF NOT EXISTS pipeline_id INTEGER;

-- Add foreign key constraint (RESTRICT to prevent deletion of pipelines with active deals)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_deals_pipeline'
  ) THEN
    ALTER TABLE deals 
      ADD CONSTRAINT fk_deals_pipeline 
      FOREIGN KEY (pipeline_id) REFERENCES pipelines(id) ON DELETE RESTRICT;
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_deals_pipeline_id ON deals(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_deals_company_pipeline_status ON deals(company_id, pipeline_id, status);

-- ============================================================================
-- Step 1.4: Add pipeline_id to pipeline_stage_reverts table
-- ============================================================================
ALTER TABLE pipeline_stage_reverts 
  ADD COLUMN IF NOT EXISTS pipeline_id INTEGER;

-- Add foreign key constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_pipeline_stage_reverts_pipeline'
  ) THEN
    ALTER TABLE pipeline_stage_reverts 
      ADD CONSTRAINT fk_pipeline_stage_reverts_pipeline 
      FOREIGN KEY (pipeline_id) REFERENCES pipelines(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Create index
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_reverts_pipeline_id ON pipeline_stage_reverts(pipeline_id);

-- ============================================================================
-- Step 1.5: Data migration - Create default pipelines per company
-- ============================================================================
-- Insert default pipeline for each company that has pipeline stages
INSERT INTO pipelines (company_id, name, description, icon, color, is_default, is_template, template_category, order_num, created_at, updated_at)
SELECT DISTINCT 
  ps.company_id,
  'Sales Pipeline' as name,
  'Default sales pipeline' as description,
  'trending-up' as icon,
  '#3a86ff' as color,
  true as is_default,
  false as is_template,
  NULL as template_category,
  1 as order_num,
  NOW() as created_at,
  NOW() as updated_at
FROM pipeline_stages ps
WHERE ps.company_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM pipelines p 
    WHERE p.company_id = ps.company_id 
      AND p.is_default = true
  )
GROUP BY ps.company_id;

-- Create default pipelines for companies that don't have any pipeline stages yet
-- (These companies exist but have no stages defined)
INSERT INTO pipelines (company_id, name, description, icon, color, is_default, is_template, template_category, order_num, created_at, updated_at)
SELECT 
  c.id as company_id,
  'Sales Pipeline' as name,
  'Default sales pipeline' as description,
  'trending-up' as icon,
  '#3a86ff' as color,
  true as is_default,
  false as is_template,
  NULL as template_category,
  1 as order_num,
  NOW() as created_at,
  NOW() as updated_at
FROM companies c
WHERE NOT EXISTS (
  SELECT 1 FROM pipelines p 
  WHERE p.company_id = c.id 
    AND p.is_default = true
);

-- ============================================================================
-- Step 1.6: Migrate legacy global stages (company_id NULL)
-- ============================================================================
-- Duplicate legacy global stages for each company and assign to their default pipeline
-- This ensures backward compatibility for companies that were using global stages
INSERT INTO pipeline_stages (pipeline_id, company_id, name, color, order_num, created_at, updated_at)
SELECT 
  p.id as pipeline_id,
  p.company_id,
  gs.name,
  gs.color,
  gs.order_num,
  NOW() as created_at,
  NOW() as updated_at
FROM pipeline_stages gs
CROSS JOIN pipelines p
WHERE gs.company_id IS NULL 
  AND p.is_default = true
  AND NOT EXISTS (
    -- Avoid duplicating if company already has stages with the same name/order
    SELECT 1 FROM pipeline_stages existing
    WHERE existing.company_id = p.company_id 
      AND existing.name = gs.name
  );

-- Delete legacy global stages now that they've been migrated
DELETE FROM pipeline_stages
WHERE company_id IS NULL;

-- ============================================================================
-- Step 1.7: Update pipeline_stages with pipeline_id
-- ============================================================================
-- Update pipeline_stages to reference the default pipeline
UPDATE pipeline_stages ps
SET pipeline_id = p.id
FROM pipelines p
WHERE ps.company_id = p.company_id 
  AND p.is_default = true
  AND ps.pipeline_id IS NULL;

-- ============================================================================
-- Step 1.8: Update deals with pipeline_id
-- ============================================================================
-- Update deals to reference pipeline through their stage
UPDATE deals d
SET pipeline_id = ps.pipeline_id
FROM pipeline_stages ps
WHERE d.stage_id = ps.id
  AND d.pipeline_id IS NULL;

-- Handle deals with NULL stage_id by assigning them to their company's default pipeline
UPDATE deals d
SET pipeline_id = p.id
FROM pipelines p
WHERE d.company_id = p.company_id 
  AND p.is_default = true
  AND d.stage_id IS NULL
  AND d.pipeline_id IS NULL;

-- ============================================================================
-- Step 1.9: Update pipeline_stage_reverts with pipeline_id
-- ============================================================================
-- Update pipeline_stage_reverts to reference pipeline through current stage
UPDATE pipeline_stage_reverts psr
SET pipeline_id = ps.pipeline_id
FROM pipeline_stages ps
WHERE psr.current_stage_id = ps.id
  AND psr.pipeline_id IS NULL;

-- ============================================================================
-- Step 1.10: Make pipeline_id NOT NULL
-- ============================================================================
-- Make pipeline_id required after migration (only if column is currently nullable)
DO $$
BEGIN
  -- Check if pipeline_stages.pipeline_id is nullable and set to NOT NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'pipeline_stages' 
      AND column_name = 'pipeline_id' 
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE pipeline_stages 
      ALTER COLUMN pipeline_id SET NOT NULL;
  END IF;

  -- Check if deals.pipeline_id is nullable and set to NOT NULL
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'deals' 
      AND column_name = 'pipeline_id' 
      AND is_nullable = 'YES'
  ) THEN
    ALTER TABLE deals 
      ALTER COLUMN pipeline_id SET NOT NULL;
  END IF;
END $$;

-- pipeline_stage_reverts.pipeline_id remains nullable for flexibility

-- ============================================================================
-- Step 1.11: Fix duplicate order_num values and Add validation constraints
-- ============================================================================
-- Fix any duplicate order_num values within the same pipeline
-- This ensures we can create the unique index
DO $$
DECLARE
    stage_rec RECORD;
    new_order INTEGER;
BEGIN
    -- For each pipeline, fix duplicate order numbers
    FOR stage_rec IN
        SELECT DISTINCT pipeline_id
        FROM pipeline_stages
        WHERE pipeline_id IS NOT NULL
    LOOP
        -- Update order_num to be sequential, starting from 1
        WITH ordered_stages AS (
            SELECT 
                id,
                ROW_NUMBER() OVER (ORDER BY order_num, id) as new_order
            FROM pipeline_stages
            WHERE pipeline_id = stage_rec.pipeline_id
        )
        UPDATE pipeline_stages ps
        SET order_num = os.new_order
        FROM ordered_stages os
        WHERE ps.id = os.id;
    END LOOP;
END $$;

-- Ensure stage belongs to same pipeline as deal
-- Note: Using a simpler approach without subquery in CHECK constraint
-- The application layer will enforce this constraint

-- Ensure unique stage order within pipeline
CREATE UNIQUE INDEX IF NOT EXISTS idx_pipeline_stages_pipeline_order_unique 
  ON pipeline_stages(pipeline_id, order_num);

-- Ensure unique pipeline name per company (excluding templates)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pipelines_company_name_unique 
  ON pipelines(company_id, name) 
  WHERE is_template = false;

-- ============================================================================
-- Migration Complete
-- ============================================================================
COMMIT;
