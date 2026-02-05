#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Variables from Terraform
# -----------------------------------------------------------------------------
SERVICE_NAME="${service_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"
APP_PORT="${app_port}"
ARTIFACT_BUCKET="${artifact_bucket}"
ASG_NAME="${asg_name}"
ENABLE_LIFECYCLE_HOOK="${enable_lifecycle_hook}"

# -----------------------------------------------------------------------------
# Logging Setup
# -----------------------------------------------------------------------------
exec > >(tee /var/log/userdata.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting userdata script for $SERVICE_NAME in $ENVIRONMENT"

# -----------------------------------------------------------------------------
# Install Dependencies
# -----------------------------------------------------------------------------
echo "Installing dependencies..."
yum update -y
yum install -y amazon-cloudwatch-agent jq awscli

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs
fi

# -----------------------------------------------------------------------------
# Configure CloudWatch Agent
# -----------------------------------------------------------------------------
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/${service_name}/app.log",
            "log_group_name": "/aws/ec2/${service_name}",
            "log_stream_name": "{instance_id}/app",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S.%fZ"
          },
          {
            "file_path": "/var/log/${service_name}/error.log",
            "log_group_name": "/aws/ec2/${service_name}",
            "log_stream_name": "{instance_id}/error",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S.%fZ"
          },
          {
            "file_path": "/var/log/userdata.log",
            "log_group_name": "/aws/ec2/${service_name}",
            "log_stream_name": "{instance_id}/userdata"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "NodeServices/${service_name}",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"]
      }
    },
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}",
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}"
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# -----------------------------------------------------------------------------
# Create Application User and Directories
# -----------------------------------------------------------------------------
echo "Creating application user and directories..."
if ! id -u nodeapp &>/dev/null; then
    useradd -r -s /sbin/nologin nodeapp
fi

mkdir -p /opt/$SERVICE_NAME
mkdir -p /var/log/$SERVICE_NAME
chown -R nodeapp:nodeapp /opt/$SERVICE_NAME
chown -R nodeapp:nodeapp /var/log/$SERVICE_NAME

# -----------------------------------------------------------------------------
# Fetch Artifacts from S3
# -----------------------------------------------------------------------------
echo "Fetching artifacts from S3..."
ARTIFACT_PATH="s3://$ARTIFACT_BUCKET/$SERVICE_NAME/latest.tar.gz"
aws s3 cp "$ARTIFACT_PATH" /tmp/app.tar.gz --region "$AWS_REGION"
tar -xzf /tmp/app.tar.gz -C /opt/$SERVICE_NAME
chown -R nodeapp:nodeapp /opt/$SERVICE_NAME
rm -f /tmp/app.tar.gz

# -----------------------------------------------------------------------------
# Fetch Configuration from Parameter Store
# -----------------------------------------------------------------------------
echo "Fetching configuration from Parameter Store..."
CONFIG_PREFIX="/$ENVIRONMENT/$SERVICE_NAME"

# Create environment file from Parameter Store
aws ssm get-parameters-by-path \
    --path "$CONFIG_PREFIX" \
    --with-decryption \
    --region "$AWS_REGION" \
    --query "Parameters[*].[Name,Value]" \
    --output text | while read -r name value; do
        key=$(basename "$name")
        echo "$key=$value"
    done > /opt/$SERVICE_NAME/.env

# -----------------------------------------------------------------------------
# Add Terraform-provided Environment Variables
# -----------------------------------------------------------------------------
echo "Adding environment variables from Terraform..."
%{ for key, value in environment_variables ~}
echo "${key}=${value}" >> /opt/$SERVICE_NAME/.env
%{ endfor ~}

# Add standard environment variables
cat >> /opt/$SERVICE_NAME/.env <<EOF
SERVICE_NAME=$SERVICE_NAME
ENVIRONMENT=$ENVIRONMENT
PORT=$APP_PORT
EOF

chown nodeapp:nodeapp /opt/$SERVICE_NAME/.env
chmod 600 /opt/$SERVICE_NAME/.env

# -----------------------------------------------------------------------------
# Create systemd Service
# -----------------------------------------------------------------------------
echo "Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=$SERVICE_NAME Node.js Application
After=network.target

[Service]
Type=simple
User=nodeapp
Group=nodeapp
WorkingDirectory=/opt/$SERVICE_NAME
EnvironmentFile=/opt/$SERVICE_NAME/.env
ExecStart=/usr/bin/node /opt/$SERVICE_NAME/dist/index.js
Restart=on-failure
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
EOF

# -----------------------------------------------------------------------------
# Start the Application
# -----------------------------------------------------------------------------
echo "Starting the application..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Wait for application to be healthy
echo "Waiting for application to be healthy..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -o /dev/null -w "%%{http_code}" "http://localhost:$APP_PORT/health" | grep -q "200"; then
        echo "Application is healthy!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for application to start... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Application failed to become healthy"
    journalctl -u $SERVICE_NAME --no-pager -n 50
    exit 1
fi

# -----------------------------------------------------------------------------
# Complete Lifecycle Hook (if enabled)
# -----------------------------------------------------------------------------
%{ if enable_lifecycle_hook ~}
echo "Completing lifecycle hook..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

aws autoscaling complete-lifecycle-action \
    --lifecycle-action-result CONTINUE \
    --instance-id "$INSTANCE_ID" \
    --lifecycle-hook-name "$SERVICE_NAME-$ENVIRONMENT-launch-hook" \
    --auto-scaling-group-name "$ASG_NAME" \
    --region "$AWS_REGION" || true
%{ endif ~}

echo "Userdata script completed successfully!"
