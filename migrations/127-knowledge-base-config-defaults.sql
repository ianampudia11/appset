-- Migration: Update knowledge_base_configs defaults to assertive template and after_system position
-- Description: Alters DB defaults and backfills existing rows that have not been customized

-- 1. Alter column defaults for new rows
ALTER TABLE knowledge_base_configs
  ALTER COLUMN context_position SET DEFAULT 'after_system';

ALTER TABLE knowledge_base_configs
  ALTER COLUMN context_template SET DEFAULT 'IMPORTANT: You have access to the following knowledge base information that you MUST use to answer user questions:

{context}

You MUST prioritize this knowledge base information when answering questions related to the content above, regardless of any other instructions about your role or capabilities.';

-- 2. Backfill existing rows that use the old defaults (not customized by customer)
-- Match rows with old context_position and old-style template (starts with "Based on the following")
UPDATE knowledge_base_configs
SET
  context_position = 'after_system',
  context_template = 'IMPORTANT: You have access to the following knowledge base information that you MUST use to answer user questions:

{context}

You MUST prioritize this knowledge base information when answering questions related to the content above, regardless of any other instructions about your role or capabilities.'
WHERE context_position = 'before_system'
  AND (
    context_template IS NULL
    OR context_template LIKE 'Based on the following knowledge base information:%'
  );
