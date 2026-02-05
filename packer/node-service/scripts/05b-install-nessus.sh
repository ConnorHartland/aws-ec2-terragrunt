#!/bin/bash
set -euo pipefail

echo "=== Installing Nessus Agent ==="

# Nessus agent should be pre-staged or pulled from internal S3
NESSUS_TMP="/var/tmp/nessus-install"
mkdir -p "$NESSUS_TMP"

if [ -n "${AGENTS_S3_BUCKET:-}" ]; then
  aws s3 cp "s3://${AGENTS_S3_BUCKET}/ness_agent.rpm" "$NESSUS_TMP/ness_agent.rpm" || true
fi

if [ -f "$NESSUS_TMP/ness_agent.rpm" ]; then
  sudo dnf install -y "$NESSUS_TMP/ness_agent.rpm"
  
  # Do NOT link here - done at boot with hostname
  # Disable auto-start
  sudo systemctl disable nessusagent
  
  echo "=== Nessus Agent installed ==="
else
  echo "=== WARNING: Nessus agent package not found ==="
fi

rm -rf "$NESSUS_TMP"
