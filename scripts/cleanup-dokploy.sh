#!/bin/bash

echo "🧹 Cleaning up Dokploy installation..."

# Function to check if command exists
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# Check if Docker is running
if ! command_exists docker; then
    echo "❌ Docker is not installed or not running"
    exit 1
fi

# Stop and remove any running dokploy containers
echo "📦 Stopping and removing Dokploy containers..."
docker ps -a --filter "name=dokploy" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true

# Remove dokploy services
echo "🔧 Removing Dokploy services..."
docker service ls --filter "name=dokploy" --format "{{.ID}}" | xargs -r docker service rm 2>/dev/null || true

# Remove dokploy networks
echo "🌐 Removing Dokploy networks..."
docker network ls --filter "name=dokploy" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true

# Remove dokploy volumes
echo "💾 Removing Dokploy volumes..."
docker volume ls --filter "name=dokploy" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true

# Remove dokploy images (optional - uncomment if you want to remove images too)
# echo "🖼️  Removing Dokploy images..."
# docker images --filter "reference=dokploy/*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true

# Clean up dokploy directory
echo "📁 Removing Dokploy configuration directory..."
sudo rm -rf /etc/dokploy 2>/dev/null || true

# Leave Docker swarm
echo "🐝 Leaving Docker swarm..."
docker swarm leave --force 2>/dev/null || true

# Clean up any remaining dokploy-related resources
echo "🧽 Cleaning up any remaining resources..."
docker system prune -f --filter "label=com.docker.swarm.service.name=dokploy" 2>/dev/null || true

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "To reinstall Dokploy, run:"
echo "  export ADVERTISE_ADDR=192.168.200.182"
echo "  sudo ./install-dokploy.sh"
echo ""
echo "Or simply run:"
echo "  sudo ./redo-dokploy.sh"
