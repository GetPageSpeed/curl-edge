#!/bin/sh
set -eu

workflow=".github/workflows/main.yml"

assert_line() {
    if ! grep -Fq "$1" "$workflow"; then
        echo "Missing required workflow configuration: $1" >&2
        exit 1
    fi
}

assert_line "cache-from: type=gha,scope=curl-edge-amd64"
assert_line "cache-to: type=gha,scope=curl-edge-amd64,mode=max,ignore-error=true"
assert_line "cache-from: type=gha,scope=curl-edge-arm64"
assert_line "cache-to: type=gha,scope=curl-edge-arm64,mode=max,ignore-error=true"
assert_line "uses: actions/checkout@v6"
assert_line "uses: docker/login-action@v4"
assert_line "uses: docker/setup-buildx-action@v4"
assert_line "uses: docker/build-push-action@v7"

echo "CI cache configuration is resilient and architecture-scoped."
