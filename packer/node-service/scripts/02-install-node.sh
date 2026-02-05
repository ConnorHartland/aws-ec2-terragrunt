#!/bin/bash
set -euo pipefail

echo "=== Installing Node.js ${NODE_VERSION} ==="

# Install Node.js via NodeSource
curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
sudo dnf install -y nodejs

# Verify installation
node --version
npm --version

# Configure npm for production
sudo npm config set --global audit false
sudo npm config set --global fund false

echo "=== Node.js ${NODE_VERSION} installed ==="
