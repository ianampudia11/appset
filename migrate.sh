for file in /www/wwwroot/multigo/migrations/*.sql; do
  echo "Running $file..."
  docker exec -i powerchat-postgres-multigo psql -U powerchat -d multigo_db < "$file"
done
