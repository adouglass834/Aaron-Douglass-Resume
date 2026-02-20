terraform {
  backend "s3" {
    # REQUIRED INPUT: Keep these names aligned with infrastructure/bootstrap/terraform.tfvars
    bucket         = "aaron-douglass-terraform-state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locking"
  }
}
