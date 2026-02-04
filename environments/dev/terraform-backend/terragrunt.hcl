# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terraform Backend (S3 + DynamoDB) - Deploy this FIRST before other modules
# ---------------------------------------------------------------------------------------------------------------------

# Include the environment-specific variables
include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Generate provider configuration (no remote state for this module - bootstrap problem)
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
  }

  # Use local backend for the backend infrastructure itself
  # This avoids the chicken-and-egg problem
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "${include.env.locals.aws_region}"

  default_tags {
    tags = {
      Project     = "${include.env.locals.project_name}"
      Environment = "${include.env.locals.environment}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}

# Specify the Terraform module to use
terraform {
  source = "${get_repo_root()}/modules/terraform-backend"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  aws_region   = include.env.locals.aws_region

  # Retain 90 days of state versions
  state_version_retention_days = 90

  # Enable point-in-time recovery for DynamoDB
  enable_dynamodb_pitr = true

  common_tags = {
    Purpose = "Terraform State Management"
  }
}
