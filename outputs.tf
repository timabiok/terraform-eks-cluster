# ------------------------------------------------------------------------------
# VPC (when create_vpc = true)
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID (from module or existing)."
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS."
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers, etc.)."
  value       = local.public_subnet_ids
}

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the cluster."
  value       = module.eks.oidc_provider_arn
}

output "cluster_platform_version" {
  description = "EKS cluster platform version."
  value       = module.eks.cluster_platform_version
}

# ------------------------------------------------------------------------------
# Node groups and auth
# ------------------------------------------------------------------------------

output "eks_managed_node_groups" {
  description = "Map of EKS managed node group attributes."
  value       = module.eks.eks_managed_node_groups
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to EKS nodes."
  value       = module.eks.node_security_group_id
}

# ------------------------------------------------------------------------------
# kubectl config
# ------------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Command to configure kubectl for the cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
