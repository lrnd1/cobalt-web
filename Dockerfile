# syntax=docker/dockerfile:1
FROM node:22-alpine AS build

ARG COBALT_REF=main
ARG WEB_HOST
ARG WEB_DEFAULT_API

ENV WEB_HOST=$WEB_HOST
ENV WEB_DEFAULT_API=$WEB_DEFAULT_API
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
COPY --from=build /src/web/build /usr/share/caddy
RUN printf '%s\n' \
  ':80 {' \
  '  root * /usr/share/caddy' \
  '  encode gzip' \
  '  try_files {path} /404.html' \
  '  file_server' \
  '}' \
  > /etc/caddy/Caddyfile
EXPOSE 80
