CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'agent');
  END IF;
END$$;


CREATE TABLE IF NOT EXISTS plans (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10, 2) NOT NULL DEFAULT 0,
  max_users INTEGER NOT NULL DEFAULT 5,
  max_contacts INTEGER NOT NULL DEFAULT 1000,
  max_channels INTEGER NOT NULL DEFAULT 3,
  max_flows INTEGER NOT NULL DEFAULT 1,
  max_campaigns INTEGER NOT NULL DEFAULT 5,
  max_campaign_recipients INTEGER NOT NULL DEFAULT 1000,
  campaign_features JSONB NOT NULL DEFAULT '["basic_campaigns"]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_free BOOLEAN NOT NULL DEFAULT FALSE,
  has_trial_period BOOLEAN NOT NULL DEFAULT FALSE,
  trial_days INTEGER DEFAULT 0,
  features JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS companies (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  subdomain TEXT UNIQUE,
  logo TEXT,
  primary_color TEXT DEFAULT '#363636',
  active BOOLEAN DEFAULT TRUE,
  plan TEXT DEFAULT 'free',
  plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL,
  subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'pending', 'cancelled', 'overdue', 'trial', 'grace_period', 'paused', 'past_due')),
  subscription_start_date TIMESTAMP,
  subscription_end_date TIMESTAMP,
  trial_start_date TIMESTAMP,
  trial_end_date TIMESTAMP,
  is_in_trial BOOLEAN DEFAULT FALSE,
  max_users INTEGER DEFAULT 5,

  -- Company details
  register_number TEXT,
  company_email TEXT,
  contact_person TEXT,
  iban TEXT,

  -- Stripe integration
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  billing_cycle_anchor TIMESTAMP,
  grace_period_end TIMESTAMP,
  pause_start_date TIMESTAMP,
  pause_end_date TIMESTAMP,
  auto_renewal BOOLEAN DEFAULT TRUE,
  dunning_attempts INTEGER DEFAULT 0,
  last_dunning_attempt TIMESTAMP,
  subscription_metadata JSONB DEFAULT '{}',

  -- Storage management
  current_storage_used INTEGER DEFAULT 0,
  current_bandwidth_used INTEGER DEFAULT 0,
  files_count INTEGER DEFAULT 0,
  last_usage_update TIMESTAMP DEFAULT NOW(),

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  role user_role DEFAULT 'agent',
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  is_super_admin BOOLEAN DEFAULT FALSE,
  active BOOLEAN DEFAULT TRUE,
  language_preference TEXT DEFAULT 'en',
  permissions JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  role user_role NOT NULL,
  permissions JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(company_id, role)
);

CREATE TABLE IF NOT EXISTS channel_connections (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  channel_type TEXT NOT NULL,
  account_id TEXT NOT NULL,
  account_name TEXT NOT NULL,
  access_token TEXT,
  status TEXT DEFAULT 'active',
  connection_data JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contacts (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  avatar_url TEXT,
  email TEXT,
  phone TEXT,
  company TEXT,
  tags TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  identifier TEXT,
  identifier_type TEXT,
  source TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversations (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  contact_id INTEGER REFERENCES contacts(id) ON DELETE CASCADE, -- Made nullable for group chats
  channel_type TEXT NOT NULL,
  channel_id INTEGER NOT NULL REFERENCES channel_connections(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'open',
  assigned_to_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  last_message_at TIMESTAMP DEFAULT NOW(),
  unread_count INTEGER DEFAULT 0,
  bot_disabled BOOLEAN DEFAULT FALSE,
  disabled_at TIMESTAMP,
  disable_duration INTEGER,
  disable_reason TEXT,

  -- Group chat support
  is_group BOOLEAN DEFAULT FALSE,
  group_jid TEXT, -- WhatsApp group JID (e.g., groupId@g.us)
  group_name TEXT, -- Group subject/name
  group_description TEXT,
  group_participant_count INTEGER DEFAULT 0,
  group_created_at TIMESTAMP,
  group_metadata JSONB, -- Store additional group metadata

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  -- Ensure either contact_id is set (individual) or group_jid is set (group)
  CONSTRAINT check_conversation_type CHECK (
    (is_group = FALSE AND contact_id IS NOT NULL AND group_jid IS NULL) OR
    (is_group = TRUE AND contact_id IS NULL AND group_jid IS NOT NULL)
  )
);

-- Group participants table for managing group membership
CREATE TABLE IF NOT EXISTS group_participants (
  id SERIAL PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  contact_id INTEGER REFERENCES contacts(id) ON DELETE CASCADE,
  participant_jid TEXT NOT NULL, -- WhatsApp JID of participant
  participant_name TEXT, -- Display name in group
  is_admin BOOLEAN DEFAULT FALSE,
  is_super_admin BOOLEAN DEFAULT FALSE,
  joined_at TIMESTAMP DEFAULT NOW(),
  left_at TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(conversation_id, participant_jid)
);

CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  external_id TEXT,
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  type TEXT DEFAULT 'text',
  content TEXT NOT NULL,
  metadata JSONB,
  sender_id INTEGER,
  sender_type TEXT CHECK (sender_type IN ('user', 'contact')),
  status TEXT DEFAULT 'sent',
  sent_at TIMESTAMP,
  read_at TIMESTAMP,
  is_from_bot BOOLEAN DEFAULT FALSE,
  media_url TEXT,

  -- Group message support
  group_participant_jid TEXT, -- JID of group message sender
  group_participant_name TEXT, -- Display name of group message sender

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notes (
  id SERIAL PRIMARY KEY,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  created_by_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS flows (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'inactive', 'archived')),
  nodes JSONB NOT NULL DEFAULT '[]'::jsonb,
  edges JSONB NOT NULL DEFAULT '[]'::jsonb,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS flow_assignments (
  id SERIAL PRIMARY KEY,
  flow_id INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  channel_id INTEGER NOT NULL REFERENCES channel_connections(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS flow_executions (
  id SERIAL PRIMARY KEY,
  execution_id TEXT NOT NULL UNIQUE,
  flow_id INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'waiting', 'completed', 'failed', 'abandoned')),
  trigger_node_id TEXT NOT NULL,
  current_node_id TEXT,
  execution_path JSONB NOT NULL DEFAULT '[]'::jsonb,
  context_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP,
  last_activity_at TIMESTAMP NOT NULL DEFAULT NOW(),
  total_duration_ms INTEGER,
  completion_rate DECIMAL(5,2),
  error_message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS flow_step_executions (
  id SERIAL PRIMARY KEY,
  flow_execution_id INTEGER NOT NULL REFERENCES flow_executions(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  node_type TEXT NOT NULL,
  step_order INTEGER NOT NULL,
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP,
  duration_ms INTEGER,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'skipped')),
  input_data JSONB,
  output_data JSONB,
  error_message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Enhanced Flow Sessions - Persistent session-aware execution tracking
CREATE TABLE IF NOT EXISTS flow_sessions (
  id SERIAL PRIMARY KEY,
  session_id TEXT NOT NULL UNIQUE,
  flow_id INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'waiting', 'paused', 'completed', 'failed', 'abandoned', 'timeout')),

  -- Flow Cursor Management
  current_node_id TEXT,
  trigger_node_id TEXT NOT NULL,
  execution_path JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of node IDs
  branching_history JSONB NOT NULL DEFAULT '[]'::jsonb, -- Track conditional decisions

  -- Session State Management
  session_data JSONB NOT NULL DEFAULT '{}'::jsonb, -- Persistent session variables
  node_states JSONB NOT NULL DEFAULT '{}'::jsonb, -- Per-node state snapshots
  waiting_context JSONB, -- Context for nodes waiting for input

  -- Timing and Lifecycle
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_activity_at TIMESTAMP NOT NULL DEFAULT NOW(),
  paused_at TIMESTAMP,
  resumed_at TIMESTAMP,
  completed_at TIMESTAMP,
  expires_at TIMESTAMP, -- Session timeout

  -- Execution Metadata
  total_duration_ms INTEGER,
  node_execution_count INTEGER DEFAULT 0,
  user_interaction_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  last_error_message TEXT,

  -- Recovery and Debugging
  checkpoint_data JSONB, -- Periodic state snapshots
  debug_info JSONB, -- Execution debugging information

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Enhanced Flow Session Variables - Hierarchical variable management
CREATE TABLE IF NOT EXISTS flow_session_variables (
  id SERIAL PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES flow_sessions(session_id) ON DELETE CASCADE,
  variable_key TEXT NOT NULL,
  variable_value JSONB NOT NULL,
  variable_type TEXT NOT NULL DEFAULT 'string' CHECK (variable_type IN ('string', 'number', 'boolean', 'object', 'array')),
  scope TEXT NOT NULL DEFAULT 'session' CHECK (scope IN ('global', 'flow', 'node', 'user', 'session')),
  node_id TEXT, -- For node-scoped variables
  is_encrypted BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP, -- For temporary variables
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(session_id, variable_key)
);

-- Flow Session Cursors - Advanced cursor positioning
CREATE TABLE IF NOT EXISTS flow_session_cursors (
  id SERIAL PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES flow_sessions(session_id) ON DELETE CASCADE UNIQUE,
  current_node_id TEXT NOT NULL,
  previous_node_id TEXT,
  next_possible_nodes JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of possible next nodes
  branch_conditions JSONB NOT NULL DEFAULT '{}'::jsonb, -- Conditions for branching
  loop_state JSONB, -- State for loop nodes
  waiting_for_input BOOLEAN DEFAULT FALSE,
  input_expected_type TEXT, -- Expected input type
  input_validation_rules JSONB, -- Validation rules for input
  timeout_at TIMESTAMP, -- When this cursor times out
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Enhanced flow step executions with session support
ALTER TABLE flow_step_executions ADD COLUMN IF NOT EXISTS session_id TEXT REFERENCES flow_sessions(session_id) ON DELETE CASCADE;
ALTER TABLE flow_step_executions ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;
ALTER TABLE flow_step_executions ADD COLUMN IF NOT EXISTS max_retries INTEGER DEFAULT 0;
ALTER TABLE flow_step_executions DROP CONSTRAINT IF EXISTS flow_step_executions_status_check;
ALTER TABLE flow_step_executions ADD CONSTRAINT flow_step_executions_status_check CHECK (status IN ('running', 'completed', 'failed', 'skipped', 'waiting', 'timeout'));

-- Follow-up Message Scheduling System
CREATE TABLE IF NOT EXISTS follow_up_schedules (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL UNIQUE,
  session_id TEXT REFERENCES flow_sessions(session_id) ON DELETE CASCADE,
  flow_id INTEGER NOT NULL REFERENCES flows(id) ON DELETE CASCADE,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,

  -- Message Configuration
  message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document')),
  message_content TEXT,
  media_url TEXT,
  caption TEXT,
  template_id INTEGER, -- Reference to follow_up_templates if needed

  -- Scheduling Configuration
  trigger_event TEXT NOT NULL DEFAULT 'conversation_start' CHECK (trigger_event IN ('conversation_start', 'node_execution', 'specific_datetime', 'relative_delay')),
  trigger_node_id TEXT, -- For node_execution trigger
  delay_amount INTEGER, -- For relative delays (in minutes)
  delay_unit TEXT CHECK (delay_unit IN ('minutes', 'hours', 'days', 'weeks')),
  scheduled_for TIMESTAMP,
  specific_datetime TIMESTAMP,

  -- Status and Execution
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'sent', 'failed', 'cancelled', 'expired')),
  sent_at TIMESTAMP,
  failed_reason TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,

  -- Channel Information
  channel_type TEXT NOT NULL,
  channel_connection_id INTEGER REFERENCES channel_connections(id),

  -- Metadata
  variables JSONB DEFAULT '{}'::jsonb,
  execution_context JSONB DEFAULT '{}'::jsonb,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMP
);

-- Follow-up Message Templates
CREATE TABLE IF NOT EXISTS follow_up_templates (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'audio', 'document')),
  content TEXT NOT NULL,
  media_url TEXT,
  caption TEXT,
  default_delay_amount INTEGER DEFAULT 24,
  default_delay_unit TEXT DEFAULT 'hours' CHECK (default_delay_unit IN ('minutes', 'hours', 'days', 'weeks')),
  variables JSONB DEFAULT '[]'::jsonb, -- Array of variable names used in template
  category TEXT DEFAULT 'general',
  is_active BOOLEAN DEFAULT true,
  usage_count INTEGER DEFAULT 0,
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(company_id, name)
);

