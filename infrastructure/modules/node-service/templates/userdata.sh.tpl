#!/bin/bash
set -euo pipefail

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
STACK_ID="${stack_id}"
ENABLE_LIFECYCLE_HOOK="${enable_lifecycle_hook}"

# Get instance metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)
AMI_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/ami-id)

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"

# =============================================================================
# SET HOSTNAME
# =============================================================================
echo "=== Setting hostname ==="
LAST_OCTET=$(echo "$PRIVATE_IP" | awk -F'.' '{print $4}')
APPSHORT=$(echo "$SERVICE_NAME" | cut -c1-6)
HOSTNAME="$${APPSHORT}$${ENVIRONMENT}$${STACK_ID}$${LAST_OCTET}"
hostnamectl set-hostname "$HOSTNAME" --static
echo "$PRIVATE_IP    $HOSTNAME" >> /etc/hosts
echo "Hostname set to: $HOSTNAME"

# =============================================================================
# TAG EC2 INSTANCE
# =============================================================================
echo "=== Tagging EC2 instance ==="
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags "Key=Name,Value=$HOSTNAME" \
         "Key=ServiceName,Value=$SERVICE_NAME" \
         "Key=Environment,Value=$ENVIRONMENT" \
         "Key=StackId,Value=$STACK_ID" \
         "Key=availability_zone,Value=$AZ" \
         "Key=instance_type,Value=$INSTANCE_TYPE" \
         "Key=ami,Value=$AMI_ID" \
  --region "$AWS_REGION"

# =============================================================================
# CONFIGURE /etc/hosts ENTRIES
# =============================================================================
echo "=== Configuring /etc/hosts ==="
%{ for entry in hosts_entries ~}
echo "${entry}" >> /etc/hosts
%{ endfor ~}

# =============================================================================
# CONFIGURE DNS FOR ACTIVE DIRECTORY
# =============================================================================
%{ if join_active_directory ~}
echo "=== Configuring DNS for Active Directory ==="
INTERFACE=$(ip route | grep default | awk '{print $5}')
resolvectl dns "$INTERFACE" ${ad_dns_servers}
resolvectl domain "$INTERFACE" ${ad_domain} ec2.internal

# Create SSSD log directory
mkdir -p /var/log/sssd

# Join Active Directory
echo "=== Joining Active Directory ==="
ADUSER=$(aws ssm get-parameter --name "${ad_user_ssm_param}" --with-decryption --query Parameter.Value --output text --region "$AWS_REGION")
ADPASS=$(aws ssm get-parameter --name "${ad_pass_ssm_param}" --with-decryption --query Parameter.Value --output text --region "$AWS_REGION")
echo "$ADPASS" | realm join -v -U "$ADUSER@${ad_domain_upper}" ${ad_domain}
unset ADUSER ADPASS
%{ endif ~}

# =============================================================================
# DOWNLOAD APPLICATION CODE FROM S3
# =============================================================================
echo "=== Downloading application code from S3 ==="
mkdir -p /opt/webapp
aws s3 cp "s3://$ARTIFACT_BUCKET/$SERVICE_NAME/$ENVIRONMENT/build.zip" /tmp/build.zip --region "$AWS_REGION"
unzip -o /tmp/build.zip -d /opt/webapp
rm -f /tmp/build.zip
chown -R nodeapp:nodeapp /opt/webapp

# =============================================================================
# PULL SSL CERTS FROM S3
# =============================================================================
echo "=== Pulling SSL certs ==="
mkdir -p /var/local/ssl /var/local/ssl/wildcard /var/local/ssl/kafka

%{ for ssl_path in s3_ssl_paths ~}
aws s3 cp "s3://$SSL_BUCKET/${ssl_path}" "/var/local/ssl/${ssl_path}" --region "$AWS_REGION" || true
%{ endfor ~}

