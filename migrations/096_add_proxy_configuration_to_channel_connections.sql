-- Migration: Add Proxy Configuration to Channel Connections
-- Description: Add proxy configuration support to enable company-specific proxy routing for Baileys WhatsApp connections

-- Add proxy configuration columns to channel_connections table using idempotent checks
DO $$ 
BEGIN
    -- Add proxy_enabled column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_enabled') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_enabled BOOLEAN DEFAULT false;
    END IF;

    -- Add proxy_type column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_type') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_type TEXT CHECK (proxy_type IN ('http', 'https', 'socks5'));
    END IF;

    -- Add proxy_host column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_host') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_host TEXT;
    END IF;

    -- Add proxy_port column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_port') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_port INTEGER;
    END IF;

    -- Add proxy_username column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_username') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_username TEXT;
    END IF;

    -- Add proxy_password column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_password') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_password TEXT;
    END IF;

    -- Add proxy_test_status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_test_status') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_test_status TEXT CHECK (proxy_test_status IN ('untested', 'working', 'failed'));
    END IF;

    -- Add proxy_last_tested column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'channel_connections' AND column_name = 'proxy_last_tested') THEN
        ALTER TABLE channel_connections 
        ADD COLUMN proxy_last_tested TIMESTAMP;
    END IF;
END $$;

-- Create index for efficient querying of proxy-enabled connections
CREATE INDEX IF NOT EXISTS idx_channel_connections_proxy ON channel_connections(proxy_enabled, proxy_test_status);

-- Add documentation comments for proxy configuration columns
COMMENT ON COLUMN channel_connections.proxy_enabled IS 'Whether proxy routing is enabled for this connection';
COMMENT ON COLUMN channel_connections.proxy_type IS 'Type of proxy protocol: http, https, or socks5';
COMMENT ON COLUMN channel_connections.proxy_host IS 'Proxy server hostname or IP address';
COMMENT ON COLUMN channel_connections.proxy_port IS 'Proxy server port number';
COMMENT ON COLUMN channel_connections.proxy_username IS 'Optional proxy authentication username';
COMMENT ON COLUMN channel_connections.proxy_password IS 'Optional proxy authentication password (should be encrypted)';
COMMENT ON COLUMN channel_connections.proxy_test_status IS 'Result of last proxy connectivity test: untested, working, or failed';
COMMENT ON COLUMN channel_connections.proxy_last_tested IS 'Timestamp when proxy connectivity was last tested';