-- Follow-up Execution Log
CREATE TABLE IF NOT EXISTS follow_up_execution_log (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT NOT NULL REFERENCES follow_up_schedules(schedule_id) ON DELETE CASCADE,
  execution_attempt INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'retry', 'expired')),
  message_id TEXT, -- External message ID from channel
  error_message TEXT,
  execution_duration_ms INTEGER,
  executed_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Response tracking
  response_received BOOLEAN DEFAULT false,
  response_at TIMESTAMP,
  response_content TEXT
);

-- Indexes for Enhanced Flow Session Performance
CREATE INDEX IF NOT EXISTS idx_flow_sessions_conversation_status ON flow_sessions(conversation_id, status);
CREATE INDEX IF NOT EXISTS idx_flow_sessions_contact_id ON flow_sessions(contact_id);
CREATE INDEX IF NOT EXISTS idx_flow_sessions_company_id ON flow_sessions(company_id);
CREATE INDEX IF NOT EXISTS idx_flow_sessions_status ON flow_sessions(status);
CREATE INDEX IF NOT EXISTS idx_flow_sessions_expires_at ON flow_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_flow_sessions_last_activity ON flow_sessions(last_activity_at);

CREATE INDEX IF NOT EXISTS idx_flow_session_variables_session_id ON flow_session_variables(session_id);
CREATE INDEX IF NOT EXISTS idx_flow_session_variables_scope ON flow_session_variables(scope);
CREATE INDEX IF NOT EXISTS idx_flow_session_variables_expires_at ON flow_session_variables(expires_at);

CREATE INDEX IF NOT EXISTS idx_flow_session_cursors_session_id ON flow_session_cursors(session_id);
CREATE INDEX IF NOT EXISTS idx_flow_session_cursors_waiting ON flow_session_cursors(waiting_for_input);
CREATE INDEX IF NOT EXISTS idx_flow_session_cursors_timeout ON flow_session_cursors(timeout_at);

CREATE INDEX IF NOT EXISTS idx_flow_step_executions_session_id ON flow_step_executions(session_id);

