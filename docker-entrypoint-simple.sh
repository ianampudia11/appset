#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${PGHOST:-postgres}" -p "${PGPORT:-5432}" -U "${PGUSER:-postgres}"
do
  echo "PostgreSQL is unavailable - sleeping 2s"
  sleep 2
done

echo "PostgreSQL is up - starting application (migrations will be handled by the application)"

# Start the application
exec "$@"
