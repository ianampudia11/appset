-- Migration: Fix Multi-Channel Trigger Support
-- Description: Safely updates existing flows to support multi-channel triggers with proper error handling

-- First, let's check if we have any flows with nodes that are not arrays or are null
-- This prevents the jsonb_array_length error

-- Update existing trigger nodes to include channelTypes array for backward compatibility
-- This ensures existing WhatsApp flows continue to work
-- Only update flows where nodes is a proper array with at least one element
UPDATE flows
SET nodes = jsonb_set(
  nodes,
  '{0,data,channelTypes}',
  '["whatsapp_unofficial"]'::jsonb
)
WHERE nodes IS NOT NULL
  AND jsonb_typeof(nodes) = 'array'
  AND nodes->0 IS NOT NULL
  AND nodes->0->>'type' IN ('trigger', 'triggerNode')
  AND (nodes->0->'data'->>'channelTypes' IS NULL OR nodes->0->'data'->>'channelTypes' = 'null');

-- Update any flows that have hardcoded 'whatsapp' channel references
UPDATE flows
SET nodes = jsonb_set(
  nodes,
  '{0,data,channelTypes}',
  CASE
    WHEN nodes->0->'data'->>'channel' = 'WhatsApp' THEN '["whatsapp_unofficial"]'::jsonb
    WHEN nodes->0->'data'->>'channel' = 'WhatsApp Official' THEN '["whatsapp_official"]'::jsonb
    WHEN nodes->0->'data'->>'channel' = 'Messenger' THEN '["messenger"]'::jsonb
    WHEN nodes->0->'data'->>'channel' = 'Instagram' THEN '["instagram"]'::jsonb
    WHEN nodes->0->'data'->>'channel' = 'Email' THEN '["email"]'::jsonb
    WHEN nodes->0->'data'->>'channel' = 'Telegram' THEN '["telegram"]'::jsonb
    ELSE '["whatsapp_unofficial"]'::jsonb
  END
)
WHERE nodes IS NOT NULL
  AND jsonb_typeof(nodes) = 'array'
  AND nodes->0 IS NOT NULL
  AND nodes->0->>'type' IN ('trigger', 'triggerNode')
  AND nodes->0->'data'->>'channel' IS NOT NULL;

-- Remove deprecated 'channel' field from trigger nodes
UPDATE flows
SET nodes = jsonb_set(
  nodes,
  '{0,data}',
  (nodes->0->'data') - 'channel'
)
WHERE nodes IS NOT NULL
  AND jsonb_typeof(nodes) = 'array'
  AND nodes->0 IS NOT NULL
  AND nodes->0->>'type' IN ('trigger', 'triggerNode')
  AND nodes->0->'data'->>'channel' IS NOT NULL;

-- Update trigger node labels to be channel-agnostic
UPDATE flows
SET nodes = jsonb_set(
  nodes,
  '{0,data,label}',
  '"Message Received"'::jsonb
)
WHERE nodes IS NOT NULL
  AND jsonb_typeof(nodes) = 'array'
  AND nodes->0 IS NOT NULL
  AND nodes->0->>'type' IN ('trigger', 'triggerNode')
  AND (
    nodes->0->'data'->>'label' = 'WhatsApp Message Trigger' OR
    nodes->0->'data'->>'label' = 'Message Trigger' OR
    nodes->0->'data'->>'label' IS NULL
  );

-- Add default session persistence settings to existing trigger nodes
UPDATE flows
SET nodes = jsonb_set(
  jsonb_set(
    jsonb_set(
      nodes,
      '{0,data,enableSessionPersistence}',
      'true'::jsonb
    ),
    '{0,data,sessionTimeout}',
    '30'::jsonb
  ),
  '{0,data,sessionTimeoutUnit}',
  '"minutes"'::jsonb
)
WHERE nodes IS NOT NULL
  AND jsonb_typeof(nodes) = 'array'
  AND nodes->0 IS NOT NULL
  AND nodes->0->>'type' IN ('trigger', 'triggerNode')
  AND nodes->0->'data'->>'enableSessionPersistence' IS NULL;

-- Create indexes for better performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_flow_assignments_channel_active 
ON flow_assignments(channel_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_channel_connections_type_status 
ON channel_connections(channel_type, status) 
WHERE status = 'active';

-- Add comment to document the migration
COMMENT ON TABLE flows IS 'Enhanced with multi-channel trigger support. Trigger nodes now support channelTypes array for cross-channel compatibility.';

-- Verify migration success with safe counting
DO $$
DECLARE
    updated_count INTEGER;
    total_flows INTEGER;
    trigger_flows INTEGER;
BEGIN
    -- Count total flows
    SELECT COUNT(*) INTO total_flows FROM flows;

    -- Count flows with trigger nodes (avoid jsonb_array_length)
    SELECT COUNT(*) INTO trigger_flows
    FROM flows
    WHERE nodes IS NOT NULL
      AND jsonb_typeof(nodes) = 'array'
      AND nodes->0 IS NOT NULL
      AND nodes->0->>'type' IN ('trigger', 'triggerNode');

    -- Count updated flows with channelTypes (avoid jsonb_array_length)
    SELECT COUNT(*) INTO updated_count
    FROM flows
    WHERE nodes IS NOT NULL
      AND jsonb_typeof(nodes) = 'array'
      AND nodes->0 IS NOT NULL
      AND nodes->0->>'type' IN ('trigger', 'triggerNode')
      AND nodes->0->'data'->>'channelTypes' IS NOT NULL;

    RAISE NOTICE 'Migration completed successfully:';
    RAISE NOTICE '  - Total flows: %', total_flows;
    RAISE NOTICE '  - Flows with trigger nodes: %', trigger_flows;
    RAISE NOTICE '  - Updated trigger nodes with multi-channel support: %', updated_count;
END $$;
