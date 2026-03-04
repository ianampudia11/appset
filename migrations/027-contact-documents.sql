-- Contact Documents Migration
-- This migration adds support for document attachments to contacts

-- Contact Documents table
CREATE TABLE IF NOT EXISTS contact_documents (
  id SERIAL PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  
  -- Document metadata
  filename TEXT NOT NULL,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  
  -- Storage information
  file_path TEXT NOT NULL,
  file_url TEXT NOT NULL,
  
  -- Document categorization
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  
  -- Audit information
  uploaded_by INTEGER REFERENCES users(id),
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_contact_documents_contact_id ON contact_documents(contact_id);
CREATE INDEX IF NOT EXISTS idx_contact_documents_category ON contact_documents(category);
CREATE INDEX IF NOT EXISTS idx_contact_documents_created_at ON contact_documents(created_at);

-- Contact Appointments table
CREATE TABLE IF NOT EXISTS contact_appointments (
  id SERIAL PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  
  -- Appointment details
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  
  -- Scheduling
  scheduled_at TIMESTAMP NOT NULL,
  duration_minutes INTEGER DEFAULT 60,
  
  -- Appointment type and status
  type TEXT NOT NULL DEFAULT 'meeting',
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'rescheduled')),
  
  -- Audit information
  created_by INTEGER REFERENCES users(id),
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for appointments
CREATE INDEX IF NOT EXISTS idx_contact_appointments_contact_id ON contact_appointments(contact_id);
CREATE INDEX IF NOT EXISTS idx_contact_appointments_scheduled_at ON contact_appointments(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_contact_appointments_status ON contact_appointments(status);
CREATE INDEX IF NOT EXISTS idx_contact_appointments_type ON contact_appointments(type);

-- Add comments for documentation
COMMENT ON TABLE contact_documents IS 'Stores document attachments for contacts';
COMMENT ON TABLE contact_appointments IS 'Stores appointments and meetings scheduled with contacts';
COMMENT ON COLUMN contact_documents.category IS 'Document category: identity, address_proof, income, general, etc.';
COMMENT ON COLUMN contact_appointments.type IS 'Appointment type: meeting, property_viewing, phone_call, document_review, etc.';
