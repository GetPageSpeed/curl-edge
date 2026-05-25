FROM alpine:edge AS builder

LABEL maintainer="Danila Vershinin <dvershinin@users.noreply.github.com>"

WORKDIR /opt

RUN apk add --no-cache build-base git autoconf libpsl-dev libtool cmake go curl nghttp2-dev zlib-dev automake rustup clang clang-dev clang-libclang lld ninja pkgconf python3 linux-headers && rustup-init -y -q

ENV LIBCLANG_PATH=/usr/lib

# Prefer clang toolchain for BoringSSL/quiche on all arches (including arm64)
ENV CC=clang
ENV CXX=g++

COPY _dl/quiche.tar.gz /opt/quiche.tar.gz
COPY _dl/curl.tar.gz /opt/curl.tar.gz

RUN mkdir -p /opt/quiche-src && \
    tar -xzf /opt/quiche.tar.gz -C /opt/quiche-src --strip-components=1 && \
    rm /opt/quiche.tar.gz
RUN cd /opt/quiche-src && \
    RUST_BACKTRACE=1 PATH="$HOME/.cargo/bin:$PATH" RUSTFLAGS="-C target-feature=-crt-static" cargo build -vv --package quiche --release --features ffi,pkg-config-meta,qlog --jobs $(nproc) && \
    mkdir -p quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib/ && \
    BORING_SSL_H=$(find /opt/quiche-src/target/release/build -path "*/boring-sys-*/*" -name ssl.h -path "*/openssl/*" | head -1) && \
    BORING_INC=$(dirname $(dirname "$BORING_SSL_H")) && \
    test -n "$BORING_INC" && test -d "$BORING_INC" && \
    ln -vnsfT "$BORING_INC" /opt/quiche-src/quiche/deps/boringssl/src/include

RUN mkdir -p /opt/curl-src && \
    tar -xzf /opt/curl.tar.gz -C /opt/curl-src --strip-components=1 && \
    rm /opt/curl.tar.gz
RUN cd /opt/curl-src && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/usr/local/lib" --with-openssl=/opt/quiche-src/quiche/deps/boringssl/src --with-quiche=/opt/quiche-src/target/release --with-nghttp2 --with-zlib && \
    make -j $(nproc) && \
    make DESTDIR="/curl/" install && \
    # libcurl.so.4 dynamically NEEDs libquiche.so.0; ship it into the runtime
    # image (only /curl/usr/local is copied to the final stage) and point the
    # rpath above at /usr/local/lib so the loader finds it there.
    install -D -m755 /opt/quiche-src/target/release/libquiche.so /curl/usr/local/lib/libquiche.so.0 && \
    ln -sf libquiche.so.0 /curl/usr/local/lib/libquiche.so

FROM alpine:edge
RUN apk add --no-cache nghttp2 zlib libpsl bash perl ca-certificates
COPY --from=builder /curl/usr/local/ /usr/local/

WORKDIR /opt
# add httpstat script
COPY _dl/httpstat.sh /opt/httpstat.sh
RUN chmod +x /opt/httpstat.sh

ENTRYPOINT ["curl"]
