-- User contact pins: per-user pinned contacts (max 7 per user)
CREATE TABLE IF NOT EXISTS user_contact_pins (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_user_contact_pins_user_id ON user_contact_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_user_contact_pins_contact_id ON user_contact_pins(contact_id);
