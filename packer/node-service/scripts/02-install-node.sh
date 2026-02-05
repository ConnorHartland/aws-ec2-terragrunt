#!/bin/bash
set -euo pipefail

echo "=== Installing Node.js ${NODE_VERSION} ==="

# Import NodeSource GPG key
sudo rpm --import https://rpm.nodesource.com/gpgkey/nodesource-repo.gpg.key

# Setup NodeSource repo for Node.js
sudo tee /etc/yum.repos.d/nodesource.repo <<EOF
[nodesource]
name=Node.js Packages
baseurl=https://rpm.nodesource.com/pub_${NODE_VERSION}.x/nodistro/nodejs/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/gpgkey/nodesource-repo.gpg.key
EOF

sudo dnf install -y nodejs

# Verify installation
node --version
npm --version

# Configure npm for production
sudo npm config set --global audit false
sudo npm config set --global fund false

echo "=== Node.js ${NODE_VERSION} installed ==="
