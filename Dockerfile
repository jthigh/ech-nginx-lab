# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim AS build

ARG NGINX_VERSION=1.29.5
ARG OPENSSL_GIT_REF=feature/ech
ARG NGINX_SHA256=

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        libpcre2-dev \
        perl \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN git clone --depth 1 --branch "${OPENSSL_GIT_REF}" https://github.com/openssl/openssl.git openssl-ech

WORKDIR /usr/src/openssl-ech

RUN ./config \
        --prefix=/opt/openssl-ech \
        --openssldir=/opt/openssl-ech \
        no-tests \
    && make -j"$(nproc)" \
    && make install_sw

WORKDIR /usr/src

RUN curl -fsSLO "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
    && if [ -n "${NGINX_SHA256}" ]; then \
         echo "${NGINX_SHA256}  nginx-${NGINX_VERSION}.tar.gz" | sha256sum -c -; \
       fi \
    && tar -xzf "nginx-${NGINX_VERSION}.tar.gz"

WORKDIR /usr/src/nginx-${NGINX_VERSION}

RUN ./configure \
        --prefix=/usr/local/nginx \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --pid-path=/tmp/nginx.pid \
        --lock-path=/tmp/nginx.lock \
        --http-log-path=/dev/stdout \
        --error-log-path=/dev/stderr \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-threads \
        --with-file-aio \
        --with-openssl=/usr/src/openssl-ech \
        --with-openssl-opt='no-tests' \
        --with-cc-opt='-O2 -fstack-protector-strong -Wformat -Werror=format-security' \
        --with-ld-opt='-Wl,-z,relro -Wl,-z,now' \
    && make -j"$(nproc)" \
    && make install

FROM debian:bookworm-slim

ARG NGINX_VERSION=1.29.5
ARG OPENSSL_GIT_REF=feature/ech

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/openssl-ech/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LABEL org.opencontainers.image.title="ech-nginx"
LABEL org.opencontainers.image.description="Custom nginx build with OpenSSL ECH branch"
LABEL org.opencontainers.image.version="${NGINX_VERSION}"
LABEL org.opencontainers.image.source="https://nginx.org/download/"
LABEL org.opencontainers.image.vendor="local"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libpcre2-8-0 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 101 nginx \
    && useradd --system --uid 101 --gid nginx --home-dir /nonexistent --shell /usr/sbin/nologin nginx

COPY --from=build /usr/local/nginx /usr/local/nginx
COPY --from=build /usr/local/sbin/nginx /usr/local/sbin/nginx
COPY --from=build /opt/openssl-ech /opt/openssl-ech

RUN printf '%s\n' \
        "/opt/openssl-ech/lib64" \
        "/opt/openssl-ech/lib" \
        > /etc/ld.so.conf.d/openssl-ech.conf \
    && ldconfig \
    && install -d -o 101 -g 101 -m 0755 /var/cache/nginx /run \
    && install -d -o 101 -g 101 -m 1777 /tmp

USER 101:101

EXPOSE 8443

STOPSIGNAL SIGQUIT

CMD ["/usr/local/sbin/nginx", "-g", "daemon off;"]
