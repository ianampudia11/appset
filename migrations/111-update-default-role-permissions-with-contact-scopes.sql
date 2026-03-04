-- Migration: Update create_default_role_permissions function with contact scope permissions
-- This ensures that new companies automatically get proper contact permissions:
-- - Admin: All permissions enabled including view_own_contacts, view_assigned_contacts, view_company_contacts
-- - Agent: view_own_contacts and view_assigned_contacts enabled, view_company_contacts disabled
-- Also adds missing permissions: view_pages, manage_pages, create_backups, restore_backups, manage_backups,
-- view_call_logs, manage_call_logs, export_call_logs, delete_call_logs

CREATE OR REPLACE FUNCTION create_default_role_permissions(company_id_param INTEGER)
RETURNS VOID AS $$
BEGIN
  -- Insert admin role permissions with all permissions enabled
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
      "view_own_contacts": true,
      "view_assigned_contacts": true,
      "view_company_contacts": true,
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
      "configure_channels": true,
      "view_pages": true,
      "manage_pages": true,
      "create_backups": true,
      "restore_backups": true,
      "manage_backups": true,
      "view_call_logs": true,
      "manage_call_logs": true,
      "export_call_logs": true,
      "delete_call_logs": true
    }'::jsonb
  )
  ON CONFLICT (company_id, role) DO NOTHING;

  -- Insert agent role permissions with view_own_contacts and view_assigned_contacts enabled
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
      "view_own_contacts": true,
      "view_assigned_contacts": true,
      "view_company_contacts": false,
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
      "configure_channels": false,
      "view_pages": false,
      "manage_pages": false,
      "create_backups": false,
      "restore_backups": false,
      "manage_backups": false,
      "view_call_logs": true,
      "manage_call_logs": false,
      "export_call_logs": false,
      "delete_call_logs": false
    }'::jsonb
  )
  ON CONFLICT (company_id, role) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Update existing companies with the new contact scope permissions
-- This merges new permissions with existing ones without overwriting custom configurations
DO $$
DECLARE
  company_record RECORD;
  updated_admin_count INTEGER := 0;
  updated_agent_count INTEGER := 0;
BEGIN
  RAISE NOTICE '🔄 Starting permission update for existing companies...';
  
  -- Loop through all companies
  FOR company_record IN SELECT id, name FROM companies LOOP
    -- Update admin role permissions (only add missing keys, preserve existing values)
    UPDATE role_permissions
    SET permissions = permissions || jsonb_strip_nulls(jsonb_build_object(
      'view_own_contacts', CASE WHEN NOT permissions ? 'view_own_contacts' THEN true END,
      'view_assigned_contacts', CASE WHEN NOT permissions ? 'view_assigned_contacts' THEN true END,
      'view_company_contacts', CASE WHEN NOT permissions ? 'view_company_contacts' THEN true END,
      'view_pages', CASE WHEN NOT permissions ? 'view_pages' THEN true END,
      'manage_pages', CASE WHEN NOT permissions ? 'manage_pages' THEN true END,
      'create_backups', CASE WHEN NOT permissions ? 'create_backups' THEN true END,
      'restore_backups', CASE WHEN NOT permissions ? 'restore_backups' THEN true END,
      'manage_backups', CASE WHEN NOT permissions ? 'manage_backups' THEN true END,
      'view_call_logs', CASE WHEN NOT permissions ? 'view_call_logs' THEN true END,
      'manage_call_logs', CASE WHEN NOT permissions ? 'manage_call_logs' THEN true END,
      'export_call_logs', CASE WHEN NOT permissions ? 'export_call_logs' THEN true END,
      'delete_call_logs', CASE WHEN NOT permissions ? 'delete_call_logs' THEN true END
    ))
    WHERE company_id = company_record.id AND role = 'admin';
    
    IF FOUND THEN
      updated_admin_count := updated_admin_count + 1;
    END IF;
    
    -- Update agent role permissions (only add missing keys, preserve existing values)
    UPDATE role_permissions
    SET permissions = permissions || jsonb_strip_nulls(jsonb_build_object(
      'view_own_contacts', CASE WHEN NOT permissions ? 'view_own_contacts' THEN true END,
      'view_assigned_contacts', CASE WHEN NOT permissions ? 'view_assigned_contacts' THEN true END,
      'view_company_contacts', CASE WHEN NOT permissions ? 'view_company_contacts' THEN false END,
      'view_pages', CASE WHEN NOT permissions ? 'view_pages' THEN false END,
      'manage_pages', CASE WHEN NOT permissions ? 'manage_pages' THEN false END,
      'create_backups', CASE WHEN NOT permissions ? 'create_backups' THEN false END,
      'restore_backups', CASE WHEN NOT permissions ? 'restore_backups' THEN false END,
      'manage_backups', CASE WHEN NOT permissions ? 'manage_backups' THEN false END,
      'view_call_logs', CASE WHEN NOT permissions ? 'view_call_logs' THEN true END,
      'manage_call_logs', CASE WHEN NOT permissions ? 'manage_call_logs' THEN false END,
      'export_call_logs', CASE WHEN NOT permissions ? 'export_call_logs' THEN false END,
      'delete_call_logs', CASE WHEN NOT permissions ? 'delete_call_logs' THEN false END
    ))
    WHERE company_id = company_record.id AND role = 'agent';
    
    IF FOUND THEN
      updated_agent_count := updated_agent_count + 1;
    END IF;
    
  END LOOP;
  
  RAISE NOTICE '✅ Updated % admin role permissions', updated_admin_count;
  RAISE NOTICE '✅ Updated % agent role permissions', updated_agent_count;
