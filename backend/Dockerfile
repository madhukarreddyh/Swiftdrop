# SwiftDrop backend — Railway production image (PHP 8.3 + artisan serve)
FROM php:8.3-cli

# System dependencies and PHP extensions required by Laravel 12 + MySQL + Sanctum
RUN apt-get update && apt-get install -y --no-install-recommends \
        git unzip \
        libzip-dev libpng-dev libonig-dev libxml2-dev \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql mbstring bcmath ctype fileinfo pcntl zip tokenizer xml opcache \
    && rm -rf /var/lib/apt/lists/*

# Sensible PHP defaults for an API server
RUN printf 'memory_limit = 256M\nmax_execution_time = 120\nopcache.enable_cli = 1\n' \
    > /usr/local/etc/php/conf.d/production.ini

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

# Install PHP dependencies (no dev packages in production)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000
CMD ["/usr/local/bin/entrypoint.sh"]
