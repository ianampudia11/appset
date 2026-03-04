-- 040-add-twilio-sms-and-calls.sql
-- Create calls table for upcoming Twilio Voice features

CREATE TABLE IF NOT EXISTS calls (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id),
  channel_id INTEGER REFERENCES channel_connections(id),
  contact_id INTEGER REFERENCES contacts(id),
  conversation_id INTEGER REFERENCES conversations(id),
  direction TEXT,
  status TEXT,
  "from" TEXT,
  "to" TEXT,
  duration_sec INTEGER,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  recording_url TEXT,
  recording_sid TEXT,
  twilio_call_sid TEXT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Note: channel_types is modeled in app code (zod enum); channel_connections.channel_type is TEXT
-- so no DB enum migration is needed for twilio_sms/twilio_voice.
