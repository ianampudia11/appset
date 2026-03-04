-- Migration: Set Default Proxy Test Status
-- Description: Set proxy_test_status default to 'untested' and backfill existing null values

-- Set default value for proxy_test_status and backfill existing rows
DO $$ 
BEGIN
    -- Check if the column exists and doesn't already have the default
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'channel_connections' AND column_name = 'proxy_test_status') THEN
        -- Backfill existing null values with 'untested'
        UPDATE channel_connections 
        SET proxy_test_status = 'untested' 
        WHERE proxy_test_status IS NULL;
        
        -- Set the default value for the column
        ALTER TABLE channel_connections 
        ALTER COLUMN proxy_test_status SET DEFAULT 'untested';
    END IF;
END $$;