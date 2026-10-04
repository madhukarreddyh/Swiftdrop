#!/bin/bash
set -e

cd /app

# Railway injects $PORT; default to 8000 for local docker runs.
PORT=${PORT:-8000}

# Ensure writable dirs exist (fresh container)
mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views \
         storage/app/private storage/app/public storage/logs bootstrap/cache

# Cache config/routes now that production env vars are present
php artisan config:cache
php artisan route:cache

# Run migrations + seeders (all seeders are idempotent firstOrCreate).
# Retry while the Railway MySQL service is still starting.
for i in $(seq 1 24); do
    if php artisan migrate --force --seed; then
        break
    fi
    if [ "$i" = "24" ]; then
        echo "Migrations failed after 24 attempts." >&2
        exit 1
    fi
    echo "Database not ready yet, retrying in 5s... ($i/24)"
    sleep 5
done

# Public storage symlink (rider document uploads)
php artisan storage:link 2>/dev/null || true

exec php artisan serve --host=0.0.0.0 --port="$PORT"
