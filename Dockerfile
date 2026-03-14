# ── Stage 1 : Build assets (Node) ────────────────────────────────────────────
FROM node:20-alpine AS assets

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY vite.config.js ./
COPY resources/ ./resources/
COPY public/ ./public/

RUN npm run build

# ── Stage 2 : Production — PHP-FPM + Nginx + Supervisord ─────────────────────
FROM php:8.3-fpm-alpine AS production

RUN apk add --no-cache \
        nginx \
        supervisor \
        gettext \
        postgresql-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        libzip-dev \
        zip \
        unzip \
        curl \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        pgsql \
        gd \
        zip \
        opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Dépendances PHP
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Code source + assets buildés
COPY . .
COPY --from=assets /app/public/build ./public/build

# Permissions + setup
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache \
    && chmod +x docker/entrypoint.sh \
    # Nginx : vider la conf par défaut, préparer le dossier template
    && rm -f /etc/nginx/conf.d/default.conf \
    && mkdir -p /etc/nginx/templates \
    && cp docker/nginx/default.conf /etc/nginx/templates/default.conf.template \
    # Supervisord
    && cp docker/supervisord.conf /etc/supervisord.conf

# Railway injecte $PORT (défaut 80 en local)
EXPOSE 80

ENTRYPOINT ["/bin/sh", "/var/www/html/docker/entrypoint.sh"]
