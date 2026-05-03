# Joshi Meets

**Joshi Meets** is the video collaboration stack for **[joshi1.com](https://joshi1.com)** — a scalable, self-hosted meeting experience built on [LiveKit](https://livekit.io/) and the [plugNmeet](https://www.plugnmeet.org/) open-source conferencing server.

This repository contains the **API server** (Go). The web UI comes from [plugNmeet-client](https://github.com/mynaparrot/plugNmeet-client) (React); recordings are handled by [plugNmeet-recorder](https://github.com/mynaparrot/plugNmeet-recorder). We retain upstream module paths so you can merge security fixes from [mynaparrot/plugNmeet-server](https://github.com/mynaparrot/plugNmeet-server) without a painful import rewrite.

![Joshi Meets banner](./github_files/banner.svg)

## Why Joshi Meets

- **HD video & screen share** with simulcast / dynacast for rough networks  
- **Whiteboard, polls, breakout rooms, shared notepad**  
- **Optional AI**: live translation, transcription, summaries (configure in `config.yaml`)  
- **SIP dial-in**, RTMP ingress, MP4 recording — same capabilities as upstream plugNmeet  
- **Your domain**: run everything behind `joshi1.com` with your TLS and branding  

## Quick architecture for joshi1.com

| Layer | Suggested host | Notes |
|--------|-----------------|--------|
| Web + API | `https://meet.joshi1.com` (or `https://joshi1.com/meet`) | This server + static client `client/dist` or CDN |
| LiveKit | `wss://livekit.joshi1.com` | UDP `7882` / TCP `7880` must reach your edge |
| NATS (browser) | `wss://nats.joshi1.com` | Must match `nats_ws_urls` in config |
| TURN | LiveKit default or Cloudflare / coturn | See `config_sample.yaml` |

Point your **plugNmeet client** build at your public API URL so tokens and room joins hit this server.

## Deploy to production (checklist)

These steps assume a single VPS or small cluster (Docker Compose or Kubernetes). Adapt names if you use a subdomain layout other than below.

### 1. DNS

Create records (example):

- `meet.joshi1.com` → your reverse proxy (API + static UI)  
- `livekit.joshi1.com` → same host or dedicated media node  
- `nats.joshi1.com` → WebSocket endpoint for NATS (often same edge as API)  

### 2. Copy and edit config

```bash
cp config_sample.yaml config.yaml
```

**Must set for joshi1.com:**

- `client.api_key` / `client.secret` — strong random values (`openssl rand -hex 32`)  
- `client.copyright_conf.text` — already oriented to Joshi Meets; tweak as you like  
- `client.bbb_join_host` — public origin users use to open the app, e.g. `https://meet.joshi1.com`  
- `livekit_info.host` — e.g. `https://livekit.joshi1.com` with matching API key/secret from LiveKit  
- `nats_info.nats_urls` — reachable from this server (`nats://...`)  
- `nats_info.nats_ws_urls` — **browser-visible** WebSocket URL(s), e.g. `https://nats.joshi1.com`  
- `redis_info`, `database_info` — your Redis and MySQL/MariaDB  

Keep the database name aligned with `sql_dump/install.sql` (default `plugnmeet`) unless you change the dump and `database_info.db` together.

### 3. TLS termination

Use **Caddy** or **nginx** (or a cloud load balancer) with valid certificates:

- Terminate HTTPS on `meet.joshi1.com` and proxy to this service on port `8080` (or your `client.port`).  
- WebSocket upgrades must be enabled for NATS and LiveKit paths your deployment exposes.  

### 4. Client assets

Either:

- Build [plugNmeet-client](https://github.com/mynaparrot/plugNmeet-client) with your API base URL and place output in `client/dist`, **or**  
- Set `client.asset_host` in `config.yaml` if you ship JS/CSS from a CDN.  

For a **full visual rebrand** (logo, colors, copy), fork or theme the client repo; this server only controls footer copyright text and server-driven settings.

### 5. Run with Docker

See [docker-compose_sample.yaml](./docker-compose_sample.yaml) for a full stack (Redis, MariaDB, NATS, LiveKit, Etherpad, API). For production, replace dev bind-mounts with release images and secrets via env or mounted `config.yaml`.

Official images (usable while you publish your own):

- `mynaparrot/plugnmeet-server`  
- `mynaparrot/plugnmeet-etherpad`  
- `mynaparrot/plugnmeet-recorder`  

### Small VPS (~1 GB RAM)

For **small rooms only**, use the trimmed stack (no Etherpad, no SIP, no RTMP ingress):

1. On the server: `git clone https://github.com/JaytirthJOSHI/Joshi-Meets.git && cd Joshi-Meets`  
2. Run `./scripts/install-small-vps.sh`  
3. Copy [env.small.example](./env.small.example) to `.env` and set `MYSQL_ROOT_PASSWORD` and `JOSHI_MEETS_IMAGE` (your Docker Hub username + `/joshi-meets-server:dev`).  
4. Edit `config.yaml`: keep Redis/DB/NATS/LiveKit pointed at compose service names; set `shared_notepad.enabled: false` (Etherpad is not in the small compose).  
5. Add **swap** (about 2 GB) if the host has little free RAM.  
6. Start: `docker compose -f docker-compose.small.yaml --env-file .env up -d`  

Put a production build of [plugNmeet-client](https://github.com/mynaparrot/plugNmeet-client) in `client/dist/`. Terminate TLS on the host (Caddy/nginx) and proxy to `127.0.0.1:8080`.

### 6. CI/CD and auto-deploy

- **CI** ([.github/workflows/ci.yml](.github/workflows/ci.yml)): on every PR and `main` push — `go mod verify` and a Docker build (no push).  
- **Docker Hub** ([.github/workflows/release-dev-dockerhub.yml](.github/workflows/release-dev-dockerhub.yml)): on every push to `main`, builds and pushes **`YOUR_DOCKERHUB/joshi-meets-server:dev`** and **`YOUR_DOCKERHUB/plugnmeet-server:dev`** (same digest). Configure secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_ACCESS_TOKEN`.  
- **Deploy** ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)): SSH into your VPS, `docker compose pull`, restart **only** `joshi-meets-api`.  

**GitHub repository settings**

| Type | Name | Purpose |
|------|------|---------|
| Secret | `DOCKERHUB_USERNAME` | Docker Hub user |
| Secret | `DOCKERHUB_ACCESS_TOKEN` | Docker Hub access token |
| Secret | `DEPLOY_HOST` | VPS hostname or IP |
| Secret | `DEPLOY_USER` | SSH user (e.g. `ubuntu`, `root`) |
| Secret | `DEPLOY_SSH_KEY` | Private key for that user |
| Variable | `DEPLOY_REMOTE_DIR` | Absolute path to the repo on the server (e.g. `/home/ubuntu/Joshi-Meets`) |
| Variable | `DEPLOY_COMPOSE_FILE` | Optional: `docker-compose.small.yaml` if you did not rename it to `docker-compose.yml` |
| Variable | `DEPLOY_SSH_PORT` | Optional SSH port (default `22`) |
| Variable | `AUTO_DEPLOY_ON_IMAGE_PUSH` | Set to `true` to deploy automatically after each successful Docker Hub push on `main` |

Run a deploy anytime: **Actions → Deploy to server → Run workflow**.

## Local development

Follow the upstream guide: [plugNmeet developer setup](https://www.plugnmeet.org/docs/developer-guide/setup-development). This repo’s `go.mod` intentionally stays compatible with `github.com/mynaparrot/plugNmeet-server` imports.

## Upstream documentation

- Installation: [plugnmeet.org/docs/installation](https://www.plugnmeet.org/docs/installation)  
- API: [plugnmeet.org/docs/api/intro](https://www.plugnmeet.org/docs/api/intro)  
- SDKs: [PHP](https://github.com/mynaparrot/plugNmeet-sdk-php), [JavaScript](https://github.com/mynaparrot/plugNmeet-sdk-js)  

## Contributing

Issues and PRs welcome for **Joshi Meets–specific** branding, docs, and deployment polish. Core protocol changes should ideally go upstream to [mynaparrot/plugNmeet-server](https://github.com/mynaparrot/plugNmeet-server) when applicable.

## License

See [LICENSE](./LICENSE) (inherits upstream licensing).
