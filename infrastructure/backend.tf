terraform {
  backend "s3" {
    bucket         = "aaron-douglass-terraform-state"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
