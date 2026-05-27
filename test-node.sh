#!/bin/sh
set -e

# cosign 3.0.6 breaks chainctl libraries verify (SLSA v1 predicate mismatch)
if ! command -v cosign >/dev/null 2>&1; then
    echo "ERROR: cosign not found. Install cosign <= 3.0.5." >&2
    exit 1
fi
COSIGN_VERSION=$(cosign version 2>&1 | grep '^GitVersion:' | sed 's/GitVersion:[[:space:]]*//' | sed 's/^v//')
COSIGN_MAJOR=$(echo "$COSIGN_VERSION" | cut -d. -f1)
COSIGN_MINOR=$(echo "$COSIGN_VERSION" | cut -d. -f2)
COSIGN_PATCH=$(echo "$COSIGN_VERSION" | cut -d. -f3)
if [ -z "$COSIGN_MAJOR" ] || [ "$COSIGN_MAJOR" -gt 3 ] || \
   { [ "$COSIGN_MAJOR" -eq 3 ] && [ "$COSIGN_MINOR" -gt 0 ]; } || \
   { [ "$COSIGN_MAJOR" -eq 3 ] && [ "$COSIGN_MINOR" -eq 0 ] && [ "$COSIGN_PATCH" -gt 5 ]; }; then
    echo "ERROR: cosign $COSIGN_VERSION is not supported. Use cosign <= 3.0.5 (3.0.6+ breaks chainctl libraries verify)." >&2
    exit 1
fi
echo "cosign $COSIGN_VERSION OK"

COMPOSE_FILE="docker-compose.yml"
if [ "${1:-}" = "--transparent" ]; then
    COMPOSE_FILE="docker-compose.transparent.yml"
    echo "==> Mode: transparent proxy"
else
    echo "==> Mode: explicit proxy"
fi

mkdir -p cache/npm
# clear previous cache so verify reflects only this run's packages
rm -rf cache/npm/*

echo ""
echo "==> Running node-client (npm install via proxy)..."
docker compose -f "$COMPOSE_FILE" --profile test run --rm node-client

echo ""
echo "==> Running chainctl libraries verify against npm cache..."
chainctl libraries verify --detailed "$(pwd)/cache/npm"

echo ""
echo "==> Done."
