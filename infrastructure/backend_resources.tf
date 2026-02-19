# S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "aaron-douglass-terraform-state" 
  
  lifecycle {
    prevent_destroy = true 
  }

  # SKIP: Cross-region replication doubles storage costs (CKV_AWS_144)
  # checkov:skip=CKV_AWS_144: "CRR not required for personal resume state"
  
  # SKIP: Access logging creates log spam and costs storage (CKV_AWS_18)
  # checkov:skip=CKV_AWS_18: "Access logging not required for state bucket"

  # SKIP: KMS Customer Keys cost money (CKV_AWS_145)
  # checkov:skip=CKV_AWS_145: "Using default AES256 encryption to save costs"
}

# FIX: Ensure State Bucket is not public (CKV2_AWS_6)
resource "aws_s3_bucket_public_access_block" "state_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# FIX: Add Lifecycle rule to clean up incomplete uploads (CKV2_AWS_61)
resource "aws_s3_bucket_lifecycle_configuration" "state_lifecycle" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  
  # SKIP: Event notifications not needed for state (CKV2_AWS_62)
  # checkov:skip=CKV2_AWS_62: "Notifications not needed for state file"
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # FIX: Enable Backup (CKV_AWS_28)
  point_in_time_recovery {
    enabled = true
  }

  # SKIP: KMS Customer Managed Keys cost $1/mo (CKV_AWS_119)
  # checkov:skip=CKV_AWS_119: "Using default AWS owned key to save costs"
}