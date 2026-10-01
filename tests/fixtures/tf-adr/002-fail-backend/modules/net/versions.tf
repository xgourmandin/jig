terraform {
  required_version = ">= 1.9"

  backend "s3" {
    bucket = "state"
  }
}
