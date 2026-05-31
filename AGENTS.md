# Homelab Agent Guide

This file is the durable context for AI agents working in this repo. Read it before editing or operating the homelab.

## Purpose

This repo manages Daniel's homelab configuration: self-hosted services, reverse proxy config, monitoring, service deployment notes, and host-specific setup.

## Current topology

The homelab currently has two main machines on Daniel's home network, connected through Tailscale:

- **Hachi** — primary homelab server.
  - A laptop running **Fedora Server**.
  - Runs the main stack from the repo root `docker-compose.yml`.
  - The stack is Compose syntax but is currently expected to run with **Podman / Podman Compose** unless the host proves otherwise.
  - Hosts core services such as AdGuard Home, Caddy, Glance, media services, Nextcloud AIO, Portainer, CouchDB, Grafana, Prometheus, and related volumes/networks.
  - Caddy terminates HTTPS using Cloudflare DNS challenge and proxies both local Hachi services and selected Nana services.
  - Cockpit is used for host admin tasks.

- **Nana** — normal workstation / dev environment.
  - Runs **Fedora 43**.
  - Used as Daniel's development machine.
  - Host-specific config lives in `srv-nana/`.
  - Runs services such as Ollama, server-status, node-exporter, OpenCode web, Portainer Agent, and Dokploy-related Docker/Swarm components.
  - Some Nana services are reached through Hachi's Caddy proxy via env vars such as `OLLAMA_HOST`, `OLLAMA_PORT`, `OPENCODE_HOST`, and `OPENCODE_PORT`.

Use the names **Hachi** and **Nana**. If old docs or paths mention `srv-hatchi` / `hatchi`, verify whether that is a legacy typo before propagating it.

## Important repo files

- `README.md` — high-level project notes and known limitations.
- `docker-compose.yml` — main Hachi service stack.
- `Caddyfile` — public HTTPS reverse proxy routes.
- `adguard/AdGuardHome.yaml` — AdGuard Home config.
- `glance/config/glance.yml` — dashboard config.
- `prometheus/prometheus.yml` — Prometheus scrape config.
- `srv-nana/README.md` — Nana architecture and deployment notes.
- `srv-nana/docker-compose.yml` — Nana Docker Compose services.
- `srv-nana/systemd/opencode-web@.service` — OpenCode web host service.
- `scripts/` — Dokploy and maintenance scripts.
- `selinux/` — SELinux policy helpers.

## Safety rules

- Do not expose, print, commit, or invent secrets. `.env` files are intentionally ignored.
- Do not run destructive commands without explicit confirmation. This includes deleting volumes, pruning containers/images, removing data directories, changing firewall/router/DNS state, rotating credentials, or reinitializing Swarm/Podman networks.
- Do not deploy, restart, or stop live services unless Daniel asks for live operations or approves the plan.
- Before a potentially disruptive change, explain the expected impact and rollback path.
- Prefer read-only diagnostics first when troubleshooting.
- Treat OpenCode, Portainer, Cockpit, Dokploy, Docker/Podman sockets, and Cloudflare tokens as highly sensitive.
- Never assume current live state from memory. Inspect repo files and, for live ops, inspect the host.

## Standard workflow for agents

1. Run `git status --short --branch` from the repo root.
2. Read this file plus the relevant README/config files for the requested change.
3. Identify whether the task affects Hachi, Nana, or both.
4. Make the smallest safe repo change.
5. Validate syntax/config when possible.
6. Summarize changed files, operational impact, and exact deploy commands if deployment is needed.

## Editing conventions

### Hachi root stack

- Main stack: `docker-compose.yml` at the repo root.
- Keep Podman compatibility in mind:
  - preserve SELinux volume labels (`:Z` for private labels, `:z` for shared labels) unless there is a clear reason not to;
  - preserve `user: "1000:1000"` and `userns_mode: "keep-id:uid=1000,gid=1000"` patterns for media-style services where present;
  - preserve the rootless Podman socket path for Portainer/Nextcloud AIO unless intentionally changing runtime;
  - keep `caddynet` as an external network for services proxied by Caddy.
- For a new web service, usually update all applicable places:
  - service definition in `docker-compose.yml`;
  - required env vars in the deployed `.env` or an example file if one exists;
  - Caddy route in `Caddyfile`;
  - AdGuard DNS rewrite/manual note if a new subdomain is introduced;
  - Glance labels or `glance/config/glance.yml` if it should appear on the dashboard;
  - persistent named volumes and SELinux labels;
  - README/runbook notes if operationally important.

### Nana services

- Nana-specific services live under `srv-nana/`.
- `srv-nana/docker-compose.yml` uses Docker Compose for services such as Ollama and exporters.
- OpenCode web runs as a host systemd service, not a container. Check `srv-nana/systemd/opencode-web@.service` and `srv-nana/opencode-web.env.example`.
- Nana may use Docker, Docker Swarm, GPU/NVIDIA runtime, and SELinux-specific setup. Do not assume Podman there unless verified.

## Secrets and environment

- Root `.env` and host env files are not in git.
- Hachi deployment env may live at `/opt/homelab/.env`; verify before relying on that path.
- Nana OpenCode env is documented as `/etc/opencode/opencode-web.env`.
- If adding a required variable, document the variable name and purpose, but do not add real values.

## Useful read-only checks

Run only where appropriate and after verifying SSH/hostnames:

```bash
# Local repo
cd /Users/danielkumlin/Projects/homelab
git status --short --branch

# Tailscale / host reachability
tailscale status
ssh hachi 'hostname; cat /etc/fedora-release; tailscale status | head'
ssh nana 'hostname; cat /etc/fedora-release; tailscale status | head'

# Hachi Podman stack, command name may be podman-compose or podman compose
ssh hachi 'cd /opt/homelab && podman-compose ps'
ssh hachi 'podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Nana Docker stack
ssh nana 'cd ~/Projects/homelab/srv-nana && docker compose ps'
ssh nana 'sudo systemctl status opencode-web@$(whoami).service --no-pager'
```

If these hostnames or paths fail, ask Daniel for the correct SSH names or deployment paths instead of guessing.

## Validation ideas

- Use `git diff` to review changes.
- Validate YAML/Compose with host-appropriate tools when available, e.g. `podman-compose config`, `podman compose config`, or `docker compose config`.
- Validate Caddy config on the target host/container when available, e.g. `caddy validate --config /etc/caddy/Caddyfile` or the equivalent container command.
- For service changes, check logs after deployment with `podman logs`, `docker logs`, `journalctl`, or service-specific health endpoints.
