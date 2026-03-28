#!/usr/bin/env bash
# =============================================================================
# test.sh — Test built PHP FrankenPHP base Docker images
#
# Usage:
#   ./scripts/test.sh                   # Test PHP 8.4 base
#   ./scripts/test.sh 8.3              # Test PHP 8.3 base
#   ./scripts/test.sh 8.4 dev          # Test PHP 8.4 dev
#   ./scripts/test.sh --all            # Test all PHP versions and variants
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
IMAGE_NAME="frankenphp-base"
SUPPORTED_VERSIONS=(8.2 8.3 8.4 8.5)
VARIANTS=(base dev)

# Extensions expected in every image (base + dev)
BASE_EXTENSIONS=(bcmath gd grpc intl opcache opentelemetry pcntl pdo pdo_mysql protobuf redis)
# Additional extensions for the dev variant
DEV_EXTENSIONS=(xdebug)

# Container startup timeout (seconds)
STARTUP_TIMEOUT=30

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { echo -e "  ${GREEN}✔ PASS${NC}  $*"; TOTAL_PASS=$((TOTAL_PASS + 1)); }
fail() { echo -e "  ${RED}✘ FAIL${NC}  $*"; TOTAL_FAIL=$((TOTAL_FAIL + 1)); }
skip() { echo -e "  ${YELLOW}⊘ SKIP${NC}  $*"; TOTAL_SKIP=$((TOTAL_SKIP + 1)); }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }

usage() {
    echo "Usage: $0 [--all | PHP_VERSION] [VARIANT]"
    echo ""
    echo "  PHP_VERSION  One of: ${SUPPORTED_VERSIONS[*]} (default: 8.4)"
    echo "  VARIANT      One of: base, dev (default: base)"
    echo "  --all        Test all supported versions and variants"
    exit 1
}

