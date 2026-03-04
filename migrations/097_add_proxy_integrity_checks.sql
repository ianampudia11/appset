-- Migration: Add Proxy Configuration Integrity Checks
-- Description: Add table-level CHECK constraints to enforce data integrity for proxy configuration

-- Add CHECK constraint to prevent enabled proxy with missing required fields
DO $$ 
BEGIN
    -- Add constraint if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'chk_proxy_enabled_requires_fields' 
                   AND table_name = 'channel_connections') THEN
        ALTER TABLE channel_connections 
        ADD CONSTRAINT chk_proxy_enabled_requires_fields 
        CHECK (
            (proxy_enabled = false) OR 
            (proxy_enabled = true AND proxy_type IS NOT NULL AND proxy_host IS NOT NULL AND proxy_port IS NOT NULL AND proxy_port >= 1 AND proxy_port <= 65535)
        );
    END IF;
END $$;