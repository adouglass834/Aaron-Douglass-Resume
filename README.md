# AWS Cloud Resume Challenge Journal
https://cloudresumechallenge.dev/docs/the-challenge/aws/

## Completed

### Created S3 bucket

- This was pretty straight forward.
- Static website has to be enabled, and all traffic must be allowed.
- Added a policy that allows anyone to read objects from the cloud-resume-aws S3 bucket, effectively making the bucket's content publicly accessible.
  - >"Version":"2012-10-17": This specifies the version of the policy language being used.
  - >"Statement": This is an array of policy statements. Here, there's only one statement.
  - >"Sid": "AddPerm": This is an optional identifier (Statement ID) for the policy statement, which helps to identify it.
  - >"Effect": "Allow": This specifies that the policy is granting (allowing) permissions.
  - >"Principal": "*": The asterisk * means that the policy applies to all users (everyone) on the internet, essentially making it a public policy.
  - >"Action": "s3:GetObject": This specifies that the allowed action is s3:GetObject, which grants permission to retrieve (read) objects in the specified S3 bucket.
  - >"Resource": "arn:aws:s3:::cloud-resume-aws/*": This defines the resources the policy applies to. In this case, it includes all objects (/*) within the S3 bucket named cloud-resume-aws.
- Files were uploaded manually at first.


### Route 53

- Already had a registered domain: aarondouglass.com
- Created a hosted zone with this domain so it is available for use.


### Certificates Manager

- Requested a public certificate using DNS validation.
  - aarondouglass.com
  - www.aarondouglass.com
- The CNAMEs for these two certificates were added into the domains records
- Still >Pending Validation

### Github Actions

- In AWS, created a new user in IAM and assigned the S3 Access Role
  - Created Access Keys for this user
- In Github, added these secret keys into the Settings:Secrets and Variables:Actions Repository Secrets.
- In the Actions tab, manually created a new work flow.
  - After tweaking the main.yml page from a previous project, able to get push to origin from command line and verify that changes were made.
  - http://cloud-resume-aws.s3-website-us-east-1.amazonaws.com
 
## Action Items

- Personalize the HTML code with applicable data
- Verify CA status: currently Pending Validation
- Attach custom URL to the S3 bucket using CloudFront
- Update Javascript code to add in a visitor counter
- Create a DynamoDB fot the counter
- Create the API to communicate between vistor counter and DB
