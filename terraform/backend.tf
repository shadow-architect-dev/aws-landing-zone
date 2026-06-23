terraform {
  backend "s3" {
    bucket         = "aws-landing-zone-tfstate-111122223333-ap-northeast-1"
    key            = "landing-zone/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "aws-landing-zone-tfstate-lock"
    encrypt        = true
  }
}
