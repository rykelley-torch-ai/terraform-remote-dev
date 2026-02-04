# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM BACKEND INFRASTRUCTURE
# Creates S3 bucket and DynamoDB table for Terraform/Terragrunt state management
# ---------------------------------------------------------------------------------------------------------------------

locals {
  bucket_name = "${var.project_name}-terraform-state-${var.environment}"
  table_name  = "${var.project_name}-terraform-locks"
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 BUCKET FOR STATE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.common_tags, {
    Name    = local.bucket_name
    Purpose = "Terraform State Storage"
  })
}

# Enable versioning for state history and recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to clean up old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB TABLE FOR STATE LOCKING
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }

  tags = merge(var.common_tags, {
    Name    = local.table_name
    Purpose = "Terraform State Locking"
  })
}