-- Indexes for Follow-up Scheduling System
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_session_id ON follow_up_schedules(session_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_conversation_id ON follow_up_schedules(conversation_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_contact_id ON follow_up_schedules(contact_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_company_id ON follow_up_schedules(company_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_status ON follow_up_schedules(status);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_scheduled_for ON follow_up_schedules(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_trigger_event ON follow_up_schedules(trigger_event);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_expires_at ON follow_up_schedules(expires_at);
CREATE INDEX IF NOT EXISTS idx_follow_up_schedules_processing ON follow_up_schedules(status, scheduled_for) WHERE status = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_follow_up_templates_company_id ON follow_up_templates(company_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_templates_category ON follow_up_templates(company_id, category);
CREATE INDEX IF NOT EXISTS idx_follow_up_templates_active ON follow_up_templates(company_id, is_active) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_schedule_id ON follow_up_execution_log(schedule_id);
CREATE INDEX IF NOT EXISTS idx_follow_up_execution_log_status ON follow_up_execution_log(status, executed_at);

-- Comments for Enhanced Flow Session Tables
COMMENT ON TABLE flow_sessions IS 'Enhanced persistent flow execution sessions with state management';
COMMENT ON COLUMN flow_sessions.session_id IS 'Unique session identifier for tracking flow state';
COMMENT ON COLUMN flow_sessions.execution_path IS 'Array of node IDs representing the execution path';
COMMENT ON COLUMN flow_sessions.branching_history IS 'History of conditional branching decisions';
COMMENT ON COLUMN flow_sessions.session_data IS 'Persistent session variables and context data';
COMMENT ON COLUMN flow_sessions.node_states IS 'Per-node execution state snapshots';
COMMENT ON COLUMN flow_sessions.waiting_context IS 'Context data for nodes waiting for user input';
COMMENT ON COLUMN flow_sessions.expires_at IS 'Session expiration timestamp for cleanup';

COMMENT ON TABLE flow_session_variables IS 'Hierarchical variable management for flow sessions';
COMMENT ON COLUMN flow_session_variables.scope IS 'Variable scope: global, flow, node, user, or session';
COMMENT ON COLUMN flow_session_variables.is_encrypted IS 'Whether the variable value is encrypted';
COMMENT ON COLUMN flow_session_variables.expires_at IS 'Variable expiration timestamp';

COMMENT ON TABLE flow_session_cursors IS 'Advanced cursor positioning for flow navigation';
COMMENT ON COLUMN flow_session_cursors.next_possible_nodes IS 'Array of possible next node IDs';
COMMENT ON COLUMN flow_session_cursors.branch_conditions IS 'Conditions for conditional branching';
COMMENT ON COLUMN flow_session_cursors.loop_state IS 'State information for loop nodes';
COMMENT ON COLUMN flow_session_cursors.waiting_for_input IS 'Whether cursor is waiting for user input';
COMMENT ON COLUMN flow_session_cursors.input_validation_rules IS 'Validation rules for expected input';

-- Comments for Follow-up Scheduling System
COMMENT ON TABLE follow_up_schedules IS 'Scheduled follow-up messages for flow automation';
COMMENT ON COLUMN follow_up_schedules.schedule_id IS 'Unique identifier for the follow-up schedule';
COMMENT ON COLUMN follow_up_schedules.trigger_event IS 'Event that triggers the follow-up timer';
COMMENT ON COLUMN follow_up_schedules.delay_amount IS 'Delay amount in specified units';
COMMENT ON COLUMN follow_up_schedules.scheduled_for IS 'Calculated timestamp when message should be sent';
COMMENT ON COLUMN follow_up_schedules.variables IS 'Variables for message content replacement';
COMMENT ON COLUMN follow_up_schedules.execution_context IS 'Flow execution context at time of scheduling';

COMMENT ON TABLE follow_up_templates IS 'Reusable templates for follow-up messages';
COMMENT ON COLUMN follow_up_templates.variables IS 'Array of variable names used in template content';
COMMENT ON COLUMN follow_up_templates.usage_count IS 'Number of times template has been used';

COMMENT ON TABLE follow_up_execution_log IS 'Execution history and tracking for follow-up messages';
COMMENT ON COLUMN follow_up_execution_log.execution_attempt IS 'Attempt number for retry tracking';
COMMENT ON COLUMN follow_up_execution_log.response_received IS 'Whether recipient responded to follow-up';


CREATE TABLE IF NOT EXISTS team_invitations (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  invited_by_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'agent',
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS pipeline_stages (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  order_num INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deals (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  stage_id INTEGER REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  stage TEXT NOT NULL DEFAULT 'lead' CHECK (stage IN ('lead', 'qualified', 'contacted', 'demo_scheduled', 'proposal', 'negotiation', 'closed_won', 'closed_lost')),
  value INTEGER,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  due_date TIMESTAMP,
  assigned_to_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  description TEXT,
  tags TEXT[],
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  last_activity_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deal_activities (
  id SERIAL PRIMARY KEY,
  deal_id INTEGER NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION check_deal_stage_company_match()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.stage_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM pipeline_stages
      WHERE id = NEW.stage_id
      AND company_id = NEW.company_id
    ) THEN
      RAISE EXCEPTION 'Pipeline stage must belong to the same company as the deal';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_deal_stage_company_match ON deals;
CREATE TRIGGER trigger_check_deal_stage_company_match
  BEFORE INSERT OR UPDATE ON deals
  FOR EACH ROW
  EXECUTE FUNCTION check_deal_stage_company_match();


CREATE TABLE IF NOT EXISTS google_calendar_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  id_token TEXT,
  token_type TEXT,
  expiry_date TIMESTAMP,
  scope TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, company_id)
);


CREATE TABLE IF NOT EXISTS app_settings (
  id SERIAL PRIMARY KEY,
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS company_settings (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  value JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(company_id, key)
);


CREATE TABLE IF NOT EXISTS payment_transactions (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
  plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL,
  amount NUMERIC(10, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded', 'cancelled')),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('stripe', 'mercadopago', 'paypal', 'bank_transfer', 'other')),
  payment_intent_id TEXT,
  external_transaction_id TEXT,
  receipt_url TEXT,
  metadata JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS languages (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  native_name TEXT NOT NULL,
  flag_icon TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  is_default BOOLEAN DEFAULT FALSE,
  direction TEXT DEFAULT 'ltr' CHECK (direction IN ('ltr', 'rtl')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS translation_namespaces (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS translation_keys (
  id SERIAL PRIMARY KEY,
  namespace_id INTEGER NOT NULL REFERENCES translation_namespaces(id) ON DELETE CASCADE,
  key TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(namespace_id, key)
);

CREATE TABLE IF NOT EXISTS translations (
  id SERIAL PRIMARY KEY,
  key_id INTEGER NOT NULL REFERENCES translation_keys(id) ON DELETE CASCADE,
  language_id INTEGER NOT NULL REFERENCES languages(id) ON DELETE CASCADE,
  value TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(key_id, language_id)
);


CREATE TABLE IF NOT EXISTS "session" (
  "sid" VARCHAR NOT NULL COLLATE "default",
  "sess" JSON NOT NULL,
  "expire" TIMESTAMP(6) NOT NULL,
  CONSTRAINT "session_pkey" PRIMARY KEY ("sid")
);

-- Password Reset Tokens Table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(255) NOT NULL UNIQUE,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT
);

-- Index for efficient token lookup and cleanup
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);

CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "session" ("expire");


CREATE TABLE IF NOT EXISTS migrations (
  id SERIAL PRIMARY KEY,
  filename TEXT NOT NULL UNIQUE,
  checksum TEXT NOT NULL,
  success BOOLEAN DEFAULT TRUE,
  execution_time_ms INTEGER,
  executed_at TIMESTAMP DEFAULT NOW()
);


DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'company_id') THEN
    CREATE INDEX IF NOT EXISTS idx_users_company_id ON users(company_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'email') THEN
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role') THEN
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'language_preference') THEN
    CREATE INDEX IF NOT EXISTS idx_users_language_preference ON users(language_preference);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'company_id') THEN
    CREATE INDEX IF NOT EXISTS idx_conversations_company_id ON conversations(company_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'contact_id') THEN
    CREATE INDEX IF NOT EXISTS idx_conversations_contact_id ON conversations(contact_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'assigned_to_user_id') THEN
    CREATE INDEX IF NOT EXISTS idx_conversations_assigned_to_user_id ON conversations(assigned_to_user_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'status') THEN
    CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'conversations' AND column_name = 'last_message_at') THEN
    CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'conversation_id') THEN
    CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'direction') THEN
    CREATE INDEX IF NOT EXISTS idx_messages_direction ON messages(direction);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'created_at') THEN
    CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'sender_id')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'sender_type') THEN
    CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, sender_type);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'contacts' AND column_name = 'company_id') THEN
    CREATE INDEX IF NOT EXISTS idx_contacts_company_id ON contacts(company_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'contacts' AND column_name = 'identifier') THEN
    CREATE INDEX IF NOT EXISTS idx_contacts_identifier ON contacts(identifier);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'contacts' AND column_name = 'email') THEN
    CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'contacts' AND column_name = 'phone') THEN
    CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'channel_connections' AND column_name = 'company_id') THEN
    CREATE INDEX IF NOT EXISTS idx_channel_connections_company_id ON channel_connections(company_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'channel_connections' AND column_name = 'user_id') THEN
    CREATE INDEX IF NOT EXISTS idx_channel_connections_user_id ON channel_connections(user_id);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'channel_connections' AND column_name = 'channel_type') THEN
    CREATE INDEX IF NOT EXISTS idx_channel_connections_type ON channel_connections(channel_type);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'flows') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'flows' AND column_name = 'company_id') THEN
      CREATE INDEX IF NOT EXISTS idx_flows_company_id ON flows(company_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'flows' AND column_name = 'user_id') THEN
      CREATE INDEX IF NOT EXISTS idx_flows_user_id ON flows(user_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'flows' AND column_name = 'status') THEN
      CREATE INDEX IF NOT EXISTS idx_flows_status ON flows(status);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'deals') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'company_id') THEN
      CREATE INDEX IF NOT EXISTS idx_deals_company_id ON deals(company_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'contact_id') THEN
      CREATE INDEX IF NOT EXISTS idx_deals_contact_id ON deals(contact_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'stage_id') THEN
      CREATE INDEX IF NOT EXISTS idx_deals_stage_id ON deals(stage_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'assigned_to_user_id') THEN
      CREATE INDEX IF NOT EXISTS idx_deals_assigned_to_user_id ON deals(assigned_to_user_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'deals' AND column_name = 'status') THEN
      CREATE INDEX IF NOT EXISTS idx_deals_status ON deals(status);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pipeline_stages') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'pipeline_stages' AND column_name = 'company_id') THEN
      CREATE INDEX IF NOT EXISTS idx_pipeline_stages_company_id ON pipeline_stages(company_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'pipeline_stages' AND column_name = 'order_num') THEN
      CREATE INDEX IF NOT EXISTS idx_pipeline_stages_order ON pipeline_stages(order_num);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'team_invitations') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'team_invitations' AND column_name = 'company_id') THEN
      CREATE INDEX IF NOT EXISTS idx_team_invitations_company_id ON team_invitations(company_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'team_invitations' AND column_name = 'email') THEN
      CREATE INDEX IF NOT EXISTS idx_team_invitations_email ON team_invitations(email);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'team_invitations' AND column_name = 'status') THEN
      CREATE INDEX IF NOT EXISTS idx_team_invitations_status ON team_invitations(status);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'team_invitations' AND column_name = 'token') THEN
      CREATE INDEX IF NOT EXISTS idx_team_invitations_token ON team_invitations(token);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'company_settings') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'company_settings' AND column_name = 'company_id') THEN
      CREATE INDEX IF NOT EXISTS idx_company_settings_company_id ON company_settings(company_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'company_settings' AND column_name = 'key') THEN
      CREATE INDEX IF NOT EXISTS idx_company_settings_key ON company_settings(key);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'translation_keys') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'translation_keys' AND column_name = 'namespace_id') THEN
      CREATE INDEX IF NOT EXISTS idx_translation_keys_namespace ON translation_keys(namespace_id);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'translations') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'translations' AND column_name = 'key_id') THEN
      CREATE INDEX IF NOT EXISTS idx_translations_key_id ON translations(key_id);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'translations' AND column_name = 'language_id') THEN
      CREATE INDEX IF NOT EXISTS idx_translations_language_id ON translations(language_id);
    END IF;
  END IF;
