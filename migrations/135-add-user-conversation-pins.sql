-- User conversation pins: per-user pinned conversations (max 7 per user)
CREATE TABLE IF NOT EXISTS user_conversation_pins (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_user_conversation_pins_user_id ON user_conversation_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_user_conversation_pins_conversation_id ON user_conversation_pins(conversation_id);
