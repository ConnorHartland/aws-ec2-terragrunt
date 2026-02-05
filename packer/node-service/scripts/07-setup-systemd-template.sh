#!/bin/bash
set -euo pipefail

echo "=== Setting up systemd service template ==="

# Create systemd service template for node apps
cat << 'SYSTEMD' | sudo tee /etc/systemd/system/nodeapp@.service
[Unit]
Description=Node.js Application - %i
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=nodeapp
Group=nodeapp
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/bin/node /opt/app/dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=%i

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/app /var/log/app
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# Resource limits
LimitNOFILE=65535
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
SYSTEMD

# Reload systemd to recognize the template
sudo systemctl daemon-reload

echo "=== Systemd service template created ==="
