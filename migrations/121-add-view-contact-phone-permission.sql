-- Migration: Add view_contact_phone permission to role_permissions
-- Backfills view_contact_phone for all existing companies (true for admin, false for agent).
-- Updates create_default_role_permissions so new companies get the new key.

-- 1. Backfill view_contact_phone for existing role_permissions
DO $$
DECLARE
  company_record RECORD;
  current_permissions jsonb;
BEGIN
  RAISE NOTICE 'Starting view_contact_phone permission migration for all companies...';

  FOR company_record IN SELECT id FROM companies LOOP
    -- Update admin role: add view_contact_phone = true if missing
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'admin';

    IF current_permissions IS NOT NULL AND NOT (current_permissions ? 'view_contact_phone') THEN
      current_permissions := current_permissions || '{"view_contact_phone": true}'::jsonb;
      UPDATE role_permissions
      SET permissions = current_permissions, updated_at = NOW()
      WHERE company_id = company_record.id AND role = 'admin';
    END IF;

    -- Update agent role: add view_contact_phone = false if missing
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'agent';

    IF current_permissions IS NOT NULL AND NOT (current_permissions ? 'view_contact_phone') THEN
      current_permissions := current_permissions || '{"view_contact_phone": false}'::jsonb;
      UPDATE role_permissions
      SET permissions = current_permissions, updated_at = NOW()
      WHERE company_id = company_record.id AND role = 'agent';
    END IF;
  END LOOP;

  RAISE NOTICE 'view_contact_phone permission backfill completed.';
END $$;

-- 2. Update create_default_role_permissions so new companies get view_contact_phone
CREATE OR REPLACE FUNCTION create_default_role_permissions(company_id_param INTEGER)
RETURNS VOID AS $$
BEGIN
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
      "view_contact_phone": true,
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
      "view_contact_phone": false,
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
