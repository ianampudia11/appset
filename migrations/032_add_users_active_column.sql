-- Add active column to users table if it doesn't exist
-- This migration ensures the users table has the active column that's defined in the schema

DO $$ 
BEGIN
    -- Check if the active column exists in the users table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'active'
    ) THEN
        -- Add the active column with default value
        ALTER TABLE users ADD COLUMN active BOOLEAN DEFAULT TRUE;
        
        -- Update existing users to be active by default
        UPDATE users SET active = TRUE WHERE active IS NULL;
        
        -- Make the column NOT NULL after setting default values
        ALTER TABLE users ALTER COLUMN active SET NOT NULL;
        
        RAISE NOTICE 'Added active column to users table';
    ELSE
        RAISE NOTICE 'Active column already exists in users table';
    END IF;
END $$;

-- Add index for active users if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);

-- Add comment for documentation
COMMENT ON COLUMN users.active IS 'Whether the user account is active and can log in';
