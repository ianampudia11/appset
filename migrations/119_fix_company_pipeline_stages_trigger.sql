-- Migration: Fix company pipeline stages trigger
-- Description: Drops the trigger and functions that insert pipeline stages without pipeline_id,
-- which causes NOT NULL violations after migration 112. Pipeline stages will now be created
-- through initPipelineStages() in the application code after company creation.
-- Author: System Migration
-- Date: 2026-01-17

BEGIN;

-- ============================================================================
-- Step 1: Drop the trigger that automatically creates pipeline stages
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_create_company_pipeline_stages ON companies;

-- ============================================================================
-- Step 2: Drop the functions that insert stages without pipeline_id
-- ============================================================================
DROP FUNCTION IF EXISTS create_company_pipeline_stages();
DROP FUNCTION IF EXISTS create_default_pipeline_stages(INTEGER);

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- Note: After this migration, pipeline stages will be created through
-- initPipelineStages() in server/init-pipeline-stages.ts, which properly
-- creates pipelines first and then stages with pipeline_id populated.
-- This ensures compliance with the NOT NULL constraint added in migration 112.
-- ============================================================================

COMMIT;
