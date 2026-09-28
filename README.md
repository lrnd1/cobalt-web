# cobalt-web

ARM64 Docker image of the official [imputnet/cobalt](https://github.com/imputnet/cobalt) **web** UI. The official Cobalt image is API-only; this repo builds the static frontend and serves it with Caddy.

URLs are **not** baked in at build time. Set them when you run the container.

## Image

```
ghcr.io/<your-github-user>/cobalt-web:latest
ghcr.io/<your-github-user>/cobalt-web:src-<12-char-sha>
```

- Platform: `linux/arm64` only
- Listens on port `80` (HTTP). Put your own reverse proxy in front for TLS.
- Rebuilds on GitHub Actions when the upstream `web/` tree changes (daily cron + manual dispatch).

## Run

```yaml
services:
  cobalt-web:
    image: ghcr.io/<your-github-user>/cobalt-web:latest
    container_name: cobalt-web
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:80"
    environment:
      WEB_HOST: cobalt.example.com
      WEB_DEFAULT_API: https://api.example.com/
```

| Variable | Required | Example |
| --- | --- | --- |
| `WEB_HOST` | yes | `cobalt.example.com` (hostname only) |
| `WEB_DEFAULT_API` | yes | `https://api.example.com/` (include scheme; trailing `/` is added if missing) |

Change env → restart the container. No image rebuild.

You still need a Cobalt **API** container (`ghcr.io/imputnet/cobalt`) and `API_URL` on that service set to the same public API URL the browser uses.

## What the build does

1. Clones `imputnet/cobalt` at the latest commit that touched `web/`.
2. Builds the SvelteKit app with placeholders (`__WEB_HOST__`, `__WEB_DEFAULT_API__`).
3. Copies the static files into `caddy:2-alpine`.
4. On start, `/entrypoint.sh` (generated in the image) substitutes the placeholders from `environment:` and starts Caddy.

Skip logic: if `src-<sha>` already exists on GHCR, the scheduled workflow does not rebuild. `workflow_dispatch` and Dockerfile changes always build.

## Actions

Workflow: `.github/workflows/build.yml`  
Schedule: `0 0 * * *` (`Europe/London` if your runner supports `timezone` on `schedule`).

No GitHub Actions variables are required for URLs.

## License

- This repo’s Dockerfile / workflow: use as you like.
- Cobalt web source: [CC-BY-NC-SA-4.0](https://github.com/imputnet/cobalt/blob/main/web/LICENSE). Branding stays with imput. Non-commercial unmodified hosting is allowed by their README.
