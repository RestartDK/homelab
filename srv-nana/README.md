# Homelab Services - srv-nana

This directory contains the configuration for homelab services including Ollama (AI model server) and Portainer Agent (container management).

> **Note**: This setup is optimized for **Fedora systems** and systems with **SELinux** enabled.

## 🏗️ Architecture

This setup uses a **hybrid approach**:

- **Dokploy**: Runs independently in Docker Swarm mode (deployed via `install-dokploy.sh`)
- **Ollama**: Runs via Docker Compose (single host)
- **Portainer Agent**: Runs as a Docker Swarm service to manage everything

## 📁 Files Overview

- `docker-compose.yml` - Ollama service configuration (Docker Compose)
- `portainer-agent-stack.yml` - Portainer Agent configuration (Docker Swarm Stack)
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

### Step 3: Deploy Portainer Agent (Docker Swarm Stack)

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
- Use secrets management for sensitive configuration

## 🔄 Integration with Dokploy

Since Dokploy runs in Swarm mode:

1. **Portainer Agent** can see and manage Dokploy services
2. **Overlay networks** allow communication between services
3. **Unified management** through Portainer web interface
4. **SELinux policies** ensure proper Docker socket access
5. **Fedora optimization** with proper file contexts and labels

## 📝 Quick Start Checklist

1. ✅ **Install Dokploy**: `sudo scripts/install-dokploy.sh`
2. ✅ **Verify Swarm**: `docker node ls`
3. ✅ **Check GPU**: `nvidia-smi` (for Ollama)
4. ✅ **Deploy Ollama**: `cd srv-nana && docker-compose up -d`
5. ✅ **Deploy Portainer**: `cd srv-nana && docker stack deploy -c portainer-agent-stack.yml portainer`
6. ✅ **Access services**:
   - Dokploy UI: `http://localhost:3000`
   - Ollama API: `http://localhost:11434`
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

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Ollama Documentation](https://ollama.ai/docs)
- [Portainer Documentation](https://docs.portainer.io/)
- [Dokploy Documentation](https://dokploy.com/docs)
- [SELinux with Docker](https://docs.docker.com/engine/security/selinux/)
- [Fedora Docker Installation](https://docs.docker.com/engine/install/fedora/)
