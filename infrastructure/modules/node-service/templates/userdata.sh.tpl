#!/bin/bash
set -euo pipefail

# Log all output to a file and console
exec > >(tee /var/log/userdata.log) 2>&1

echo "=== Starting user data script for ${service_name} ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Variables from Terraform
SERVICE_NAME="${service_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"
ARTIFACT_BUCKET="${artifact_bucket}"
APP_PORT="${app_port}"
ENABLE_LIFECYCLE_HOOK="${enable_lifecycle_hook}"

# Get instance metadata (IMDSv2)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# Install dependencies
echo "=== Installing dependencies ==="
yum update -y
yum install -y jq awscli

# Create nodeapp user
echo "=== Creating nodeapp user ==="
useradd -r -s /sbin/nologin nodeapp || true
mkdir -p /opt/nodeapp /var/log/$SERVICE_NAME
chown -R nodeapp:nodeapp /opt/nodeapp /var/log/$SERVICE_NAME

# Fetch artifacts from S3
echo "=== Fetching artifacts from S3 ==="
aws s3 cp "s3://$ARTIFACT_BUCKET/$SERVICE_NAME/latest/app.tar.gz" /tmp/app.tar.gz --region $AWS_REGION
tar -xzf /tmp/app.tar.gz -C /opt/nodeapp
chown -R nodeapp:nodeapp /opt/nodeapp

# Fetch config from Parameter Store
echo "=== Fetching config from Parameter Store ==="
aws ssm get-parameters-by-path \
  --path "/$SERVICE_NAME/$ENVIRONMENT" \
  --with-decryption \
  --region $AWS_REGION \
  --query "Parameters[*].[Name,Value]" \
  --output text | while read name value; do
    param_name=$(basename "$name")
    echo "export $param_name=\"$value\"" >> /opt/nodeapp/.env
done

# Add Terraform-provided environment variables
echo "=== Setting environment variables ==="
cat >> /opt/nodeapp/.env <<'ENVVARS'
${env_vars}
ENVVARS

# Add standard environment variables
cat >> /opt/nodeapp/.env <<STDENV
export NODE_ENV=$ENVIRONMENT
export PORT=$APP_PORT
export SERVICE_NAME=$SERVICE_NAME
export AWS_REGION=$AWS_REGION
export INSTANCE_ID=$INSTANCE_ID
STDENV

chown nodeapp:nodeapp /opt/nodeapp/.env
chmod 600 /opt/nodeapp/.env

# Create systemd service
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/$SERVICE_NAME.service <<SERVICE
[Unit]
Description=$SERVICE_NAME Node.js Service
After=network.target

[Service]
Type=simple
User=nodeapp
Group=nodeapp
WorkingDirectory=/opt/nodeapp
EnvironmentFile=/opt/nodeapp/.env
ExecStart=/usr/bin/node /opt/nodeapp/dist/index.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/$SERVICE_NAME/app.log
StandardError=append:/var/log/$SERVICE_NAME/error.log

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/$SERVICE_NAME

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
echo "=== Starting service ==="
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Wait for service to be healthy
echo "=== Waiting for service health check ==="
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf http://localhost:$APP_PORT/health > /dev/null 2>&1; then
    echo "Service is healthy!"
    break
  fi
  echo "Waiting for service to be healthy... (attempt $((attempt + 1))/$max_attempts)"
  sleep 10
  attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
  echo "ERROR: Service did not become healthy within timeout"
  systemctl status $SERVICE_NAME || true
  journalctl -u $SERVICE_NAME --no-pager -n 50 || true
  exit 1
fi

# Complete lifecycle hook if enabled
if [ "$ENABLE_LIFECYCLE_HOOK" = "true" ]; then
  echo "=== Completing lifecycle hook ==="
  # Get ASG name from instance tags
  ASG_NAME=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:autoscaling:groupName" \
    --region $AWS_REGION \
    --query "Tags[0].Value" \
    --output text)

  if [ -n "$ASG_NAME" ] && [ "$ASG_NAME" != "None" ]; then
    aws autoscaling complete-lifecycle-action \
      --lifecycle-hook-name "$SERVICE_NAME-$ENVIRONMENT-launch-hook" \
      --auto-scaling-group-name "$ASG_NAME" \
      --lifecycle-action-result CONTINUE \
      --instance-id "$INSTANCE_ID" \
      --region $AWS_REGION || echo "Failed to complete lifecycle hook (may already be completed)"
  fi
fi

echo "=== User data script completed successfully ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
