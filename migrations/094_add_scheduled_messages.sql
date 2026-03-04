-- Create scheduled message status enum (if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'scheduled_message_status') THEN
        CREATE TYPE scheduled_message_status AS ENUM (
          'pending',
          'scheduled', 
          'processing',
          'sent',
          'failed',
          'cancelled'
        );
    END IF;
END $$;

-- Create scheduled messages table (if it doesn't exist)
CREATE TABLE IF NOT EXISTS scheduled_messages (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL,
  conversation_id INTEGER NOT NULL,
  channel_id INTEGER NOT NULL,
  channel_type TEXT NOT NULL,
  
  -- Message content
  content TEXT NOT NULL,
  message_type TEXT NOT NULL DEFAULT 'text',
  media_url TEXT,
  media_type TEXT,
  caption TEXT,
  
  -- Scheduling
  scheduled_for TIMESTAMP NOT NULL,
  timezone TEXT DEFAULT 'UTC',
  
  -- Status and execution
  status scheduled_message_status DEFAULT 'pending',
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  last_attempt_at TIMESTAMP,
  sent_at TIMESTAMP,
  failed_at TIMESTAMP,
  error_message TEXT,
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  created_by INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add indexes for performance (if they don't exist)
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_company_id ON scheduled_messages(company_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_conversation_id ON scheduled_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_channel_id ON scheduled_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_scheduled_for ON scheduled_messages(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_status ON scheduled_messages(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_messages_created_by ON scheduled_messages(created_by);

-- Add foreign key constraints (if they don't exist)
DO $$ 
BEGIN
    -- Company foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'fk_scheduled_messages_company_id' 
                   AND table_name = 'scheduled_messages') THEN
        ALTER TABLE scheduled_messages 
        ADD CONSTRAINT fk_scheduled_messages_company_id 
        FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE;
    END IF;

    -- Conversation foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'fk_scheduled_messages_conversation_id' 
                   AND table_name = 'scheduled_messages') THEN
        ALTER TABLE scheduled_messages 
        ADD CONSTRAINT fk_scheduled_messages_conversation_id 
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE;
    END IF;

    -- Channel connection foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'fk_scheduled_messages_channel_id' 
                   AND table_name = 'scheduled_messages') THEN
        ALTER TABLE scheduled_messages 
        ADD CONSTRAINT fk_scheduled_messages_channel_id 
        FOREIGN KEY (channel_id) REFERENCES channel_connections(id) ON DELETE CASCADE;
    END IF;

    -- User foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'fk_scheduled_messages_created_by' 
                   AND table_name = 'scheduled_messages') THEN
        ALTER TABLE scheduled_messages 
        ADD CONSTRAINT fk_scheduled_messages_created_by 
        FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;
