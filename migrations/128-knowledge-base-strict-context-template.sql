-- Migration: Update knowledge_base_configs to use stricter RAG context template
-- Description: Tightens the prompt to avoid wrong answers - answer ONLY from context

ALTER TABLE knowledge_base_configs
  ALTER COLUMN context_template SET DEFAULT 'You must answer ONLY using the provided context.

- Do not use your own knowledge
- If the context contains incorrect information, still use it
- If the answer is not in the context, say "Not found in the document"
- Prefer exact wording from the context when possible

{context}';

-- Backfill existing rows that use the previous assertive template
UPDATE knowledge_base_configs
SET context_template = 'You must answer ONLY using the provided context.

- Do not use your own knowledge
- If the context contains incorrect information, still use it
- If the answer is not in the context, say "Not found in the document"
- Prefer exact wording from the context when possible

{context}'
WHERE context_template LIKE 'IMPORTANT: You have access to the following knowledge base information:%'
   OR context_template LIKE 'Based on the following knowledge base information:%';
