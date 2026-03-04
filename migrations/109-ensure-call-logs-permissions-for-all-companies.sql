-- Migration: Ensure call logs permissions are enabled for all existing companies
-- This migration ensures that all companies have proper call logs permissions configured
-- for both admin and agent roles

DO $$
DECLARE
  company_record RECORD;
  current_permissions jsonb;
BEGIN
  RAISE NOTICE 'Starting call logs permissions migration for all companies...';
  
  FOR company_record IN SELECT id FROM companies LOOP
    RAISE NOTICE 'Processing company %', company_record.id;
    
    -- Update admin role permissions to ensure call logs permissions are enabled
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'admin';
    
    -- Add/update call logs permissions for admin role
    current_permissions := current_permissions || '{
      "view_call_logs": true,
      "manage_call_logs": true,
      "export_call_logs": true,
      "delete_call_logs": true
    }'::jsonb;
    
    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'admin', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET 
      permissions = current_permissions,
      updated_at = NOW();
    
    RAISE NOTICE 'Updated admin permissions for company %', company_record.id;
    
    -- Update agent role permissions to ensure view_call_logs is enabled
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'agent';
    
    -- Add/update call logs permissions for agent role
    -- Always set view_call_logs to true
    current_permissions := jsonb_set(current_permissions, '{view_call_logs}', 'true'::jsonb);
    
    -- Only set manage_call_logs if it doesn't exist, preserving existing true values
    IF NOT (current_permissions ? 'manage_call_logs') THEN
      current_permissions := jsonb_set(current_permissions, '{manage_call_logs}', 'false'::jsonb);
    END IF;
    
    -- Only set export_call_logs if it doesn't exist, preserving existing true values
    IF NOT (current_permissions ? 'export_call_logs') THEN
      current_permissions := jsonb_set(current_permissions, '{export_call_logs}', 'false'::jsonb);
    END IF;
    
    -- Only set delete_call_logs if it doesn't exist, preserving existing true values
    IF NOT (current_permissions ? 'delete_call_logs') THEN
      current_permissions := jsonb_set(current_permissions, '{delete_call_logs}', 'false'::jsonb);
    END IF;
    
    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'agent', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET 
      permissions = current_permissions,
      updated_at = NOW();
    
    RAISE NOTICE 'Updated agent permissions for company %', company_record.id;
  END LOOP;
  
  RAISE NOTICE 'Call logs permissions migration completed successfully!';
END $$;

-- Verify the migration by checking call logs permissions
DO $$
DECLARE
  admin_count INTEGER;
  agent_count INTEGER;
  total_companies INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_companies FROM companies;
  
  SELECT COUNT(*) INTO admin_count
  FROM role_permissions 
  WHERE permissions->>'view_call_logs' = 'true' 
    AND permissions->>'manage_call_logs' = 'true' 
    AND permissions->>'export_call_logs' = 'true'
    AND permissions->>'delete_call_logs' = 'true'
    AND role = 'admin';
  
  SELECT COUNT(*) INTO agent_count
  FROM role_permissions 
  WHERE permissions->>'view_call_logs' = 'true' 
    AND permissions ? 'manage_call_logs'
    AND permissions ? 'export_call_logs'
    AND permissions ? 'delete_call_logs'
    AND role = 'agent';
  
  RAISE NOTICE 'Migration verification:';
  RAISE NOTICE 'Total companies: %', total_companies;
  RAISE NOTICE 'Admin users with call logs permissions: %', admin_count;
  RAISE NOTICE 'Agent users with call logs permissions: %', agent_count;
  
  IF admin_count = total_companies AND agent_count = total_companies THEN
    RAISE NOTICE '✅ All companies have proper call logs permissions configured!';
  ELSE
    RAISE WARNING '⚠️ Some companies may not have call logs permissions properly configured';
  END IF;
END $$;
