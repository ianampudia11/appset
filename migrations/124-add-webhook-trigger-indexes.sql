-- Composite index for webhook_triggers lookup by flow_id and node_id (used by sync and getWebhookTriggerByFlowAndNode)
CREATE INDEX IF NOT EXISTS idx_webhook_triggers_flow_node
ON webhook_triggers(flow_id, node_id);
