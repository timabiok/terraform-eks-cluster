# ------------------------------------------------------------------------------
# Providers
# ------------------------------------------------------------------------------

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.env
      Owner       = var.owner
      Project     = var.app
      Terraform   = "true"
    }
  }
}

# Kubernetes provider configured after EKS cluster is created (see providers.tf / data "aws_eks_cluster")
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ------------------------------------------------------------------------------
# VPC: Create new (same design as terraform-aws-vpc) or use existing
# ------------------------------------------------------------------------------
# When create_vpc = true we use terraform-aws-modules/vpc/aws with the same
# layout as https://github.com/timabiok/terraform-aws-vpc (private/public/DB
# subnets, NAT, DNS). The upstream repo cannot be used with count because it
# contains a provider block.
# ------------------------------------------------------------------------------

locals {
  vpc_name_prefix = var.app != "" ? var.app : "vpc"
  vpc_name        = "${local.vpc_name_prefix}-${var.env}-vpc"
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  count = var.create_vpc ? 1 : 0

  name = local.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 101)]
  database_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 21)]

  manage_default_security_group  = false
  enable_nat_gateway             = true
  enable_vpn_gateway             = false
  single_nat_gateway             = var.single_nat_gateway
  create_database_subnet_group   = true
  create_database_subnet_route_table = true
  create_database_internet_gateway_route = false
  manage_default_network_acl     = true
  manage_default_route_table     = true
  enable_dns_hostnames           = true
  enable_dns_support             = true

  tags = {
    Name        = local.vpc_name
    Terraform   = "true"
    Environment = var.env
  }
}

# App security group (same as terraform-aws-vpc): 443, 22, DB ports from allowed CIDRs / VPC
resource "aws_security_group" "app" {
  count = var.create_vpc ? 1 : 0

  name        = "${local.vpc_name_prefix}-${var.env}-app-sg"
  description = "Application security group (443, 22, DB ports only)"
  vpc_id      = module.vpc[0].vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_https_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_https_cidr_blocks
      description = "HTTPS"
    }
  }
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidr_blocks
      description = "SSH"
    }
  }
  dynamic "ingress" {
    for_each = var.db_ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [module.vpc[0].vpc_cidr_block]
      description = "DB port ${ingress.value}"
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all egress"
  }
  tags = {
    Name = "${local.vpc_name_prefix}-${var.env}-app-sg"
  }
}

locals {
  vpc_id             = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  vpc_cidr_block     = var.create_vpc ? module.vpc[0].vpc_cidr_block : var.vpc_cidr_block
  private_subnet_ids = var.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = var.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids
}

# Fail fast when existing VPC is selected but required inputs are missing
check "existing_vpc_inputs" {
  assert {
    condition     = var.create_vpc || (length(var.vpc_id) > 0 && length(var.private_subnet_ids) > 0)
    error_message = "When create_vpc is false, vpc_id and private_subnet_ids must be set."
  }
}

# ------------------------------------------------------------------------------
# EKS Cluster (terraform-aws-modules/eks/aws)
# ------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Control plane in private subnets; optional explicit control_plane_subnet_ids
  control_plane_subnet_ids = local.private_subnet_ids

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  enable_cluster_creator_admin_permissions = true

  cluster_enabled_log_types = var.cluster_enabled_log_types

  # Encryption (module creates KMS key when create_kms_key = true)
  create_kms_key = var.enable_cluster_encryption
  cluster_encryption_config = var.enable_cluster_encryption ? {
    resources = ["secrets"]
  } : {}

  # IRSA
  enable_irsa = var.enable_irsa

  # Managed node groups
  eks_managed_node_groups = {
    for name, ng in var.node_groups : name => {
      name            = name
      instance_types  = ng.instance_types
      min_size        = ng.min_size
      max_size        = ng.max_size
      desired_size    = ng.desired_size
      disk_size       = ng.disk_size

      subnet_ids = local.private_subnet_ids

      # Production: use launch template with IMDSv2 and no public IP
      iam_role_attach_cni_policy = true

      tags = {
        NodeGroup = name
      }
    }
  }

  tags = var.tags
}
