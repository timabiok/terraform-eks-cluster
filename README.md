# Production-Ready EKS Cluster

Terraform root module that provisions a production-ready **Amazon EKS** cluster. You can either **create a new VPC** using the [terraform-aws-vpc](https://github.com/timabiok/terraform-aws-vpc) module or **use an existing VPC** by supplying VPC and subnet IDs.

## Features

- **VPC**: Create a new VPC with the same design as [terraform-aws-vpc](https://github.com/timabiok/terraform-aws-vpc) (using `terraform-aws-modules/vpc/aws` and matching subnets/NAT/app SG), or use an existing VPC and subnets.
- **EKS**: Uses the [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) module with managed node groups.
- **High availability**: Control plane and nodes in private subnets across multiple AZs; optional NAT per AZ when creating VPC.
- **Security**: Optional KMS encryption for secrets, IRSA (IAM Roles for Service Accounts), and configurable API endpoint (public/private).
- **Observability**: Optional control plane logs (API, audit, authenticator) to CloudWatch.

## Prerequisites

- **Terraform** >= 1.5.0, < 2.0.0
- **AWS credentials** configured (e.g. `AWS_PROFILE` or environment variables)
- For **existing VPC**: ensure private subnets have a route to a NAT gateway (or equivalent) for node egress

## Quick Start

### Option A: Create VPC + EKS (default)

1. Clone and enter the repo.
2. Copy the example variables and set your values:

   ```bash
   cp terraform.auto.tfvars.example terraform.auto.tfvars
   # Edit terraform.auto.tfvars: cluster_name, region, env, owner (if prod), etc.
   ```

3. Ensure `create_vpc = true` (default). VPC will be created from [terraform-aws-vpc](https://github.com/timabiok/terraform-aws-vpc).
4. Apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. Configure kubectl:

   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```

### Option B: Use existing VPC

1. Set in your tfvars or variables:

   ```hcl
   create_vpc = false
   vpc_id     = "vpc-xxxxxxxxxxxxxxxxx"
   private_subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
   # optional:
   public_subnet_ids  = ["subnet-xxx", "subnet-yyy", "subnet-zzz"]
   vpc_cidr_block     = "10.0.0.0/16"
   ```

2. Run `terraform init`, `terraform plan`, `terraform apply`.

**Note:** When `create_vpc = false`, you must set `vpc_id` and `private_subnet_ids`. Subnets should span at least two AZs and have outbound connectivity (e.g. NAT) for nodes.

## Inputs (summary)

| Name | Description | Default |
|------|-------------|--------|
| `create_vpc` | Create VPC from terraform-aws-vpc (true) or use existing (false) | `true` |
| `vpc_id` | Existing VPC ID (required when `create_vpc = false`) | `""` |
| `private_subnet_ids` | Existing private subnet IDs (required when `create_vpc = false`) | `[]` |
| `public_subnet_ids` | Existing public subnet IDs (optional) | `[]` |
| `vpc_cidr_block` | VPC CIDR when using existing VPC | `"10.0.0.0/16"` |
| `region` | AWS region | `"us-east-1"` |
| `env` | Environment: dev, staging, prod | `"dev"` |
| `app` | Application/project name | `"eks"` |
| `owner` | Owner/team (required when env = prod) | `""` |
| `vpc_cidr` | CIDR for new VPC when `create_vpc = true` | `"10.0.0.0/16"` |
| `single_nat_gateway` | Single NAT for all AZs when creating VPC (cost-saving) | `false` |
| `cluster_name` | EKS cluster name | (required) |
| `cluster_version` | Kubernetes version (e.g. 1.31) | `"1.31"` |
| `cluster_endpoint_public_access` | Enable public API endpoint | `true` |
| `cluster_endpoint_private_access` | Enable private API endpoint | `true` |
| `cluster_enabled_log_types` | Control plane log types | `["api", "audit", "authenticator"]` |
| `node_groups` | Map of managed node group configs (instance_types, min/max/desired size, disk_size) | one group `general` |
| `enable_irsa` | Enable IRSA (OIDC) | `true` |
| `enable_cluster_encryption` | KMS encryption for secrets | `true` |
| `tags` | Additional tags | `{}` |

VPC-related variables (`allowed_https_cidr_blocks`, `allowed_ssh_cidr_blocks`, `db_ingress_ports`) are only used when `create_vpc = true`.

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `private_subnet_ids` | Private subnet IDs used by EKS |
| `public_subnet_ids` | Public subnet IDs |
| `cluster_name` | EKS cluster name |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | EKS API endpoint |
| `cluster_certificate_authority_data` | CA cert (sensitive) |
| `cluster_oidc_issuer_url` | OIDC issuer for IRSA |
| `cluster_oidc_provider_arn` | OIDC provider ARN |
| `eks_managed_node_groups` | Node group attributes |
| `configure_kubectl` | Command to update kubeconfig |

## Architecture

A detailed **architecture schema** (components, data flow, deployment modes, security) is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Backend

For production, configure a remote backend in `terraform.tf` (e.g. S3 + DynamoDB or Terraform Cloud) and run `terraform init -reconfigure` after editing.

## License

See repository license.
