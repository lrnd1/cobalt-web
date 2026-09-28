# syntax=docker/dockerfile:1
FROM node:22-alpine AS build

ARG COBALT_REF=main
ENV WEB_DEFAULT_API=__WEB_DEFAULT_API__
ENV WEB_HOST=__WEB_HOST__
ENV PNPM_HOME=/pnpm
ENV PATH="$PNPM_HOME:$PATH"

RUN apk add --no-cache git python3 make g++
RUN corepack enable && corepack prepare pnpm@9.6.0 --activate

WORKDIR /src
RUN git clone --depth 1 https://github.com/imputnet/cobalt.git . \
 && git fetch --depth 1 origin "${COBALT_REF}" \
 && git checkout --force "${COBALT_REF}"
RUN mkdir -p .git/logs \
 && echo "0000000000000000000000000000000000000000 $(git rev-parse HEAD)" > .git/logs/HEAD
RUN pnpm install --frozen-lockfile --filter=./web
RUN pnpm --filter=./web build

FROM caddy:2-alpine
COPY --from=build /src/web/build /templates
RUN printf '%s\n' \
  ':80 {' \
  '  root * /usr/share/caddy' \
  '  encode gzip' \
  '  try_files {path} /404.html' \
  '  file_server' \
  '}' \
  > /etc/caddy/Caddyfile
COPY <<'EOF' /entrypoint.sh
#!/bin/sh
set -eu
: "${WEB_DEFAULT_API:?set in .env}"
: "${WEB_HOST:?set in .env}"
case "$WEB_DEFAULT_API" in
  */) ;;
  *) WEB_DEFAULT_API="${WEB_DEFAULT_API}/" ;;
esac
rm -rf /usr/share/caddy
cp -a /templates /usr/share/caddy
find /usr/share/caddy -type f \( -name '*.js' -o -name '*.html' -o -name '*.json' -o -name '*.xml' \) \
  -exec sed -i \
    -e "s|__WEB_DEFAULT_API__|${WEB_DEFAULT_API}|g" \
    -e "s|__WEB_HOST__|${WEB_HOST}|g" \
    {} +
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
EOF
RUN chmod +x /entrypoint.sh
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
