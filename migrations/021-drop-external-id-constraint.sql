-- Migration: Drop External ID Constraint
-- Date: 2025-01-07
-- Description: Drop the idx_messages_conversation_external_id constraint that is preventing
--              legitimate duplicate messages from being saved

-- 🔧 DROP THE PROBLEMATIC CONSTRAINT
-- This constraint prevents users from sending identical messages multiple times
-- from WhatsApp mobile app because it creates a unique constraint on external_id

DROP INDEX IF EXISTS idx_messages_conversation_external_id;

-- 🔧 VERIFICATION
-- Verify the constraint has been removed
-- Run this query to check: 
-- SELECT indexname FROM pg_indexes WHERE tablename = 'messages' AND indexname = 'idx_messages_conversation_external_id';

-- 🔧 RESULT
-- Users can now send identical messages multiple times from WhatsApp mobile app
-- All messages will be preserved in the PowerChat inbox
-- Only PowerChat echo prevention remains (handled by in-memory tracking)
