-- Migration: Add Pipeline Transition Rules
-- Description: Creates pipeline_transition_rules, pipeline_transition_schedules, and pipeline_transition_logs tables
-- Author: System Migration
-- Date: 2026-01-17
--
-- NOTE: This migration has been SUPERSEDED by migration 117_remove_pipeline_transition_rules.sql
-- which removes all transition rule tables and related enums.
-- This file is kept for historical reference only. The migration system will recognize it as already-applied.
-- DO NOT modify or re-run this migration.

-- Create enum for transition rule status
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_transition_rule_status') THEN
    CREATE TYPE pipeline_transition_rule_status AS ENUM ('active', 'inactive', 'archived');
  END IF;
END $$;

-- Create pipeline_transition_rules table
CREATE TABLE IF NOT EXISTS pipeline_transition_rules (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  pipeline_id INTEGER REFERENCES pipelines(id) ON DELETE CASCADE,
  rule_name TEXT NOT NULL,
  description TEXT,
  from_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE CASCADE,
  to_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE CASCADE,
  conditions JSONB NOT NULL DEFAULT '{}',
  delay_amount INTEGER NOT NULL DEFAULT 0,
  delay_unit TEXT NOT NULL CHECK (delay_unit IN ('minutes', 'hours', 'days')),
  priority INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  status pipeline_transition_rule_status DEFAULT 'active',
  metadata JSONB DEFAULT '{}',
  created_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_pipeline_transition_rules_company ON pipeline_transition_rules(company_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_transition_rules_pipeline ON pipeline_transition_rules(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_transition_rules_from_stage ON pipeline_transition_rules(from_stage_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_transition_rules_status ON pipeline_transition_rules(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_transition_rules_active ON pipeline_transition_rules(is_active) WHERE is_active = true;

-- Create scheduled transitions table (similar to pipeline_stage_reverts)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_transition_schedule_status') THEN
    CREATE TYPE pipeline_transition_schedule_status AS ENUM ('scheduled', 'executed', 'cancelled', 'failed', 'skipped');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS pipeline_transition_schedules (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL UNIQUE,
  rule_id INTEGER NOT NULL REFERENCES pipeline_transition_rules(id) ON DELETE CASCADE,
  deal_id INTEGER NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  pipeline_id INTEGER REFERENCES pipelines(id) ON DELETE CASCADE,
  from_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  to_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  scheduled_for TIMESTAMP NOT NULL,
  status pipeline_transition_schedule_status NOT NULL DEFAULT 'scheduled',
  retry_count INTEGER NOT NULL DEFAULT 0,
  max_retries INTEGER NOT NULL DEFAULT 3,
  failed_reason TEXT,
  executed_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for scheduled transitions
CREATE INDEX IF NOT EXISTS idx_transition_schedules_status ON pipeline_transition_schedules(status);
CREATE INDEX IF NOT EXISTS idx_transition_schedules_scheduled_for ON pipeline_transition_schedules(scheduled_for) WHERE status = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_transition_schedules_deal ON pipeline_transition_schedules(deal_id);
CREATE INDEX IF NOT EXISTS idx_transition_schedules_rule ON pipeline_transition_schedules(rule_id);

-- Create execution logs table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_transition_log_status') THEN
    CREATE TYPE pipeline_transition_log_status AS ENUM ('success', 'failed', 'skipped');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS pipeline_transition_logs (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL REFERENCES pipeline_transition_schedules(schedule_id) ON DELETE CASCADE,
  execution_attempt INTEGER NOT NULL,
  status pipeline_transition_log_status NOT NULL,
  error_message TEXT,
  execution_duration_ms INTEGER,
  previous_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  new_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  condition_evaluation_result JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transition_logs_schedule ON pipeline_transition_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_transition_logs_status ON pipeline_transition_logs(status);
