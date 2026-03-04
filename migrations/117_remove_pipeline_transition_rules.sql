-- Migration: Remove Pipeline Transition Rules
-- Description: Drops pipeline_transition_rules, pipeline_transition_schedules, pipeline_transition_logs tables and related enums
-- Author: System Migration
-- Date: 2026-01-17

BEGIN;

-- ============================================================================
-- Step 1: Drop dependent tables first (due to foreign key constraints)
-- ============================================================================
DROP TABLE IF EXISTS pipeline_transition_logs CASCADE;
DROP TABLE IF EXISTS pipeline_transition_schedules CASCADE;
DROP TABLE IF EXISTS pipeline_transition_rules CASCADE;

-- ============================================================================
-- Step 2: Drop the enums
-- ============================================================================
DROP TYPE IF EXISTS pipeline_transition_log_status CASCADE;
DROP TYPE IF EXISTS pipeline_transition_schedule_status CASCADE;
DROP TYPE IF EXISTS pipeline_transition_rule_status CASCADE;

-- ============================================================================
-- Migration Complete
-- ============================================================================
COMMIT;
