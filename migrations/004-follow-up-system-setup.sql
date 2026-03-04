-- Follow-up Scheduling System Setup Migration
-- This migration creates the follow-up scheduling system tables and setup

-- Check if follow_up_templates table exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'follow_up_templates'
  ) THEN
    RAISE NOTICE 'Creating follow_up_templates table...';
    
    CREATE TABLE follow_up_templates (
      id SERIAL PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id),
      name TEXT NOT NULL,
      description TEXT,
      message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document')),
      content TEXT NOT NULL,
      media_url TEXT,
      caption TEXT,
      default_delay_amount INTEGER DEFAULT 24,
      default_delay_unit TEXT DEFAULT 'hours' CHECK (default_delay_unit IN ('minutes', 'hours', 'days', 'weeks')),
      variables JSONB DEFAULT '[]', -- Array of variable names
      category TEXT DEFAULT 'general',
      is_active BOOLEAN DEFAULT true,
      usage_count INTEGER DEFAULT 0,
      created_by INTEGER REFERENCES users(id),
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      
      CONSTRAINT unique_company_template_name UNIQUE (company_id, name)
    );
  ELSE
    RAISE NOTICE 'follow_up_templates table exists, adding missing fields...';
    
    -- Add missing fields to follow_up_templates table
    ALTER TABLE follow_up_templates 
    ADD COLUMN IF NOT EXISTS default_delay_amount INTEGER DEFAULT 24,
    ADD COLUMN IF NOT EXISTS default_delay_unit TEXT DEFAULT 'hours' CHECK (default_delay_unit IN ('minutes', 'hours', 'days', 'weeks'));
  END IF;
END $$;

-- Check if follow_up_schedules table exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'follow_up_schedules'
  ) THEN
    RAISE NOTICE 'Creating follow_up_schedules table...';
    
    CREATE TABLE follow_up_schedules (
      id SERIAL PRIMARY KEY,
      schedule_id TEXT NOT NULL UNIQUE,
      session_id TEXT REFERENCES flow_sessions(session_id),
      flow_id INTEGER NOT NULL REFERENCES flows(id),
      conversation_id INTEGER NOT NULL REFERENCES conversations(id),
      contact_id INTEGER NOT NULL REFERENCES contacts(id),
      company_id INTEGER REFERENCES companies(id),
      node_id TEXT NOT NULL,
      
      -- Message Configuration
      message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document')),
      message_content TEXT,
      media_url TEXT,
      caption TEXT,
      template_id INTEGER,
      
      -- Scheduling Configuration
      trigger_event TEXT NOT NULL DEFAULT 'conversation_start' CHECK (trigger_event IN ('conversation_start', 'node_execution', 'specific_datetime', 'relative_delay')),
      trigger_node_id TEXT,
      delay_amount INTEGER,
      delay_unit TEXT CHECK (delay_unit IN ('minutes', 'hours', 'days', 'weeks')),
      scheduled_for TIMESTAMP,
      specific_datetime TIMESTAMP,
      
      -- Status and Execution
      status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'sent', 'failed', 'cancelled', 'expired')),
      sent_at TIMESTAMP,
      failed_reason TEXT,
      retry_count INTEGER DEFAULT 0,
      max_retries INTEGER DEFAULT 3,
      
      -- Channel Information
      channel_type TEXT NOT NULL,
      channel_connection_id INTEGER REFERENCES channel_connections(id),
      
      -- Metadata
      variables JSONB DEFAULT '{}',
      execution_context JSONB DEFAULT '{}',
      
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMP
    );
  ELSE
    RAISE NOTICE 'follow_up_schedules table exists, updating constraints...';
    
    -- Add missing status values to follow_up_schedules
    ALTER TABLE follow_up_schedules DROP CONSTRAINT IF EXISTS follow_up_schedules_status_check;
    ALTER TABLE follow_up_schedules ADD CONSTRAINT follow_up_schedules_status_check 
    CHECK (status IN ('scheduled', 'sent', 'failed', 'cancelled', 'expired'));
  END IF;
END $$;

