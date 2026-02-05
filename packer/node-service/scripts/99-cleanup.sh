#!/bin/bash
set -euo pipefail

echo "=== Cleaning up for AMI creation ==="

# Clear package cache
sudo dnf clean all
sudo rm -rf /var/cache/dnf/*

# Clear logs
sudo truncate -s 0 /var/log/messages || true
sudo truncate -s 0 /var/log/secure || true
sudo truncate -s 0 /var/log/wtmp || true
sudo truncate -s 0 /var/log/lastlog || true
sudo rm -rf /var/log/journal/*

# Clear temp files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear SSH host keys (will be regenerated on first boot)
sudo rm -f /etc/ssh/ssh_host_*

# Clear machine-id (will be regenerated on first boot)
sudo truncate -s 0 /etc/machine-id

# Clear bash history
cat /dev/null > ~/.bash_history
history -c

echo "=== Cleanup complete, AMI ready ==="
