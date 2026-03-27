# Homelab Services - srv-nana

This directory contains the configuration for homelab services including Ollama (AI model server), OpenCode (remote coding interface), and Portainer Agent (container management).

> **Note**: This setup is optimized for **Fedora systems** and systems with **SELinux** enabled.

## 🏗️ Architecture

This setup uses a **hybrid approach**:

- **Dokploy**: Runs independently in Docker Swarm mode (deployed via `install-dokploy.sh`)
- **Ollama**: Runs via Docker Compose (single host)
- **OpenCode**: Runs as a systemd service on the host and is exposed through `srv-hatchi` Caddy
- **Portainer Agent**: Runs as a Docker Swarm service to manage everything

## 📁 Files Overview

- `docker-compose.yml` - Ollama service configuration (Docker Compose)
- `opencode-web.env.example` - Example environment file for the OpenCode systemd service
- `portainer-agent-stack.yml` - Portainer Agent configuration (Docker Swarm Stack)
- `systemd/opencode-web.service` - OpenCode systemd service unit template
- `scripts/install-dokploy.sh` - Dokploy installation script with SELinux support

## 🚀 Deployment Options

### Step 1: Install Dokploy (Prerequisites)

First, install Dokploy which sets up the Docker Swarm cluster:

```bash
# Run as root (required for SELinux policies and Docker setup)
sudo scripts/install-dokploy.sh

# Or update existing Dokploy installation
sudo scripts/install-dokploy.sh update
```

**What this script does:**

- Installs Docker if not present
- Applies SELinux policies for Docker socket access
- Initializes Docker Swarm cluster
- Creates `dokploy-network` overlay network
- Deploys Dokploy services (PostgreSQL, Redis, Traefik, Dokploy)
- Sets up proper file contexts for SELinux

### Step 2: Deploy Ollama (Docker Compose)

Deploy Ollama using Docker Compose:

```bash
# Start Ollama service
cd srv-nana
docker-compose up -d
```

### Step 3: Install OpenCode web as a host service

OpenCode should run directly on `srv-nana` so it has access to local repos, SSH keys, and toolchains.

1. Copy the example env file and set the password:

```bash
sudo mkdir -p /etc/opencode
sudo cp srv-nana/opencode-web.env.example /etc/opencode/opencode-web.env
sudo chmod 600 /etc/opencode/opencode-web.env
sudoedit /etc/opencode/opencode-web.env
```

2. Install and start the systemd unit:

```bash
sudo cp srv-nana/systemd/opencode-web.service /etc/systemd/system/opencode-web.service
sudo systemctl daemon-reload
sudo systemctl enable --now opencode-web.service
```

3. Verify the local service:

```bash
sudo systemctl status opencode-web.service
source /etc/opencode/opencode-web.env
curl -u "${OPENCODE_SERVER_USERNAME}:${OPENCODE_SERVER_PASSWORD}" "http://127.0.0.1:${OPENCODE_PORT}/global/health"
```

4. Add the remote proxy settings to `/opt/homelab/.env` on `srv-hatchi`:

```bash
OPENCODE_HOST=100.91.192.69
OPENCODE_PORT=4096
```

5. Once the Caddy config is deployed on `srv-hatchi`, access OpenCode at:

```text
https://opencode.${DOMAIN}
```

### Step 4: Deploy Portainer Agent (Docker Swarm Stack)

Deploy Portainer Agent to manage all containers:

```bash
# Deploy Portainer Agent as Swarm service
cd srv-nana
docker stack deploy -c portainer-agent-stack.yml portainer
```

## 🔧 Service Details

### Dokploy (Deployment Platform)

- **Image**: `dokploy/dokploy:latest`
- **Port**: `3000` (Web UI)
- **Services**: PostgreSQL, Redis, Traefik
- **Network**: `dokploy-network` (overlay)
- **SELinux**: Custom policies applied for Docker socket access

### Ollama (AI Model Server)

- **Image**: `ollama/ollama`
- **Port**: `11434`
- **GPU Support**: NVIDIA GPU acceleration enabled
- **Volume**: Persistent storage for models in `/root/.ollama`
- **Network**: `nana-net` (bridge)
- **Deployment**: Docker Compose

### Portainer Agent

- **Image**: `portainer/agent:2.33.0`
- **Port**: `9001`
- **Mode**: Global (runs on all nodes)
- **Access**: Docker socket, volumes, and host filesystem
- **Network**: `agent_network` (overlay)
- **Deployment**: Docker Swarm Stack

