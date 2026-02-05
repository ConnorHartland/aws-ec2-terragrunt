#!/bin/bash
set -euo pipefail

echo "=== Installing New Relic infrastructure agent ==="

# Add New Relic repository
sudo curl -o /etc/yum.repos.d/newrelic-infra.repo \
  https://download.newrelic.com/infrastructure_agent/linux/yum/amazonlinux/2023/x86_64/newrelic-infra.repo

# Install New Relic infrastructure agent
sudo dnf install -y newrelic-infra

# Create base configuration (placeholders replaced at boot)
cat << NRCONFIG | sudo tee /etc/newrelic-infra.yml
license_key: ${NEWRELIC_LICENSE_KEY}
display_name: PLACEHOLDER_HOSTNAME
custom_attributes:
  environment: PLACEHOLDER_ENVIRONMENT
  application: PLACEHOLDER_APPLICATION
  stack_id: PLACEHOLDER_STACK_ID
log_file: /var/log/newrelic-infra/newrelic-infra.log
NRCONFIG

# Disable auto-start - configured and started at boot
sudo systemctl disable newrelic-infra

echo "=== New Relic infrastructure agent installed ==="
