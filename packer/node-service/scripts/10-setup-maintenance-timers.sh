#!/bin/bash
set -euo pipefail

echo "=== Setting up maintenance timers ==="

# Create scripts directory
sudo mkdir -p /var/local/scripts/patching

# ============================================================================
# LOG MAINTENANCE
# ============================================================================
cat << 'LOGSCRIPT' | sudo tee /var/local/scripts/runLogMaintenance.sh
#!/bin/bash
# Log maintenance - clean old logs
find /var/log -type f -name "*.log" -mtime +14 -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null || true
journalctl --vacuum-time=14d 2>/dev/null || true
echo "Log maintenance completed at $(date)"
LOGSCRIPT
sudo chmod 755 /var/local/scripts/runLogMaintenance.sh

cat << 'LOGSVC' | sudo tee /etc/systemd/system/logMaintenance.service
[Unit]
Description=Cleanup old log files

[Service]
Type=oneshot
ExecStart=/bin/bash /var/local/scripts/runLogMaintenance.sh
LOGSVC

cat << 'LOGTIMER' | sudo tee /etc/systemd/system/logMaintenance.timer
[Unit]
Description=Run log cleanup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
LOGTIMER

sudo systemctl enable logMaintenance.timer

# ============================================================================
# OS UPDATES
# ============================================================================
cat << 'PATCHSCRIPT' | sudo tee /var/local/scripts/patching/run_updates.bash
#!/bin/bash
dnf upgrade --releasever=latest -y
yum update -y

/usr/bin/needs-restarting -r
if [ $? -eq 1 ]; then
  echo "$(hostname) :: $(date) :: Patches require reboot"
  # Optionally notify or reboot
else
  echo "$(hostname) :: $(date) :: Patching completed, no reboot needed"
fi
PATCHSCRIPT
sudo chmod 755 /var/local/scripts/patching/run_updates.bash

cat << 'UPDATESVC' | sudo tee /etc/systemd/system/osUpdate.service
[Unit]
Description=Run OS updates

[Service]
Type=oneshot
ExecStart=/bin/bash /var/local/scripts/patching/run_updates.bash

[Install]
WantedBy=multi-user.target
UPDATESVC

cat << 'UPDATETIMER' | sudo tee /etc/systemd/system/osUpdate.timer
[Unit]
Description=Run OS update daily at 7am

[Timer]
OnCalendar=*-*-* 7:00:00
AccuracySec=10m
RandomizedDelaySec=30m
Persistent=true
Unit=osUpdate.service

[Install]
WantedBy=timers.target
UPDATETIMER

sudo systemctl enable osUpdate.timer

echo "=== Maintenance timers configured ==="
