#!/bin/bash
set -euo pipefail

echo "=== Installing CrowdStrike Falcon sensor ==="

# Note: Falcon sensor package typically needs to be downloaded from your Falcon console
# or stored in a private S3 bucket. This script assumes it's available.

# Create temp directory for installer
FALCON_TMP="/tmp/falcon-install"
mkdir -p "$FALCON_TMP"

# Option 1: Download from S3 (recommended for production)
# aws s3 cp s3://your-security-bucket/falcon-sensor.rpm "$FALCON_TMP/falcon-sensor.rpm"

# Option 2: Download from Falcon API (requires API credentials)
# This is a placeholder - implement based on your Falcon deployment method

# For now, check if package exists and install
if [ -f "$FALCON_TMP/falcon-sensor.rpm" ]; then
  sudo dnf install -y "$FALCON_TMP/falcon-sensor.rpm"
  
  # Configure CID
  sudo /opt/CrowdStrike/falconctl -s --cid="${FALCON_CID}"
  
  # Disable auto-start during AMI build
  sudo systemctl disable falcon-sensor
  
  echo "=== CrowdStrike Falcon sensor installed ==="
else
  echo "=== WARNING: Falcon sensor package not found, skipping installation ==="
  echo "=== Ensure falcon-sensor.rpm is available during build ==="
fi

# Cleanup
rm -rf "$FALCON_TMP"
