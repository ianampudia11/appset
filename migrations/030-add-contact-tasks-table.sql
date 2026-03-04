-- Migration: Add contact_tasks table
-- Description: Create table for managing tasks associated with contacts

CREATE TABLE IF NOT EXISTS contact_tasks (
  id SERIAL PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  
  -- Task details
  title TEXT NOT NULL,
  description TEXT,
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status TEXT NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'cancelled')),
  
  -- Scheduling
  due_date TIMESTAMP,
  completed_at TIMESTAMP,
  
  -- Assignment and categorization
  assigned_to TEXT,
  category TEXT,
  tags TEXT[],
  
  -- Audit information
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_contact_tasks_contact_id ON contact_tasks(contact_id);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_company_id ON contact_tasks(company_id);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_status ON contact_tasks(status);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_priority ON contact_tasks(priority);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_due_date ON contact_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_created_at ON contact_tasks(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_contact_tasks_contact_company ON contact_tasks(contact_id, company_id);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_status_priority ON contact_tasks(status, priority);
CREATE INDEX IF NOT EXISTS idx_contact_tasks_company_status ON contact_tasks(company_id, status);
