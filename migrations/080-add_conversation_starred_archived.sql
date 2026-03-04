-- Migration: Add starred and archived fields to conversations table
-- This enables conversation filtering for starred and archived conversations

-- Add starred field to conversations table
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS is_starred BOOLEAN DEFAULT FALSE;

-- Add archived field to conversations table  
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- Add archived_at timestamp for tracking when conversation was archived
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP;

-- Add starred_at timestamp for tracking when conversation was starred
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS starred_at TIMESTAMP;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_starred 
ON conversations (is_starred, company_id, last_message_at DESC) 
WHERE is_starred = TRUE;

CREATE INDEX IF NOT EXISTS idx_conversations_archived 
ON conversations (is_archived, company_id, archived_at DESC) 
WHERE is_archived = TRUE;

-- Create composite index for filtering active (non-archived) conversations
CREATE INDEX IF NOT EXISTS idx_conversations_active_non_archived 
ON conversations (channel_id, is_archived, last_message_at DESC) 
WHERE is_archived = FALSE;

-- Create composite index for starred conversations by channel
CREATE INDEX IF NOT EXISTS idx_conversations_channel_starred 
ON conversations (channel_id, is_starred, last_message_at DESC) 
WHERE is_starred = TRUE;
