-- Add media_file_path column to scheduled_messages table
-- This column will store local file paths for scheduled media messages

-- Add the media_file_path column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scheduled_messages' 
        AND column_name = 'media_file_path'
    ) THEN
        ALTER TABLE scheduled_messages 
        ADD COLUMN media_file_path TEXT;
        
        -- Add comment to the column
        COMMENT ON COLUMN scheduled_messages.media_file_path IS 'Local file path for scheduled media messages stored in uploads/scheduled-media/';
    END IF;
END $$;
