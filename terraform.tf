terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version  = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version  = "~> 2.23"
    }
    tls = {
      source  = "hashicorp/tls"
      version  = "~> 4.0"
    }
  }

  # Uncomment and configure for production (S3 + DynamoDB or Terraform Cloud)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "eks/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}
