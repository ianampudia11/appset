-- Migration: Set default response config for existing webhook triggers with empty bodyTemplate
-- Description: Backfill response_config with full default for existing records

UPDATE webhook_triggers
SET response_config = jsonb_build_object(
  'statusCode', COALESCE((response_config->>'statusCode')::int, 200),
  'bodyTemplate', '{"success": true, "requestId": "{{webhook.requestId}}", "message": "Webhook received"}',
  'headers', COALESCE(response_config->'headers', '{}'::jsonb) || '{"Content-Type":"application/json"}'::jsonb,
  'mode', COALESCE(response_config->>'mode', 'async'),
  'timeout', COALESCE((response_config->>'timeout')::int, 30000)
)
WHERE response_config->>'bodyTemplate' IS NULL
   OR response_config->>'bodyTemplate' = '';
