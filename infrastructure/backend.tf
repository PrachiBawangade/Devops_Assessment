terraform {
  backend "s3" {
    bucket         = "zentrumhub-devops-bucket-1"
    key            = "assessment/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "zentrumhub-devops-tflock"
    encrypt        = true
  }
}