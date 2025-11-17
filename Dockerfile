FROM alpine:edge AS builder

LABEL maintainer="Danila Vershinin <dvershinin@users.noreply.github.com>"

WORKDIR /opt

RUN apk add --no-cache build-base git autoconf libpsl-dev libtool cmake go curl nghttp2-dev zlib-dev automake rustup clang lld ninja pkgconf python3 linux-headers && rustup-init -y -q

# Prefer clang toolchain for BoringSSL/quiche on all arches (including arm64)
ENV CC=clang
ENV CXX=g++

COPY _dl/quiche.tar.gz /opt/quiche.tar.gz
COPY _dl/curl.tar.gz /opt/curl.tar.gz

RUN mkdir -p /opt/quiche-src && \
    tar -xzf /opt/quiche.tar.gz -C /opt/quiche-src --strip-components=1 && \
    rm /opt/quiche.tar.gz
RUN cd /opt/quiche-src && \
    RUST_BACKTRACE=1 PATH="$HOME/.cargo/bin:$PATH" cargo build -vv --package quiche --release --features ffi,pkg-config-meta,qlog --jobs $(nproc) && \
    mkdir -p quiche/deps/boringssl/src/lib && \
    ln -vnf $(find target/release -name libcrypto.a -o -name libssl.a) quiche/deps/boringssl/src/lib/

RUN mkdir -p /opt/curl-src && \
    tar -xzf /opt/curl.tar.gz -C /opt/curl-src --strip-components=1 && \
    rm /opt/curl.tar.gz
RUN cd /opt/curl-src && \
    autoreconf -fi && \
    ./configure LDFLAGS="-Wl,-rpath,/opt/quiche-src/target/release" --with-openssl=/opt/quiche-src/quiche/deps/boringssl/src --with-quiche=/opt/quiche-src/target/release --with-nghttp2 --with-zlib && \
    make -j $(nproc) && \
    make DESTDIR="/curl/" install

FROM alpine:edge
RUN apk add --no-cache nghttp2 zlib libpsl bash perl ca-certificates
COPY --from=builder /curl/usr/local/ /usr/local/

WORKDIR /opt
# add httpstat script
COPY _dl/httpstat.sh /opt/httpstat.sh
RUN chmod +x /opt/httpstat.sh

ENTRYPOINT ["curl"]
