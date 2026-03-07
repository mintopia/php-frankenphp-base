#!/usr/bin/env bash
# =============================================================================
# build.sh — Build PHP FrankenPHP base Docker images locally
#
# Usage:
#   ./scripts/build.sh                  # Build PHP 8.4 base + dev
#   ./scripts/build.sh 8.3              # Build PHP 8.3 base + dev
#   ./scripts/build.sh 8.4 base         # Build PHP 8.4 base only
#   ./scripts/build.sh 8.4 dev          # Build PHP 8.4 dev only
#   ./scripts/build.sh --all            # Build all PHP versions, both variants
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
IMAGE_NAME="frankenphp-base"
SUPPORTED_VERSIONS=(8.2 8.3 8.4 8.5)
VARIANTS=(base dev)

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    echo "Usage: $0 [--all | PHP_VERSION] [VARIANT]"
    echo ""
    echo "  PHP_VERSION  One of: ${SUPPORTED_VERSIONS[*]} (default: 8.4)"
    echo "  VARIANT      One of: base, dev, or omit for both (default: both)"
    echo "  --all        Build all supported PHP versions, both variants"
    exit 1
}

# ---------------------------------------------------------------------------
# Build a single image
# ---------------------------------------------------------------------------
build_image() {
    local php_version="$1"
    local variant="$2"
    local tag="${IMAGE_NAME}:php${php_version}-${variant}"

    info "Building ${BOLD}${tag}${NC} (PHP ${php_version}, target: ${variant}) …"

    local rc=0
    DOCKER_BUILDKIT=1 docker build \
        --build-arg PHP_VERSION="${php_version}" \
        --target "${variant}" \
        --tag "${tag}" \
        . || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        return "$rc"
    fi

    ok "Built ${BOLD}${tag}${NC}"
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
BUILD_ALL=false
PHP_VERSION="8.4"
SELECTED_VARIANTS=("${VARIANTS[@]}")

if [[ $# -ge 1 ]]; then
    case "$1" in
        --all)
            BUILD_ALL=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            PHP_VERSION="$1"
            ;;
    esac
fi

if [[ $# -ge 2 && "$BUILD_ALL" == false ]]; then
    case "$2" in
        base|dev)
            SELECTED_VARIANTS=("$2")
            ;;
        *)
            err "Unknown variant '$2'. Must be 'base' or 'dev'."
            usage
            ;;
    esac
fi

# Validate the PHP version when not building all
if [[ "$BUILD_ALL" == false ]]; then
    valid=false
    for v in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$v" == "$PHP_VERSION" ]]; then
            valid=true
            break
        fi
    done
    if [[ "$valid" == false ]]; then
        err "Unsupported PHP version '${PHP_VERSION}'. Supported: ${SUPPORTED_VERSIONS[*]}"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Resolve the project root (one directory up from this script)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

# ---------------------------------------------------------------------------
# Run builds
# ---------------------------------------------------------------------------
START_TIME=$(date +%s)
BUILD_COUNT=0
FAILED=0

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     FrankenPHP Base Image Builder             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$BUILD_ALL" == true ]]; then
    info "Building ALL versions: ${SUPPORTED_VERSIONS[*]}"
    info "Variants: ${VARIANTS[*]}"
    echo ""

    for php_ver in "${SUPPORTED_VERSIONS[@]}"; do
        for variant in "${VARIANTS[@]}"; do
            if build_image "$php_ver" "$variant"; then
                BUILD_COUNT=$((BUILD_COUNT + 1))
            else
                err "Failed to build php${php_ver}-${variant}"
                FAILED=$((FAILED + 1))
            fi
            echo ""
        done
    done
else
    info "PHP version: ${PHP_VERSION}"
    info "Variants: ${SELECTED_VARIANTS[*]}"
    echo ""

    for variant in "${SELECTED_VARIANTS[@]}"; do
        if build_image "$PHP_VERSION" "$variant"; then
            BUILD_COUNT=$((BUILD_COUNT + 1))
        else
            err "Failed to build php${PHP_VERSION}-${variant}"
            FAILED=$((FAILED + 1))
        fi
        echo ""
    done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo -e "${BOLD}──────────────────────────────────────────────${NC}"
if [[ "$FAILED" -eq 0 ]]; then
    ok "All ${BUILD_COUNT} image(s) built successfully in ${MINS}m ${SECS}s"
else
    err "${FAILED} build(s) failed, ${BUILD_COUNT} succeeded (${MINS}m ${SECS}s)"
    exit 1
fi
