-- Migration: Remove All Duplicate Message Constraints
-- Date: 2025-01-07
-- Description: Completely remove all duplicate message detection constraints
--              to allow legitimate duplicate messages from users

-- 🔧 DROP ALL DUPLICATE CONSTRAINTS
-- Remove all constraints that prevent legitimate duplicate messages

-- Drop content-based duplicate constraint
DROP INDEX IF EXISTS idx_messages_content_dedup;

-- Drop rapid duplicate constraint (10-second window)
DROP INDEX IF EXISTS idx_messages_rapid_dedup;

-- Drop media duplicate constraint
DROP INDEX IF EXISTS idx_messages_media_dedup;

-- Drop WhatsApp message ID constraint (system duplicates will be handled in application logic)
DROP INDEX IF EXISTS idx_messages_whatsapp_dedup;

-- Drop external ID constraint
DROP INDEX IF EXISTS idx_messages_conversation_external_id;

-- 🔧 RESULT: NO DATABASE-LEVEL DUPLICATE PREVENTION
-- All duplicate detection is now handled purely in application logic
-- Users can send identical messages multiple times and all will be preserved
-- PowerChat echo prevention is handled by in-memory tracking only

-- 🔧 VERIFICATION QUERY
-- Run this to verify ALL duplicate constraints have been removed:
-- SELECT indexname, indexdef FROM pg_indexes
-- WHERE tablename = 'messages' AND (indexname LIKE '%dedup%' OR indexname LIKE '%external_id%');
