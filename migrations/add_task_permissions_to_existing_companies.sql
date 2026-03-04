-- Migration: Add task permissions to all existing companies
-- This script adds VIEW_TASKS and MANAGE_TASKS permissions to all existing companies
-- Run this script to enable task management for existing admin users

DO $$
DECLARE
  company_record RECORD;
  current_permissions jsonb;
BEGIN
  FOR company_record IN SELECT id FROM companies LOOP
    -- Update admin role permissions
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'admin';

    -- Add task permissions for admin
    current_permissions := current_permissions || '{
      "view_tasks": true,
      "manage_tasks": true
    }'::jsonb;

    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'admin', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET permissions = current_permissions, updated_at = NOW();

    -- Update agent role permissions
    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'agent';

    -- Add task permissions for agent (view only)
    current_permissions := current_permissions || '{
      "view_tasks": true,
      "manage_tasks": false
    }'::jsonb;

    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'agent', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET permissions = current_permissions, updated_at = NOW();
  END LOOP;

  RAISE NOTICE 'Task permissions added to all companies successfully!';
END $$;

