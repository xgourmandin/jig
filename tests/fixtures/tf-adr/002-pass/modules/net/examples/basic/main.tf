provider "aws" {
  region = "eu-west-1"
}

module "net" {
  source = "../.."
}
