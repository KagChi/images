# Pelican Production Dockerfile

FROM node:20-alpine AS yarn

WORKDIR /build

RUN apk update && apk add --no-cache \
    git curl

RUN git clone https://github.com/pelican-dev/panel

WORKDIR /build/panel

RUN corepack enable && corepack prepare pnpm@latest

RUN pnpm install --frozen-lockfile && pnpm build:production

FROM php:8.3-fpm-alpine

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# Install dependencies
RUN apk update && apk add --no-cache \
    libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev icu-dev git \
    zip unzip curl \
    caddy ca-certificates supervisor \
    && docker-php-ext-install bcmath gd intl zip opcache pcntl posix pdo_mysql

# Copy the Caddyfile to the container
COPY ./Caddyfile /etc/caddy/Caddyfile

RUN git clone https://github.com/pelican-dev/panel /var/www/html/panel

# Set working directory
WORKDIR /var/www/html/panel

COPY --from=yarn /build/panel/public/assets ./public/assets

RUN echo "APP_KEY=" > .env \
    && echo "DB_DATABASE=docker/database.sqlite" >> .env

RUN composer install --no-dev --optimize-autoloader

# Set file permissions
RUN chmod -R 755 /var/www/html/panel/storage \
    && chmod -R 755 /var/www/html/panel/bootstrap/cache

#echo "* * * * * /usr/local/bin/php /build/artisan schedule:run >> /dev/null 2>&1" >> /var/spool/cron/crontabs/root

HEALTHCHECK --interval=5m --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/up || exit 1

EXPOSE 80:2019
EXPOSE 443

VOLUME /pelican-data

# Start PHP-FPM
CMD ["sh", "-c", "php-fpm"]

ENTRYPOINT [ "/bin/ash", ".github/docker/entrypoint.sh" ]