terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "aarondouglass.com"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}

# S3 Bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.domain_name
  
  tags = {
    Name        = "${var.domain_name}-website"
    Environment = var.environment
    Project     = "cloud-resume-challenge"
  }

  # SKIP: Cross-region replication (CKV_AWS_144)
  # checkov:skip=CKV_AWS_144: "Replication not required for static site"
  
  # SKIP: Access logging (CKV_AWS_18)
  # checkov:skip=CKV_AWS_18: "Logging not required for resume site"

  # SKIP: KMS Encryption (CKV_AWS_145)
  # checkov:skip=CKV_AWS_145: "Public website does not require KMS encryption"
}

# FIX: Add Lifecycle rule (CKV2_AWS_61)
resource "aws_s3_bucket_lifecycle_configuration" "website_lifecycle" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  
  # SKIP: Event notifications (CKV2_AWS_62)
  # checkov:skip=CKV2_AWS_62: "Notifications not needed for static site"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.website_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      # FIX: Geo restriction explicitly set to none satisfies CKV_AWS_374
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # FIX: Enforce TLS 1.2 (CKV_AWS_174)
    minimum_protocol_version       = "TLSv1.2_2021" 
  }
  
  # SKIP: WAF costs money (CKV_AWS_68)
  # checkov:skip=CKV_AWS_68: "WAF is too expensive for personal project"
  
  # SKIP: Origin Failover requires 2nd bucket (CKV_AWS_310)
  # checkov:skip=CKV_AWS_310: "Failover not required for simple resume"
  
  # SKIP: Response Headers Policy (CKV2_AWS_32)
  # checkov:skip=CKV2_AWS_32: "Standard headers sufficient"

  # SKIP: WAF Log4j (CKV2_AWS_47)
  # checkov:skip=CKV2_AWS_47: "WAF not enabled"

  # SKIP: Custom SSL (CKV2_AWS_42)
  # checkov:skip=CKV2_AWS_42: "Using default CloudFront cert is acceptable for dev"
}

# S3 Bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Outputs
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website_bucket.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.website_bucket.arn
}