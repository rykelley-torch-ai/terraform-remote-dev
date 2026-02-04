# ---------------------------------------------------------------------------------------------------------------------
# REMOTE DEVELOPMENT INSTANCE
# Creates an EC2 instance configured for remote development
# ---------------------------------------------------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Auto-detect IP if no CIDR blocks provided
  my_ip = length(var.allowed_ssh_cidr_blocks) > 0 ? var.allowed_ssh_cidr_blocks : ["${chomp(data.http.my_ip[0].response_body)}/32"]

  # Combine all tags
  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-dev-instance"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# SSH KEY PAIR
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_key_pair" "dev" {
  key_name   = "${local.name_prefix}-key"
  public_key = trimspace(data.local_file.ssh_public_key.content)

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "dev" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for remote development instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.my_ip
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_instance" "dev" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.dev.key_name
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = concat([aws_security_group.dev.id], var.additional_security_group_ids)

  iam_instance_profile = var.iam_instance_profile

  # Enable public IP
  associate_public_ip_address = true

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true

    tags = merge(var.common_tags, {
      Name = "${local.name_prefix}-root-volume"
    })
  }

  # Monitoring
  monitoring = var.enable_detailed_monitoring

  # User data for initial setup
  user_data = var.user_data != "" ? var.user_data : <<-EOF
    #!/bin/bash
    set -e

    # Update system packages
    apt-get update
    apt-get upgrade -y

    # Install basic packages needed for Ansible
    apt-get install -y python3 python3-pip

    # Set hostname
    hostnamectl set-hostname ${local.name_prefix}

    echo "Initial setup complete. Ready for Ansible provisioning."
  EOF

  # Enable termination protection (optional, set to false for easier cleanup)
  disable_api_termination = false

  # Instance metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [ami] # Don't replace instance when AMI updates
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ELASTIC IP (OPTIONAL)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_eip" "dev" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.dev.id
  domain   = "vpc"

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-eip"
  })

  depends_on = [aws_instance.dev]
}