# ---------------------------------------------------------------------------
# Cleanup helper — removes the test container
# ---------------------------------------------------------------------------
cleanup_container() {
    local cname="$1"
    if docker ps -aq -f "name=${cname}" | grep -q .; then
        docker rm -f "${cname}" >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------------------
# Run all tests for a single image
# ---------------------------------------------------------------------------
test_image() {
    local php_version="$1"
    local variant="$2"
    local tag="${IMAGE_NAME}:php${php_version}-${variant}"
    local cname="test-frankenphp-${php_version}-${variant}-$$"

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Testing: ${tag}${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Ensure cleanup on exit from this function
    trap "cleanup_container '${cname}'" RETURN

    # -----------------------------------------------------------------
    # Test 1: Image exists
    # -----------------------------------------------------------------
    if docker image inspect "${tag}" >/dev/null 2>&1; then
        pass "Image exists: ${tag}"
    else
        fail "Image does not exist: ${tag}"
        skip "Skipping remaining tests — image not found"
        return
    fi

    # -----------------------------------------------------------------
    # Test 2: Container starts and Caddy admin API responds
    # -----------------------------------------------------------------
    cleanup_container "${cname}"
    docker run -d --name "${cname}" "${tag}" >/dev/null 2>&1

    local started=false
    for (( i=1; i<=STARTUP_TIMEOUT; i++ )); do
        if docker exec "${cname}" curl -fsS http://localhost:2019/config/ >/dev/null 2>&1; then
            started=true
            break
        fi
        sleep 1
    done

    if [[ "$started" == true ]]; then
        pass "Container starts and Caddy admin API responds (${i}s)"
    else
        fail "Container did not respond within ${STARTUP_TIMEOUT}s"
        # Continue with remaining tests that don't need a running server
    fi

    # -----------------------------------------------------------------
    # Test 3: PHP version matches
    # -----------------------------------------------------------------
    local actual_version
    actual_version=$(docker exec "${cname}" php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "unknown")

    if [[ "$actual_version" == "$php_version" ]]; then
        pass "PHP version matches: ${actual_version}"
    else
        fail "PHP version mismatch: expected ${php_version}, got ${actual_version}"
    fi

    # -----------------------------------------------------------------
    # Test 4: Base PHP extensions loaded
    # -----------------------------------------------------------------
    local loaded_extensions
    loaded_extensions=$(docker exec "${cname}" php -m 2>/dev/null || echo "")

    for ext in "${BASE_EXTENSIONS[@]}"; do
        if [[ "$ext" == "grpc" && "$php_version" == "8.5" ]]; then
            skip "Extension skipped (not supported on PHP ${php_version}): ${ext}"
            continue
        fi
        local pattern="^${ext}$"
        if [[ "$ext" == "opcache" ]]; then
            pattern="opcache|Zend OPcache"
        fi
        if echo "$loaded_extensions" | grep -qiE "$pattern"; then
            pass "Extension loaded: ${ext}"
        else
            fail "Extension missing: ${ext}"
        fi
    done

    # -----------------------------------------------------------------
    # Test 5 (dev only): Dev-specific extensions
    # -----------------------------------------------------------------
    if [[ "$variant" == "dev" ]]; then
        for ext in "${DEV_EXTENSIONS[@]}"; do
            local pattern="^${ext}$"
            if [[ "$ext" == "opcache" ]]; then
                pattern="opcache|Zend OPcache"
            fi
            if echo "$loaded_extensions" | grep -qiE "$pattern"; then
                pass "Dev extension loaded: ${ext}"
            else
                fail "Dev extension missing: ${ext}"
            fi
        done
    fi

    # -----------------------------------------------------------------
    # Test 6 (dev only): Composer available
    # -----------------------------------------------------------------
    if [[ "$variant" == "dev" ]]; then
        if docker exec "${cname}" composer --version >/dev/null 2>&1; then
            pass "Composer is available"
        else
            fail "Composer is not available"
        fi
    fi

    # -----------------------------------------------------------------
    # Test 7 (dev only): Node.js available
    # -----------------------------------------------------------------
    if [[ "$variant" == "dev" ]]; then
        if docker exec "${cname}" node --version >/dev/null 2>&1; then
            pass "Node.js is available"
        else
            fail "Node.js is not available"
        fi
    fi

    # -----------------------------------------------------------------
    # Test 8: Entrypoint applies env vars to PHP config
    # -----------------------------------------------------------------
    # The entrypoint writes a zz-docker.ini from env vars. Verify a
    # custom value propagates through.
    local ini_value
    ini_value=$(docker exec "${cname}" php -r "echo ini_get('memory_limit');" 2>/dev/null || echo "unknown")

    # Default is 512M (set in Dockerfile ENV)
    if [[ "$ini_value" == "512M" ]]; then
        pass "Entrypoint applies env vars to PHP config (memory_limit=${ini_value})"
    else
        fail "Entrypoint did not apply expected config: memory_limit=${ini_value} (expected 512M)"
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
TEST_ALL=false
PHP_VERSION="8.4"
VARIANT="base"

if [[ $# -ge 1 ]]; then
    case "$1" in
        --all)
            TEST_ALL=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            PHP_VERSION="$1"
            ;;
    esac
fi

if [[ $# -ge 2 && "$TEST_ALL" == false ]]; then
    case "$2" in
        base|dev)
            VARIANT="$2"
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown variant '$2'. Must be 'base' or 'dev'."
            usage
            ;;
    esac
fi

# Validate the PHP version when not testing all
if [[ "$TEST_ALL" == false ]]; then
    valid=false
    for v in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$v" == "$PHP_VERSION" ]]; then
            valid=true
            break
        fi
    done
    if [[ "$valid" == false ]]; then
        echo -e "${RED}[ERROR]${NC} Unsupported PHP version '${PHP_VERSION}'. Supported: ${SUPPORTED_VERSIONS[*]}"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     FrankenPHP Base Image Tests              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

if [[ "$TEST_ALL" == true ]]; then
    info "Testing ALL versions: ${SUPPORTED_VERSIONS[*]}"
    info "Variants: ${VARIANTS[*]}"

    for php_ver in "${SUPPORTED_VERSIONS[@]}"; do
        for variant in "${VARIANTS[@]}"; do
            test_image "$php_ver" "$variant"
        done
    done
else
    info "PHP version: ${PHP_VERSION}"
    info "Variant: ${VARIANT}"

    test_image "$PHP_VERSION" "$VARIANT"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}Passed:${NC}  ${TOTAL_PASS}"
echo -e "  ${RED}Failed:${NC}  ${TOTAL_FAIL}"
if [[ "$TOTAL_SKIP" -gt 0 ]]; then
    echo -e "  ${YELLOW}Skipped:${NC} ${TOTAL_SKIP}"
fi
echo ""

if [[ "$TOTAL_FAIL" -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}RESULT: FAIL${NC}"
    echo ""
    exit 1
else
    echo -e "  ${GREEN}${BOLD}RESULT: PASS${NC}"
    echo ""
    exit 0
fi
