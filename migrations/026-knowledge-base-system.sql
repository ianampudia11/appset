-- Migration: Knowledge Base System with RAG Support (No Vector Extension)
-- Description: Add support for document upload, processing, and vector-based retrieval without pgvector dependency
-- Date: 2025-01-04

-- Note: Vector extension is optional and can be added later for better performance
-- For now, we'll store embeddings as JSON text which works but is less efficient

-- Skip this migration if tables already exist (from previous failed migration)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'knowledge_base_documents') THEN
        RAISE NOTICE 'Knowledge base tables already exist, skipping migration';
        RETURN;
    END IF;
END $$;

-- Knowledge Base Documents table
CREATE TABLE IF NOT EXISTS knowledge_base_documents (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  node_id TEXT, -- Optional: Associate with specific AI Assistant node
  
  -- Document metadata
  filename TEXT NOT NULL,
  original_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  
  -- Processing status
  status TEXT NOT NULL DEFAULT 'uploading' CHECK (status IN ('uploading', 'processing', 'completed', 'failed')),
  
  -- Storage information
  file_path TEXT NOT NULL,
  file_url TEXT,
  
  -- Content processing
  extracted_text TEXT,
  chunk_count INTEGER DEFAULT 0,
  embedding_model TEXT DEFAULT 'text-embedding-3-small',
  
  -- Metadata
  processing_error TEXT,
  processing_duration_ms INTEGER,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Knowledge Base Chunks table
CREATE TABLE IF NOT EXISTS knowledge_base_chunks (
  id SERIAL PRIMARY KEY,
  document_id INTEGER NOT NULL REFERENCES knowledge_base_documents(id) ON DELETE CASCADE,
  
  -- Chunk content
  content TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  token_count INTEGER,
  
  -- Vector embedding (stored as JSON text for now, can be migrated to vector type later)
  embedding TEXT, -- JSON array representation
  
  -- Chunk metadata
  start_position INTEGER,
  end_position INTEGER,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Knowledge Base Configurations table
CREATE TABLE IF NOT EXISTS knowledge_base_configs (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL, -- AI Assistant node ID
  flow_id INTEGER REFERENCES flows(id) ON DELETE CASCADE,
  
  -- RAG Configuration
  enabled BOOLEAN DEFAULT TRUE,
  max_retrieved_chunks INTEGER DEFAULT 3,
  similarity_threshold REAL DEFAULT 0.7,
  embedding_model TEXT DEFAULT 'text-embedding-3-small',
  
  -- Context injection settings
  context_position TEXT DEFAULT 'before_system' CHECK (context_position IN ('before_system', 'after_system', 'before_user')),
  context_template TEXT DEFAULT 'Based on the following knowledge base information:

{context}

Please answer the user''s question using this information when relevant.',
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(company_id, node_id)
);

-- Knowledge Base Document-Node associations table
CREATE TABLE IF NOT EXISTS knowledge_base_document_nodes (
  id SERIAL PRIMARY KEY,
  document_id INTEGER NOT NULL REFERENCES knowledge_base_documents(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  flow_id INTEGER REFERENCES flows(id) ON DELETE CASCADE,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(document_id, node_id)
);

-- Knowledge Base Usage tracking table
CREATE TABLE IF NOT EXISTS knowledge_base_usage (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  document_id INTEGER REFERENCES knowledge_base_documents(id) ON DELETE SET NULL,
  
  -- Query information
  query_text TEXT NOT NULL,
  query_embedding TEXT, -- JSON array
  
  -- Retrieval results
  chunks_retrieved INTEGER DEFAULT 0,
  chunks_used INTEGER DEFAULT 0,
  similarity_scores JSONB DEFAULT '[]',
  
  -- Performance metrics
  retrieval_duration_ms INTEGER,
  embedding_duration_ms INTEGER,
  
  -- Context injection
  context_injected BOOLEAN DEFAULT FALSE,
  context_length INTEGER,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_knowledge_base_documents_company_id ON knowledge_base_documents(company_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_documents_node_id ON knowledge_base_documents(node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_documents_status ON knowledge_base_documents(status);

CREATE INDEX IF NOT EXISTS idx_knowledge_base_chunks_document_id ON knowledge_base_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_chunks_chunk_index ON knowledge_base_chunks(chunk_index);

CREATE INDEX IF NOT EXISTS idx_knowledge_base_configs_company_id ON knowledge_base_configs(company_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_configs_node_id ON knowledge_base_configs(node_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_base_document_nodes_document_id ON knowledge_base_document_nodes(document_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_document_nodes_company_id ON knowledge_base_document_nodes(company_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_document_nodes_node_id ON knowledge_base_document_nodes(node_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_base_usage_company_id ON knowledge_base_usage(company_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_usage_node_id ON knowledge_base_usage(node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_usage_created_at ON knowledge_base_usage(created_at);

-- Add comments for documentation
COMMENT ON TABLE knowledge_base_documents IS 'Stores uploaded documents for knowledge base processing';
COMMENT ON TABLE knowledge_base_chunks IS 'Stores processed text chunks with embeddings from documents';
COMMENT ON TABLE knowledge_base_configs IS 'Stores RAG configuration per AI Assistant node';
COMMENT ON TABLE knowledge_base_document_nodes IS 'Associates documents with specific AI Assistant nodes';
COMMENT ON TABLE knowledge_base_usage IS 'Tracks knowledge base usage and performance metrics';

COMMENT ON COLUMN knowledge_base_chunks.embedding IS 'Vector embedding stored as JSON text. Can be migrated to vector type when pgvector is available.';
COMMENT ON COLUMN knowledge_base_configs.similarity_threshold IS 'Minimum cosine similarity score (0-1) for chunk retrieval';
COMMENT ON COLUMN knowledge_base_configs.context_template IS 'Template for injecting context. Use {context} placeholder for retrieved chunks.';