END $$;


DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM plans LIMIT 1) THEN
    INSERT INTO plans (name, description, price, max_users, max_contacts, max_channels, max_flows, max_campaigns, max_campaign_recipients, campaign_features, features, is_active)
    VALUES
      ('Free', 'Basic plan for small teams', 0, 3, 500, 2, 1, 2, 100, '["basic_campaigns"]'::jsonb, '["Basic chat", "Contact management", "1 flow"]'::jsonb, TRUE),
      ('Starter', 'Perfect for growing businesses', 29, 10, 2000, 5, 5, 10, 1000, '["basic_campaigns", "templates", "segments"]'::jsonb, '["Basic chat", "Contact management", "5 flows", "Email notifications", "Basic analytics"]'::jsonb, TRUE),
      ('Professional', 'Advanced features for established businesses', 79, 25, 10000, 10, 999, 50, 5000, '["basic_campaigns", "templates", "segments", "advanced_scheduling", "anti_ban_protection"]'::jsonb, '["All Starter features", "Advanced analytics", "Priority support", "Custom integrations", "Team collaboration", "Unlimited flows"]'::jsonb, TRUE),
      ('Enterprise', 'Custom solution for large organizations', 199, 999, 999999, 999, 999, 200, 25000, '["basic_campaigns", "templates", "segments", "advanced_scheduling", "anti_ban_protection", "multi_account_support", "campaign_analytics"]'::jsonb, '["All Professional features", "Custom branding", "Dedicated support", "SLA", "Advanced security", "Custom integrations"]'::jsonb, TRUE);
  END IF;
END $$;

INSERT INTO companies (name, slug, plan, max_users, primary_color, active)
VALUES ('System', 'system', 'enterprise', 999, '#333235', TRUE)
ON CONFLICT (slug) DO NOTHING;

-- Create default admin user
-- Password: Admin@123456 (CHANGE THIS AFTER FIRST LOGIN!)
INSERT INTO users (username, password, full_name, email, role, is_super_admin, company_id)
SELECT
  'admin',
  '29afa0d245666f74f88337abf5f76577d07a99132f5d5d6cc7902ce2ef2df5d13b545b36c5e7efd5830eeb243bc4dbb3b68fe560a9c1ed2e3de9af548bc2f66d.aa1da567baf11c4a100b592c24bcb9a8',
  'Admin User',
  'admin@app.com',
  'super_admin',
  TRUE,
  id
FROM companies
WHERE slug = 'system'
ON CONFLICT (username) DO NOTHING;

INSERT INTO languages (code, name, native_name, flag_icon, is_active, is_default, direction)
VALUES
  ('en', 'English', 'English', '🇺🇸', TRUE, TRUE, 'ltr'),
  ('es', 'Spanish', 'Español', '🇪🇸', TRUE, FALSE, 'ltr')
ON CONFLICT (code) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM translation_namespaces LIMIT 1) THEN
    INSERT INTO translation_namespaces (name, description)
    VALUES
      ('common', 'Common UI elements and messages'),
      ('auth', 'Authentication and authorization'),
      ('dashboard', 'Dashboard and main interface'),
      ('conversations', 'Conversation management'),
      ('contacts', 'Contact management'),
      ('flows', 'Flow builder and automation'),
      ('settings', 'Application settings'),
      ('admin', 'Admin panel'),
      ('errors', 'Error messages'),
      ('notifications', 'Notification messages');
  END IF;
END $$;


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

SELECT create_default_role_permissions(id) FROM companies WHERE slug = 'system';


