#!/bin/bash

echo "🔄 Redoing Dokploy installation..."

# Check if we're running as root
if [ "$(id -u)" != "0" ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Check if install script exists
if [ ! -f "./install-dokploy.sh" ]; then
    echo "❌ install-dokploy.sh not found in current directory"
    exit 1
fi

# Check if cleanup script exists
if [ ! -f "./cleanup-dokploy.sh" ]; then
    echo "❌ cleanup-dokploy.sh not found in current directory"
    exit 1
fi

# Set the advertise address
export ADVERTISE_ADDR=192.168.200.182
echo "📍 Using advertise address: $ADVERTISE_ADDR"

# Run cleanup
echo ""
echo "🧹 Step 1: Cleaning up existing installation..."
./cleanup-dokploy.sh

# Wait a moment for cleanup to complete
sleep 2

# Run installation
echo ""
echo "🚀 Step 2: Installing Dokploy fresh..."
./install-dokploy.sh

echo ""
echo "🎉 Dokploy reinstallation completed!"
echo "🌐 Access your Dokploy instance at: http://$ADVERTISE_ADDR:3000"
