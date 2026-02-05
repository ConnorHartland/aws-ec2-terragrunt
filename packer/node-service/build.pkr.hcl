packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "base_ami_name" {
  type        = string
  description = "Name filter for base AMI (Amazon Linux 2023 CIS L2)"
  default     = "al2023-ami-cis-level2-*"
}

variable "base_ami_owner" {
  type        = string
  description = "Owner ID for base AMI"
  default     = "amazon"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_version" {
  type        = string
  description = "Node.js version to install"
  default     = "22"
}

variable "wazuh_manager_ip" {
  type        = string
  description = "Wazuh manager IP for agent registration"
}

variable "newrelic_license_key" {
  type        = string
  description = "New Relic license key"
  sensitive   = true
}

variable "falcon_cid" {
  type        = string
  description = "CrowdStrike Falcon CID"
  sensitive   = true
}

variable "agents_s3_bucket" {
  type        = string
  description = "S3 bucket containing security agent RPMs (Falcon, Nessus, Wazuh)"
  default     = ""
}

variable "ami_name_prefix" {
  type    = string
  default = "node-service"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to launch builder instance in"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to launch builder instance in"
  default     = ""
}

# Locals
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "${var.ami_name_prefix}-${local.timestamp}"
}

# Data source to find base AMI
data "amazon-ami" "base" {
  filters = {
    name                = var.base_ami_name
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
  most_recent = true
  owners      = [var.base_ami_owner]
  region      = var.aws_region
}

# Builder
source "amazon-ebs" "node-service" {
  ami_name        = local.ami_name
  ami_description = "Node.js service AMI with security agents and base configuration"
  instance_type   = var.instance_type
  region          = var.aws_region
  source_ami      = data.amazon-ami.base.id

  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null

  ssh_username = "ec2-user"

  # IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Tags for the AMI
  tags = {
    Name         = local.ami_name
    BaseAMI      = data.amazon-ami.base.id
    NodeVersion  = var.node_version
    BuildTime    = timestamp()
    ManagedBy    = "Packer"
  }

  # Tags for snapshots
  snapshot_tags = {
    Name      = local.ami_name
    ManagedBy = "Packer"
  }

  # Launch block device
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
}

# Build
build {
  sources = ["source.amazon-ebs.node-service"]

  # Run provisioning scripts in order
  # remote_folder: /var/tmp avoids noexec on /tmp (CIS hardened images)
  provisioner "shell" {
    script        = "scripts/01-base-packages.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/02-install-node.sh"
    remote_folder = "/var/tmp"
    environment_vars = [
      "NODE_VERSION=${var.node_version}"
    ]
  }

  provisioner "shell" {
    script        = "scripts/03-install-wazuh.sh"
    remote_folder = "/var/tmp"
    environment_vars = [
      "WAZUH_MANAGER_IP=${var.wazuh_manager_ip}",
      "AGENTS_S3_BUCKET=${var.agents_s3_bucket}"
    ]
  }

  provisioner "shell" {
    script        = "scripts/04-install-newrelic.sh"
    remote_folder = "/var/tmp"
    environment_vars = [
      "NEWRELIC_LICENSE_KEY=${var.newrelic_license_key}"
    ]
  }

  provisioner "shell" {
    script        = "scripts/05-install-falcon.sh"
    remote_folder = "/var/tmp"
    environment_vars = [
      "FALCON_CID=${var.falcon_cid}",
      "AGENTS_S3_BUCKET=${var.agents_s3_bucket}"
    ]
  }

  provisioner "shell" {
    script        = "scripts/05b-install-nessus.sh"
    remote_folder = "/var/tmp"
    environment_vars = [
      "AGENTS_S3_BUCKET=${var.agents_s3_bucket}"
    ]
  }

  provisioner "shell" {
    script        = "scripts/06-configure-nftables.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/07-setup-systemd-template.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/08-setup-ssl-base.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/09-setup-app-directories.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/10-setup-maintenance-timers.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/11-setup-ad-leave-service.sh"
    remote_folder = "/var/tmp"
  }

  provisioner "shell" {
    script        = "scripts/99-cleanup.sh"
    remote_folder = "/var/tmp"
  }

  # Output manifest
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
