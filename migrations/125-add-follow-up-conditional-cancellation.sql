-- Migration: Add conditional cancellation support to follow-up schedules
-- Adds fields to enable cancellation based on user response behavior

DO $$
BEGIN
  -- Add cancelOnUserResponse column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'follow_up_schedules' 
    AND column_name = 'cancel_on_user_response'
  ) THEN
    RAISE NOTICE 'Adding cancel_on_user_response column...';
    ALTER TABLE follow_up_schedules 
    ADD COLUMN cancel_on_user_response BOOLEAN DEFAULT false;
    COMMENT ON COLUMN follow_up_schedules.cancel_on_user_response IS 'Whether to cancel this follow-up if user responds';
  END IF;

  -- Add cancelCondition column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'follow_up_schedules' 
    AND column_name = 'cancel_condition'
  ) THEN
    RAISE NOTICE 'Adding cancel_condition column...';
    ALTER TABLE follow_up_schedules 
    ADD COLUMN cancel_condition TEXT DEFAULT 'none' 
    CHECK (cancel_condition IN ('any_message', 'specific_topic', 'none'));
    COMMENT ON COLUMN follow_up_schedules.cancel_condition IS 'Condition that triggers cancellation: any_message, specific_topic, or none';
  END IF;

  -- Add monitoringStartedAt column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'follow_up_schedules' 
    AND column_name = 'monitoring_started_at'
  ) THEN
    RAISE NOTICE 'Adding monitoring_started_at column...';
    ALTER TABLE follow_up_schedules 
    ADD COLUMN monitoring_started_at TIMESTAMP;
    COMMENT ON COLUMN follow_up_schedules.monitoring_started_at IS 'Timestamp when monitoring for user responses began';
  END IF;

  -- Add lastUserMessageAt column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'follow_up_schedules' 
    AND column_name = 'last_user_message_at'
  ) THEN
    RAISE NOTICE 'Adding last_user_message_at column...';
    ALTER TABLE follow_up_schedules 
    ADD COLUMN last_user_message_at TIMESTAMP;
    COMMENT ON COLUMN follow_up_schedules.last_user_message_at IS 'Timestamp of the last message from the user in this conversation';
  END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_cancel_on_user_response 
  ON follow_up_schedules(cancel_on_user_response) 
  WHERE cancel_on_user_response = true;

CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_monitoring 
  ON follow_up_schedules(conversation_id, status, cancel_on_user_response) 
  WHERE status = 'scheduled' AND cancel_on_user_response = true;

-- Migration completed
SELECT 'Conditional cancellation support added to follow-up schedules' AS result;
