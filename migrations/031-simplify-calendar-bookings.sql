-- Migration: Simplify Calendar Bookings
-- This migration simplifies the calendar booking system by replacing the complex locking mechanism
-- with a simple booking record system that stores only confirmed bookings.

-- Create calendar_bookings table with simplified schema
CREATE TABLE IF NOT EXISTS calendar_bookings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  calendar_type TEXT NOT NULL,
  start_date_time TIMESTAMP NOT NULL,
  end_date_time TIMESTAMP NOT NULL,
  event_id TEXT, -- Calendar provider's event ID (Google Calendar event ID, etc.)
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create unique index to prevent duplicate bookings
CREATE UNIQUE INDEX IF NOT EXISTS idx_calendar_bookings_unique_slot 
ON calendar_bookings(user_id, company_id, calendar_type, start_date_time, end_date_time);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_calendar_bookings_user_company_calendar 
ON calendar_bookings(user_id, company_id, calendar_type, start_date_time, end_date_time);

CREATE INDEX IF NOT EXISTS idx_calendar_bookings_time_range 
ON calendar_bookings(start_date_time, end_date_time);

CREATE INDEX IF NOT EXISTS idx_calendar_bookings_created_at 
ON calendar_bookings(created_at);


-- Add comments for documentation
COMMENT ON TABLE calendar_bookings IS 'Stores confirmed calendar bookings to prevent double bookings and calculate availability';
COMMENT ON COLUMN calendar_bookings.user_id IS 'Reference to the user who owns the calendar';
COMMENT ON COLUMN calendar_bookings.company_id IS 'Reference to the company the user belongs to';
COMMENT ON COLUMN calendar_bookings.calendar_type IS 'Type of calendar (google, zoho, etc.)';
COMMENT ON COLUMN calendar_bookings.start_date_time IS 'Start time of the booked time slot';
COMMENT ON COLUMN calendar_bookings.end_date_time IS 'End time of the booked time slot';
COMMENT ON COLUMN calendar_bookings.event_id IS 'Calendar provider event ID for reference and deletion';
COMMENT ON COLUMN calendar_bookings.created_at IS 'Timestamp when the booking was created';

