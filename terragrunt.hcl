# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# This file contains the root configuration for all Terragrunt modules
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Load environment-specific variables
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl", "env.hcl"))

  # Extract commonly used variables
  aws_region   = local.env_vars.locals.aws_region
  project_name = local.env_vars.locals.project_name
  environment  = local.env_vars.locals.environment

  # ---------------------------------------------------------------------------------------------------------------------
  # REMOTE STATE CONFIGURATION
  # ---------------------------------------------------------------------------------------------------------------------
  # Set to true after deploying the terraform-backend module:
  #   1. cd environments/dev/terraform-backend && terragrunt apply
  #   2. Set use_remote_state = true below
  #   3. For existing modules, run: terragrunt init -migrate-state
  use_remote_state = true
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These parameters apply to all configurations in this live repository
# ---------------------------------------------------------------------------------------------------------------------

remote_state {
  backend = local.use_remote_state ? "s3" : "local"

  config = local.use_remote_state ? {
    encrypt        = true
    bucket         = "${local.project_name}-terraform-state-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "${local.project_name}-terraform-locks"
  } : {
    path = "${path_relative_to_include()}/terraform.tfstate"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project     = "${local.project_name}"
      Environment = "${local.environment}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL INPUTS
# These inputs apply to all configurations in this live repository
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  aws_region   = local.aws_region
  project_name = local.project_name
  environment  = local.environment

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
