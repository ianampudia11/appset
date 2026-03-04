-- Migration: Update AI provider constraints to support streamlined provider system
-- This migration updates the check constraints to only allow OpenAI and OpenRouter providers
-- as part of the AI system streamlining effort

-- Use DO block for error-resistant execution
DO $$ 
BEGIN
    -- Check if system_ai_credentials table exists and has provider column
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'system_ai_credentials'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_ai_credentials' AND column_name = 'provider'
    ) THEN
        -- Drop existing check constraints safely
        BEGIN
            ALTER TABLE system_ai_credentials DROP CONSTRAINT IF EXISTS system_ai_credentials_provider_check;
        EXCEPTION WHEN OTHERS THEN
            -- Log error but continue
            RAISE NOTICE 'Could not drop system_ai_credentials_provider_check constraint: %', SQLERRM;
        END;

        -- Add new check constraints with updated provider list
        BEGIN
            ALTER TABLE system_ai_credentials 
            ADD CONSTRAINT system_ai_credentials_provider_check 
            CHECK (provider IN ('openai', 'openrouter'));
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add system_ai_credentials_provider_check constraint: %', SQLERRM;
        END;

        -- Update any existing credentials with removed providers to use OpenAI as fallback
        BEGIN
            UPDATE system_ai_credentials 
            SET provider = 'openai' 
            WHERE provider IN ('anthropic', 'gemini', 'deepseek', 'xai');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not update system_ai_credentials: %', SQLERRM;
        END;
    END IF;

    -- Check if company_ai_credentials table exists and has provider column
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'company_ai_credentials'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'company_ai_credentials' AND column_name = 'provider'
    ) THEN
        -- Drop existing check constraints safely
        BEGIN
            ALTER TABLE company_ai_credentials DROP CONSTRAINT IF EXISTS company_ai_credentials_provider_check;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not drop company_ai_credentials_provider_check constraint: %', SQLERRM;
        END;

        -- Add new check constraints with updated provider list
        BEGIN
            ALTER TABLE company_ai_credentials 
            ADD CONSTRAINT company_ai_credentials_provider_check 
            CHECK (provider IN ('openai', 'openrouter'));
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add company_ai_credentials_provider_check constraint: %', SQLERRM;
        END;

        -- Update any existing credentials with removed providers to use OpenAI as fallback
        BEGIN
            UPDATE company_ai_credentials 
            SET provider = 'openai' 
            WHERE provider IN ('anthropic', 'gemini', 'deepseek', 'xai');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not update company_ai_credentials: %', SQLERRM;
        END;
    END IF;

    -- Update AI credential usage records if table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'ai_credential_usage'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ai_credential_usage' AND column_name = 'provider'
    ) THEN
        BEGIN
            UPDATE ai_credential_usage 
            SET provider = 'openai' 
            WHERE provider IN ('anthropic', 'gemini', 'deepseek', 'xai');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not update ai_credential_usage: %', SQLERRM;
        END;
    END IF;

    -- Update company AI preferences if table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'company_ai_preferences'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'company_ai_preferences' AND column_name = 'default_provider'
    ) THEN
        BEGIN
            UPDATE company_ai_preferences 
            SET default_provider = 'openai' 
            WHERE default_provider IN ('anthropic', 'gemini', 'deepseek', 'xai');
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not update company_ai_preferences: %', SQLERRM;
        END;
    END IF;

    -- Add comments for documentation (if constraints exist)
    BEGIN
        COMMENT ON CONSTRAINT system_ai_credentials_provider_check ON system_ai_credentials 
        IS 'Ensures only OpenAI and OpenRouter providers are allowed in the streamlined AI system';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not add comment to system_ai_credentials_provider_check: %', SQLERRM;
    END;

    BEGIN
        COMMENT ON CONSTRAINT company_ai_credentials_provider_check ON company_ai_credentials 
        IS 'Ensures only OpenAI and OpenRouter providers are allowed in the streamlined AI system';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not add comment to company_ai_credentials_provider_check: %', SQLERRM;
    END;

END $$;

-- Migration completed successfully
-- This migration updates the AI provider system to only support OpenAI and OpenRouter
