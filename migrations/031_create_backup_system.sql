-- Create backup system tables
-- This migration creates the database schema for the inbox backup and restore system

-- Clean up any partially created backup tables from previous failed migrations
DROP TABLE IF EXISTS backup_audit_logs CASCADE;
DROP TABLE IF EXISTS inbox_restores CASCADE;
DROP TABLE IF EXISTS inbox_backups CASCADE;
DROP TABLE IF EXISTS backup_schedules CASCADE;

-- Drop enums if they exist
DROP TYPE IF EXISTS restore_status CASCADE;
DROP TYPE IF EXISTS backup_type CASCADE;
DROP TYPE IF EXISTS backup_status CASCADE;

-- Create backup status enum
CREATE TYPE backup_status AS ENUM ('pending', 'in_progress', 'completed', 'failed', 'cancelled');

-- Create backup type enum
CREATE TYPE backup_type AS ENUM ('manual', 'scheduled');

-- Create restore status enum
CREATE TYPE restore_status AS ENUM ('pending', 'in_progress', 'completed', 'failed', 'cancelled');

-- Create inbox_backups table
CREATE TABLE inbox_backups (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_by_user_id INTEGER NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    description TEXT,
    type backup_type NOT NULL DEFAULT 'manual',
    status backup_status NOT NULL DEFAULT 'pending',
    file_path TEXT,
    file_name TEXT,
    file_size INTEGER, -- in bytes
    compressed_size INTEGER, -- in bytes
    checksum TEXT,
    metadata JSONB DEFAULT '{}', -- backup metadata like version, counts, etc.
    include_contacts BOOLEAN DEFAULT true,
    include_conversations BOOLEAN DEFAULT true,
    include_messages BOOLEAN DEFAULT true,
    date_range_start TIMESTAMP,
    date_range_end TIMESTAMP,
    total_contacts INTEGER DEFAULT 0,
    total_conversations INTEGER DEFAULT 0,
    total_messages INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    expires_at TIMESTAMP, -- for automatic cleanup
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create backup_schedules table
CREATE TABLE backup_schedules (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_by_user_id INTEGER NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    frequency TEXT NOT NULL, -- 'daily', 'weekly', 'monthly'
    cron_expression TEXT,
    retention_days INTEGER DEFAULT 30,
    include_contacts BOOLEAN DEFAULT true,
    include_conversations BOOLEAN DEFAULT true,
    include_messages BOOLEAN DEFAULT true,
    last_run_at TIMESTAMP,
    next_run_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create inbox_restores table
CREATE TABLE inbox_restores (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    backup_id INTEGER REFERENCES inbox_backups(id),
    restored_by_user_id INTEGER NOT NULL REFERENCES users(id),
    status restore_status NOT NULL DEFAULT 'pending',
    restore_type TEXT NOT NULL, -- 'full', 'selective'
    conflict_resolution TEXT DEFAULT 'merge', -- 'merge', 'overwrite', 'skip'
    date_range_start TIMESTAMP,
    date_range_end TIMESTAMP,
    restore_contacts BOOLEAN DEFAULT true,
    restore_conversations BOOLEAN DEFAULT true,
    restore_messages BOOLEAN DEFAULT true,
    total_items_to_restore INTEGER DEFAULT 0,
    items_restored INTEGER DEFAULT 0,
    items_skipped INTEGER DEFAULT 0,
    items_errored INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create backup_audit_logs table
CREATE TABLE backup_audit_logs (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id),
    action TEXT NOT NULL, -- 'backup_created', 'backup_downloaded', 'restore_started', etc.
    entity_type TEXT NOT NULL, -- 'backup', 'restore', 'schedule'
    entity_id INTEGER,
    details JSONB DEFAULT '{}',
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_inbox_backups_company_id ON inbox_backups(company_id);
CREATE INDEX idx_inbox_backups_status ON inbox_backups(status);
CREATE INDEX idx_inbox_backups_created_at ON inbox_backups(created_at);
CREATE INDEX idx_inbox_backups_type ON inbox_backups(type);

CREATE INDEX idx_backup_schedules_company_id ON backup_schedules(company_id);
CREATE INDEX idx_backup_schedules_is_active ON backup_schedules(is_active);
CREATE INDEX idx_backup_schedules_next_run_at ON backup_schedules(next_run_at);

CREATE INDEX idx_inbox_restores_company_id ON inbox_restores(company_id);
CREATE INDEX idx_inbox_restores_backup_id ON inbox_restores(backup_id);
CREATE INDEX idx_inbox_restores_status ON inbox_restores(status);
CREATE INDEX idx_inbox_restores_created_at ON inbox_restores(created_at);

CREATE INDEX idx_backup_audit_logs_company_id ON backup_audit_logs(company_id);
CREATE INDEX idx_backup_audit_logs_user_id ON backup_audit_logs(user_id);
CREATE INDEX idx_backup_audit_logs_action ON backup_audit_logs(action);
CREATE INDEX idx_backup_audit_logs_created_at ON backup_audit_logs(created_at);

-- Create triggers to update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to update updated_at timestamps
CREATE TRIGGER update_inbox_backups_updated_at
    BEFORE UPDATE ON inbox_backups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_backup_schedules_updated_at
    BEFORE UPDATE ON backup_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inbox_restores_updated_at
    BEFORE UPDATE ON inbox_restores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();



-- Add backup permissions to role_permissions table if it exists
-- This will be handled by the application code to ensure proper integration

-- Comments for documentation
COMMENT ON TABLE inbox_backups IS 'Stores metadata and status for inbox backup operations';
COMMENT ON TABLE backup_schedules IS 'Stores automated backup schedule configurations';
COMMENT ON TABLE inbox_restores IS 'Stores metadata and status for inbox restore operations';
COMMENT ON TABLE backup_audit_logs IS 'Stores audit trail for all backup and restore operations';

COMMENT ON COLUMN inbox_backups.metadata IS 'JSON metadata including backup version, item counts, and other details';
COMMENT ON COLUMN inbox_backups.file_size IS 'Original uncompressed backup file size in bytes';
COMMENT ON COLUMN inbox_backups.compressed_size IS 'Compressed backup file size in bytes';
COMMENT ON COLUMN inbox_backups.checksum IS 'SHA-256 checksum for backup file integrity verification';

COMMENT ON COLUMN backup_schedules.frequency IS 'Backup frequency: daily, weekly, or monthly';
COMMENT ON COLUMN backup_schedules.cron_expression IS 'Custom cron expression for advanced scheduling';
COMMENT ON COLUMN backup_schedules.retention_days IS 'Number of days to retain scheduled backups before automatic cleanup';

COMMENT ON COLUMN inbox_restores.conflict_resolution IS 'How to handle conflicts: merge, overwrite, or skip existing data';
COMMENT ON COLUMN inbox_restores.restore_type IS 'Type of restore: full (all data) or selective (filtered data)';

COMMENT ON COLUMN backup_audit_logs.action IS 'Action performed: backup_created, backup_downloaded, restore_started, etc.';
COMMENT ON COLUMN backup_audit_logs.entity_type IS 'Type of entity: backup, restore, or schedule';
COMMENT ON COLUMN backup_audit_logs.details IS 'Additional details about the action in JSON format';
