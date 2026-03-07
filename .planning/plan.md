---
project: "PHP FrankenPHP Base Docker Images"
version: "1.1"
status: "draft"
date: "2026-03-07"
author: "Copilot"
---

# PHP FrankenPHP Base Docker Images — Implementation Plan

## 1. Overview

This document describes the complete implementation plan for building PHP base Docker images powered by [FrankenPHP](https://frankenphp.dev/). The images are designed to serve as production-ready and development-ready foundations for PHP applications, published to both GitHub Container Registry and GitLab Container Registry.

---

## 2. Decisions

| # | Decision | Outcome |
|---|----------|---------|
| 1 | **Tagging strategy** | `stable` = latest stable GA PHP version; `latest` = newest PHP version including RC/beta. Both tags exist separately. |
| 2 | **Worker mode** | Optional via environment variable. Disabled by default; enable by setting `FRANKENPHP_WORKERS`. |
| 3 | **Node.js version** | LTS (22.x) for dev images only. |
| 4 | **CI/CD** | Both GitHub Actions and GitLab CI. GitHub → GHCR (`ghcr.io/mintopia/frankenphp-base`). GitLab → GitLab Container Registry. |
| 5 | **Opcache** | Enabled with sensible production defaults; configurable via environment variables. |
| 6 | **Health check** | Yes, include `HEALTHCHECK` instruction in the Dockerfile. |
| 7 | **bcmath** | Confirmed correct spelling is `bcmath` (not `bcmatch`). |

---

## 3. Architecture

### 3.1 Dockerfile Strategy

- **Single Dockerfile** with `ARG`-parameterized PHP version.
- **Multi-stage build**: `base` stage (production) → `dev` stage (extends base).
- Key `ARG`s:
  - `PHP_VERSION` (default: `8.4`)
  - Build target selection (`base` for production, `dev` for development)

### 3.2 Base Image

```
dunglas/frankenphp:latest-php${PHP_VERSION}-alpine
```

- Tracks the latest FrankenPHP release.
- PHP version is parameterized via build arg.

### 3.3 PHP Versions

| Version | Status | Allow Failure |
|---------|--------|---------------|
| 8.2 | Stable GA | No |
| 8.3 | Stable GA | No |
| 8.4 | Stable GA | No |
| 8.5 | RC / Beta | **Yes** |

### 3.4 Tag Matrix

| PHP Version | Production Tag | Dev Tag | Special Tags |
|-------------|---------------|---------|--------------|
| 8.2 | `8.2` | `8.2-dev` | — |
| 8.3 | `8.3` | `8.3-dev` | — |
| 8.4 | `8.4` | `8.4-dev` | `stable`, `stable-dev` |
| 8.5 | `8.5` | `8.5-dev` | `latest`, `latest-dev` |

> **Note:** `stable` points to the highest GA PHP version (currently 8.4). `latest` points to the newest PHP version including RC/beta (currently 8.5). When PHP 8.5 reaches GA, `stable` should be switched to 8.5.

---

## 4. Extensions

### 4.1 Production Extensions

All extensions installed via `install-php-extensions` where possible:

| Extension | Notes |
|-----------|-------|
| `bcmath` | — |
| `grpc` | Source compile against Alpine `grpc-cpp`/`grpc-dev` packages |
| `opentelemetry` | — |
| `pcntl` | — |
| `pdo` | — |
| `pdo_mysql` | — |
| `protobuf` | — |
| `redis` | — |
| `gd` | With freetype, jpeg, and webp support |
| `opcache` | Configure with sensible production defaults |

### 4.2 Dev-Only Extensions

| Extension | Configuration |
|-----------|--------------|
| `xdebug` | `xdebug.mode=debug` |
| | `xdebug.client_host=host.docker.internal` |
| | `xdebug.start_with_request=yes` |
| | `xdebug.discover_client_host=0` |

---

## 5. Extension Build Strategy

### 5.1 Build Method per Extension

| Extension | Method | Approx. Time | Rationale |
|---|---|---|---|
| grpc | Source compile against Alpine `grpc-cpp`/`grpc-dev` packages | ~30-60s | Pre-compiled C++ library avoids 30+ min full build |
| protobuf | `install-php-extensions` | ~30-60s | PECL source, fast enough |
| opentelemetry | `install-php-extensions` | ~20-40s | Well-supported |
| redis | `install-php-extensions` | ~15-30s | Self-contained |
| bcmath | `install-php-extensions` | ~5s | Bundled PHP extension |
| pcntl | `install-php-extensions` | ~5s | Bundled |
| pdo | `install-php-extensions` | ~5s | Bundled, likely already enabled |
| pdo_mysql | `install-php-extensions` | ~5s | Bundled |
| gd | `install-php-extensions` | ~20-40s | Handles deps automatically |
| opcache | `install-php-extensions` | ~5s | Bundled, may already be enabled |
| xdebug (dev) | `install-php-extensions` | ~15-30s | Dev image only |

### 5.2 Build Optimization

- Separate grpc into its own `RUN` layer (slowest, changes least)
- Group fast extensions in a single `RUN`
- Order by change frequency for Docker cache
- Consider `--mount=type=cache,target=/var/cache/apk` for APK cache
- Alpine PHP packages (`php84-redis` etc.) are **NOT** compatible with FrankenPHP's custom ZTS PHP build

### 5.3 PIE (PHP Installer for Extensions)

- Official PECL replacement by PHP Foundation
- Install in dev images only (useful for devs adding extensions on the fly)
- Not yet mature enough to replace `install-php-extensions` in Docker builds
- grpc and protobuf not yet available via PIE

---

## 6. Configuration Strategy

### 6.1 Caddyfile

Ship a default Caddyfile using Caddy's native `{$ENV_VAR:default}` syntax for environment-driven configuration:

| Environment Variable | Default | Purpose |
|---------------------|---------|---------|
| `APP_DIR` | `/app` | Application root directory |
| `APP_PUBLIC_DIR` | `/app/public` | Public document root |
| `FRANKENPHP_WORKERS` | *(empty — disabled)* | Set to worker config string to enable worker mode |
| `FRANKENPHP_MAX_REQUESTS` | `1000` | Max requests per worker before restart |
| `FRANKENPHP_WATCH` | *(empty — disabled)* | Dev images: set to enable file watching |

### 6.2 PHP Configuration

An entrypoint script writes `.ini` files from environment variables at container startup. All settings below are configurable.

#### Resource Limits

| Env Var | Default | INI Directive(s) |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `512M` | `memory_limit` |
| `PHP_UPLOAD_MAX_SIZE` | `20M` | `upload_max_filesize`, `post_max_size` |

#### Error Handling

| Env Var | Prod Default | Dev Default |
|---|---|---|
| `PHP_DISPLAY_ERRORS` | `Off` | `On` |
| `PHP_DISPLAY_STARTUP_ERRORS` | `Off` | `On` |
| `PHP_ERROR_REPORTING` | `E_ALL & ~E_DEPRECATED & ~E_STRICT` | `E_ALL` |
| `PHP_LOG_ERRORS` | `On` | `On` |
| `PHP_ERROR_LOG` | `/dev/stderr` | `/dev/stderr` |

#### Execution Limits

| Env Var | Prod Default | Dev Default |
|---|---|---|
| `PHP_MAX_EXECUTION_TIME` | `30` | `0` (unlimited) |
| `PHP_MAX_INPUT_TIME` | `60` | `-1` (unlimited) |
| `PHP_MAX_INPUT_VARS` | `1000` | `3000` |

#### OPcache

| Env Var | Prod Default | Dev Default |
|---|---|---|
| `PHP_OPCACHE_ENABLE` | `1` | `1` |
| `PHP_OPCACHE_MEMORY` | `128` | `128` |
| `PHP_OPCACHE_MAX_FILES` | `10000` | `10000` |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` | `1` |
| `PHP_OPCACHE_REVALIDATE_FREQ` | `0` | `0` |
| `PHP_OPCACHE_SAVE_COMMENTS` | `1` | `1` |
| `PHP_OPCACHE_PRELOAD` | *(empty)* | *(empty)* |
| `PHP_OPCACHE_PRELOAD_USER` | `www-data` | `www-data` |
| `PHP_OPCACHE_JIT` | `disable` | `disable` |

> **Note:** JIT is disabled by default as it can cause issues with FrankenPHP's ZTS PHP.

#### Session

| Env Var | Prod Default | Dev Default |
|---|---|---|
| `PHP_SESSION_HANDLER` | `files` | `files` |
| `PHP_SESSION_SAVE_PATH` | `/tmp/sessions` | `/tmp/sessions` |
| `PHP_SESSION_COOKIE_SECURE` | `1` | `0` |

#### Other

| Env Var | Prod Default | Dev Default |
|---|---|---|
| `PHP_TIMEZONE` | `UTC` | `UTC` |
| `PHP_REALPATH_CACHE_SIZE` | `4096K` | `4096K` |
| `PHP_REALPATH_CACHE_TTL` | `600` | `120` |
| `PHP_EXPOSE_PHP` | `Off` | `On` |
| `PHP_SERIALIZE_PRECISION` | `-1` | `-1` |
| `PHP_ZEND_ASSERTIONS` | `-1` | `1` |

### 6.3 FrankenPHP / Caddy Configuration

#### Caddy Settings

| Env Var | Default | Notes |
|---|---|---|
| `SERVER_NAME` | `:80` | Set to domain for auto-TLS |
| `CADDY_GLOBAL_OPTIONS` | *(empty)* | Inject global config (e.g., `"debug"`, `"servers { metrics }"`) |
| `CADDY_ENCODE` | `zstd gzip` | Compression algorithms, empty to disable. `zstd` and `gzip` are built into Caddy; Brotli (`br`) requires a separate Caddy module. |
| `TRUSTED_PROXIES` | *(empty)* | CIDR ranges for reverse proxy |

#### FrankenPHP Settings

| Env Var | Default | Notes |
|---|---|---|
| `FRANKENPHP_CONFIG` | *(empty)* | Additional FrankenPHP directives |
| `SERVER_NAME` | `:80` | Caddy server name/address |

#### Security Recommendations

- Disable Caddy admin API in production: `CADDY_GLOBAL_OPTIONS="admin off"`
- HTTP/3 (QUIC) enabled by default with HTTPS, requires UDP port 443

### 6.4 User/Group ID Mapping

The entrypoint script accepts `PUID` and `PGID` environment variables:

- Requires the `shadow` package on Alpine (provides `usermod` / `groupmod`).
- Modifies the `www-data` user and group IDs before starting FrankenPHP.

---

## 7. Entrypoint Script

Custom entrypoint (`scripts/entrypoint.sh`) that performs the following steps in order:

1. **UID/GID mapping** — If `PUID` and/or `PGID` are set, modify `www-data` user/group accordingly.
2. **Write PHP ini** — Generate `.ini` files from environment variables covering all configurable settings:
   - Resource limits (`PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_SIZE`)
   - Error handling (`PHP_DISPLAY_ERRORS`, `PHP_ERROR_REPORTING`, `PHP_LOG_ERRORS`, etc.)
   - Execution limits (`PHP_MAX_EXECUTION_TIME`, `PHP_MAX_INPUT_TIME`, `PHP_MAX_INPUT_VARS`)
   - OPcache settings (`PHP_OPCACHE_ENABLE`, `PHP_OPCACHE_MEMORY`, `PHP_OPCACHE_VALIDATE_TIMESTAMPS`, `PHP_OPCACHE_JIT`, etc.)
   - Session settings (`PHP_SESSION_HANDLER`, `PHP_SESSION_SAVE_PATH`, `PHP_SESSION_COOKIE_SECURE`)
   - Other settings (`PHP_TIMEZONE`, `PHP_REALPATH_CACHE_SIZE`, `PHP_EXPOSE_PHP`, `PHP_ZEND_ASSERTIONS`, etc.)
3. **Create session directory** — Ensure `PHP_SESSION_SAVE_PATH` exists with correct permissions.
4. **Exec original entrypoint** — Hand off to the original FrankenPHP entrypoint via `exec`.

---

## 8. Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost/healthz || exit 1
```

- `curl` is installed in the production image for health check support.

---

## 9. Dev Image Additions

The `dev` stage extends the `base` stage with additional tooling:

### 9.1 Core Tools

| Component | Installation Method |
|-----------|-------------------|
| **Composer** | `COPY --from=composer:latest /usr/bin/composer /usr/bin/composer` |
| **Node.js LTS 22.x** | Alpine packages (`nodejs` + `npm`) or official binary |
| **xdebug** | `install-php-extensions xdebug` + ini configuration |
| **PIE** | Install via Composer or official installer (useful for adding extensions on the fly) |
| **File watching** | Set `FRANKENPHP_WATCH` env variable in Caddyfile |

### 9.2 Shell & Terminal

| Package | Purpose |
|---------|---------|
| `bash` | Full shell |
| `jq` | JSON processing — essential for API debugging |
| `yq` | YAML processing |
| `tree` | Directory visualization |
| `less` | Proper pager |
| `git` | Version control |
| `openssh-client` | SSH access for VCS |
| `zip`, `unzip` | Archive handling |
| `nano` | Lightweight editor |
| `vim` | Fuller editor option |

### 9.3 Debugging & Profiling

| Package | Purpose |
|---------|---------|
| `strace` | System call tracing — invaluable for PHP debugging |
| `lsof` | List open files/sockets |
| `procps` | Full `ps`, `top`, `pgrep` vs limited busybox versions |
| `htop` | Interactive process viewer |

### 9.4 Network

| Package | Purpose |
|---------|---------|
| `curl` | HTTP client |
| `wget` | HTTP client |
| `netcat-openbsd` | Port testing |
| `mtr` | Network diagnostics |
| `bind-tools` | DNS utilities (`dig`, `nslookup`) |
| `iputils` | `ping` and related |
| `traceroute` | Route tracing |

### 9.5 Database CLI

| Package | Purpose |
|---------|---------|
| `mariadb-client` | MySQL/MariaDB CLI access |
| `redis` | Includes `redis-cli` |

### 9.6 Styling & Output

| Package | Purpose |
|---------|---------|
| `ccze` | Log colorizer |

### 9.7 Explicitly NOT Included

The following tools are per-project concerns and should be installed via Composer in each project:

- PHPStan
- Psalm
- PHPUnit
- PHP_CodeSniffer
- php-cs-fixer

---

## 10. CI/CD

### 10.1 GitHub Actions

- **Matrix:** 4 PHP versions × 2 variants (prod / dev)
- **Multi-arch:** `linux/amd64` + `linux/arm64` via `docker buildx` + QEMU
- **Registry:** GHCR (`ghcr.io/mintopia/frankenphp-base`)
- **Triggers:**
  - Push to `main`
  - Pull requests (build only, no push)
  - Weekly schedule (rebuild with latest base images)
- **PHP 8.5 builds:** `continue-on-error: true`
- **Caching:** GitHub Actions cache for Docker layers
- **Smoke test:** `php -m` verification after build to confirm all extensions loaded

### 10.2 GitLab CI

- **Pipeline:** Mirrored in `.gitlab-ci.yml`
- **Matrix:** Same strategy as GitHub Actions
- **Registry:** GitLab Container Registry (`registry.gitlab.com/mintopia/frankenphp-base`)
- **Build method:** GitLab CI services with Docker-in-Docker or kaniko
- **Tagging:** Same tagging strategy as GitHub Actions

---

## 11. Risk Register

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R1 | PHP 8.5 FrankenPHP base image may not exist | **High** | CI allow-failure for 8.5; only apply `latest` tag when build succeeds |
| R2 | `grpc` extension fails on PHP 8.5 | **High** | Allow 8.5 build to fail; monitor upstream compatibility |
| R3 | `opentelemetry` / `xdebug` not compatible with PHP 8.5 | **Medium** | Same approach as R2 |
| R4 | `grpc` source-build is fragile across Alpine versions | **Medium** | Source compile against Alpine `grpc-dev`; add smoke test to verify |
| R5 | QEMU arm64 builds are slow (~20–40 min per build) | **Medium** | Use native arm64 runners if available, or accept build times |
| R6 | Alpine package availability varies across base image updates | **Low** | CI smoke tests catch breaking changes early |

---

## 12. File Structure

```
.
├── .github/
│   ├── copilot-instructions.md    # Copilot agent instructions
│   └── workflows/
│       └── build.yml              # GitHub Actions CI
├── .gitlab-ci.yml                 # GitLab CI
├── .planning/
│   └── plan.md                    # This document
├── Dockerfile                     # Single multi-stage Dockerfile
├── config/
│   ├── Caddyfile                  # Default Caddyfile with env placeholders
│   ├── php/
│   │   ├── opcache.ini            # Opcache prod defaults
│   │   ├── opcache-dev.ini        # Opcache dev settings
│   │   ├── php.ini                # Base PHP settings template
│   │   └── xdebug.ini            # Xdebug config (dev only)
│   └── ...
├── scripts/
│   └── entrypoint.sh              # Custom entrypoint script
├── CLAUDE.md
├── LICENSE
└── README.md
```

---

## 13. Implementation Phases

### Phase 1: Core Dockerfile

- Parameterized single Dockerfile with multi-stage build (`base` + `dev`).
- All production and dev extensions installed.
- Caddyfile with environment variable placeholders.
- Entrypoint script for full PHP configuration and UID/GID mapping.
- Health check instruction.

### Phase 2: GitHub Actions CI

- Build matrix for all PHP versions × variants × architectures.
- Push to GHCR with correct tag matrix.
- Smoke tests (`php -m`, extension verification).
- Scheduled weekly rebuilds to pick up base image updates.

### Phase 3: GitLab CI

- Mirror pipeline in `.gitlab-ci.yml`.
- Push to GitLab Container Registry.
- Same smoke tests and matrix strategy.

### Phase 4: Testing & Hardening

- Verify all extensions load on all PHP versions.
- Test environment variable configuration works correctly for all PHP settings.
- Test dev image tools (Composer, Node.js, xdebug, PIE, database CLIs).
- Test multi-arch builds on both `amd64` and `arm64`.
- Handle PHP 8.5 builds as they become available upstream.
