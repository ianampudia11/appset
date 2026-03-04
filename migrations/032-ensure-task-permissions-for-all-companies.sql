-- Migration: Ensure task permissions are enabled for all existing companies
-- This migration ensures that all companies have proper task permissions configured
-- for both admin and agent roles

DO $$
DECLARE
  company_record RECORD;
  current_permissions jsonb;
BEGIN
  RAISE NOTICE 'Starting task permissions migration for all companies...';
  
  FOR company_record IN SELECT id FROM companies LOOP
    RAISE NOTICE 'Processing company %', company_record.id;
    
    -- Update admin role permissions to ensure task permissions are enabled
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'admin';
    
    -- Add/update task permissions for admin role
    current_permissions := current_permissions || '{
      "view_tasks": true,
      "manage_tasks": true
    }'::jsonb;
    
    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'admin', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET 
      permissions = current_permissions,
      updated_at = NOW();
    
    RAISE NOTICE 'Updated admin permissions for company %', company_record.id;
    
    -- Update agent role permissions to ensure view_tasks is enabled
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'agent';
    
    -- Add/update task permissions for agent role (view only)
    current_permissions := current_permissions || '{
      "view_tasks": true,
      "manage_tasks": false
    }'::jsonb;
    
    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'agent', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET 
      permissions = current_permissions,
      updated_at = NOW();
    
    RAISE NOTICE 'Updated agent permissions for company %', company_record.id;
  END LOOP;
  
  RAISE NOTICE 'Task permissions migration completed successfully!';
END $$;

-- Verify the migration by checking task permissions
DO $$
DECLARE
  admin_count INTEGER;
  agent_count INTEGER;
  total_companies INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_companies FROM companies;
  
  SELECT COUNT(*) INTO admin_count
  FROM role_permissions 
  WHERE permissions->>'view_tasks' = 'true' 
    AND permissions->>'manage_tasks' = 'true' 
    AND role = 'admin';
  
  SELECT COUNT(*) INTO agent_count
  FROM role_permissions 
  WHERE permissions->>'view_tasks' = 'true' 
    AND permissions->>'manage_tasks' = 'false' 
    AND role = 'agent';
  
  RAISE NOTICE 'Migration verification:';
  RAISE NOTICE 'Total companies: %', total_companies;
  RAISE NOTICE 'Admin users with task permissions: %', admin_count;
  RAISE NOTICE 'Agent users with task permissions: %', agent_count;
  
  IF admin_count = total_companies AND agent_count = total_companies THEN
    RAISE NOTICE '✅ All companies have proper task permissions configured!';
  ELSE
    RAISE WARNING '⚠️ Some companies may not have task permissions properly configured';
  END IF;
END $$;
