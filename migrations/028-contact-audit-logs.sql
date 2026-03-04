-- Create contact audit logs table
CREATE TABLE IF NOT EXISTS contact_audit_logs (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  action_type VARCHAR(50) NOT NULL,
  action_category VARCHAR(30) NOT NULL DEFAULT 'contact',
  description TEXT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  metadata JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_contact_id ON contact_audit_logs(contact_id);
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_company_id ON contact_audit_logs(company_id);
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_user_id ON contact_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_action_type ON contact_audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_action_category ON contact_audit_logs(action_category);
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_created_at ON contact_audit_logs(created_at DESC);

-- Create composite index for efficient contact history queries
CREATE INDEX IF NOT EXISTS idx_contact_audit_logs_contact_created ON contact_audit_logs(contact_id, created_at DESC);

-- Add comments for documentation
COMMENT ON TABLE contact_audit_logs IS 'Audit trail for all contact-related actions and changes';
COMMENT ON COLUMN contact_audit_logs.action_type IS 'Specific action performed (e.g., created, updated, deleted, document_uploaded, agent_assigned)';
COMMENT ON COLUMN contact_audit_logs.action_category IS 'Category of action (contact, document, appointment, agent, tag)';
COMMENT ON COLUMN contact_audit_logs.description IS 'Human-readable description of the action';
COMMENT ON COLUMN contact_audit_logs.old_values IS 'Previous values before the change (for updates)';
COMMENT ON COLUMN contact_audit_logs.new_values IS 'New values after the change';
COMMENT ON COLUMN contact_audit_logs.metadata IS 'Additional context data (e.g., document info, appointment details)';
