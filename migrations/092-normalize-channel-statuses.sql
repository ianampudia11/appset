-- Migration: Normalize legacy channel connection statuses
-- Convert 'connected' -> 'active' and 'disconnected' -> 'inactive'

DO $$
BEGIN
  RAISE NOTICE 'Starting migration 092-normalize-channel-statuses.sql';

  -- Update Instagram specific rows first (conservative)
  UPDATE channel_connections
  SET status = 'active'
  WHERE channel_type = 'instagram' AND status = 'connected';
  RAISE NOTICE 'Instagram: set % rows from connected->active', FOUND;

  UPDATE channel_connections
  SET status = 'inactive'
  WHERE channel_type = 'instagram' AND status = 'disconnected';
  RAISE NOTICE 'Instagram: set % rows from disconnected->inactive', FOUND;

  -- Update any remaining legacy statuses globally
  UPDATE channel_connections
  SET status = 'active'
  WHERE status = 'connected';
  RAISE NOTICE 'Global: set % rows from connected->active', FOUND;

  UPDATE channel_connections
  SET status = 'inactive'
  WHERE status = 'disconnected';
  RAISE NOTICE 'Global: set % rows from disconnected->inactive', FOUND;

  RAISE NOTICE 'Completed migration 092-normalize-channel-statuses.sql';
END
$$;