chown -R nodeapp:nodeapp /var/local/ssl
chmod 600 /var/local/ssl/kafka/* 2>/dev/null || true

# =============================================================================
# DOWNLOAD ENVIRONMENT FILE FROM S3
# =============================================================================
echo "=== Downloading environment file from S3 ==="
aws s3 cp "s3://$ARTIFACT_BUCKET/$SERVICE_NAME/$ENVIRONMENT/.env" /opt/webapp/.env --region "$AWS_REGION"

# Append standard environment variables
cat >> /opt/webapp/.env << STDENV
${env_vars}
export NODE_ENV=$ENVIRONMENT
export PORT=$APP_PORT
export SERVICE_NAME=$SERVICE_NAME
export AWS_REGION=$AWS_REGION
export INSTANCE_ID=$INSTANCE_ID
export HOSTNAME=$HOSTNAME
STDENV

chown nodeapp:nodeapp /opt/webapp/.env
chmod 600 /opt/webapp/.env

# =============================================================================
# CONFIGURE AND START CROWDSTRIKE
# =============================================================================
%{ if falcon_cid != "" ~}
echo "=== Configuring CrowdStrike ==="
if [ -f /opt/CrowdStrike/falconctl ]; then
  /opt/CrowdStrike/falconctl -s --cid="${falcon_cid}"
  systemctl enable falcon-sensor
  systemctl start falcon-sensor
fi
%{ endif ~}

# =============================================================================
# CONFIGURE AND START NESSUS
# =============================================================================
%{ if nessus_key != "" ~}
echo "=== Configuring Nessus ==="
if [ -f /opt/nessus_agent/sbin/nessuscli ]; then
  systemctl start nessusagent
  systemctl enable nessusagent
  /opt/nessus_agent/sbin/nessuscli agent link \
    --key="${nessus_key}" \
    --groups="${nessus_groups}" \
    --cloud
fi
%{ endif ~}

# =============================================================================
# CONFIGURE AND START WAZUH
# =============================================================================
echo "=== Configuring Wazuh ==="
if [ -f /var/ossec/bin/agent-auth ]; then
  WAZUH_MANAGER=$(aws ssm get-parameter --name "${wazuh_manager_ssm_param}" --with-decryption --query Parameter.Value --output text --region "$AWS_REGION" 2>/dev/null || echo "${wazuh_manager_ip}")
  
  # Update ossec.conf with manager IP
  sed -i "s|<address>.*</address>|<address>$WAZUH_MANAGER</address>|g" /var/ossec/etc/ossec.conf
  
  # Register with manager
  /var/ossec/bin/agent-auth -m "$WAZUH_MANAGER" -A "$HOSTNAME" -G "${wazuh_agent_group}" || true
  
  systemctl daemon-reload
  systemctl enable wazuh-agent
  systemctl start wazuh-agent
fi

# =============================================================================
# CONFIGURE AND START NEW RELIC
# =============================================================================
echo "=== Configuring New Relic ==="
FEATURES=$(aws ssm get-parameter --name "/$SERVICE_NAME/features" --with-decryption --query Parameter.Value --output text --region "$AWS_REGION" 2>/dev/null || echo "")

cat > /etc/newrelic-infra.yml << NRCONFIG
license_key: ${newrelic_license_key}
display_name: $HOSTNAME
custom_attributes:
  environment: $ENVIRONMENT
  application: $SERVICE_NAME
  stack_id: $STACK_ID
  features: $FEATURES
log_file: /var/log/newrelic-infra/newrelic-infra.log
NRCONFIG

systemctl enable newrelic-infra
systemctl start newrelic-infra

# =============================================================================
# CONFIGURE NFTABLES
# =============================================================================
echo "=== Configuring nftables ==="
%{ if nftables_s3_path != "" ~}
mkdir -p /var/local/scripts/firewall
aws s3 sync "s3://$SSL_BUCKET/${nftables_s3_path}" /var/local/scripts/firewall --region "$AWS_REGION"
if [ -f /var/local/scripts/firewall/ffc.rules ]; then
  cp /var/local/scripts/firewall/ffc.rules /etc/nftables/ffc.rules
  echo 'include "/etc/nftables/ffc.rules"' > /etc/sysconfig/nftables.conf
  systemctl restart nftables
fi
%{ else ~}
%{ if app_port > 0 ~}
# Add app port rule
nft add rule inet filter input tcp dport $APP_PORT accept 2>/dev/null || true
%{ endif ~}
%{ endif ~}

# =============================================================================
# CREATE AND START APPLICATION SERVICE
# =============================================================================
echo "=== Creating application service ==="
cat > /etc/systemd/system/nodeapp.service << SERVICE
[Unit]
Description=$SERVICE_NAME Node.js Service
After=network.target

[Service]
Type=simple
User=nodeapp
Group=nodeapp
WorkingDirectory=/opt/webapp
EnvironmentFile=/opt/webapp/.env
ExecStart=/usr/bin/node /opt/webapp/dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/webapp /var/log/app /var/local/ssl

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable nodeapp
systemctl start nodeapp

# =============================================================================
# HEALTH CHECK
# =============================================================================
echo "=== Waiting for service health check ==="
max_attempts=30
attempt=0

%{ if app_port > 0 ~}
# HTTP/HTTPS health check
while [ $attempt -lt $max_attempts ]; do
  if curl -sfk "https://localhost:$APP_PORT${health_check_path}" > /dev/null 2>&1; then
    echo "Service is healthy!"
    break
  fi
  echo "Waiting for service... (attempt $((attempt + 1))/$max_attempts)"
  sleep 10
  attempt=$((attempt + 1))
done
%{ else ~}
# Process-based health check (no HTTP port)
while [ $attempt -lt $max_attempts ]; do
  if systemctl is-active --quiet nodeapp && pgrep -f "node.*/opt/webapp" > /dev/null; then
    # Verify process has been stable for at least 5 seconds
    sleep 5
    if systemctl is-active --quiet nodeapp && pgrep -f "node.*/opt/webapp" > /dev/null; then
      echo "Service is healthy (process running)!"
      break
    fi
  fi
  echo "Waiting for service... (attempt $((attempt + 1))/$max_attempts)"
  sleep 10
  attempt=$((attempt + 1))
done
%{ endif ~}

if [ $attempt -eq $max_attempts ]; then
  echo "ERROR: Service did not become healthy"
  journalctl -u nodeapp --no-pager -n 50 || true
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
      --region "$AWS_REGION" || true
  fi
fi

echo "=== Userdata completed successfully ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
