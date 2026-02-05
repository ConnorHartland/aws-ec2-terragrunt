#!/bin/bash
set -euo pipefail

echo "=== Setting up AD leave service for instance termination ==="

# Create script to leave AD domain on shutdown
cat << 'ADLEAVE' | sudo tee /var/local/scripts/LeaveActiveDirectory.bash
#!/bin/bash
# Leave Active Directory domain on instance termination
if realm list | grep -q "office.local"; then
  echo "Leaving Active Directory domain..."
  realm leave office.local || true
fi
ADLEAVE
sudo chmod 755 /var/local/scripts/LeaveActiveDirectory.bash

# Create systemd service for AD leave
cat << 'ADLEAVESVC' | sudo tee /etc/systemd/system/RealmLeaveDomain.service
[Unit]
Description=Leave Active Directory Domain on Shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=/bin/bash /var/local/scripts/LeaveActiveDirectory.bash
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
ADLEAVESVC

sudo systemctl daemon-reload
sudo systemctl enable RealmLeaveDomain.service

echo "=== AD leave service configured ==="
