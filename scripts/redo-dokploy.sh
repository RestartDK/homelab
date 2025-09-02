#!/bin/bash

echo "🔄 Redoing Dokploy installation..."

# Check if we're running as root
if [ "$(id -u)" != "0" ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if install script exists
if [ ! -f "$SCRIPT_DIR/install-dokploy.sh" ]; then
    echo "❌ install-dokploy.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Check if cleanup script exists
if [ ! -f "$SCRIPT_DIR/cleanup-dokploy.sh" ]; then
    echo "❌ cleanup-dokploy.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Set the advertise address
export ADVERTISE_ADDR=192.168.200.182
echo "📍 Using advertise address: $ADVERTISE_ADDR"

# Run cleanup
echo ""
echo "🧹 Step 1: Cleaning up existing installation..."
"$SCRIPT_DIR/cleanup-dokploy.sh"

# Wait a moment for cleanup to complete
sleep 2

# Run installation
echo ""
echo "🚀 Step 2: Installing Dokploy fresh..."
"$SCRIPT_DIR/install-dokploy.sh"

echo ""
echo "🎉 Dokploy reinstallation completed!"
echo "🌐 Access your Dokploy instance at: http://$ADVERTISE_ADDR:3000"
