-- Migration: Comprehensive Affiliate Management System
-- This migration creates all necessary tables for enterprise-grade affiliate management

DO $$
BEGIN
  RAISE NOTICE 'Starting affiliate management system migration...';

  -- Create affiliate status enum
  CREATE TYPE affiliate_status AS ENUM ('pending', 'active', 'suspended', 'rejected');
  
  -- Create commission type enum
  CREATE TYPE commission_type AS ENUM ('percentage', 'fixed', 'tiered');
  
  -- Create payout status enum
  CREATE TYPE payout_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'cancelled');
  
  -- Create referral status enum
  CREATE TYPE referral_status AS ENUM ('pending', 'converted', 'expired', 'cancelled');

  -- Affiliates table - stores affiliate partner information
  CREATE TABLE IF NOT EXISTS affiliates (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    
    -- Basic affiliate information
    affiliate_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    website TEXT,
    
    -- Status and approval
    status affiliate_status NOT NULL DEFAULT 'pending',
    approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    
    -- Commission settings
    default_commission_rate DECIMAL(5,2) DEFAULT 0.00,
    commission_type commission_type DEFAULT 'percentage',
    
    -- Contact and business information
    business_name TEXT,
    tax_id TEXT,
    address JSONB, -- {street, city, state, country, postal_code}
    
    -- Payment information
    payment_details JSONB, -- {method, account_info, preferences}
    
    -- Performance tracking
    total_referrals INTEGER DEFAULT 0,
    successful_referrals INTEGER DEFAULT 0,
    total_earnings DECIMAL(12,2) DEFAULT 0.00,
    pending_earnings DECIMAL(12,2) DEFAULT 0.00,
    paid_earnings DECIMAL(12,2) DEFAULT 0.00,
    
    -- Metadata and settings
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Commission structures table - flexible commission rules
  CREATE TABLE IF NOT EXISTS affiliate_commission_structures (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
    plan_id INTEGER REFERENCES plans(id) ON DELETE CASCADE,
    
    -- Commission configuration
    name TEXT NOT NULL,
    commission_type commission_type NOT NULL DEFAULT 'percentage',
    commission_value DECIMAL(10,2) NOT NULL,
    
    -- Tiered commission settings (for tiered type)
    tier_rules JSONB, -- [{min_referrals: 0, max_referrals: 10, rate: 5.0}, ...]
    
    -- Conditions and limits
    minimum_payout DECIMAL(10,2) DEFAULT 0.00,
    maximum_payout DECIMAL(10,2),
    recurring_commission BOOLEAN DEFAULT FALSE,
    recurring_months INTEGER DEFAULT 0,
    
    -- Validity period
    valid_from TIMESTAMP DEFAULT NOW(),
    valid_until TIMESTAMP,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Referrals table - tracks all referral activities
  CREATE TABLE IF NOT EXISTS affiliate_referrals (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
    
    -- Referral tracking
    referral_code TEXT NOT NULL,
    referred_company_id INTEGER REFERENCES companies(id) ON DELETE SET NULL,
    referred_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    referred_email TEXT,
    
    -- Conversion tracking
    status referral_status NOT NULL DEFAULT 'pending',
    converted_at TIMESTAMP,
    conversion_value DECIMAL(12,2) DEFAULT 0.00,
    
    -- Commission calculation
    commission_structure_id INTEGER REFERENCES affiliate_commission_structures(id) ON DELETE SET NULL,
    commission_amount DECIMAL(12,2) DEFAULT 0.00,
    commission_rate DECIMAL(5,2) DEFAULT 0.00,
    
    -- Attribution tracking
    source_url TEXT,
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    utm_content TEXT,
    utm_term TEXT,
    
    -- Browser and device info
    user_agent TEXT,
    ip_address INET,
    country_code TEXT,
    
    -- Expiration
    expires_at TIMESTAMP,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Affiliate payouts table - manages payment processing
  CREATE TABLE IF NOT EXISTS affiliate_payouts (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
    
    -- Payout details
    amount DECIMAL(12,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    status payout_status NOT NULL DEFAULT 'pending',
    
    -- Payment processing
    payment_method TEXT, -- 'bank_transfer', 'paypal', 'stripe', etc.
    payment_reference TEXT,
    external_transaction_id TEXT,
    
    -- Period covered
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    
    -- Processing details
    processed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    processed_at TIMESTAMP,
    failure_reason TEXT,
    
    -- Included referrals
    referral_ids INTEGER[], -- Array of referral IDs included in this payout
    
    -- Metadata
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Affiliate analytics table - tracks performance metrics
  CREATE TABLE IF NOT EXISTS affiliate_analytics (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,

    -- Time period
    date DATE NOT NULL,
    period_type TEXT NOT NULL DEFAULT 'daily', -- 'daily', 'weekly', 'monthly'

    -- Traffic metrics
    clicks INTEGER DEFAULT 0,
    unique_clicks INTEGER DEFAULT 0,
    impressions INTEGER DEFAULT 0,

    -- Conversion metrics
    referrals INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Revenue metrics
    revenue DECIMAL(12,2) DEFAULT 0.00,
    commission_earned DECIMAL(12,2) DEFAULT 0.00,
    average_order_value DECIMAL(10,2) DEFAULT 0.00,

    -- Geographic data
    top_countries JSONB DEFAULT '[]'::jsonb,

    -- Source tracking
    top_sources JSONB DEFAULT '[]'::jsonb,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE(company_id, affiliate_id, date, period_type)
  );

  -- Affiliate click tracking table - detailed click analytics
  CREATE TABLE IF NOT EXISTS affiliate_clicks (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
    referral_id INTEGER REFERENCES affiliate_referrals(id) ON DELETE SET NULL,

    -- Click details
    clicked_url TEXT NOT NULL,
    landing_page TEXT,

    -- User tracking
    session_id TEXT,
    user_agent TEXT,
    ip_address INET,
    country_code TEXT,
    city TEXT,

    -- Attribution
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    utm_content TEXT,
    utm_term TEXT,

    -- Referrer information
    referrer_url TEXT,
    referrer_domain TEXT,

    -- Device info
    device_type TEXT, -- 'desktop', 'mobile', 'tablet'
    browser TEXT,
    os TEXT,

    -- Conversion tracking
    converted BOOLEAN DEFAULT FALSE,
    converted_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT NOW()
  );

  -- Multi-level affiliate relationships (for MLM-style programs)
  CREATE TABLE IF NOT EXISTS affiliate_relationships (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
    parent_affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
    child_affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,

    -- Relationship details
    level INTEGER NOT NULL DEFAULT 1, -- 1 = direct, 2 = second level, etc.
    commission_percentage DECIMAL(5,2) DEFAULT 0.00,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE(company_id, parent_affiliate_id, child_affiliate_id)
  );

  -- Create indexes for optimal performance
  CREATE INDEX IF NOT EXISTS idx_affiliates_company_id ON affiliates(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliates_status ON affiliates(status);
  CREATE INDEX IF NOT EXISTS idx_affiliates_affiliate_code ON affiliates(affiliate_code);
  CREATE INDEX IF NOT EXISTS idx_affiliates_email ON affiliates(email);
  CREATE INDEX IF NOT EXISTS idx_affiliates_created_at ON affiliates(created_at DESC);

  CREATE INDEX IF NOT EXISTS idx_affiliate_commission_structures_company_id ON affiliate_commission_structures(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_commission_structures_affiliate_id ON affiliate_commission_structures(affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_commission_structures_plan_id ON affiliate_commission_structures(plan_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_commission_structures_active ON affiliate_commission_structures(is_active);

  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_company_id ON affiliate_referrals(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_affiliate_id ON affiliate_referrals(affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_status ON affiliate_referrals(status);
  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_referral_code ON affiliate_referrals(referral_code);
  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_referred_company_id ON affiliate_referrals(referred_company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_created_at ON affiliate_referrals(created_at DESC);

  CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_company_id ON affiliate_payouts(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_affiliate_id ON affiliate_payouts(affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_status ON affiliate_payouts(status);
  CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_created_at ON affiliate_payouts(created_at DESC);

  CREATE INDEX IF NOT EXISTS idx_affiliate_analytics_company_id ON affiliate_analytics(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_analytics_affiliate_id ON affiliate_analytics(affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_analytics_date ON affiliate_analytics(date DESC);
  CREATE INDEX IF NOT EXISTS idx_affiliate_analytics_period_type ON affiliate_analytics(period_type);

  CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_company_id ON affiliate_clicks(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_affiliate_id ON affiliate_clicks(affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_created_at ON affiliate_clicks(created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_ip_address ON affiliate_clicks(ip_address);
  CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_converted ON affiliate_clicks(converted);

  CREATE INDEX IF NOT EXISTS idx_affiliate_relationships_company_id ON affiliate_relationships(company_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_relationships_parent_affiliate_id ON affiliate_relationships(parent_affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_relationships_child_affiliate_id ON affiliate_relationships(child_affiliate_id);
  CREATE INDEX IF NOT EXISTS idx_affiliate_relationships_level ON affiliate_relationships(level);

  RAISE NOTICE 'Created affiliate analytics and relationship tables with indexes successfully';

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating affiliate tables: %', SQLERRM;
END $$;