END $$;

-- Verify the function was updated successfully
DO $$
DECLARE
  function_source TEXT;
BEGIN
  SELECT prosrc INTO function_source 
  FROM pg_proc 
  WHERE proname = 'create_default_role_permissions';
  
  IF function_source LIKE '%view_own_contacts%' 
     AND function_source LIKE '%view_assigned_contacts%' 
     AND function_source LIKE '%view_company_contacts%' THEN
    RAISE NOTICE '✅ Function successfully updated with contact scope permissions';
  ELSE
    RAISE WARNING '⚠️ Function may not include contact scope permissions';
  END IF;
END $$;

-- Verification: Show sample of updated permissions
DO $$
DECLARE
  sample_record RECORD;
BEGIN
  RAISE NOTICE '📊 Sample of updated permissions:';
  
  FOR sample_record IN 
    SELECT 
      c.name as company_name, 
      rp.role,
      rp.permissions->>'view_own_contacts' as view_own_contacts,
      rp.permissions->>'view_assigned_contacts' as view_assigned_contacts,
      rp.permissions->>'view_company_contacts' as view_company_contacts
    FROM role_permissions rp
    JOIN companies c ON c.id = rp.company_id
    ORDER BY c.id
    LIMIT 6
  LOOP
    RAISE NOTICE 'Company: %, Role: %, view_own: %, view_assigned: %, view_company: %',
      sample_record.company_name,
      sample_record.role,
      COALESCE(sample_record.view_own_contacts, 'NULL'),
      COALESCE(sample_record.view_assigned_contacts, 'NULL'),
      COALESCE(sample_record.view_company_contacts, 'NULL');
  END LOOP;
END $$;

-- Count total permissions per role to verify completeness
DO $$
DECLARE
  admin_permission_count INTEGER;
  agent_permission_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_permission_count
  FROM role_permissions rp, jsonb_object_keys(rp.permissions)
  WHERE role = 'admin'
  GROUP BY rp.id
  LIMIT 1;
  
  SELECT COUNT(*) INTO agent_permission_count
  FROM role_permissions rp, jsonb_object_keys(rp.permissions)
  WHERE role = 'agent'
  GROUP BY rp.id
  LIMIT 1;
  
  RAISE NOTICE '📈 Permission counts - Admin: %, Agent: %', 
    COALESCE(admin_permission_count, 0), 
    COALESCE(agent_permission_count, 0);
END $$;