### OpenCode Web

- **Binary**: `/home/dkumlin/.opencode/bin/opencode`
- **Port**: `4096`
- **Bind address**: `0.0.0.0`
- **Working directory**: `/home/dkumlin/Projects`
- **Auth**: HTTP basic auth via `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`
- **Public URL**: `https://opencode.${DOMAIN}` (proxied by `srv-hatchi`)
- **Deployment**: systemd service on the host

## 🛠️ Configuration Notes

### GPU Support

- Requires NVIDIA Docker runtime
- GPU resources are reserved for Ollama service
- Check GPU availability: `nvidia-smi`

### Volume Management

- Ollama models are stored in persistent volumes
- Volumes are automatically created if they don't exist
- Use `docker volume ls` to list volumes

### Security Considerations

- Portainer Agent has access to Docker socket (required for management)
- Consider firewall rules for exposed ports
- Treat OpenCode like remote shell access and keep basic auth enabled behind TLS
- Use secrets management for sensitive configuration

## 🔄 Integration with Dokploy

Since Dokploy runs in Swarm mode:

1. **Portainer Agent** can see and manage Dokploy services
2. **Overlay networks** allow communication between services
3. **Unified management** through Portainer web interface
4. **SELinux policies** ensure proper Docker socket access
5. **Fedora optimization** with proper file contexts and labels
6. **Remote coding access** is exposed through `srv-hatchi` Caddy at `opencode.${DOMAIN}`

## 📝 Quick Start Checklist

1. ✅ **Install Dokploy**: `sudo scripts/install-dokploy.sh`
2. ✅ **Verify Swarm**: `docker node ls`
3. ✅ **Check GPU**: `nvidia-smi` (for Ollama)
4. ✅ **Deploy Ollama**: `cd srv-nana && docker-compose up -d`
5. ✅ **Install OpenCode**: copy `srv-nana/systemd/opencode-web.service` and `srv-nana/opencode-web.env.example`
6. ✅ **Start OpenCode**: `sudo systemctl enable --now opencode-web.service`
7. ✅ **Deploy Portainer**: `cd srv-nana && docker stack deploy -c portainer-agent-stack.yml portainer`
6. ✅ **Access services**:
    - Dokploy UI: `http://localhost:3000`
    - Ollama API: `http://localhost:11434`
    - OpenCode Health: `http://localhost:4096/global/health`
    - Portainer Agent: `http://localhost:9001`

## 🆘 Common Issues

### SELinux Issues (Fedora)

- **Docker socket access denied**: Run `sudo scripts/install-dokploy.sh` to apply SELinux policies
- **File context issues**: Check with `ls -Z /etc/dokploy` and run `restorecon -Rv /etc/dokploy`
- **Container startup failures**: Verify SELinux policies with `semodule -l | grep dockersock`

### Port Conflicts

- Ensure ports 80, 443, 3000, 11434, and 9001 are not in use
- Check with: `ss -tulnp | grep :3000`

### GPU Issues

- Verify NVIDIA Docker runtime: `docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi`
- Check GPU resource allocation in service logs
- Ensure NVIDIA drivers are installed: `nvidia-smi`

### Network Issues

- Verify overlay network creation: `docker network ls`
- Check service connectivity: `docker service logs <service-name>`
- Ensure Swarm is initialized: `docker node ls`

### Dokploy Issues

- **Installation fails**: Ensure running as root and ports 80/443 are free
- **Services not starting**: Check SELinux status with `sestatus`
- **Update issues**: Use `sudo scripts/install-dokploy.sh update`

### OpenCode Issues

- **Service fails at startup**: Check `sudo journalctl -u opencode-web -n 100 --no-pager`
- **Binary missing**: Verify `/home/dkumlin/.opencode/bin/opencode` exists and is executable
- **Proxy returns 502**: Confirm `OPENCODE_HOST` in `/opt/homelab/.env` points to `srv-nana` and Caddy was restarted on `srv-hatchi`
- **Login fails**: Verify `/etc/opencode/opencode-web.env` contains the correct username/password and restart the service

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Ollama Documentation](https://ollama.ai/docs)
- [Portainer Documentation](https://docs.portainer.io/)
- [Dokploy Documentation](https://dokploy.com/docs)
- [SELinux with Docker](https://docs.docker.com/engine/security/selinux/)
- [Fedora Docker Installation](https://docs.docker.com/engine/install/fedora/)
