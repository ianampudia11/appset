-- 108-enhance-calls-table.sql
-- Enhance calls table with additional fields for comprehensive call logging

-- Add new columns
ALTER TABLE calls
  ADD COLUMN IF NOT EXISTS flow_id INTEGER REFERENCES flows(id),
  ADD COLUMN IF NOT EXISTS node_id TEXT,
  ADD COLUMN IF NOT EXISTS transcript JSONB,
  ADD COLUMN IF NOT EXISTS conversation_data JSONB,
  ADD COLUMN IF NOT EXISTS agent_config JSONB,
  ADD COLUMN IF NOT EXISTS cost NUMERIC(10, 4),
  ADD COLUMN IF NOT EXISTS cost_currency TEXT DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS is_starred BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_calls_company_id ON calls(company_id);
CREATE INDEX IF NOT EXISTS idx_calls_contact_id ON calls(contact_id);
CREATE INDEX IF NOT EXISTS idx_calls_flow_id ON calls(flow_id);
CREATE INDEX IF NOT EXISTS idx_calls_direction ON calls(direction);
CREATE INDEX IF NOT EXISTS idx_calls_status ON calls(status);
CREATE INDEX IF NOT EXISTS idx_calls_started_at ON calls(started_at);
CREATE INDEX IF NOT EXISTS idx_calls_company_started_at ON calls(company_id, started_at DESC);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_calls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_calls_updated_at_trigger
  BEFORE UPDATE ON calls
  FOR EACH ROW
  EXECUTE FUNCTION update_calls_updated_at();
