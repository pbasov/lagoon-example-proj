ARG IMAGE_REPO
FROM ${IMAGE_REPO:-lagoon}/commons as commons
FROM openresty/openresty:1.21.4.3-3-alpine

LABEL org.opencontainers.image.authors="The Lagoon Authors" maintainer="The Lagoon Authors"
LABEL org.opencontainers.image.source="https://github.com/uselagoon/lagoon-images" repository="https://github.com/uselagoon/lagoon-images"

ENV LAGOON=nginx

ARG LAGOON_VERSION
ENV LAGOON_VERSION=$LAGOON_VERSION

# Copy commons files
COPY --from=commons /lagoon /lagoon
COPY --from=commons /bin/fix-permissions /bin/ep /bin/docker-sleep /bin/wait-for /bin/
COPY --from=commons /sbin/tini /sbin/
COPY --from=commons /home /home

RUN fix-permissions /etc/passwd \
    && mkdir -p /home

ENV TMPDIR=/tmp \
    TMP=/tmp \
    HOME=/home \
    # When Bash is invoked via `sh` it behaves like the old Bourne Shell and sources a file that is given in `ENV`
    ENV=/home/.bashrc \
    # When Bash is invoked as non-interactive (like `bash -c command`) it sources a file that is given in `BASH_ENV`
    BASH_ENV=/home/.bashrc

RUN apk update \
    && apk add --no-cache \
        openssl \
        rsync \
        tar \
    && rm -rf /var/cache/apk/*

RUN rm -Rf /etc/nginx && ln -s /usr/local/openresty/nginx/conf /etc/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY fastcgi.conf /etc/nginx/fastcgi.conf
COPY fastcgi.conf /etc/nginx/fastcgi_params
COPY helpers/ /etc/nginx/helpers/
COPY static-files.conf /etc/nginx/conf.d/app.conf
COPY redirects-map.conf /etc/nginx/redirects-map.conf
COPY healthcheck/healthz.locations healthcheck/healthz.locations.php.disable /etc/nginx/conf.d/

RUN mkdir -p /app \
    && rm -f /etc/nginx/conf.d/default.conf \
    && fix-permissions /usr/local/openresty/nginx \
    && fix-permissions /var/run/

COPY docker-entrypoint /lagoon/entrypoints/70-nginx-entrypoint
COPY matomo/80-nginx-matomo-config /lagoon/entrypoints/

WORKDIR /app

EXPOSE 8080

# tells the local development environment on which port we are running
ENV LAGOON_LOCALDEV_HTTP_PORT=8080

ENTRYPOINT ["/sbin/tini", "--", "/lagoon/entrypoints.sh"]
CMD ["nginx", "-g", "daemon off;"]
