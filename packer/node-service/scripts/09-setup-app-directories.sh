#!/bin/bash
set -euo pipefail

echo "=== Setting up application directories ==="

# Create nodeapp user (system user, no login shell)
sudo useradd -r -s /sbin/nologin -d /opt/app nodeapp || true

# Create application directories
sudo mkdir -p /opt/app
sudo mkdir -p /var/log/app

# Set ownership and permissions
sudo chown nodeapp:nodeapp /opt/app
sudo chown nodeapp:nodeapp /var/log/app
sudo chmod 755 /opt/app
sudo chmod 755 /var/log/app

# Create log rotation config
cat << 'LOGROTATE' | sudo tee /etc/logrotate.d/nodeapp
/var/log/app/*.log {
  daily
  missingok
  rotate 14
  compress
  delaycompress
  notifempty
  create 0640 nodeapp nodeapp
  sharedscripts
  postrotate
    systemctl kill -s HUP nodeapp@* 2>/dev/null || true
  endscript
}
LOGROTATE

# Grant nodeapp access to SSL directories
sudo chown -R nodeapp:nodeapp /etc/pki/app/private
sudo chown -R nodeapp:nodeapp /etc/pki/app/kafka
sudo chown -R nodeapp:nodeapp /etc/pki/app/kerberos

echo "=== Application directories configured ==="
