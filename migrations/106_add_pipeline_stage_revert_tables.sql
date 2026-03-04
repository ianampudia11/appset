-- Pipeline Stage Revert System Setup Migration
-- This migration creates the pipeline stage revert scheduling system tables

-- Create enum types for revert status
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_stage_revert_status') THEN
    CREATE TYPE pipeline_stage_revert_status AS ENUM ('scheduled', 'executed', 'cancelled', 'failed', 'skipped');
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pipeline_stage_revert_log_status') THEN
    CREATE TYPE pipeline_stage_revert_log_status AS ENUM ('success', 'failed', 'skipped');
  END IF;
END $$;

-- Create pipeline_stage_reverts table
CREATE TABLE IF NOT EXISTS pipeline_stage_reverts (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL UNIQUE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  deal_id INTEGER NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  flow_id INTEGER REFERENCES flows(id) ON DELETE SET NULL,
  node_id TEXT NOT NULL,
  current_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  revert_to_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  scheduled_for TIMESTAMP NOT NULL,
  revert_time_amount INTEGER NOT NULL,
  revert_time_unit TEXT NOT NULL CHECK (revert_time_unit IN ('hours', 'days')),
  only_if_no_activity BOOLEAN DEFAULT false,
  status pipeline_stage_revert_status NOT NULL DEFAULT 'scheduled',
  executed_at TIMESTAMP,
  failed_reason TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create pipeline_stage_revert_logs table
CREATE TABLE IF NOT EXISTS pipeline_stage_revert_logs (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL REFERENCES pipeline_stage_reverts(schedule_id) ON DELETE CASCADE,
  execution_attempt INTEGER NOT NULL,
  status pipeline_stage_revert_log_status NOT NULL,
  error_message TEXT,
  execution_duration_ms INTEGER,
  previous_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  new_stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  activity_check_result BOOLEAN,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_reverts_deal_id ON pipeline_stage_reverts(deal_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_reverts_scheduled_for ON pipeline_stage_reverts(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_reverts_status ON pipeline_stage_reverts(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_reverts_status_scheduled_for ON pipeline_stage_reverts(status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_pipeline_stage_revert_logs_schedule_id ON pipeline_stage_revert_logs(schedule_id);

-- Add comments for documentation
COMMENT ON TABLE pipeline_stage_reverts IS 'Stores scheduled pipeline stage reverts that will automatically move deals back to a previous stage after a specified time period';
COMMENT ON TABLE pipeline_stage_revert_logs IS 'Stores execution logs for pipeline stage revert operations';