CREATE OR REPLACE FUNCTION create_company_role_permissions()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_default_role_permissions(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_company_role_permissions ON companies;
CREATE TRIGGER trigger_create_company_role_permissions
  AFTER INSERT ON companies
  FOR EACH ROW
  EXECUTE FUNCTION create_company_role_permissions();


CREATE OR REPLACE FUNCTION create_default_pipeline_stages(company_id_param INTEGER)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pipeline_stages WHERE company_id = company_id_param LIMIT 1) THEN
    INSERT INTO pipeline_stages (company_id, name, color, order_num)
    VALUES
      (company_id_param, 'Lead', '#333235', 1),
      (company_id_param, 'Qualified', '#8B5CF6', 2),
      (company_id_param, 'Contacted', '#EC4899', 3),
      (company_id_param, 'Demo Scheduled', '#F59E0B', 4),
      (company_id_param, 'Proposal', '#10B981', 5),
      (company_id_param, 'Negotiation', '#3B82F6', 6),
      (company_id_param, 'Closed Won', '#059669', 7),
      (company_id_param, 'Closed Lost', '#DC2626', 8);
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_company_pipeline_stages()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM create_default_pipeline_stages(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_company_pipeline_stages ON companies;
CREATE TRIGGER trigger_create_company_pipeline_stages
  AFTER INSERT ON companies
  FOR EACH ROW
  EXECUTE FUNCTION create_company_pipeline_stages();

SELECT create_default_pipeline_stages(id) FROM companies WHERE slug = 'system';






CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_conversation_external_id
ON messages(conversation_id, external_id)
WHERE external_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_metadata_message_id
ON messages USING GIN ((metadata->'messageId'))
WHERE metadata->'messageId' IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_direction_created
ON messages(conversation_id, direction, created_at DESC);

CREATE OR REPLACE FUNCTION get_whatsapp_message_id(metadata_json JSONB)
RETURNS TEXT AS $$
BEGIN
  RETURN metadata_json->>'messageId';
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_whatsapp_dedup
ON messages(conversation_id, get_whatsapp_message_id(metadata))
WHERE metadata->>'messageId' IS NOT NULL;


-- 🔧 REMOVED: Content-based duplicate constraint
-- This was preventing legitimate duplicate messages when users intentionally
-- send the same content multiple times from WhatsApp mobile app
-- System duplicates are now handled by WhatsApp message ID constraint only


-- Media message deduplication (for messages with media_url)
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_media_dedup
ON messages(conversation_id, content, type, direction, media_url,
           floor(extract(epoch from created_at) / 5)) -- 5-second buckets for media
WHERE media_url IS NOT NULL AND length(content) > 0;

-- 🔧 REMOVED: Overly aggressive rapid duplicate constraint
-- This was preventing legitimate duplicate messages when users intentionally
-- send the same content multiple times from WhatsApp mobile app
-- System duplicates are now handled by WhatsApp message ID constraint only



CREATE INDEX IF NOT EXISTS idx_messages_read_status
ON messages(conversation_id, direction, read_at)
WHERE direction = 'inbound' AND read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_unread_count
ON conversations(unread_count)
WHERE unread_count > 0;

CREATE INDEX IF NOT EXISTS idx_messages_external_id
ON messages(external_id)
WHERE external_id IS NOT NULL;

CREATE OR REPLACE FUNCTION calculate_unread_count(conversation_id_param INTEGER)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM messages
    WHERE conversation_id = conversation_id_param
    AND direction = 'inbound'
    AND read_at IS NULL
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_conversation_unread_count(conversation_id_param INTEGER)
RETURNS VOID AS $$
DECLARE
  new_count INTEGER;
BEGIN
  new_count := calculate_unread_count(conversation_id_param);

  UPDATE conversations
  SET unread_count = new_count,
      updated_at = NOW()
  WHERE id = conversation_id_param;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_update_unread_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.direction = 'inbound' THEN
    PERFORM update_conversation_unread_count(NEW.conversation_id);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.direction = 'inbound' THEN
    IF (OLD.read_at IS NULL AND NEW.read_at IS NOT NULL) OR
       (OLD.read_at IS NOT NULL AND NEW.read_at IS NULL) THEN
      PERFORM update_conversation_unread_count(NEW.conversation_id);
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' AND OLD.direction = 'inbound' THEN
    PERFORM update_conversation_unread_count(OLD.conversation_id);
    RETURN OLD;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_messages_unread_count ON messages;
CREATE TRIGGER trigger_messages_unread_count
  AFTER INSERT OR UPDATE OR DELETE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_unread_count();

UPDATE conversations
SET unread_count = (
  SELECT COUNT(*)
  FROM messages
  WHERE messages.conversation_id = conversations.id
  AND messages.direction = 'inbound'
  AND messages.read_at IS NULL
);

COMMENT ON COLUMN messages.read_at IS 'Timestamp when the message was read by the user (only for inbound messages)';
COMMENT ON COLUMN conversations.unread_count IS 'Cached count of unread inbound messages for performance';


-- Auto-Update System Tables
-- Create update status enum
DO $$ BEGIN
    CREATE TYPE update_status AS ENUM ('pending', 'downloading', 'validating', 'applying', 'completed', 'failed', 'rolled_back');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- System Updates table
CREATE TABLE IF NOT EXISTS system_updates (
    id SERIAL PRIMARY KEY,
    version TEXT NOT NULL,
    release_notes TEXT,
    download_url TEXT NOT NULL,
    package_hash TEXT,
    package_size INTEGER,
    status update_status NOT NULL DEFAULT 'pending',
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    rollback_data JSONB,
    migration_scripts JSONB DEFAULT '[]',
    backup_path TEXT,
    progress_percentage INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);



-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_system_updates_status ON system_updates(status);
CREATE INDEX IF NOT EXISTS idx_system_updates_created_at ON system_updates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_updates_version ON system_updates(version);



-- Create trigger to update updated_at timestamp for auto-update tables
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to auto-update tables
DROP TRIGGER IF EXISTS update_system_updates_updated_at ON system_updates;
CREATE TRIGGER update_system_updates_updated_at
    BEFORE UPDATE ON system_updates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();





-- Add comments for documentation
COMMENT ON TABLE system_updates IS 'Tracks system update history and progress';


COMMENT ON COLUMN system_updates.version IS 'Version number of the update (e.g., 1.2.0)';
COMMENT ON COLUMN system_updates.release_notes IS 'Human-readable description of changes';
COMMENT ON COLUMN system_updates.download_url IS 'URL to download the update package';
COMMENT ON COLUMN system_updates.package_hash IS 'SHA256 hash for package verification';
COMMENT ON COLUMN system_updates.package_size IS 'Size of update package in bytes';
COMMENT ON COLUMN system_updates.status IS 'Current status of the update process';
COMMENT ON COLUMN system_updates.migration_scripts IS 'Array of database migration scripts to run';
COMMENT ON COLUMN system_updates.backup_path IS 'Path to backup created before update';
COMMENT ON COLUMN system_updates.progress_percentage IS 'Update progress from 0-100';



ANALYZE;







CREATE TABLE IF NOT EXISTS backup_schedules (
  id SERIAL PRIMARY KEY,
  schedule_id TEXT UNIQUE NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly')),
  time TEXT NOT NULL, 
  day_of_week INTEGER CHECK (day_of_week >= 0 AND day_of_week <= 6),
  day_of_month INTEGER CHECK (day_of_month >= 1 AND day_of_month <= 31),
  enabled BOOLEAN DEFAULT TRUE,
  storage_locations JSONB DEFAULT '["local"]',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS backup_logs (
  id SERIAL PRIMARY KEY,
  log_id TEXT UNIQUE NOT NULL,
  schedule_id TEXT,
  backup_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
  timestamp TIMESTAMP DEFAULT NOW(),
  error_message TEXT,
  metadata JSONB
);


CREATE INDEX IF NOT EXISTS idx_backup_schedules_enabled ON backup_schedules(enabled);
CREATE INDEX IF NOT EXISTS idx_backup_logs_timestamp ON backup_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_backup_logs_status ON backup_logs(status);


CREATE OR REPLACE FUNCTION update_backup_schedule_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_backup_schedule_updated_at
  BEFORE UPDATE ON backup_schedules
  FOR EACH ROW
  EXECUTE FUNCTION update_backup_schedule_timestamp();









CREATE TABLE IF NOT EXISTS campaign_templates (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  created_by_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT DEFAULT 'general',
  content TEXT NOT NULL,
  content_type TEXT DEFAULT 'text', 
  media_urls JSONB DEFAULT '[]'::jsonb,
  media_metadata JSONB DEFAULT '{}'::jsonb, 
  variables JSONB DEFAULT '[]'::jsonb, 
  channel_type TEXT NOT NULL DEFAULT 'whatsapp',
  is_active BOOLEAN DEFAULT TRUE,
  usage_count INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS contact_segments (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  created_by_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  criteria JSONB NOT NULL, 
  contact_count INTEGER DEFAULT 0,
  last_updated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS campaigns (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  created_by_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template_id INTEGER REFERENCES campaign_templates(id) ON DELETE SET NULL,
  segment_id INTEGER REFERENCES contact_segments(id) ON DELETE SET NULL,

  name TEXT NOT NULL,
  description TEXT,
  channel_type TEXT NOT NULL DEFAULT 'whatsapp',
  channel_id INTEGER REFERENCES channel_connections(id) ON DELETE SET NULL,
  channel_ids JSONB DEFAULT '[]'::jsonb, 

  
  content TEXT NOT NULL,
  media_urls JSONB DEFAULT '[]'::jsonb,
  variables JSONB DEFAULT '{}'::jsonb,

  
  campaign_type TEXT NOT NULL DEFAULT 'immediate' CHECK (campaign_type IN ('immediate', 'scheduled', 'drip')),
  scheduled_at TIMESTAMP,
  timezone TEXT DEFAULT 'UTC',
  drip_settings JSONB, 

  
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'running', 'paused', 'completed', 'cancelled', 'failed')),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  paused_at TIMESTAMP,

  
  total_recipients INTEGER DEFAULT 0,
  processed_recipients INTEGER DEFAULT 0,
  successful_sends INTEGER DEFAULT 0,
  failed_sends INTEGER DEFAULT 0,

  
  rate_limit_settings JSONB DEFAULT '{
    "messages_per_minute": 10,
    "messages_per_hour": 200,
    "messages_per_day": 1000,
    "delay_between_messages": 6,
    "random_delay_range": [3, 10],
    "humanization_enabled": true
  }'::jsonb,

  
  compliance_settings JSONB DEFAULT '{
    "require_opt_out": true,
    "spam_check_enabled": true,
    "content_filter_enabled": true
  }'::jsonb,

  
  anti_ban_settings JSONB DEFAULT '{
    "enabled": true,
    "mode": "moderate",
    "businessHoursOnly": false,
    "respectWeekends": false,
    "randomizeDelay": true,
    "minDelay": 3,
    "maxDelay": 15,
    "accountRotation": true,
    "cooldownPeriod": 30,
    "messageVariation": false
  }'::jsonb,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS campaign_recipients (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  contact_id INTEGER NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

  
  personalized_content TEXT,
  variables JSONB DEFAULT '{}'::jsonb,

  
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'delivered', 'read', 'failed', 'skipped')),
  scheduled_at TIMESTAMP,
  sent_at TIMESTAMP,
  delivered_at TIMESTAMP,
  read_at TIMESTAMP,
  failed_at TIMESTAMP,

  
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,

  
  external_message_id TEXT,
  conversation_id INTEGER REFERENCES conversations(id) ON DELETE SET NULL,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(campaign_id, contact_id)
);


