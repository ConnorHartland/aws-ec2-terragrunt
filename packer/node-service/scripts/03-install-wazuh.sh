#!/bin/bash
set -euo pipefail

echo "=== Installing Wazuh agent ==="

# Import Wazuh GPG key
sudo rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH

# Add Wazuh repository
cat << REPO | sudo tee /etc/yum.repos.d/wazuh.repo
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO

# Install Wazuh agent
sudo WAZUH_MANAGER="${WAZUH_MANAGER_IP}" dnf install -y wazuh-agent

# Configure base ossec.conf (manager IP will be confirmed at boot)
sudo sed -i "s/MANAGER_IP/${WAZUH_MANAGER_IP}/" /var/ossec/etc/ossec.conf

# Disable auto-start - will be started after registration at boot
sudo systemctl disable wazuh-agent

echo "=== Wazuh agent installed (will register at boot) ==="
