# =============================================================================
# Multi-stage Dockerfile for PHP FrankenPHP Base Images
# =============================================================================

ARG PHP_VERSION=8.4

# =============================================================================
# Stage 1: Production Base Image
# =============================================================================
FROM dunglas/frankenphp:1-php${PHP_VERSION}-alpine AS base

LABEL org.opencontainers.image.authors="jess@mintopia.net"
LABEL org.opencontainers.image.source="https://github.com/mintopia/frankenphp-base"

# -----------------------------------------------------------------------------
# System packages (production)
# -----------------------------------------------------------------------------
RUN apk add --no-cache \
    shadow \
    curl

# -----------------------------------------------------------------------------
# gRPC extension — source compile against Alpine system packages
# Note: grpc-cpp is intentionally kept as a runtime dependency
# -----------------------------------------------------------------------------
RUN apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS && \
    GRPC_VERSION=$(apk policy grpc-cpp 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
    [ -n "$GRPC_VERSION" ] || { echo "ERROR: Failed to determine gRPC version"; exit 1; } && \
    echo "Building gRPC PHP extension for version ${GRPC_VERSION}" && \
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc && \
    cd /tmp/grpc/src/php/ext/grpc && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    rm -rf /tmp/grpc && \
    apk del --no-cache git grpc-dev $PHPIZE_DEPS && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini

# -----------------------------------------------------------------------------
# PHP extensions via install-php-extensions
# -----------------------------------------------------------------------------
RUN install-php-extensions \
    bcmath \
    pcntl \
    pdo \
    pdo_mysql \
    redis \
    protobuf \
    opentelemetry \
    gd \
    opcache

# -----------------------------------------------------------------------------
# Configuration files
# -----------------------------------------------------------------------------
COPY config/Caddyfile /etc/caddy/Caddyfile
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# -----------------------------------------------------------------------------
# Working directory and public folder
# -----------------------------------------------------------------------------
WORKDIR /app
RUN mkdir -p /app/public

# -----------------------------------------------------------------------------
# Environment variables (production defaults)
# -----------------------------------------------------------------------------
ENV SERVER_NAME=:80 \
    APP_PUBLIC_DIR=/app/public \
    PHP_MEMORY_LIMIT=512M \
    PHP_UPLOAD_MAX_SIZE=20M \
    PHP_DISPLAY_ERRORS=Off \
    PHP_DISPLAY_STARTUP_ERRORS=Off \
    PHP_ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT" \
    PHP_LOG_ERRORS=On \
    PHP_ERROR_LOG=/dev/stderr \
    PHP_MAX_EXECUTION_TIME=30 \
    PHP_MAX_INPUT_TIME=60 \
    PHP_MAX_INPUT_VARS=1000 \
    PHP_OPCACHE_ENABLE=1 \
    PHP_OPCACHE_MEMORY=128 \
    PHP_OPCACHE_MAX_FILES=10000 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_REVALIDATE_FREQ=0 \
    PHP_OPCACHE_SAVE_COMMENTS=1 \
    PHP_OPCACHE_JIT=disable \
    PHP_OPCACHE_JIT_BUFFER_SIZE=0 \
    PHP_SESSION_HANDLER=files \
    PHP_SESSION_SAVE_PATH=/tmp/sessions \
    PHP_SESSION_COOKIE_SECURE=1 \
    PHP_TIMEZONE=UTC \
    PHP_REALPATH_CACHE_SIZE=4096K \
    PHP_REALPATH_CACHE_TTL=600 \
    PHP_EXPOSE_PHP=Off \
    PHP_SERIALIZE_PRECISION=-1 \
    PHP_ZEND_ASSERTIONS=-1

EXPOSE 80 443 2019

# -----------------------------------------------------------------------------
# Entrypoint, command, and healthcheck
# -----------------------------------------------------------------------------
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://localhost:2019/config/ > /dev/null || exit 1

# =============================================================================
# Stage 2: Development Image
# =============================================================================
FROM base AS dev

# -----------------------------------------------------------------------------
# System packages (dev tools)
# -----------------------------------------------------------------------------
RUN apk add --no-cache \
    bash jq yq tree less \
    git openssh-client \
    zip unzip \
    nano vim \
    strace lsof procps htop \
    wget netcat-openbsd \
    mtr bind-tools iputils traceroute \
    mariadb-client \
    redis \
    lnav \
    nodejs npm

# -----------------------------------------------------------------------------
# Composer
# -----------------------------------------------------------------------------
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# -----------------------------------------------------------------------------
# Xdebug
# -----------------------------------------------------------------------------
RUN install-php-extensions xdebug
COPY config/php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# -----------------------------------------------------------------------------
# PIE (PHP Installer for Extensions)
# -----------------------------------------------------------------------------
RUN curl -sSL https://github.com/php/pie/releases/latest/download/pie.phar -o /usr/local/bin/pie && \
    chmod +x /usr/local/bin/pie

# -----------------------------------------------------------------------------
# Environment variables (development overrides)
# -----------------------------------------------------------------------------
ENV PHP_DISPLAY_ERRORS=On \
    PHP_DISPLAY_STARTUP_ERRORS=On \
    PHP_ERROR_REPORTING=E_ALL \
    PHP_MAX_EXECUTION_TIME=0 \
    PHP_MAX_INPUT_TIME=-1 \
    PHP_MAX_INPUT_VARS=3000 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_SESSION_COOKIE_SECURE=0 \
    PHP_REALPATH_CACHE_TTL=120 \
    PHP_EXPOSE_PHP=On \
    PHP_ZEND_ASSERTIONS=1 \
    FRANKENPHP_CONFIG=watch

# -----------------------------------------------------------------------------
# Default shell for dev
# -----------------------------------------------------------------------------
SHELL ["/bin/bash", "-c"]
