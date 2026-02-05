#!/bin/bash
set -euo pipefail

echo "=== Installing base packages ==="

# Update system
sudo dnf update -y

# Install essential packages
sudo dnf install -y --allowerasing \
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
  chrony \
  logrotate \
  systemd-sysv

# Active Directory packages
sudo dnf install -y --allowerasing \
  realmd \
  sssd \
  oddjob \
  oddjob-mkhomedir \
  adcli \
  samba-common-tools \
  krb5-workstation

# Enable services
sudo systemctl enable nftables
sudo systemctl enable chronyd

# Configure chrony for AWS time sync (uses Amazon Time Sync Service)
cat << 'CHRONYCONF' | sudo tee /etc/chrony.conf
# Use Amazon Time Sync Service
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC)
rtcsync

# Specify directory for log files
logdir /var/log/chrony
CHRONYCONF

echo "=== Base packages installed ==="
