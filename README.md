# AWS Cloud Resume Challenge

A deployment-ready static website and AWS Infrastructure as Code (Terraform) for the AWS Cloud Resume Challenge.

## Project Structure

```
/
├── assets/
│   ├── images/
│   │   └── profile.jpg (placeholder - replace with actual image)
│   └── icons/
├── css/
│   ├── style.css
│   └── responsive.css
├── js/
│   └── main.js
├── infrastructure/
│   └── main.tf
├── index.html
└── README.md
```

## Features

### Frontend
- **Responsive Design**: Two-column desktop layout, single-column mobile
- **Modern CSS**: Uses CSS Grid, Flexbox, and CSS Variables
- **Semantic HTML5**: Proper structure with accessibility in mind
- **Interactive Elements**: Smooth scrolling, fade-in animations
- **Visitor Counter**: Placeholder API integration for visitor tracking
- **Telemetry Ready**: Prepared function for future Kinesis Firehose integration

### Infrastructure
- **S3 Bucket**: Static website hosting with encryption and versioning
- **CloudFront CDN**: Global content delivery with HTTPS enforcement
- **Origin Access Control**: Secure S3 access through CloudFront
- **Terraform**: Infrastructure as Code for reproducible deployments

## Color Palette

- `--bg-primary`: #040404 (Black - Background)
- `--bg-secondary`: #13505b (Dark Teal - Sidebar/Cards)
- `--accent-primary`: #119da4 (Dark Cyan - Headers)
- `--accent-secondary`: #0c7489 (Cerulean - Buttons/Hover)
- `--text-main`: #d7d9ce (Dust Grey - Text)

## Deployment Instructions

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform installed
- Domain name (optional, for custom domain)

### Infrastructure Deployment

1. Navigate to the infrastructure directory:
   ```bash
   cd infrastructure
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review and customize variables in `main.tf` if needed:
   - `aws_region`: AWS region (default: us-east-1)
   - `domain_name`: Your domain name (default: aarondouglass.com)

4. Plan the deployment:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

6. Note the outputs:
   - `cloudfront_domain_name`: Use this for your CNAME record
   - `s3_bucket_name`: Your S3 bucket name

### Website Deployment

1. Upload website files to the S3 bucket:
   ```bash
   aws s3 sync . s3://your-bucket-name --delete
   ```

2. Configure your domain:
   - Create a CNAME record pointing to the CloudFront domain
   - Update the visitor count API URL in `js/main.js`

### Custom Domain Setup

1. After Terraform deployment, update the CloudFront distribution:
   - Replace `cloudfront_default_certificate = true` with custom SSL certificate
   - Add alternate domain names (CNAMEs)

2. Update Route53 or your DNS provider:
   - Create CNAME record pointing to CloudFront domain

## JavaScript Functions

### Visitor Count
```javascript
getVisitorCount() // Fetches visitor count from API
```

### Telemetry (Future)
```javascript
collectTelemetry() // Prepares analytics data for Kinesis Firehose
```

## Customization

### Profile Image
Replace `assets/images/profile.jpg` with your actual profile image (150x150 pixels recommended).

### Content
Update the following files:
- `index.html`: Personal information, experience, education
- `css/style.css`: Colors, fonts, layout adjustments
- `js/main.js`: API endpoints, analytics configuration

### Infrastructure
Modify `infrastructure/main.tf` for:
- Different AWS regions
- Additional security settings
- Custom domain configurations
- Logging and monitoring

## Security Features

- S3 bucket encryption (AES256)
- CloudFront Origin Access Control
- HTTPS enforcement
- No public S3 access
- Versioning enabled
- Security headers ready

## Performance Optimizations

- CloudFront CDN for global delivery
- Gzip compression enabled
- Cache optimization for different file types
- Minified assets (recommended for production)

## Future Enhancements

- API Gateway + Lambda for visitor count
- Kinesis Firehose for analytics
- Custom SSL certificate
- CI/CD pipeline
- Additional security headers
- Performance monitoring

## License

This project is part of the AWS Cloud Resume Challenge and is intended for educational and portfolio purposes.
