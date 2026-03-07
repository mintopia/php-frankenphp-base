# Base FrankenPHP Image for Mintopia's Projects

Base PHP images built on [FrankenPHP](https://frankenphp.dev/) for PHP projects such as [Control](https://github.com/mintopia/control) and [Music Party](https://github.com/mintopia/musicparty). These images exist because some of the required extensions (especially gRPC) take a very long time to build, so pre-building them saves significant CI time.

## Versioning

- **PHP versions:** 8.2, 8.3, 8.4, 8.5
- **FrankenPHP:** latest stable
- **Architectures:** linux/amd64, linux/arm64
- **Base OS:** Alpine

## Image Tags

Images are published to `ghcr.io/mintopia/frankenphp-base`.

| Tag | PHP Version | Type | Notes |
|---|---|---|---|
| `latest` | 8.5 | Production | Newest PHP (may include RC) |
| `stable` | 8.4 | Production | Highest stable GA version |
| `8.5` | 8.5 | Production | |
| `8.4` | 8.4 | Production | |
| `8.3` | 8.3 | Production | |
| `8.2` | 8.2 | Production | |
| `latest-dev` | 8.5 | Development | |
| `stable-dev` | 8.4 | Development | |
| `8.5-dev` | 8.5 | Development | |
| `8.4-dev` | 8.4 | Development | |
| `8.3-dev` | 8.3 | Development | |
| `8.2-dev` | 8.2 | Development | |

## Extensions

Production images include:

- bcmath
- gd (with freetype, jpeg, and webp support)
- grpc
- opcache
- opentelemetry
- pcntl
- pdo
- pdo_mysql
- protobuf
- redis

Dev images additionally include:

- xdebug (configured for remote debugging)

## Configuration

All configuration is driven by environment variables.

### Application Settings

| Variable | Default | Description |
|---|---|---|
| `SERVER_NAME` | `:80` | Caddy server address |
| `APP_PUBLIC_DIR` | `/app/public` | Document root |
| `FRANKENPHP_CONFIG` | *(empty)* | FrankenPHP directives (e.g., `worker /app/public/index.php`) |
| `FRANKENPHP_MAX_REQUESTS` | `1000` | Max requests per worker |
| `CADDY_GLOBAL_OPTIONS` | *(empty)* | Global Caddy config |
| `CADDY_ENCODE` | `zstd gzip` | Response compression |
| `CADDY_SERVER_TRUSTED_PROXIES` | *(empty)* | Trusted proxy config |
| `PUID` | *(unset)* | User ID for www-data |
| `PGID` | *(unset)* | Group ID for www-data |

### PHP Settings

| Variable | Default (Prod) | Default (Dev) | Description |
|---|---|---|---|
| `PHP_MEMORY_LIMIT` | `512M` | `512M` | Memory limit |
| `PHP_UPLOAD_MAX_SIZE` | `20M` | `20M` | Upload size (sets both `upload_max_filesize` and `post_max_size`) |
| `PHP_DISPLAY_ERRORS` | `Off` | `On` | Display errors |
| `PHP_ERROR_REPORTING` | `E_ALL & ~E_DEPRECATED & ~E_STRICT` | `E_ALL` | Error reporting level |
| `PHP_MAX_EXECUTION_TIME` | `30` | `0` | Max execution time (0 = unlimited) |
| `PHP_TIMEZONE` | `UTC` | `UTC` | Default timezone |
| `PHP_EXPOSE_PHP` | `Off` | `On` | Expose PHP version in headers |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | `1` | Check file changes (0 = never, 1 = check) |
| `PHP_ZEND_ASSERTIONS` | `-1` | `1` | Assertions (-1 = compiled out, 1 = enabled) |

The table above covers the most commonly adjusted settings. The full list — including session, realpath cache, OPcache tuning, JIT, and more — can be found in [`scripts/entrypoint.sh`](scripts/entrypoint.sh).

### Worker Mode

Worker mode is disabled by default. To enable it, set the `FRANKENPHP_CONFIG` environment variable:

```bash
docker run -e FRANKENPHP_CONFIG="worker /app/public/index.php" ...
```

## Development Images

Dev images (`-dev` tags) include everything in the production image plus:

- **Composer** (latest)
- **Node.js** (LTS 22.x) with npm
- **PIE** (PHP Installer for Extensions)
- **xdebug** (configured for `host.docker.internal`, auto-start)
- **FrankenPHP watch mode** (auto-reload on file changes)
- **Shell tools:** bash, jq, yq, tree, less, vim, nano
- **Git:** git, openssh-client
- **Debugging:** strace, lsof, procps, htop
- **Network:** curl, wget, mtr, dig, ping, traceroute, netcat
- **Database CLI:** mariadb-client, redis-cli
- **Utilities:** zip/unzip, ccze

## Quick Start

```bash
# Production
docker run -p 80:80 -v ./app:/app ghcr.io/mintopia/frankenphp-base:stable

# Development
docker run -p 80:80 -v ./app:/app ghcr.io/mintopia/frankenphp-base:stable-dev
```

## Docker Compose Example

```yaml
services:
  app:
    image: ghcr.io/mintopia/frankenphp-base:stable
    ports:
      - "80:80"
    volumes:
      - ./:/app
    environment:
      PHP_MEMORY_LIMIT: "256M"
      FRANKENPHP_CONFIG: "worker /app/public/index.php"
```

## Building Locally

```bash
# Build production image for PHP 8.4
docker build --target base --build-arg PHP_VERSION=8.4 -t my-app .

# Build dev image for PHP 8.4
docker build --target dev --build-arg PHP_VERSION=8.4 -t my-app-dev .
```

## Contributing

If you want to contribute, please raise a PR. I've only really intended this for my own projects, but if you're getting some use and value out of it, that's awesome and I'm happy to accept contributions!

## License

MIT License

Copyright (c) 2025 Jessica Smith

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
