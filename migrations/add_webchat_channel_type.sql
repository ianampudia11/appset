-- Add indexes for webchat performance

-- Channel connections by type
CREATE INDEX IF NOT EXISTS idx_channel_connections_webchat 
ON channel_connections(channel_type) 
WHERE channel_type = 'webchat';

-- Conversations by channel_type
CREATE INDEX IF NOT EXISTS idx_conversations_webchat 
ON conversations(channel_type) 
WHERE channel_type = 'webchat';

-- Contacts by identifier for webchat visitors
CREATE INDEX IF NOT EXISTS idx_contacts_webchat_identifier 
ON contacts(identifier, identifier_type) 
WHERE identifier_type = 'webchat';
