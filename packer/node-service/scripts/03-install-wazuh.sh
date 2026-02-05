#!/bin/bash
set -euo pipefail

echo "=== Installing Wazuh agent ==="

# Download from internal repo (will be copied during build or pulled from S3)
# For now, use official repo
sudo rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH

cat << REPO | sudo tee /etc/yum.repos.d/wazuh.repo
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-\$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
REPO

# Install without registering (registration happens at boot)
sudo dnf install -y wazuh-agent

# Disable auto-start - registration happens in userdata
sudo systemctl disable wazuh-agent

# Create deregister script for instance termination
cat << 'DEREG' | sudo tee /var/local/scripts/deregister-wazuh-agent.sh
#!/bin/bash
# Wazuh deregistration is handled by the manager
# This is a placeholder for any cleanup needed
echo "Wazuh agent stopping - deregistration handled by manager"
DEREG
sudo chmod 755 /var/local/scripts/deregister-wazuh-agent.sh

echo "=== Wazuh agent installed (will register at boot) ==="
