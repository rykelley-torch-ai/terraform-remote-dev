# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# Fetch existing AWS resources and information
# ---------------------------------------------------------------------------------------------------------------------

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Get the first available subnet
data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-${var.ubuntu_version}-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get current caller identity for naming
data "aws_caller_identity" "current" {}

# Get current public IP for security group (if no CIDR blocks specified)
data "http" "my_ip" {
  count = length(var.allowed_ssh_cidr_blocks) == 0 ? 1 : 0
  url   = "https://checkip.amazonaws.com"
}

# Read the SSH public key
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_public_key_path)
}