CREATE TABLE IF NOT EXISTS campaign_messages (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  recipient_id INTEGER NOT NULL REFERENCES campaign_recipients(id) ON DELETE CASCADE,
  message_id INTEGER REFERENCES messages(id) ON DELETE SET NULL,

  
  content TEXT NOT NULL,
  media_urls JSONB DEFAULT '[]'::jsonb,
  message_type TEXT DEFAULT 'text',

  
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'failed')),
  sent_at TIMESTAMP,
  delivered_at TIMESTAMP,
  read_at TIMESTAMP,
  failed_at TIMESTAMP,

  
  whatsapp_message_id TEXT,
  whatsapp_status TEXT,

  
  error_code TEXT,
  error_message TEXT,

  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS campaign_analytics (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,

  
  recorded_at TIMESTAMP NOT NULL DEFAULT NOW(),

  
  total_recipients INTEGER DEFAULT 0,
  messages_sent INTEGER DEFAULT 0,
  messages_delivered INTEGER DEFAULT 0,
  messages_read INTEGER DEFAULT 0,
  messages_failed INTEGER DEFAULT 0,

  
  delivery_rate DECIMAL(5,2) DEFAULT 0.00,
  read_rate DECIMAL(5,2) DEFAULT 0.00,
  failure_rate DECIMAL(5,2) DEFAULT 0.00,

  
  avg_delivery_time INTEGER, 
  avg_read_time INTEGER, 

  
  estimated_cost DECIMAL(10,4) DEFAULT 0.0000,

  
  metrics_data JSONB DEFAULT '{}'::jsonb
);


CREATE TABLE IF NOT EXISTS whatsapp_accounts (
  id SERIAL PRIMARY KEY,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  channel_id INTEGER REFERENCES channel_connections(id) ON DELETE SET NULL,

  
  account_name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  account_type TEXT NOT NULL DEFAULT 'unofficial' CHECK (account_type IN ('official', 'unofficial')),

  
  session_data JSONB,
  qr_code TEXT,
  connection_status TEXT DEFAULT 'disconnected' CHECK (connection_status IN ('connected', 'disconnected', 'connecting', 'error', 'banned')),

  
  last_activity_at TIMESTAMP,
  message_count_today INTEGER DEFAULT 0,
  message_count_hour INTEGER DEFAULT 0,
  warning_count INTEGER DEFAULT 0,
  restriction_count INTEGER DEFAULT 0,

  
  rate_limits JSONB DEFAULT '{
    "max_messages_per_minute": 10,
    "max_messages_per_hour": 200,
    "max_messages_per_day": 1000,
    "cooldown_period": 300,
    "humanization_enabled": true
  }'::jsonb,

  
  health_score INTEGER DEFAULT 100, 
  last_health_check TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,

  
  rotation_group TEXT,
  priority INTEGER DEFAULT 1,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  UNIQUE(company_id, phone_number)
);


CREATE TABLE IF NOT EXISTS whatsapp_account_logs (
  id SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES whatsapp_accounts(id) ON DELETE CASCADE,

  
  event_type TEXT NOT NULL, 
  event_data JSONB,
  message TEXT,

  
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),

  
  messages_sent_today INTEGER DEFAULT 0,
  health_score INTEGER DEFAULT 100,

  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS campaign_queue (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  recipient_id INTEGER NOT NULL REFERENCES campaign_recipients(id) ON DELETE CASCADE,
  account_id INTEGER REFERENCES channel_connections(id) ON DELETE SET NULL,

  
  priority INTEGER DEFAULT 1,
  scheduled_for TIMESTAMP NOT NULL,
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,

  
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,

  
  error_message TEXT,
  last_error_at TIMESTAMP,

  
  metadata JSONB DEFAULT '{}'::jsonb,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);


COMMENT ON COLUMN campaign_queue.account_id IS 'References channel_connections.id - the WhatsApp connection to use for this queue item';


CREATE INDEX IF NOT EXISTS idx_campaign_templates_company_id ON campaign_templates(company_id);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_category ON campaign_templates(category);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_channel_type ON campaign_templates(channel_type);

