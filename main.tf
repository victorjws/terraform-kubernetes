terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2.3"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

# provider "tls" {
#   proxy {
#     url = "https://corporate.proxy.service"
#   }
# }
