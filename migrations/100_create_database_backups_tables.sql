-- Create database-level backup tables
-- This migration creates the database schema for full PostgreSQL database backups
-- (separate from inbox backups which are company-level backups)

-- Drop tables if they exist (for clean migration)
DROP TABLE IF EXISTS database_backup_logs CASCADE;
DROP TABLE IF EXISTS database_backups CASCADE;

-- Drop enums if they exist
DROP TYPE IF EXISTS database_backup_status CASCADE;
DROP TYPE IF EXISTS database_backup_type CASCADE;
DROP TYPE IF EXISTS database_backup_format CASCADE;

-- Create database backup status enum
CREATE TYPE database_backup_status AS ENUM ('creating', 'completed', 'failed', 'uploading', 'uploaded');

-- Create database backup type enum
CREATE TYPE database_backup_type AS ENUM ('manual', 'scheduled');

-- Create database backup format enum
CREATE TYPE database_backup_format AS ENUM ('sql', 'custom');

-- Create database_backups table
CREATE TABLE database_backups (
    id TEXT PRIMARY KEY, -- UUID
    filename TEXT NOT NULL,
    type database_backup_type NOT NULL DEFAULT 'manual',
    description TEXT NOT NULL,
    size INTEGER NOT NULL DEFAULT 0, -- in bytes
    status database_backup_status NOT NULL DEFAULT 'creating',
    storage_locations JSONB NOT NULL DEFAULT '["local"]', -- array of storage locations
    checksum TEXT NOT NULL,
    error_message TEXT,
    -- Metadata
    database_size INTEGER DEFAULT 0,
    table_count INTEGER DEFAULT 0,
    row_count INTEGER DEFAULT 0,
    compression_ratio REAL,
    encryption_enabled BOOLEAN DEFAULT false,
    -- Version and compatibility metadata
    app_version TEXT,
    pg_version TEXT,
    instance_id TEXT,
    dump_format database_backup_format DEFAULT 'sql',
    schema_checksum TEXT,
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create database_backup_logs table
CREATE TABLE database_backup_logs (
    id TEXT PRIMARY KEY, -- UUID
    schedule_id TEXT NOT NULL, -- 'manual', 'restore', or schedule UUID
    backup_id TEXT REFERENCES database_backups(id) ON DELETE CASCADE,
    status TEXT NOT NULL, -- 'success' | 'failed'
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_database_backups_status ON database_backups(status);
CREATE INDEX idx_database_backups_created_at ON database_backups(created_at);
CREATE INDEX idx_database_backups_type ON database_backups(type);
CREATE INDEX idx_database_backups_instance_id ON database_backups(instance_id);
CREATE INDEX idx_database_backups_pg_version ON database_backups(pg_version);

CREATE INDEX idx_database_backup_logs_backup_id ON database_backup_logs(backup_id);
CREATE INDEX idx_database_backup_logs_schedule_id ON database_backup_logs(schedule_id);
CREATE INDEX idx_database_backup_logs_status ON database_backup_logs(status);
CREATE INDEX idx_database_backup_logs_timestamp ON database_backup_logs(timestamp);

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_database_backups_updated_at
    BEFORE UPDATE ON database_backups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE database_backups IS 'Stores metadata and status for full PostgreSQL database backup operations';
COMMENT ON TABLE database_backup_logs IS 'Stores audit trail for database backup and restore operations';

COMMENT ON COLUMN database_backups.storage_locations IS 'JSON array of storage locations where backup is stored (e.g., ["local", "google_drive"])';
COMMENT ON COLUMN database_backups.checksum IS 'SHA-256 checksum for backup file integrity verification';
COMMENT ON COLUMN database_backups.database_size IS 'Total database size in bytes at time of backup';
COMMENT ON COLUMN database_backups.table_count IS 'Number of tables in the database';
COMMENT ON COLUMN database_backups.row_count IS 'Total number of rows across all tables';
COMMENT ON COLUMN database_backups.compression_ratio IS 'Compression ratio achieved (if applicable)';
COMMENT ON COLUMN database_backups.app_version IS 'PowerChat application version at time of backup';
COMMENT ON COLUMN database_backups.pg_version IS 'PostgreSQL version at time of backup';
COMMENT ON COLUMN database_backups.instance_id IS 'Unique identifier for the PowerChat instance';
COMMENT ON COLUMN database_backups.dump_format IS 'Format of the backup file: sql (plain text) or custom (pg_dump custom format)';
COMMENT ON COLUMN database_backups.schema_checksum IS 'Checksum of database schema for compatibility validation';

COMMENT ON COLUMN database_backup_logs.schedule_id IS 'Identifier for the schedule that triggered this backup, or "manual" for manual backups, or "restore" for restore operations';
COMMENT ON COLUMN database_backup_logs.metadata IS 'Additional metadata about the backup/restore operation in JSON format';

-- Migrate existing backup records from app_settings to database_backups table
DO $$
DECLARE
    backup_records_setting RECORD;
    backup_record JSONB;
BEGIN
    -- Get backup_records from app_settings
    SELECT * INTO backup_records_setting
    FROM app_settings
    WHERE key = 'backup_records';

    -- If backup_records exist, migrate them
    IF FOUND AND backup_records_setting.value IS NOT NULL THEN
        -- Iterate through each backup record in the JSON array
        FOR backup_record IN SELECT * FROM jsonb_array_elements(backup_records_setting.value)
        LOOP
            -- Insert into database_backups table if not already exists
            INSERT INTO database_backups (
                id,
                filename,
                type,
                description,
                size,
                status,
                storage_locations,
                checksum,
                error_message,
                database_size,
                table_count,
                row_count,
                compression_ratio,
                encryption_enabled,
                app_version,
                pg_version,
                instance_id,
                dump_format,
                schema_checksum,
                created_at,
                updated_at
            )
            VALUES (
                backup_record->>'id',
                backup_record->>'filename',
                COALESCE((backup_record->>'type')::database_backup_type, 'manual'),
                COALESCE(backup_record->>'description', ''),
                COALESCE((backup_record->>'size')::integer, 0),
                COALESCE((backup_record->>'status')::database_backup_status, 'completed'),
                COALESCE(backup_record->'storage_locations', '["local"]'::jsonb),
                COALESCE(backup_record->>'checksum', ''),
                backup_record->>'error_message',
                COALESCE((backup_record->'metadata'->>'database_size')::integer, 0),
                COALESCE((backup_record->'metadata'->>'table_count')::integer, 0),
                COALESCE((backup_record->'metadata'->>'row_count')::integer, 0),
                (backup_record->'metadata'->>'compression_ratio')::real,
                COALESCE((backup_record->'metadata'->>'encryption_enabled')::boolean, false),
                backup_record->'metadata'->>'app_version',
                backup_record->'metadata'->>'pg_version',
                backup_record->'metadata'->>'instance_id',
                CASE
                    WHEN backup_record->'metadata'->>'dump_format' = 'custom' THEN 'custom'::database_backup_format
                    ELSE 'sql'::database_backup_format
                END,
                backup_record->'metadata'->>'schema_checksum',
                COALESCE((backup_record->>'created_at')::timestamp, NOW()),
                NOW()
            )
            ON CONFLICT (id) DO NOTHING;
        END LOOP;

        RAISE NOTICE 'Migrated backup records from app_settings to database_backups table';
    ELSE
        RAISE NOTICE 'No backup records found in app_settings to migrate';
    END IF;
END $$;

