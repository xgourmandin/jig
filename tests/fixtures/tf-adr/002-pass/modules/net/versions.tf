terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      configuration_aliases = [aws.peer]
    }
  }
}

# provider "aws" { region = "x" }  (a comment, not a block)
locals {
  doc = "provider \"aws\" { }"
}

locals {
  script = <<-EOT
    provider "aws" {
      region = "x"
    }
  EOT
  nested = "a ${lookup({ k = "}" }, "k", "provider \"x\" {")} b"
}
