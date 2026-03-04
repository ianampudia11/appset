-- 120-check-twilio-voice-sdk-credentials.sql
-- Check for Twilio Voice connections missing Voice SDK credentials
-- This is informational only since connectionData is JSONB and already supports the new fields

DO $$
DECLARE
  missing_count INTEGER;
  connection_record RECORD;
BEGIN
  -- Count active Twilio Voice connections missing Voice SDK credentials
  SELECT COUNT(*) INTO missing_count
  FROM channel_connections
  WHERE channel_type = 'twilio_voice'
    AND status = 'active'
    AND (
      connection_data->>'apiKey' IS NULL 
      OR connection_data->>'apiKey' = ''
      OR connection_data->>'apiSecret' IS NULL 
      OR connection_data->>'apiSecret' = ''
      OR connection_data->>'twimlAppSid' IS NULL 
      OR connection_data->>'twimlAppSid' = ''
    );
  
  IF missing_count > 0 THEN
    RAISE NOTICE 'Found % Twilio Voice connection(s) missing Voice SDK credentials', missing_count;
    RAISE NOTICE 'These connections will need to be reconfigured with API Key, API Secret, and TwiML App SID';
    RAISE NOTICE 'Direct calls will fail until Voice SDK credentials are added';
    RAISE NOTICE 'See docs/TWILIO_VOICE_SDK_SETUP.md for configuration instructions';
    
    -- Log details of affected connections (for admin reference)
    FOR connection_record IN
      SELECT id, company_id, account_name, status
      FROM channel_connections
      WHERE channel_type = 'twilio_voice'
        AND status = 'active'
        AND (
          connection_data->>'apiKey' IS NULL 
          OR connection_data->>'apiKey' = ''
          OR connection_data->>'apiSecret' IS NULL 
          OR connection_data->>'apiSecret' = ''
          OR connection_data->>'twimlAppSid' IS NULL 
          OR connection_data->>'twimlAppSid' = ''
        )
      LIMIT 10
    LOOP
      RAISE NOTICE '  - Connection ID: %, Company ID: %, Name: %', 
        connection_record.id, 
        connection_record.company_id, 
        connection_record.account_name;
    END LOOP;
    
    IF missing_count > 10 THEN
      RAISE NOTICE '  ... and % more connection(s)', missing_count - 10;
    END IF;
  ELSE
    RAISE NOTICE 'All active Twilio Voice connections have Voice SDK credentials configured';
  END IF;
END $$;
