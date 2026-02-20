# Required Inputs and Placeholders

This file lists every value you must provide manually before production deployment.

## Frontend Assets

1. `index.html`
   - `%%PROFILE_IMAGE%%`
     - Replace with your profile image filename in `assets/images/`
     - Example: `profile.jpg`
   - `%%GCIH_CERT_IMAGE%%`
     - Replace with your GCIH image filename in `assets/images/certifications/`
     - Example: `gcih.png`
   - `%%GSEC_CERT_IMAGE%%`
     - Replace with your GSEC image filename in `assets/images/certifications/`
     - Example: `gsec.png`
   - `%%AWS_CERT_IMAGE%%`
     - Replace with your AWS cert image filename in `assets/images/certifications/`
     - Example: `aws-cloud-practitioner.png`

2. `js/main.js`
   - `%%API_URL_PLACEHOLDER%%`
     - Replaced automatically by GitHub Actions from Terraform output during deploy
     - For local/manual testing, replace with your API Gateway endpoint URL

## GitHub Actions Inputs

1. Repository Secret
   - Name: `AWS_ROLE_TO_ASSUME`
   - Value: IAM role ARN used by GitHub OIDC
   - Used in: `.github/workflows/main.yml`

2. Repository Variable
   - Name: `DEPLOY_BUCKET`
   - Value: S3 website bucket name used for frontend sync
   - Used in: `.github/workflows/main.yml`

## Terraform Inputs

1. Main Infrastructure (`infrastructure/terraform.tfvars`)
   - Start from: `infrastructure/terraform.tfvars.example`
   - Required values:
     - `aws_region`
     - `domain_name`
     - `environment`
    - `allowed_cors_origin` (set to your site URL, e.g., `https://your-domain.example.com`)
    - `geo_restriction_type` (`none`, `whitelist`, or `blacklist`)
    - `geo_restriction_locations` (country code list; default `US`)
    - `alternate_domain_names` (list of CloudFront aliases)
    - `acm_certificate_arn` (required when using custom domain TLS)

2. Backend Bootstrap (`infrastructure/bootstrap/terraform.tfvars`)
   - Start from: `infrastructure/bootstrap/terraform.tfvars.example`
   - Required values:
     - `aws_region`
     - `state_bucket_name`
     - `lock_table_name`

## Consistency Requirements

If you customize backend names, keep these values aligned:
- `infrastructure/bootstrap/terraform.tfvars` (`state_bucket_name`, `lock_table_name`)
- `infrastructure/backend.tf` (`bucket`, `dynamodb_table`)

## Optional Manual Inputs

- `error.html`, `index.html`, and text content can be customized for branding/contact details.
- For custom TLS/domain on CloudFront, update certificate and aliases in `infrastructure/main.tf`.
