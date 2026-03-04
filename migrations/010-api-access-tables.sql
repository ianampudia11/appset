-- API Access Tables Migration
-- This migration creates tables for API key management, usage tracking, and rate limiting

-- Create api_keys table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'api_keys'
  ) THEN
    RAISE NOTICE 'Creating api_keys table...';
    
    CREATE TABLE api_keys (
      id SERIAL PRIMARY KEY,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL, -- User-friendly name for the API key
      key_hash TEXT NOT NULL UNIQUE, -- Hashed API key for security
      key_prefix TEXT NOT NULL, -- First 8 characters for display
      permissions JSONB DEFAULT '["messages:send", "channels:read"]', -- Array of permissions
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      last_used_at TIMESTAMP,
      expires_at TIMESTAMP, -- Optional expiration
      rate_limit_per_minute INTEGER DEFAULT 60, -- Rate limit per minute
      rate_limit_per_hour INTEGER DEFAULT 1000, -- Rate limit per hour
      rate_limit_per_day INTEGER DEFAULT 10000, -- Rate limit per day
      allowed_ips JSONB DEFAULT '[]', -- Array of allowed IP addresses
      webhook_url TEXT, -- Webhook URL for status updates
      metadata JSONB DEFAULT '{}', -- Additional metadata
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes for better performance
    CREATE INDEX idx_api_keys_company_id ON api_keys(company_id);
    CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
    CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);
    CREATE INDEX idx_api_keys_is_active ON api_keys(is_active);
    CREATE INDEX idx_api_keys_expires_at ON api_keys(expires_at);
    
    RAISE NOTICE 'api_keys table created successfully';
  ELSE
    RAISE NOTICE 'api_keys table already exists, skipping creation';
  END IF;
END$$;

