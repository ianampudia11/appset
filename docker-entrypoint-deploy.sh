#!/bin/bash
set -e

# Wait for PostgreSQL to be ready using a simple connection test
echo "Waiting for PostgreSQL to be ready..."
until psql -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${PGUSER:-postgres}" -d "${PGDATABASE:-postgres}" -c "SELECT 1;" > /dev/null 2>&1
do
  echo "PostgreSQL is unavailable - sleeping 2s"
  sleep 2
done

echo "PostgreSQL is up - starting application (migrations will be handled by the application)"

# Start the application
exec "$@"
