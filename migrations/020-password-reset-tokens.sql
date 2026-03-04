-- Migration: Add Password Reset Tokens Table
-- Description: Creates table for secure password reset functionality

-- Password Reset Tokens Table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT
);

-- Index for efficient token lookup and cleanup
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);

-- Comments for documentation
COMMENT ON TABLE password_reset_tokens IS 'Stores secure tokens for password reset functionality';
COMMENT ON COLUMN password_reset_tokens.token IS 'Hashed token for security - original token is sent via email';
COMMENT ON COLUMN password_reset_tokens.expires_at IS 'Token expiration time (typically 1 hour from creation)';
COMMENT ON COLUMN password_reset_tokens.used_at IS 'Timestamp when token was used (prevents reuse)';
COMMENT ON COLUMN password_reset_tokens.ip_address IS 'IP address of the request for security logging';
COMMENT ON COLUMN password_reset_tokens.user_agent IS 'User agent string for security logging';
