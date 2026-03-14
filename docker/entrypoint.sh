#!/bin/sh
set -e

# ── Nginx : substituer $PORT dans la config template ─────────────────────────
PORT="${PORT:-80}"
mkdir -p /etc/nginx/conf.d
envsubst '${PORT}' < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

# ── Créer les dossiers runtime Laravel (absents car exclus du build context) ──
mkdir -p storage/framework/views \
         storage/framework/cache/data \
         storage/framework/sessions \
         storage/logs \
         bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# ── Migrations (endpoint direct Neon, sans pooler) ───────────────────────────
echo "▶ Migrations..."
MIGRATE_HOST="${DB_HOST_DIRECT:-$DB_HOST}"
DB_HOST="$MIGRATE_HOST" php artisan migrate --force

# ── Storage link + caches ─────────────────────────────────────────────────────
echo "▶ Storage link..."
php artisan storage:link --force

echo "▶ Cache config / routes / vues..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# ── Lancement via supervisord ─────────────────────────────────────────────────
echo "✓ Démarrage supervisord (nginx + php-fpm + reverb)..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
