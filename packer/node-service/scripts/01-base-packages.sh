#!/bin/bash
set -euo pipefail

echo "=== Installing base packages ==="

# Update system
sudo dnf update -y

# Install essential packages
sudo dnf install -y \
  jq \
  awscli \
  curl \
  wget \
  tar \
  gzip \
  unzip \
  openssl \
  ca-certificates \
  nftables \
  systemd \
  logrotate

echo "=== Base packages installed ==="
