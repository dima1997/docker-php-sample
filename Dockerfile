# syntax=docker/dockerfile:1

# --- Composer dependencies ---
FROM composer:lts AS prod-deps
WORKDIR /app
RUN --mount=type=bind,source=./composer.json,target=composer.json \
    --mount=type=bind,source=./composer.lock,target=composer.lock \
    --mount=type=cache,target=/tmp/cache \
    composer install --no-dev --no-interaction --no-progress

FROM composer:lts AS dev-deps
WORKDIR /app
RUN --mount=type=bind,source=./composer.json,target=composer.json \
    --mount=type=bind,source=./composer.lock,target=composer.lock \
    --mount=type=cache,target=/tmp/cache \
    composer install --no-interaction --no-progress

# --- Base PHP + Apache ---
FROM php:8.4-apache AS base
RUN docker-php-ext-install pdo pdo_mysql
WORKDIR /var/www/html
COPY ./src ./

# --- Development ---
FROM base AS development
# Install utilities required by Composer
RUN apt-get update && apt-get install -y \
        zip unzip git \
    && rm -rf /var/lib/apt/lists/*
# Copy project files needed for development
COPY ./tests ./tests
COPY ./composer.json ./composer.json
COPY ./composer.lock ./composer.lock
# Copy Composer binary from official Composer image
COPY --from=composer:lts /usr/bin/composer /usr/bin/composer
# Copy vendor from previous dev-deps stage
COPY --from=dev-deps /app/vendor ./vendor
# Use development PHP ini
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
# Set writable cache directory for Composer
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache
RUN mkdir -p /tmp/composer-cache && chmod -R 777 /tmp/composer-cache
USER root

# --- Production ---
FROM base AS final
COPY --from=prod-deps /app/vendor ./vendor
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
# Security: run as non-root in prod
USER www-data
