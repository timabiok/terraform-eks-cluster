# ------------------------------------------------------------------------------
# VPC: Create new (from terraform-aws-vpc) or use existing
# ------------------------------------------------------------------------------

variable "create_vpc" {
  type        = bool
  description = "When true, create a new VPC using the terraform-aws-vpc module (https://github.com/timabiok/terraform-aws-vpc). When false, use existing VPC and subnet IDs provided below."
  default     = true
}

# Used when create_vpc = false (existing VPC)
variable "vpc_id" {
  type        = string
  description = "Existing VPC ID. Required when create_vpc = false."
  default     = ""
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Existing private subnet IDs for EKS nodes and control plane. Required when create_vpc = false."
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Existing public subnet IDs (optional). Used for public load balancers and public API endpoint when enabled."
  default     = []
}


variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of the VPC. Used for cluster security group rules when create_vpc = false. Ignored when create_vpc = true (derived from VPC module)."
  default     = "10.0.0.0/16"
}

# Pass-through when create_vpc = true (terraform-aws-vpc module)
variable "region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment: dev, staging, or prod. Used in naming and tags."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod."
  }
}

variable "app" {
  type        = string
  description = "Application or project name. Used in resource naming and tags."
  default     = "eks"
}

variable "owner" {
  type        = string
  description = "Owner or team for tagging. Required when env = prod."
  default     = ""

  validation {
    condition     = var.env != "prod" || length(trimspace(var.owner)) > 0
    error_message = "owner must be set when env is prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the new VPC when create_vpc = true. Ignored when create_vpc = false."
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT gateway for all AZs when create_vpc = true (cost-saving). Set false for production HA."
  default     = false
}

variable "allowed_https_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed for HTTPS (443) on VPC app security group. Only used when create_vpc = true."
  default     = []
}

variable "allowed_ssh_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed for SSH (22) on VPC app security group. Only used when create_vpc = true."
  default     = []
}

variable "db_ingress_ports" {
  type        = list(number)
  description = "Database ports allowed from VPC on app security group. Only used when create_vpc = true."
  default     = [3306, 5432]
}

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster. Used as prefix for related resources."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS control plane (e.g. 1.31, 1.30)."
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Enable public API endpoint for the EKS cluster."
  default     = true
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Enable private API endpoint (within VPC). Recommended for production."
  default     = true
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "List of control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)."
  default     = ["api", "audit", "authenticator"]
}

# ------------------------------------------------------------------------------
# Managed Node Groups
# ------------------------------------------------------------------------------

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 50)
  }))
  description = "Map of managed node group configurations. Keys are node group names (e.g. general, spot)."
  default = {
    general = {
      instance_types = ["m5.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      disk_size      = 50
    }
  }
}

# ------------------------------------------------------------------------------
# Add-ons and extras
# ------------------------------------------------------------------------------

variable "enable_irsa" {
  type        = bool
  description = "Enable IAM Roles for Service Accounts (IRSA) for the cluster."
  default     = true
}

variable "enable_cluster_encryption" {
  type        = bool
  description = "Enable envelope encryption for Kubernetes secrets (KMS)."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to all resources."
  default     = {}
}