-- Check if follow_up_execution_log table exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'follow_up_execution_log'
  ) THEN
    RAISE NOTICE 'Creating follow_up_execution_log table...';
    
    CREATE TABLE follow_up_execution_log (
      id SERIAL PRIMARY KEY,
      schedule_id TEXT NOT NULL REFERENCES follow_up_schedules(schedule_id),
      execution_attempt INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'retry', 'expired')),
      message_id TEXT, -- External message ID from channel
      error_message TEXT,
      execution_duration_ms INTEGER,
      executed_at TIMESTAMP NOT NULL DEFAULT NOW(),
      
      -- Response tracking
      response_received BOOLEAN DEFAULT false,
      response_at TIMESTAMP,
      response_content TEXT
    );
  ELSE
    RAISE NOTICE 'follow_up_execution_log table exists, updating constraints...';
    
    -- Add missing status value to follow_up_execution_log
    ALTER TABLE follow_up_execution_log DROP CONSTRAINT IF EXISTS follow_up_execution_log_status_check;
    ALTER TABLE follow_up_execution_log ADD CONSTRAINT follow_up_execution_log_status_check 
    CHECK (status IN ('success', 'failed', 'retry', 'expired'));
  END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_status ON follow_up_schedules(status);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_scheduled_for ON follow_up_schedules(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_conversation_id ON follow_up_schedules(conversation_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_contact_id ON follow_up_schedules(contact_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_company_id ON follow_up_schedules(company_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_expires_at ON follow_up_schedules(expires_at);

CREATE INDEX IF NOT EXISTS idx_follow_up_templates_company_id ON follow_up_templates(company_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_templates_is_active ON follow_up_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_follow_up_templates_category ON follow_up_templates(category);

CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_schedule_id ON follow_up_execution_log(schedule_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_executed_at ON follow_up_execution_log(executed_at);
CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_status ON follow_up_execution_log(status);

-- Add follow_up to flow node types enum if it doesn't exist
DO $$
BEGIN
    -- Check if the enum value already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'follow_up' 
        AND enumtypid = (
            SELECT oid FROM pg_type WHERE typname = 'flow_node_type'
        )
    ) THEN
        -- Add the new enum value
        ALTER TYPE flow_node_type ADD VALUE 'follow_up';
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        -- If the enum doesn't exist, that's fine - it might be handled differently
        NULL;
END $$;

-- Insert some default follow-up templates for companies that don't have them
INSERT INTO follow_up_templates (company_id, name, description, message_type, content, default_delay_amount, default_delay_unit, category, created_by)
SELECT 
    c.id,
    'Welcome Follow-up',
    'A friendly welcome message sent 24 hours after first contact',
    'text',
    'Hi {{contact.name}}! 👋 Thank you for reaching out to us. We''re excited to help you with your needs. Is there anything specific you''d like to know about our services?',
    24,
    'hours',
    'welcome',
    (SELECT id FROM users WHERE company_id = c.id AND role = 'admin' LIMIT 1)
FROM companies c
WHERE c.active = true
  AND NOT EXISTS (
    SELECT 1 FROM follow_up_templates ft 
    WHERE ft.company_id = c.id AND ft.name = 'Welcome Follow-up'
  );

INSERT INTO follow_up_templates (company_id, name, description, message_type, content, default_delay_amount, default_delay_unit, category, created_by)
SELECT 
    c.id,
    'Check-in Follow-up',
    'A check-in message sent 3 days after initial contact',
    'text',
    'Hi {{contact.name}}! Just checking in to see if you have any questions about our previous conversation. We''re here to help whenever you''re ready! 😊',
    3,
    'days',
    'check_in',
    (SELECT id FROM users WHERE company_id = c.id AND role = 'admin' LIMIT 1)
FROM companies c
WHERE c.active = true
  AND NOT EXISTS (
    SELECT 1 FROM follow_up_templates ft 
    WHERE ft.company_id = c.id AND ft.name = 'Check-in Follow-up'
  );

INSERT INTO follow_up_templates (company_id, name, description, message_type, content, default_delay_amount, default_delay_unit, category, created_by)
SELECT 
    c.id,
    'Weekly Follow-up',
    'A weekly follow-up message for ongoing engagement',
    'text',
    'Hello {{contact.name}}! Hope you''re having a great week. We wanted to reach out and see if there''s anything we can assist you with. Feel free to let us know! 🌟',
    1,
    'weeks',
    'engagement',
    (SELECT id FROM users WHERE company_id = c.id AND role = 'admin' LIMIT 1)
FROM companies c
WHERE c.active = true
  AND NOT EXISTS (
    SELECT 1 FROM follow_up_templates ft 
    WHERE ft.company_id = c.id AND ft.name = 'Weekly Follow-up'
  );

-- Add comments for documentation
COMMENT ON TABLE follow_up_schedules IS 'Stores scheduled follow-up messages with timing and execution details';
COMMENT ON TABLE follow_up_templates IS 'Reusable templates for follow-up messages';
COMMENT ON TABLE follow_up_execution_log IS 'Logs all follow-up execution attempts and results';

COMMENT ON COLUMN follow_up_templates.default_delay_amount IS 'Default delay amount for this template';
COMMENT ON COLUMN follow_up_templates.default_delay_unit IS 'Default delay unit (minutes, hours, days, weeks) for this template';

-- Migration completed successfully
SELECT 'Follow-up Scheduling System setup completed successfully' AS result;
