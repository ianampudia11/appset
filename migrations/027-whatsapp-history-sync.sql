-- Migration: Add WhatsApp History Sync Support
-- Description: Add fields to support WhatsApp message history synchronization

-- Add history sync settings to channel connections
ALTER TABLE channel_connections 
ADD COLUMN history_sync_enabled BOOLEAN DEFAULT false,
ADD COLUMN history_sync_status TEXT DEFAULT 'pending' CHECK (history_sync_status IN ('pending', 'syncing', 'completed', 'failed', 'disabled')),
ADD COLUMN history_sync_progress INTEGER DEFAULT 0,
ADD COLUMN history_sync_total INTEGER DEFAULT 0,
ADD COLUMN last_history_sync_at TIMESTAMP,
ADD COLUMN history_sync_error TEXT;

-- Create index for history sync queries
CREATE INDEX idx_channel_connections_history_sync ON channel_connections(history_sync_enabled, history_sync_status);

-- Add history sync metadata to messages table
ALTER TABLE messages 
ADD COLUMN is_history_sync BOOLEAN DEFAULT false,
ADD COLUMN history_sync_batch_id TEXT;

-- Create index for history sync messages
CREATE INDEX idx_messages_history_sync ON messages(is_history_sync, history_sync_batch_id);

-- Add history sync metadata to conversations table  
ALTER TABLE conversations
ADD COLUMN is_history_sync BOOLEAN DEFAULT false,
ADD COLUMN history_sync_batch_id TEXT;

-- Create index for history sync conversations
CREATE INDEX idx_conversations_history_sync ON conversations(is_history_sync, history_sync_batch_id);

-- Add history sync metadata to contacts table
ALTER TABLE contacts
ADD COLUMN is_history_sync BOOLEAN DEFAULT false,
ADD COLUMN history_sync_batch_id TEXT;

-- Create index for history sync contacts
CREATE INDEX idx_contacts_history_sync ON contacts(is_history_sync, history_sync_batch_id);

-- Create table to track history sync batches
CREATE TABLE history_sync_batches (
    id SERIAL PRIMARY KEY,
    connection_id INTEGER NOT NULL REFERENCES channel_connections(id) ON DELETE CASCADE,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    batch_id TEXT NOT NULL UNIQUE,
    sync_type TEXT NOT NULL CHECK (sync_type IN ('initial', 'manual', 'incremental')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    total_chats INTEGER DEFAULT 0,
    processed_chats INTEGER DEFAULT 0,
    total_messages INTEGER DEFAULT 0,
    processed_messages INTEGER DEFAULT 0,
    total_contacts INTEGER DEFAULT 0,
    processed_contacts INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for history sync batches
CREATE INDEX idx_history_sync_batches_connection ON history_sync_batches(connection_id);
CREATE INDEX idx_history_sync_batches_company ON history_sync_batches(company_id);
CREATE INDEX idx_history_sync_batches_status ON history_sync_batches(status);
CREATE INDEX idx_history_sync_batches_batch_id ON history_sync_batches(batch_id);

-- Update existing WhatsApp connections to have history sync disabled by default
UPDATE channel_connections 
SET history_sync_enabled = false, 
    history_sync_status = 'disabled'
WHERE channel_type IN ('whatsapp_unofficial', 'whatsapp');

-- Add comment for documentation
COMMENT ON COLUMN channel_connections.history_sync_enabled IS 'Whether history sync is enabled for this WhatsApp connection';
COMMENT ON COLUMN channel_connections.history_sync_status IS 'Current status of history sync: pending, syncing, completed, failed, disabled';
COMMENT ON COLUMN channel_connections.history_sync_progress IS 'Number of items processed during history sync';
COMMENT ON COLUMN channel_connections.history_sync_total IS 'Total number of items to process during history sync';
COMMENT ON COLUMN channel_connections.last_history_sync_at IS 'Timestamp of last successful history sync';
COMMENT ON COLUMN channel_connections.history_sync_error IS 'Error message if history sync failed';

COMMENT ON TABLE history_sync_batches IS 'Tracks WhatsApp history sync operations and their progress';
COMMENT ON COLUMN history_sync_batches.batch_id IS 'Unique identifier for the sync batch';
COMMENT ON COLUMN history_sync_batches.sync_type IS 'Type of sync: initial (first time), manual (user triggered), incremental (automatic)';