CREATE INDEX IF NOT EXISTS idx_contact_segments_company_id ON contact_segments(company_id);

CREATE INDEX IF NOT EXISTS idx_campaigns_company_id ON campaigns(company_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_channel_type ON campaigns(channel_type);
CREATE INDEX IF NOT EXISTS idx_campaigns_scheduled_at ON campaigns(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_by_id ON campaigns(created_by_id);

CREATE INDEX IF NOT EXISTS idx_campaign_recipients_campaign_id ON campaign_recipients(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_contact_id ON campaign_recipients(contact_id);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_status ON campaign_recipients(status);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_scheduled_at ON campaign_recipients(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_campaign_messages_campaign_id ON campaign_messages(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_messages_recipient_id ON campaign_messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_campaign_messages_status ON campaign_messages(status);
CREATE INDEX IF NOT EXISTS idx_campaign_messages_whatsapp_message_id ON campaign_messages(whatsapp_message_id);

CREATE INDEX IF NOT EXISTS idx_campaign_analytics_campaign_id ON campaign_analytics(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_analytics_recorded_at ON campaign_analytics(recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_company_id ON whatsapp_accounts(company_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_connection_status ON whatsapp_accounts(connection_status);
CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_health_score ON whatsapp_accounts(health_score);
CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_rotation_group ON whatsapp_accounts(rotation_group);

CREATE INDEX IF NOT EXISTS idx_whatsapp_account_logs_account_id ON whatsapp_account_logs(account_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_account_logs_event_type ON whatsapp_account_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_whatsapp_account_logs_severity ON whatsapp_account_logs(severity);
CREATE INDEX IF NOT EXISTS idx_whatsapp_account_logs_created_at ON whatsapp_account_logs(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_campaign_queue_campaign_id ON campaign_queue(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_queue_status ON campaign_queue(status);
CREATE INDEX IF NOT EXISTS idx_campaign_queue_scheduled_for ON campaign_queue(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_campaign_queue_priority ON campaign_queue(priority DESC);
CREATE INDEX IF NOT EXISTS idx_campaign_queue_account_id ON campaign_queue(account_id);






CREATE OR REPLACE FUNCTION update_campaign_stats()
RETURNS TRIGGER AS $$
BEGIN
  
  IF TG_TABLE_NAME = 'campaign_recipients' THEN
    UPDATE campaigns
    SET
      processed_recipients = (
        SELECT COUNT(*) FROM campaign_recipients
        WHERE campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id)
        AND status != 'pending'
      ),
      successful_sends = (
        SELECT COUNT(*) FROM campaign_recipients
        WHERE campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id)
        AND status IN ('sent', 'delivered', 'read')
      ),
      failed_sends = (
        SELECT COUNT(*) FROM campaign_recipients
        WHERE campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id)
        AND status = 'failed'
      ),
      updated_at = NOW()
    WHERE id = COALESCE(NEW.campaign_id, OLD.campaign_id);
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_update_campaign_stats ON campaign_recipients;
CREATE TRIGGER trigger_update_campaign_stats
  AFTER INSERT OR UPDATE OR DELETE ON campaign_recipients
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_stats();


CREATE OR REPLACE FUNCTION update_template_usage()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.template_id IS NOT NULL THEN
    UPDATE campaign_templates
    SET usage_count = usage_count + 1,
        updated_at = NOW()
    WHERE id = NEW.template_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_update_template_usage ON campaigns;
CREATE TRIGGER trigger_update_template_usage
  AFTER INSERT ON campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_template_usage();


CREATE OR REPLACE FUNCTION update_segment_count()
RETURNS TRIGGER AS $$
DECLARE
  segment_record RECORD;
  calculated_contact_count INTEGER;
BEGIN
  
  FOR segment_record IN
    SELECT id, criteria FROM contact_segments
    WHERE company_id = COALESCE(NEW.company_id, OLD.company_id)
  LOOP
    
    
    SELECT COUNT(*) INTO calculated_contact_count
    FROM contacts
    WHERE company_id = COALESCE(NEW.company_id, OLD.company_id)
    AND is_active = true;

    UPDATE contact_segments
    SET contact_count = calculated_contact_count,
        last_updated_at = NOW(),
        updated_at = NOW()
    WHERE id = segment_record.id;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_update_segment_count ON contacts;
CREATE TRIGGER trigger_update_segment_count
  AFTER INSERT OR UPDATE OR DELETE ON contacts
  FOR EACH ROW
  EXECUTE FUNCTION update_segment_count();


CREATE OR REPLACE FUNCTION update_whatsapp_account_health()
RETURNS TRIGGER AS $$
DECLARE
  current_health INTEGER;
  warning_penalty INTEGER := 10;
  restriction_penalty INTEGER := 25;
BEGIN
  
  current_health := 100 - (NEW.warning_count * warning_penalty) - (NEW.restriction_count * restriction_penalty);
  current_health := GREATEST(0, LEAST(100, current_health));

  
  UPDATE whatsapp_accounts
  SET health_score = current_health,
      last_health_check = NOW(),
      updated_at = NOW()
  WHERE id = NEW.id;

  
  INSERT INTO whatsapp_account_logs (account_id, event_type, event_data, message, severity, health_score)
  VALUES (
    NEW.id,
    'health_check',
    jsonb_build_object(
      'previous_health', OLD.health_score,
      'new_health', current_health,
      'warnings', NEW.warning_count,
      'restrictions', NEW.restriction_count
    ),
    'Health score updated',
    CASE
      WHEN current_health < 30 THEN 'critical'
      WHEN current_health < 60 THEN 'warning'
      ELSE 'info'
    END,
    current_health
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_update_whatsapp_account_health ON whatsapp_accounts;
CREATE TRIGGER trigger_update_whatsapp_account_health
  AFTER UPDATE OF warning_count, restriction_count ON whatsapp_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_whatsapp_account_health();


CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trigger_campaign_templates_updated_at ON campaign_templates;
CREATE TRIGGER trigger_campaign_templates_updated_at
  BEFORE UPDATE ON campaign_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_contact_segments_updated_at ON contact_segments;
CREATE TRIGGER trigger_contact_segments_updated_at
  BEFORE UPDATE ON contact_segments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_campaigns_updated_at ON campaigns;
CREATE TRIGGER trigger_campaigns_updated_at
  BEFORE UPDATE ON campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_campaign_recipients_updated_at ON campaign_recipients;
CREATE TRIGGER trigger_campaign_recipients_updated_at
  BEFORE UPDATE ON campaign_recipients
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_whatsapp_accounts_updated_at ON whatsapp_accounts;
CREATE TRIGGER trigger_whatsapp_accounts_updated_at
  BEFORE UPDATE ON whatsapp_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_campaign_queue_updated_at ON campaign_queue;
CREATE TRIGGER trigger_campaign_queue_updated_at
  BEFORE UPDATE ON campaign_queue
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();








DO $$
DECLARE
  company_record RECORD;
  current_permissions jsonb;
BEGIN
  FOR company_record IN SELECT id FROM companies LOOP

    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'admin';


    current_permissions := current_permissions || '{
      "view_campaigns": true,
      "create_campaigns": true,
      "edit_campaigns": true,
      "delete_campaigns": true,
      "manage_templates": true,
      "manage_segments": true,
      "view_campaign_analytics": true,
      "manage_whatsapp_accounts": true,
      "configure_channels": true
    }'::jsonb;

    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'admin', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET permissions = current_permissions;


    SELECT COALESCE(permissions, '{}'::jsonb) INTO current_permissions
    FROM role_permissions
    WHERE company_id = company_record.id AND role = 'agent';


    current_permissions := current_permissions || '{
      "view_campaigns": false,
      "create_campaigns": false,
      "edit_campaigns": false,
      "delete_campaigns": false,
      "manage_templates": false,
      "manage_segments": false,
      "view_campaign_analytics": false,
      "manage_whatsapp_accounts": false,
      "configure_channels": false
    }'::jsonb;

    INSERT INTO role_permissions (company_id, role, permissions)
    VALUES (company_record.id, 'agent', current_permissions)
    ON CONFLICT (company_id, role)
    DO UPDATE SET permissions = current_permissions;
  END LOOP;

  RAISE NOTICE 'Campaign permissions added to all companies successfully!';
END $$;

-- Add task permissions to all existing companies
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
    DO UPDATE SET permissions = current_permissions;

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
    DO UPDATE SET permissions = current_permissions;
  END LOOP;

  RAISE NOTICE 'Task permissions added to all companies successfully!';
END $$;







CREATE INDEX IF NOT EXISTS idx_conversations_company_last_message
ON conversations(company_id, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_contact_channel
ON conversations(contact_id, channel_id);

CREATE INDEX IF NOT EXISTS idx_conversations_status_company
ON conversations(status, company_id);


CREATE INDEX IF NOT EXISTS idx_messages_conversation_unread
ON messages(conversation_id, direction, read_at)
WHERE direction = 'inbound' AND read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_timestamp
ON messages(conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_direction_status
ON messages(direction, status);


CREATE INDEX IF NOT EXISTS idx_contacts_company_active
ON contacts(company_id, is_active);

CREATE INDEX IF NOT EXISTS idx_contacts_identifier_type
ON contacts(identifier, identifier_type);

CREATE INDEX IF NOT EXISTS idx_contacts_phone_company
ON contacts(phone, company_id)
WHERE phone IS NOT NULL AND phone != '';


CREATE INDEX IF NOT EXISTS idx_campaigns_company_status
ON campaigns(company_id, status);

CREATE INDEX IF NOT EXISTS idx_campaigns_created_at
ON campaigns(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_campaign_queue_status_scheduled
ON campaign_queue(status, scheduled_for);

CREATE INDEX IF NOT EXISTS idx_campaign_queue_campaign_status
ON campaign_queue(campaign_id, status);

CREATE INDEX IF NOT EXISTS idx_campaign_recipients_campaign_status
ON campaign_recipients(campaign_id, status);


CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_company_active
ON whatsapp_accounts(company_id, is_active);

CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_health_activity
ON whatsapp_accounts(health_score, last_activity_at);

CREATE INDEX IF NOT EXISTS idx_whatsapp_accounts_message_counts
ON whatsapp_accounts(message_count_today, message_count_hour);


CREATE INDEX IF NOT EXISTS idx_flows_company_status
ON flows(company_id, status);

CREATE INDEX IF NOT EXISTS idx_flow_assignments_channel_active
ON flow_assignments(channel_id, is_active);


CREATE INDEX IF NOT EXISTS idx_flow_executions_flow_id
ON flow_executions(flow_id);

CREATE INDEX IF NOT EXISTS idx_flow_executions_conversation_id
ON flow_executions(conversation_id);

CREATE INDEX IF NOT EXISTS idx_flow_executions_company_status
ON flow_executions(company_id, status);

CREATE INDEX IF NOT EXISTS idx_flow_executions_started_at
ON flow_executions(started_at);

CREATE INDEX IF NOT EXISTS idx_flow_executions_execution_id
ON flow_executions(execution_id);

CREATE INDEX IF NOT EXISTS idx_flow_step_executions_flow_execution_id
ON flow_step_executions(flow_execution_id);

CREATE INDEX IF NOT EXISTS idx_flow_step_executions_node_id
ON flow_step_executions(node_id, status);


CREATE INDEX IF NOT EXISTS idx_channel_connections_user_type
ON channel_connections(user_id, channel_type);

CREATE INDEX IF NOT EXISTS idx_channel_connections_company_status
ON channel_connections(company_id, status);


CREATE INDEX IF NOT EXISTS idx_users_company_role
ON users(company_id, role);

CREATE INDEX IF NOT EXISTS idx_users_username_active
ON users(username)
WHERE is_super_admin = false;


CREATE INDEX IF NOT EXISTS idx_notes_contact_created
ON notes(contact_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_deal_activities_deal_created
ON deal_activities(deal_id, created_at DESC);


CREATE INDEX IF NOT EXISTS idx_conversations_unread_company
ON conversations(company_id, unread_count)
WHERE unread_count > 0;

CREATE INDEX IF NOT EXISTS idx_messages_outbound_recent
ON messages(conversation_id, direction, created_at DESC)
WHERE direction = 'outbound';


CREATE INDEX IF NOT EXISTS idx_contacts_active_company
ON contacts(company_id, created_at DESC)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_campaigns_running
ON campaigns(company_id, created_at DESC)
WHERE status IN ('running', 'scheduled');


CREATE INDEX IF NOT EXISTS idx_contacts_normalized_phone
ON contacts(company_id, (REGEXP_REPLACE(phone, '[^0-9+]', '', 'g')))
WHERE phone IS NOT NULL AND phone != '';


CREATE INDEX IF NOT EXISTS idx_campaign_queue_processing
ON campaign_queue(status, scheduled_for, priority)
WHERE status = 'pending';


CREATE INDEX IF NOT EXISTS idx_companies_subscription_status ON companies(subscription_status);
CREATE INDEX IF NOT EXISTS idx_companies_plan_id ON companies(plan_id);
CREATE INDEX IF NOT EXISTS idx_companies_subscription_end_date ON companies(subscription_end_date);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_company_id ON payment_transactions(company_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_created_at ON payment_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_payment_method ON payment_transactions(payment_method);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_company_status ON payment_transactions(company_id, status);

-- Group chat indexes
CREATE INDEX IF NOT EXISTS idx_conversations_group_jid ON conversations(group_jid) WHERE is_group = TRUE;
CREATE INDEX IF NOT EXISTS idx_conversations_is_group ON conversations(is_group);
CREATE INDEX IF NOT EXISTS idx_conversations_group_company ON conversations(company_id, is_group);

CREATE INDEX IF NOT EXISTS idx_group_participants_conversation ON group_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_group_participants_contact ON group_participants(contact_id);
CREATE INDEX IF NOT EXISTS idx_group_participants_jid ON group_participants(participant_jid);
CREATE INDEX IF NOT EXISTS idx_group_participants_active ON group_participants(conversation_id, is_active);
CREATE INDEX IF NOT EXISTS idx_group_participants_admin ON group_participants(conversation_id, is_admin);

CREATE INDEX IF NOT EXISTS idx_messages_group_participant ON messages(group_participant_jid) WHERE group_participant_jid IS NOT NULL;


COMMENT ON INDEX idx_conversations_company_last_message IS 'Optimizes conversation listing by company with latest message first';
COMMENT ON INDEX idx_messages_conversation_unread IS 'Optimizes unread message count calculations';
COMMENT ON INDEX idx_contacts_normalized_phone IS 'Enables efficient phone number deduplication in campaigns';
COMMENT ON INDEX idx_campaign_queue_processing IS 'Optimizes campaign queue processing queries';
COMMENT ON INDEX idx_companies_subscription_status IS 'Optimizes payment management queries by subscription status';
COMMENT ON INDEX idx_payment_transactions_company_status IS 'Optimizes payment transaction queries by company and status';

-- Group chat index comments
COMMENT ON INDEX idx_conversations_group_jid IS 'Optimizes group conversation lookups by WhatsApp group JID';
COMMENT ON INDEX idx_group_participants_conversation IS 'Optimizes group participant queries by conversation';
COMMENT ON INDEX idx_group_participants_active IS 'Optimizes active group participant lookups';
COMMENT ON INDEX idx_messages_group_participant IS 'Optimizes group message queries by sender JID';