#!/bin/bash
set -euo pipefail

# Log all output
exec > >(tee /var/log/userdata.log) 2>&1

echo "=== Starting userdata for ${service_name} ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Variables from Terraform
SERVICE_NAME="${service_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"
ARTIFACT_BUCKET="${artifact_bucket}"
SSL_BUCKET="${ssl_bucket}"
APP_PORT="${app_port}"
ENABLE_LIFECYCLE_HOOK="${enable_lifecycle_hook}"

# Get instance metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"

# =============================================================================
# TAG EC2 INSTANCE
# =============================================================================
echo "=== Tagging EC2 instance ==="
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags "Key=ServiceName,Value=$SERVICE_NAME" \
         "Key=Environment,Value=$ENVIRONMENT" \
  --region "$AWS_REGION"

# =============================================================================
# GET APP VERSION FROM SSM PARAMETER
# =============================================================================
echo "=== Getting app version from SSM ==="
APP_VERSION=$(aws ssm get-parameter \
  --name "/$SERVICE_NAME/$ENVIRONMENT/app-version" \
  --query "Parameter.Value" \
  --output text \
  --region "$AWS_REGION" 2>/dev/null || echo "latest")
echo "App version: $APP_VERSION"

# =============================================================================
# PULL APP CODE FROM S3
# =============================================================================
echo "=== Pulling app code from S3 ==="
aws s3 cp "s3://$ARTIFACT_BUCKET/$SERVICE_NAME/$APP_VERSION/app.tar.gz" /tmp/app.tar.gz --region "$AWS_REGION"
tar -xzf /tmp/app.tar.gz -C /opt/app
chown -R nodeapp:nodeapp /opt/app
rm -f /tmp/app.tar.gz

# =============================================================================
# PULL SSL CERTS AND KEYTABS FROM S3
# =============================================================================
echo "=== Pulling SSL certs and keytabs ==="
%{ for ssl_path in s3_ssl_paths ~}
echo "Fetching: ${ssl_path}"
aws s3 cp "s3://$SSL_BUCKET/${ssl_path}" "/etc/pki/app/${ssl_path}" --region "$AWS_REGION"
%{ endfor ~}

# Set permissions on downloaded certs
chown -R nodeapp:nodeapp /etc/pki/app/private /etc/pki/app/kafka /etc/pki/app/kerberos
chmod 600 /etc/pki/app/private/* 2>/dev/null || true
chmod 600 /etc/pki/app/kafka/* 2>/dev/null || true
chmod 600 /etc/pki/app/kerberos/* 2>/dev/null || true

# =============================================================================
# GENERATE ENV CONFIG
# =============================================================================
echo "=== Generating environment config ==="

# Pull base config from Parameter Store
aws ssm get-parameters-by-path \
  --path "/$SERVICE_NAME/$ENVIRONMENT" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameters[*].[Name,Value]" \
  --output text | while IFS=$'\t' read -r name value; do
    param_name=$(basename "$name")
    echo "export $param_name=\"$value\"" >> /opt/app/.env
done

# Add Terraform-provided environment variables
cat >> /opt/app/.env << 'ENVVARS'
${env_vars}
ENVVARS

# Add standard environment variables
cat >> /opt/app/.env << STDENV
export NODE_ENV=$ENVIRONMENT
export PORT=$APP_PORT
export SERVICE_NAME=$SERVICE_NAME
export AWS_REGION=$AWS_REGION
export INSTANCE_ID=$INSTANCE_ID
STDENV

chown nodeapp:nodeapp /opt/app/.env
chmod 600 /opt/app/.env

# =============================================================================
# CONFIGURE NEW RELIC
# =============================================================================
echo "=== Configuring New Relic ==="
sudo sed -i "s/PLACEHOLDER_DISPLAY_NAME/$SERVICE_NAME-$INSTANCE_ID/" /etc/newrelic-infra.yml
sudo sed -i "s/PLACEHOLDER_ENVIRONMENT/$ENVIRONMENT/" /etc/newrelic-infra.yml
sudo sed -i "s/PLACEHOLDER_SERVICE/$SERVICE_NAME/" /etc/newrelic-infra.yml
sudo systemctl enable newrelic-infra
sudo systemctl start newrelic-infra

# =============================================================================
# REGISTER WITH WAZUH MANAGER
# =============================================================================
echo "=== Registering with Wazuh manager ==="
sudo /var/ossec/bin/agent-auth -m "${wazuh_manager_ip}" -A "$SERVICE_NAME-$INSTANCE_ID"
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# =============================================================================
# CONFIGURE NFTABLES APP PORT
# =============================================================================
echo "=== Configuring firewall for app port ==="
sudo sed "s/APP_PORT/$APP_PORT/" /etc/nftables.d/app-port.nft.template > /etc/nftables.d/app-port.nft
sudo nft -f /etc/nftables.d/app-port.nft

# =============================================================================
# START CROWDSTRIKE FALCON
# =============================================================================
echo "=== Starting CrowdStrike Falcon ==="
if systemctl list-unit-files | grep -q falcon-sensor; then
  sudo systemctl enable falcon-sensor
  sudo systemctl start falcon-sensor
fi

# =============================================================================
# START APPLICATION
# =============================================================================
echo "=== Starting application ==="
sudo systemctl enable "nodeapp@$SERVICE_NAME"
sudo systemctl start "nodeapp@$SERVICE_NAME"

# =============================================================================
# HEALTH CHECK
# =============================================================================
echo "=== Waiting for service health check ==="
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf "http://localhost:$APP_PORT${health_check_path}" > /dev/null 2>&1; then
    echo "Service is healthy!"
    break
  fi
  echo "Waiting for service... (attempt $((attempt + 1))/$max_attempts)"
  sleep 10
  attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
  echo "ERROR: Service did not become healthy"
  sudo journalctl -u "nodeapp@$SERVICE_NAME" --no-pager -n 50 || true
  exit 1
fi

# =============================================================================
# COMPLETE LIFECYCLE HOOK
# =============================================================================
if [ "$ENABLE_LIFECYCLE_HOOK" = "true" ]; then
  echo "=== Completing lifecycle hook ==="
  ASG_NAME=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:autoscaling:groupName" \
    --region "$AWS_REGION" \
    --query "Tags[0].Value" \
    --output text)

  if [ -n "$ASG_NAME" ] && [ "$ASG_NAME" != "None" ]; then
    aws autoscaling complete-lifecycle-action \
      --lifecycle-hook-name "$SERVICE_NAME-$ENVIRONMENT-launch-hook" \
      --auto-scaling-group-name "$ASG_NAME" \
      --lifecycle-action-result CONTINUE \
      --instance-id "$INSTANCE_ID" \
      --region "$AWS_REGION" || echo "Lifecycle hook completion failed (may already be completed)"
  fi
fi

echo "=== Userdata completed successfully ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
