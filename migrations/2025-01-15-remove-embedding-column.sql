-- Migration: Remove embedding column from knowledge_base_chunks
-- Date: 2025-01-15
-- Description: Remove PostgreSQL-based vector storage as we've migrated to Pinecone

-- Remove the embedding column from knowledge_base_chunks table
-- This column stored embeddings as JSON strings, which is no longer needed
-- as all vector operations are now handled by Pinecone
ALTER TABLE knowledge_base_chunks DROP COLUMN IF EXISTS embedding;

-- Log migration completion
SELECT 'Embedding column removed from knowledge_base_chunks - Pinecone migration complete' as status;

