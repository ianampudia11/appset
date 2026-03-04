-- Migration: Add Pipeline Assignment Rules
-- Description: Creates pipeline_assignment_rules table for automatic deal assignment based on conditions
-- Author: System Migration
-- Date: 2026-01-17
--
-- NOTE: This migration has been SUPERSEDED by migration 116_remove_pipeline_assignment_rules.sql
-- which removes the pipeline_assignment_rules table and related enum.
-- This file is kept for historical reference only. The migration system will recognize it as already-applied.
-- DO NOT modify or re-run this migration.

BEGIN;

-- ============================================================================
-- Step 1: Create enum type for assignment rule status
-- ============================================================================
CREATE TYPE pipeline_assignment_rule_status AS ENUM ('active', 'inactive', 'archived');

-- ============================================================================
-- Step 2: Create pipeline_assignment_rules table
-- ============================================================================
CREATE TABLE pipeline_assignment_rules (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  pipeline_id INTEGER REFERENCES pipelines(id) ON DELETE CASCADE,
  rule_name TEXT NOT NULL,
  description TEXT,
  conditions JSONB NOT NULL DEFAULT '{}',
  assign_to_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  status pipeline_assignment_rule_status DEFAULT 'active',
  apply_on_creation BOOLEAN DEFAULT true,
  apply_on_stage_change BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}',
  created_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- Step 3: Create indexes for performance
-- ============================================================================
CREATE INDEX idx_pipeline_assignment_rules_company_id ON pipeline_assignment_rules(company_id);
CREATE INDEX idx_pipeline_assignment_rules_pipeline_id ON pipeline_assignment_rules(pipeline_id);
CREATE INDEX idx_pipeline_assignment_rules_priority ON pipeline_assignment_rules(priority);
CREATE INDEX idx_pipeline_assignment_rules_status ON pipeline_assignment_rules(status);
CREATE INDEX idx_pipeline_assignment_rules_active ON pipeline_assignment_rules(is_active, status, priority);

-- ============================================================================
-- Step 4: Add table comment
-- ============================================================================
COMMENT ON TABLE pipeline_assignment_rules IS 'Stores automatic deal assignment rules that assign deals to users based on conditions';

-- ============================================================================
-- Step 5: Document conditions JSON structure
-- ============================================================================
COMMENT ON COLUMN pipeline_assignment_rules.conditions IS 'JSON structure for rule conditions:
{
  "stageIds": [1, 2, 3],
  "valueRange": { "min": 1000, "max": 50000 },
  "contactProperties": { "country": "US", "industry": "Technology" },
  "tags": ["hot-lead", "enterprise"],
  "priority": ["high", "medium"],
  "timeBasedConditions": {
    "dayOfWeek": [1, 2, 3, 4, 5],
    "hourRange": { "start": 9, "end": 17 }
  }
}';

-- ============================================================================
-- Migration Complete
-- ============================================================================
COMMIT;
