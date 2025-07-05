FROM dunglas/frankenphp:1.7.0-php8.4.10-alpine

RUN install-php-extensions \
        pcntl \
        redis \
        bcmath \
        pdo \
        pdo_mysql \
        grpc \
        protobuf \
        opentelemetry && \
    echo 'memory_limit = 256M' > /usr/local/etc/php/conf.d/memory_limit.ini \