-- Create api_usage table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'api_usage'
  ) THEN
    RAISE NOTICE 'Creating api_usage table...';
    
    CREATE TABLE api_usage (
      id SERIAL PRIMARY KEY,
      api_key_id INTEGER NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
      company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
      endpoint TEXT NOT NULL, -- API endpoint called
      method TEXT NOT NULL, -- HTTP method
      status_code INTEGER NOT NULL, -- Response status code
      request_size INTEGER, -- Request size in bytes
      response_size INTEGER, -- Response size in bytes
      duration INTEGER, -- Request duration in milliseconds
      ip_address TEXT, -- Client IP address
      user_agent TEXT, -- Client user agent
      request_id TEXT UNIQUE, -- Unique request identifier
      error_message TEXT, -- Error message if failed
      metadata JSONB DEFAULT '{}', -- Additional request metadata
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes for better performance
    CREATE INDEX idx_api_usage_api_key_id ON api_usage(api_key_id);
    CREATE INDEX idx_api_usage_company_id ON api_usage(company_id);
    CREATE INDEX idx_api_usage_created_at ON api_usage(created_at);
    CREATE INDEX idx_api_usage_endpoint ON api_usage(endpoint);
    CREATE INDEX idx_api_usage_status_code ON api_usage(status_code);
    CREATE INDEX idx_api_usage_request_id ON api_usage(request_id);
    
    RAISE NOTICE 'api_usage table created successfully';
  ELSE
    RAISE NOTICE 'api_usage table already exists, skipping creation';
  END IF;
END$$;

-- Create api_rate_limits table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'api_rate_limits'
  ) THEN
    RAISE NOTICE 'Creating api_rate_limits table...';
    
    CREATE TABLE api_rate_limits (
      id SERIAL PRIMARY KEY,
      api_key_id INTEGER NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
      window_type TEXT NOT NULL CHECK (window_type IN ('minute', 'hour', 'day')),
      window_start TIMESTAMP NOT NULL, -- Start of the time window
      request_count INTEGER NOT NULL DEFAULT 0, -- Number of requests in this window
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Create indexes for better performance
    CREATE INDEX idx_api_rate_limits_api_key_id ON api_rate_limits(api_key_id);
    CREATE INDEX idx_api_rate_limits_window_type ON api_rate_limits(window_type);
    CREATE INDEX idx_api_rate_limits_window_start ON api_rate_limits(window_start);
    CREATE UNIQUE INDEX idx_api_rate_limits_unique ON api_rate_limits(api_key_id, window_type, window_start);
    
    RAISE NOTICE 'api_rate_limits table created successfully';
  ELSE
    RAISE NOTICE 'api_rate_limits table already exists, skipping creation';
  END IF;
END$$;

-- Add comments for documentation
COMMENT ON TABLE api_keys IS 'API keys for programmatic access to messaging endpoints';
COMMENT ON COLUMN api_keys.company_id IS 'Reference to the company that owns this API key';
COMMENT ON COLUMN api_keys.user_id IS 'Reference to the user who created this API key';
COMMENT ON COLUMN api_keys.name IS 'User-friendly name for the API key';
COMMENT ON COLUMN api_keys.key_hash IS 'SHA-256 hash of the API key for secure storage';
COMMENT ON COLUMN api_keys.key_prefix IS 'First 8 characters of the API key for display purposes';
COMMENT ON COLUMN api_keys.permissions IS 'JSON array of permissions granted to this API key';
COMMENT ON COLUMN api_keys.is_active IS 'Whether this API key is currently active';
COMMENT ON COLUMN api_keys.last_used_at IS 'Timestamp of when this API key was last used';
COMMENT ON COLUMN api_keys.expires_at IS 'Optional expiration timestamp for the API key';
COMMENT ON COLUMN api_keys.rate_limit_per_minute IS 'Maximum requests per minute for this API key';
COMMENT ON COLUMN api_keys.rate_limit_per_hour IS 'Maximum requests per hour for this API key';
COMMENT ON COLUMN api_keys.rate_limit_per_day IS 'Maximum requests per day for this API key';
COMMENT ON COLUMN api_keys.allowed_ips IS 'JSON array of IP addresses allowed to use this API key';
COMMENT ON COLUMN api_keys.webhook_url IS 'Optional webhook URL for status updates';
COMMENT ON COLUMN api_keys.metadata IS 'Additional metadata for the API key';

COMMENT ON TABLE api_usage IS 'Usage tracking for API requests';
COMMENT ON COLUMN api_usage.api_key_id IS 'Reference to the API key used for this request';
COMMENT ON COLUMN api_usage.company_id IS 'Reference to the company that made this request';
COMMENT ON COLUMN api_usage.endpoint IS 'API endpoint that was called';
COMMENT ON COLUMN api_usage.method IS 'HTTP method used (GET, POST, etc.)';
COMMENT ON COLUMN api_usage.status_code IS 'HTTP response status code';
COMMENT ON COLUMN api_usage.request_size IS 'Size of the request in bytes';
COMMENT ON COLUMN api_usage.response_size IS 'Size of the response in bytes';
COMMENT ON COLUMN api_usage.duration IS 'Request processing duration in milliseconds';
COMMENT ON COLUMN api_usage.ip_address IS 'IP address of the client making the request';
COMMENT ON COLUMN api_usage.user_agent IS 'User agent string of the client';
COMMENT ON COLUMN api_usage.request_id IS 'Unique identifier for this request';
COMMENT ON COLUMN api_usage.error_message IS 'Error message if the request failed';
COMMENT ON COLUMN api_usage.metadata IS 'Additional request metadata';

COMMENT ON TABLE api_rate_limits IS 'Rate limiting tracking for API keys';
COMMENT ON COLUMN api_rate_limits.api_key_id IS 'Reference to the API key being rate limited';
COMMENT ON COLUMN api_rate_limits.window_type IS 'Type of time window (minute, hour, day)';
COMMENT ON COLUMN api_rate_limits.window_start IS 'Start timestamp of the time window';
COMMENT ON COLUMN api_rate_limits.request_count IS 'Number of requests made in this time window';

-- Rollback instructions (for manual rollback if needed)
-- To rollback this migration, run:
-- DROP TABLE IF EXISTS api_rate_limits CASCADE;
-- DROP TABLE IF EXISTS api_usage CASCADE;
-- DROP TABLE IF EXISTS api_keys CASCADE;
