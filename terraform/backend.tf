terraform {
  backend "s3" {
    bucket         = "landingzone-terraform-state-111122223333"
    key            = "landing-zone/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "landingzone-terraform-state-lock"
    encrypt        = true
  }
}
