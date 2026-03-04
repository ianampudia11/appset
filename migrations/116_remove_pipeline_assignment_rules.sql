-- Migration: Remove Pipeline Assignment Rules
-- Description: Drops pipeline_assignment_rules table and related enum
-- Author: System Migration
-- Date: 2026-01-17

BEGIN;

-- ============================================================================
-- Step 1: Drop the pipeline_assignment_rules table
-- ============================================================================
DROP TABLE IF EXISTS pipeline_assignment_rules CASCADE;

-- ============================================================================
-- Step 2: Drop the pipeline_assignment_rule_status enum
-- ============================================================================
DROP TYPE IF EXISTS pipeline_assignment_rule_status CASCADE;

-- ============================================================================
-- Migration Complete
-- ============================================================================
COMMIT;
