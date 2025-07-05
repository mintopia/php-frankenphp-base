FROM dunglas/frankenphp:1.7.0-php8.4.10-alpine
LABEL org.opencontainers.image.authors="jess@mintopia.net"

# Install GRPC extension separately
RUN apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS && \
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2) && \
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc && \
    cd /tmp/grpc/src/php/ext/grpc && \
    phpize && \
    ./configure && \
    make && \
    make install && \
    rm -rf /tmp/grpc && \
    apk del --no-cache git grpc-dev $PHPIZE_DEPS && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini && \
    install-php-extensions \
        pcntl \
        redis \
        bcmath \
        pdo \
        pdo_mysql \
        protobuf \
        opentelemetry && \
    echo 'memory_limit = 256M' > /usr/local/etc/php/conf.d/memory_limit.ini \