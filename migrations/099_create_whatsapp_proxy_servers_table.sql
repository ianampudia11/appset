-- Migration: Create WhatsApp Proxy Servers Table
-- Description: Enable multiple proxy server configurations per company for Baileys WhatsApp connections

-- Step 1: Create whatsapp_proxy_servers Table
CREATE TABLE IF NOT EXISTS whatsapp_proxy_servers (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  type TEXT NOT NULL CHECK (type IN ('http', 'https', 'socks5')),
  host TEXT NOT NULL,
  port INTEGER NOT NULL CHECK (port > 0 AND port <= 65535),
  username TEXT,
  password TEXT,
  test_status TEXT DEFAULT 'untested' CHECK (test_status IN ('untested', 'working', 'failed')),
  last_tested TIMESTAMP,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Step 2: Create Indexes
CREATE INDEX IF NOT EXISTS idx_whatsapp_proxy_servers_company ON whatsapp_proxy_servers(company_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_proxy_servers_enabled ON whatsapp_proxy_servers(company_id, enabled);

-- Step 3: Add proxyServerId to channel_connections
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'channel_connections' AND column_name = 'proxy_server_id') THEN
    ALTER TABLE channel_connections 
    ADD COLUMN proxy_server_id INTEGER REFERENCES whatsapp_proxy_servers(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Step 4: Create Index on Foreign Key
CREATE INDEX IF NOT EXISTS idx_channel_connections_proxy_server ON channel_connections(proxy_server_id);

-- Step 5: Migrate Existing Company-Wide Proxy to New Table
INSERT INTO whatsapp_proxy_servers (company_id, name, enabled, type, host, port, username, password, test_status, last_tested)
SELECT 
  company_id,
  'Default Proxy' as name,
  (value->>'enabled')::boolean as enabled,
  value->>'type' as type,
  value->>'host' as host,
  (value->>'port')::integer as port,
  value->>'username' as username,
  value->>'password' as password,
  COALESCE(value->>'testStatus', 'untested') as test_status,
  (value->>'lastTested')::timestamp as last_tested
FROM company_settings
WHERE key = 'whatsapp_proxy_config'
  AND value->>'host' IS NOT NULL
  AND value->>'port' IS NOT NULL
ON CONFLICT DO NOTHING;

-- Step 6: Update Existing Connections to Use Migrated Proxy
UPDATE channel_connections cc
SET proxy_server_id = wps.id
FROM whatsapp_proxy_servers wps
WHERE cc.company_id = wps.company_id
  AND cc.channel_type = 'whatsapp_unofficial'
  AND cc.proxy_server_id IS NULL
  AND wps.name = 'Default Proxy';

-- Step 7: Add Column Comments
COMMENT ON TABLE whatsapp_proxy_servers IS 'Stores multiple proxy server configurations for WhatsApp Baileys connections';
COMMENT ON COLUMN whatsapp_proxy_servers.name IS 'User-friendly name to identify the proxy (e.g., US Proxy, EU Proxy)';
COMMENT ON COLUMN whatsapp_proxy_servers.enabled IS 'Whether this proxy is currently active and available for use';
COMMENT ON COLUMN channel_connections.proxy_server_id IS 'Reference to the selected proxy server for this connection';
