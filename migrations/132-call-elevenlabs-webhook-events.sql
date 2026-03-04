-- Store ElevenLabs post-call webhook events (transcription, audio, call_initiation_failure)
-- so we can display analysis in Call Details and match by conversation_id.

CREATE TABLE IF NOT EXISTS call_elevenlabs_webhook_events (
  id SERIAL PRIMARY KEY,
  call_log_id INTEGER REFERENCES calls(id) ON DELETE SET NULL,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  elevenlabs_conversation_id TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('post_call_transcription', 'post_call_audio', 'call_initiation_failure')),
  payload JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_call_el_webhook_call_log_id ON call_elevenlabs_webhook_events(call_log_id);
CREATE INDEX IF NOT EXISTS idx_call_el_webhook_conversation_id ON call_elevenlabs_webhook_events(elevenlabs_conversation_id);
CREATE INDEX IF NOT EXISTS idx_call_el_webhook_company_created ON call_elevenlabs_webhook_events(company_id, created_at DESC);
