-- Migration: Add pricing discounts and coupon system
-- Created: 2025-01-XX
-- Description: Adds discount fields to plans, coupon management system, and affiliate earnings integration

-- Add discount fields to plans table
ALTER TABLE plans ADD COLUMN IF NOT EXISTS discount_type TEXT CHECK (discount_type IN ('none', 'percentage', 'fixed_amount')) DEFAULT 'none';
ALTER TABLE plans ADD COLUMN IF NOT EXISTS discount_value NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS discount_duration TEXT CHECK (discount_duration IN ('permanent', 'first_month', 'first_year', 'limited_time')) DEFAULT 'permanent';
ALTER TABLE plans ADD COLUMN IF NOT EXISTS discount_start_date TIMESTAMP;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS discount_end_date TIMESTAMP;
ALTER TABLE plans ADD COLUMN IF NOT EXISTS original_price NUMERIC(10, 2); -- Store original price when discount is applied

-- Create coupon codes table
CREATE TABLE IF NOT EXISTS coupon_codes (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE, -- NULL for global coupons
  
  -- Coupon identification
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  
  -- Discount configuration
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
  discount_value NUMERIC(10, 2) NOT NULL,
  
  -- Usage limits
  usage_limit INTEGER, -- NULL for unlimited
  usage_limit_per_user INTEGER DEFAULT 1,
  current_usage_count INTEGER DEFAULT 0,
  
  -- Date restrictions
  start_date TIMESTAMP NOT NULL DEFAULT NOW(),
  end_date TIMESTAMP,
  
  -- Plan restrictions
  applicable_plan_ids INTEGER[], -- NULL for all plans
  minimum_plan_value NUMERIC(10, 2), -- Minimum plan price to apply coupon
  
  -- Status and metadata
  is_active BOOLEAN DEFAULT TRUE,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create coupon usage tracking table
CREATE TABLE IF NOT EXISTS coupon_usage (
  id SERIAL PRIMARY KEY,
  coupon_id INTEGER REFERENCES coupon_codes(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  
  -- Usage details
  plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL,
  original_amount NUMERIC(10, 2) NOT NULL,
  discount_amount NUMERIC(10, 2) NOT NULL,
  final_amount NUMERIC(10, 2) NOT NULL,
  
  -- Transaction reference
  payment_transaction_id INTEGER REFERENCES payment_transactions(id) ON DELETE SET NULL,
  
  -- Metadata
  usage_context JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create affiliate earnings balance table
CREATE TABLE IF NOT EXISTS affiliate_earnings_balance (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
  
  -- Balance tracking
  total_earned NUMERIC(12, 2) DEFAULT 0.00,
  available_balance NUMERIC(12, 2) DEFAULT 0.00, -- Available for plan credits
  applied_to_plans NUMERIC(12, 2) DEFAULT 0.00, -- Used for plan purchases
  pending_payout NUMERIC(12, 2) DEFAULT 0.00, -- Scheduled for payout
  paid_out NUMERIC(12, 2) DEFAULT 0.00, -- Already paid out
  
  -- Metadata
  last_updated TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  UNIQUE(company_id, affiliate_id)
);

-- Create affiliate earnings transactions table
CREATE TABLE IF NOT EXISTS affiliate_earnings_transactions (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  affiliate_id INTEGER REFERENCES affiliates(id) ON DELETE CASCADE,
  
  -- Transaction details
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('earned', 'applied_to_plan', 'payout', 'adjustment')),
  amount NUMERIC(12, 2) NOT NULL,
  balance_after NUMERIC(12, 2) NOT NULL,
  
  -- References
  referral_id INTEGER REFERENCES affiliate_referrals(id) ON DELETE SET NULL,
  payment_transaction_id INTEGER REFERENCES payment_transactions(id) ON DELETE SET NULL,
  payout_id INTEGER REFERENCES affiliate_payouts(id) ON DELETE SET NULL,
  
  -- Description and metadata
  description TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add discount tracking to payment transactions
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS original_amount NUMERIC(10, 2);
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS coupon_code_id INTEGER REFERENCES coupon_codes(id) ON DELETE SET NULL;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS affiliate_credit_applied NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE payment_transactions ADD COLUMN IF NOT EXISTS discount_details JSONB DEFAULT '{}'::jsonb;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_coupon_codes_code ON coupon_codes(code);
CREATE INDEX IF NOT EXISTS idx_coupon_codes_active ON coupon_codes(is_active, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_coupon_id ON coupon_usage(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_company_user ON coupon_usage(company_id, user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_earnings_balance_company_affiliate ON affiliate_earnings_balance(company_id, affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_earnings_transactions_affiliate ON affiliate_earnings_transactions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_earnings_transactions_type ON affiliate_earnings_transactions(transaction_type);

-- Create triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_coupon_codes_updated_at BEFORE UPDATE ON coupon_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add audit logging trigger for coupon usage
CREATE OR REPLACE FUNCTION log_coupon_usage()
RETURNS TRIGGER AS $$
BEGIN
    -- Update coupon usage count
    UPDATE coupon_codes 
    SET current_usage_count = current_usage_count + 1,
        updated_at = NOW()
    WHERE id = NEW.coupon_id;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_log_coupon_usage AFTER INSERT ON coupon_usage FOR EACH ROW EXECUTE FUNCTION log_coupon_usage();

-- Add function to update affiliate earnings balance
CREATE OR REPLACE FUNCTION update_affiliate_earnings_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert or update affiliate earnings balance
    INSERT INTO affiliate_earnings_balance (company_id, affiliate_id, total_earned, available_balance, last_updated)
    VALUES (NEW.company_id, NEW.affiliate_id, NEW.amount, NEW.amount, NOW())
    ON CONFLICT (company_id, affiliate_id) 
    DO UPDATE SET
        total_earned = affiliate_earnings_balance.total_earned + NEW.amount,
        available_balance = CASE 
            WHEN NEW.transaction_type = 'earned' THEN affiliate_earnings_balance.available_balance + NEW.amount
            WHEN NEW.transaction_type = 'applied_to_plan' THEN affiliate_earnings_balance.available_balance - NEW.amount
            WHEN NEW.transaction_type = 'payout' THEN affiliate_earnings_balance.available_balance - NEW.amount
            ELSE affiliate_earnings_balance.available_balance
        END,
        applied_to_plans = CASE 
            WHEN NEW.transaction_type = 'applied_to_plan' THEN affiliate_earnings_balance.applied_to_plans + NEW.amount
            ELSE affiliate_earnings_balance.applied_to_plans
        END,
        paid_out = CASE 
            WHEN NEW.transaction_type = 'payout' THEN affiliate_earnings_balance.paid_out + NEW.amount
            ELSE affiliate_earnings_balance.paid_out
        END,
        last_updated = NOW();
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_update_affiliate_earnings_balance 
    AFTER INSERT ON affiliate_earnings_transactions 
    FOR EACH ROW EXECUTE FUNCTION update_affiliate_earnings_balance();

-- Insert some sample coupon codes for testing
INSERT INTO coupon_codes (code, name, description, discount_type, discount_value, usage_limit, start_date, end_date, is_active)
VALUES 
    ('WELCOME10', 'Welcome Discount', '10% off for new customers', 'percentage', 10.00, 1000, NOW(), NOW() + INTERVAL '30 days', true),
    ('SAVE50', 'Save $50', '$50 off any plan', 'fixed_amount', 50.00, 500, NOW(), NOW() + INTERVAL '60 days', true),
    ('FIRSTMONTH', 'First Month Free', '100% off first month', 'percentage', 100.00, NULL, NOW(), NULL, true);
