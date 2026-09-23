#!/bin/sh
set -eu

workflow=".github/workflows/main.yml"
dockerfile="Dockerfile"

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

if ! grep -Fxq 'ENV CXX=clang++' "$dockerfile"; then
    echo "BoringSSL must use clang++ for its C++ compiler flags" >&2
    exit 1
fi
if ! grep -Fq 'CXXFLAGS="-isystem $(dirname "$(dirname "$(find /usr/include/c++ -name c++config.h -print -quit)")")"' "$dockerfile" || \
   ! grep -Fq 'libpsl libstdc++ bash' "$dockerfile" || \
   ! grep -Fq 'LIBS="-lstdc++"' "$dockerfile"; then
    echo "Clang must use Alpine's libstdc++ headers and runtime" >&2
    exit 1
fi

echo "CI cache configuration is resilient and architecture-scoped."
