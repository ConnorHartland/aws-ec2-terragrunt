#!/bin/bash
set -euo pipefail

echo "=== Installing Wazuh agent ==="

WAZUH_TMP="/var/tmp/wazuh-install"
mkdir -p "$WAZUH_TMP"

if [ -n "${AGENTS_S3_BUCKET:-}" ]; then
  aws s3 cp "s3://${AGENTS_S3_BUCKET}/wazuh-agent.rpm" "$WAZUH_TMP/wazuh-agent.rpm" || true
fi

if [ -f "$WAZUH_TMP/wazuh-agent.rpm" ]; then
  sudo dnf install -y "$WAZUH_TMP/wazuh-agent.rpm"

  # Disable auto-start - registration happens in userdata
  sudo systemctl disable wazuh-agent

  echo "=== Wazuh agent installed (will register at boot) ==="
else
  echo "=== WARNING: Wazuh agent package not found ==="
fi

rm -rf "$WAZUH_TMP"
