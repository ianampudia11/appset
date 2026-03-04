-- Cleanup failed migration record
-- This removes the failed migration record so the corrected migration can run

DELETE FROM migrations WHERE filename = 'add_messenger_indexes.sql';
