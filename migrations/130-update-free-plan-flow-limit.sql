-- Increase Free plan flow limit from 1 to 3.
-- This updates existing databases after migration and also affects fresh setups
-- because this migration runs after initial plan seeding.

UPDATE plans
SET
  max_flows = 3,
  features = CASE
    WHEN features::text LIKE '%1 flow%' THEN REPLACE(features::text, '1 flow', '3 flows')::jsonb
    ELSE features
  END
WHERE LOWER(name) = 'free';
