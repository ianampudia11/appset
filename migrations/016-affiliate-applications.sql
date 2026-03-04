-- Migration: Add Affiliate Applications Table
-- This migration creates the affiliate applications table for managing affiliate partner applications

DO $$
BEGIN
  RAISE NOTICE 'Creating affiliate applications table...';

  -- Create affiliate application status enum
  CREATE TYPE affiliate_application_status AS ENUM ('pending', 'approved', 'rejected', 'under_review');

  -- Affiliate applications table - stores affiliate applications before approval
  CREATE TABLE IF NOT EXISTS affiliate_applications (
    id SERIAL PRIMARY KEY,
    
    -- Personal information
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    
    -- Business information
    company TEXT,
    website TEXT,
    country TEXT NOT NULL,
    
    -- Marketing information
    marketing_channels TEXT[] NOT NULL, -- Array of marketing channels
    expected_monthly_referrals TEXT NOT NULL,
    experience TEXT NOT NULL,
    motivation TEXT NOT NULL,
    
    -- Application status and processing
    status affiliate_application_status NOT NULL DEFAULT 'pending',
    agree_to_terms BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Review information
    reviewed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP,
    review_notes TEXT,
    rejection_reason TEXT,
    
    -- Timestamps
    submitted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Create indexes for better performance
  CREATE INDEX IF NOT EXISTS idx_affiliate_applications_email ON affiliate_applications(email);
  CREATE INDEX IF NOT EXISTS idx_affiliate_applications_status ON affiliate_applications(status);
  CREATE INDEX IF NOT EXISTS idx_affiliate_applications_submitted_at ON affiliate_applications(submitted_at);

  RAISE NOTICE 'Affiliate applications table created successfully';

EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Affiliate applications table already exists, skipping...';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating affiliate applications table: %', SQLERRM;
END $$;
