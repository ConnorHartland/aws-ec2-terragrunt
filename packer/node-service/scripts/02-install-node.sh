#!/bin/bash
set -euo pipefail

echo "=== Installing Node.js (latest v${NODE_VERSION}.x) ==="

# Get latest version for this major release
LATEST_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | \
  jq -r "[.[] | select(.version | startswith(\"v${NODE_VERSION}.\"))][0].version")

echo "Latest version: ${LATEST_VERSION}"

# Download and install from official tarball
NODE_DIST="node-${LATEST_VERSION}-linux-x64"
curl -fsSL "https://nodejs.org/dist/${LATEST_VERSION}/${NODE_DIST}.tar.xz" -o /tmp/node.tar.xz
sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
rm -f /tmp/node.tar.xz

# Verify installation
node --version
npm --version

# Configure npm for production
sudo npm config set --global audit false
sudo npm config set --global fund false

echo "=== Node.js ${LATEST_VERSION} installed ==="
