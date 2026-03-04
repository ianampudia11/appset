-- Migration: Add 'reaction' message type support
-- Date: 2025-01-18
-- Description: Add 'reaction' as a valid message type for WhatsApp reactions

-- Update follow_up_schedules table constraint to include 'reaction'
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'follow_up_schedules_message_type_check' 
    AND table_name = 'follow_up_schedules'
  ) THEN
    ALTER TABLE follow_up_schedules DROP CONSTRAINT follow_up_schedules_message_type_check;
  END IF;
  
  -- Add updated constraint with 'reaction' message type
  ALTER TABLE follow_up_schedules ADD CONSTRAINT follow_up_schedules_message_type_check 
    CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document', 'reaction'));
    
  RAISE NOTICE 'Successfully updated follow_up_schedules message_type constraint';
END$$;

-- Update follow_up_templates table constraint to include 'reaction'
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'follow_up_templates_message_type_check' 
    AND table_name = 'follow_up_templates'
  ) THEN
    ALTER TABLE follow_up_templates DROP CONSTRAINT follow_up_templates_message_type_check;
  END IF;
  
  -- Add updated constraint with 'reaction' message type
  ALTER TABLE follow_up_templates ADD CONSTRAINT follow_up_templates_message_type_check 
    CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document', 'reaction'));
    
  RAISE NOTICE 'Successfully updated follow_up_templates message_type constraint';
END$$;

-- Add index for better performance on reaction message queries
CREATE INDEX IF NOT EXISTS idx_messages_type_reaction ON messages(type) WHERE type = 'reaction';

-- Add index for reaction messages by conversation for better performance
CREATE INDEX IF NOT EXISTS idx_messages_reaction_conversation ON messages(conversation_id, type) WHERE type = 'reaction';
