# AWS Cloud Resume - AaronDouglass.com

Production-oriented static resume site with AWS infrastructure managed through Terraform and deployed with GitHub Actions.

## Architecture

### Frontend Layer
- `index.html`, `error.html`, `css/`, `js/`, and `assets/` are deployed to S3.
- CloudFront serves content globally and forces HTTPS.
- `js/main.js` calls API Gateway for visitor counts and updates `#visitor-count` in the page.

### API/Counter Layer
- API Gateway HTTP API exposes `GET /visitor-count`.
- Lambda (`counter.py`) increments and reads a DynamoDB counter item.
- API response returns JSON count and CORS headers.

### Storage and Edge Security
- Website S3 bucket is private via OAC-backed CloudFront access.
- S3 encryption, versioning, lifecycle, and access logging are enabled.
- CloudFront has WAF association, managed security response headers, TLS 1.2+ policy, access logs, and configurable geo restriction.

### State Management
- Terraform state is stored in a dedicated S3 backend bucket.
- DynamoDB state-lock table enforces Terraform locking.
- Bootstrap stack (`infrastructure/bootstrap`) creates backend resources.

## CI/CD Pipeline

Pipeline file: `.github/workflows/main.yml`

1. **security_audit**
   - Runs Checkov against Terraform with `soft_fail: false`.
2. **validate_terraform**
   - Validates both bootstrap and main Terraform stacks.
   - Main stack validation uses `terraform init -backend=false` for PR-safe checks.
3. **bootstrap_backend** (push to `main` only)
   - Applies `infrastructure/bootstrap` to ensure state bucket/lock table exist.
4. **deploy_infra** (push to `main` only)
   - Applies `infrastructure/` and exports `api_endpoint` + `cloudfront_distribution_id`.
5. **deploy_frontend** (push to `main` only)
   - Injects API URL placeholder into JS.
   - Syncs frontend files to S3.
   - Invalidates CloudFront.

## Checkov Filtering Status

Fixable bypass filters were removed by implementing controls (WAF, logging, encryption, TLS policy, DLQ, code signing config, KMS-backed settings where practical).

Current remaining skips are intentional architectural/cost tradeoffs and are documented inline in Terraform:
- S3 replication for static site
- S3 event notifications for static site bucket
- CloudFront origin failover pair
- Custom ACM cert requirement while using default CloudFront cert
- Lambda VPC requirement (not used to avoid NAT dependency)

## Inputs You Must Provide

Use [PLACEHOLDERS.md](PLACEHOLDERS.md) as the source of truth for all manual values, including:
- Image placeholders in `index.html`
- API placeholder behavior in `js/main.js`
- GitHub secret `AWS_ROLE_TO_ASSUME`
- GitHub variable `DEPLOY_BUCKET`
- Terraform values from both `terraform.tfvars.example` files

## Repository Structure

```
/
├── assets/
├── css/
├── js/
├── infrastructure/
│   ├── bootstrap/
│   ├── api.tf
│   ├── backend.tf
│   ├── main.tf
│   └── outputs.tf
├── .github/workflows/main.yml
├── PLACEHOLDERS.md
├── index.html
├── error.html
└── README.md
```

## Pre-Deploy Checklist (Strict Order)

1. Fill all manual values listed in [PLACEHOLDERS.md](PLACEHOLDERS.md).
2. Add your image files to:
   - `assets/images/`
   - `assets/images/certifications/`
3. Create `infrastructure/bootstrap/terraform.tfvars` from `infrastructure/bootstrap/terraform.tfvars.example` and set all values.
4. Create `infrastructure/terraform.tfvars` from `infrastructure/terraform.tfvars.example` and set all values.
5. For production TLS/domain, set `alternate_domain_names` and `acm_certificate_arn` in `infrastructure/terraform.tfvars`.
6. Confirm geo policy values (`geo_restriction_type`, `geo_restriction_locations`) match your release scope.
7. Ensure `infrastructure/backend.tf` bucket/table names match bootstrap tfvars values.
8. In GitHub repo settings, set secret `AWS_ROLE_TO_ASSUME`.
9. In GitHub repo settings, set variable `DEPLOY_BUCKET`.
10. Run bootstrap deployment (one time):
   - `cd infrastructure/bootstrap`
   - `terraform init`
   - `terraform apply`
11. Deploy main infrastructure:
   - `cd ../`
   - `terraform init`
   - `terraform plan`
   - `terraform apply`
12. Push to `main` to trigger full pipeline deploy + CloudFront invalidation.
