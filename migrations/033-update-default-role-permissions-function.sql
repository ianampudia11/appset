-- Migration: Update create_default_role_permissions function to ensure task permissions are included
-- This ensures that new companies automatically get task permissions enabled for admin users

CREATE OR REPLACE FUNCTION create_default_role_permissions(company_id_param INTEGER)
RETURNS VOID AS $$
BEGIN
  -- Insert admin role permissions with task permissions enabled
  INSERT INTO role_permissions (company_id, role, permissions)
  VALUES (
    company_id_param,
    'admin',
    '{
      "view_all_conversations": true,
      "view_assigned_conversations": true,
      "assign_conversations": true,
      "manage_conversations": true,
      "view_contacts": true,
      "manage_contacts": true,
      "view_channels": true,
      "manage_channels": true,
      "view_flows": true,
      "manage_flows": true,
      "view_analytics": true,
      "view_detailed_analytics": true,
      "view_team": true,
      "manage_team": true,
      "view_settings": true,
      "manage_settings": true,
      "view_pipeline": true,
      "manage_pipeline": true,
      "view_calendar": true,
      "manage_calendar": true,
      "view_tasks": true,
      "manage_tasks": true,
      "view_campaigns": true,
      "create_campaigns": true,
      "edit_campaigns": true,
      "delete_campaigns": true,
      "manage_templates": true,
      "manage_segments": true,
      "view_campaign_analytics": true,
      "manage_whatsapp_accounts": true,
      "configure_channels": true
    }'::jsonb
  )
  ON CONFLICT (company_id, role) DO NOTHING;

  -- Insert agent role permissions with view_tasks enabled
  INSERT INTO role_permissions (company_id, role, permissions)
  VALUES (
    company_id_param,
    'agent',
    '{
      "view_all_conversations": false,
      "view_assigned_conversations": true,
      "assign_conversations": false,
      "manage_conversations": true,
      "view_contacts": true,
      "manage_contacts": false,
      "view_channels": false,
      "manage_channels": false,
      "view_flows": false,
      "manage_flows": false,
      "view_analytics": false,
      "view_detailed_analytics": false,
      "view_team": false,
      "manage_team": false,
      "view_settings": false,
      "manage_settings": false,
      "view_pipeline": false,
      "manage_pipeline": false,
      "view_calendar": true,
      "manage_calendar": false,
      "view_tasks": true,
      "manage_tasks": false,
      "view_campaigns": true,
      "create_campaigns": false,
      "edit_campaigns": false,
      "delete_campaigns": false,
      "manage_templates": false,
      "manage_segments": false,
      "view_campaign_analytics": true,
      "manage_whatsapp_accounts": false,
      "configure_channels": false
    }'::jsonb
  )
  ON CONFLICT (company_id, role) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Test the function by applying it to a test company (if any exist)
DO $$
DECLARE
  test_company_id INTEGER;
BEGIN
  -- Get the first company ID for testing
  SELECT id INTO test_company_id FROM companies LIMIT 1;
  
  IF test_company_id IS NOT NULL THEN
    RAISE NOTICE 'Testing updated function with company %', test_company_id;
    -- This will test the function without actually creating new permissions
    -- since ON CONFLICT DO NOTHING will prevent duplicates
    PERFORM create_default_role_permissions(test_company_id);
    RAISE NOTICE 'Function test completed successfully';
  ELSE
    RAISE NOTICE 'No companies found for testing';
  END IF;
END $$;

-- Verify that the function now includes task permissions
DO $$
DECLARE
  function_source TEXT;
BEGIN
  SELECT prosrc INTO function_source 
  FROM pg_proc 
  WHERE proname = 'create_default_role_permissions';
  
  IF function_source LIKE '%view_tasks%' AND function_source LIKE '%manage_tasks%' THEN
    RAISE NOTICE '✅ Function successfully updated with task permissions';
  ELSE
    RAISE WARNING '⚠️ Function may not include task permissions';
  END IF;
END $$;
