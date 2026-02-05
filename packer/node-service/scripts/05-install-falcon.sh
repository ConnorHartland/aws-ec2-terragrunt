#!/bin/bash
set -euo pipefail

echo "=== Installing CrowdStrike Falcon sensor ==="

# Falcon sensor should be pre-staged or pulled from internal S3
# This assumes it's available at build time

FALCON_TMP="/var/tmp/falcon-install"
mkdir -p "$FALCON_TMP"

# Try to get from S3 if available (bucket passed as env var)
if [ -n "${FALCON_S3_BUCKET:-}" ]; then
  aws s3 cp "s3://${FALCON_S3_BUCKET}/falcon-sensor.rpm" "$FALCON_TMP/falcon-sensor.rpm" || true
fi

if [ -f "$FALCON_TMP/falcon-sensor.rpm" ]; then
  sudo dnf install -y "$FALCON_TMP/falcon-sensor.rpm"
  
  # Do NOT set CID here - done at boot with hostname
  # sudo /opt/CrowdStrike/falconctl -s --cid="${FALCON_CID}"
  
  # Disable auto-start - started after registration at boot
  sudo systemctl disable falcon-sensor
  
  echo "=== CrowdStrike Falcon sensor installed ==="
else
  echo "=== WARNING: Falcon sensor package not found ==="
  echo "=== Ensure falcon-sensor.rpm is staged before build ==="
fi

rm -rf "$FALCON_TMP"
