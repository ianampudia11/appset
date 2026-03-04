-- Migration: Add indexes for Messenger interface performance optimization
-- Created: 2024-08-24
-- Description: Adds database indexes to optimize Messenger conversation and message queries

-- Index for messages by conversation_id and created_at (for message pagination)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created 
ON messages (conversation_id, created_at DESC);

-- Index for messages by conversation_id and sent_at (for message ordering)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_sent 
ON messages (conversation_id, sent_at DESC, created_at DESC);

-- Index for conversations by channel_id and last_message_at (for conversation list)
CREATE INDEX IF NOT EXISTS idx_conversations_channel_last_message 
ON conversations (channel_id, last_message_at DESC);

-- Index for conversations by channel_id and company_id (for security filtering)
CREATE INDEX IF NOT EXISTS idx_conversations_channel_company 
ON conversations (channel_id, company_id);

-- Index for conversations by channel_id and unread_count (for unread filtering)
CREATE INDEX IF NOT EXISTS idx_conversations_channel_unread 
ON conversations (channel_id, unread_count) 
WHERE unread_count > 0;

-- Index for messages by external_id (for duplicate detection)
CREATE INDEX IF NOT EXISTS idx_messages_external_id 
ON messages (external_id) 
WHERE external_id IS NOT NULL;

-- Index for messages by direction and status (for message status queries)
CREATE INDEX IF NOT EXISTS idx_messages_direction_status 
ON messages (direction, status);

-- Index for conversations by contact_id (for contact-based queries)
CREATE INDEX IF NOT EXISTS idx_conversations_contact 
ON conversations (contact_id);

-- Index for conversations by channel_type and channel_id (for channel filtering)
CREATE INDEX IF NOT EXISTS idx_conversations_channel_type 
ON conversations (channel_type, channel_id);

-- Index for messages by conversation_id and direction (for outbound message queries)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_direction 
ON messages (conversation_id, direction);

-- Composite index for active conversations (open status)
CREATE INDEX IF NOT EXISTS idx_conversations_active 
ON conversations (channel_id, status, last_message_at DESC) 
WHERE status = 'open';

-- Index for message search by content (for future search functionality)
CREATE INDEX IF NOT EXISTS idx_messages_content_search 
ON messages USING gin(to_tsvector('english', content)) 
WHERE content IS NOT NULL AND content != '';

-- Index for conversations by company_id and channel_type (for multi-tenant queries)
CREATE INDEX IF NOT EXISTS idx_conversations_company_channel_type 
ON conversations (company_id, channel_type);

-- Update table statistics for better query planning
ANALYZE conversations;
ANALYZE messages;
