-- Enhance TikTok token tracking: indexes for efficient querying of connections needing refresh
-- connectionData (JSONB) stores: lastHealthCheckAt, tokenRefreshedAt, healthCheckCount, nextTokenRefreshAt, tokenExpiresAt

-- Index for querying TikTok connections by status and token expiry (for batch refresh safety net)
CREATE INDEX IF NOT EXISTS idx_channel_connections_tiktok_status_expires
  ON channel_connections (channel_type, status)
  WHERE channel_type = 'tiktok';

-- Index for monitoring stale TikTok connections (last health check)
CREATE INDEX IF NOT EXISTS idx_channel_connections_tiktok_health
  ON channel_connections (channel_type)
  WHERE channel_type = 'tiktok';

-- Expression index for querying imminent TikTok token expirations (avoids full-table scan in batch refresh)
-- Supports: WHERE channel_type = 'tiktok' AND status IN ('active','connected') AND (connection_data->>'tokenExpiresAt')::bigint < threshold
CREATE INDEX IF NOT EXISTS idx_channel_connections_tiktok_token_expires_at
  ON channel_connections (((connection_data->>'tokenExpiresAt')::bigint))
  WHERE channel_type = 'tiktok' AND status IN ('active', 'connected');
