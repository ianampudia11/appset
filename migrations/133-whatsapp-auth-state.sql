-- Store WhatsApp (Baileys) auth state in PostgreSQL per connection:
-- creds and signal keys (session, sender-key, etc.) for usePostgresAuthState.

CREATE TABLE IF NOT EXISTS whatsapp_auth_state (
  id SERIAL PRIMARY KEY,
  connection_id INTEGER NOT NULL REFERENCES channel_connections(id) ON DELETE CASCADE,
  key_type TEXT NOT NULL,
  key_id TEXT NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_whatsapp_auth_state_lookup ON whatsapp_auth_state(connection_id, key_type, key_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_auth_state_connection ON whatsapp_auth_state(connection_id);
