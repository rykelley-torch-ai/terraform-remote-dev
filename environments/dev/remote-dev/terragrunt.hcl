# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Remote development instance configuration
# ---------------------------------------------------------------------------------------------------------------------

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders()
}

# Include the environment-specific variables
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Specify the Terraform module to use
terraform {
  source = "${get_repo_root()}/modules/remote-dev-instance"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE INPUTS
# Pass variables to the Terraform module
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Required variables (inherited from env.hcl via root terragrunt.hcl)
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  aws_region   = include.env.locals.aws_region

  # Instance configuration
  instance_type    = "t3.large"
  root_volume_size = 50
  root_volume_type = "gp3"

  # Ubuntu version
  ubuntu_version = "24.04"

  # SSH configuration - uses default ~/.ssh/id_rsa.pub
  # Uncomment and modify if you want to use a different key
  # ssh_public_key_path = "~/.ssh/remote-dev.pub"

  # SSH access - leave empty to auto-detect your current IP
  # Or specify explicit CIDR blocks:
  # allowed_ssh_cidr_blocks = ["YOUR_IP/32", "OFFICE_CIDR"]
  allowed_ssh_cidr_blocks = []

  # Elastic IP - set to true if you want a persistent IP address
  use_elastic_ip = false

  # Detailed monitoring (costs extra)
  enable_detailed_monitoring = false

  # Additional tags
  common_tags = {
    Purpose = "Remote Development"
    Owner   = "DevOps"
  }
}
