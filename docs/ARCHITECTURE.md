# EKS System Architecture Schema

This document describes the architecture of the production-ready EKS system provisioned by this Terraform root module, including components, data flow, and deployment options.

---

## 1. High-Level Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                      AWS Region                          │
                                    │                                                          │
  Internet ────────────────────────│  ┌──────────────┐     ┌──────────────────────────────┐  │
                                    │  │   Internet   │     │     EKS Control Plane         │  │
                                    │  │   Gateway    │     │  (API Server, etcd, managed)   │  │
                                    │  └──────┬───────┘     │  - Public endpoint (optional)  │  │
                                    │         │             │  - Private endpoint (optional)  │  │
                                    │         │             └───────────────┬────────────────┘  │
                                    │         │                             │                   │
                                    │  ┌──────▼─────────────────────────────▼────────────────┐  │
                                    │  │              Public Subnets (per AZ)                 │  │
                                    │  │  - NAT Gateways (1 per AZ or 1 shared)               │  │
                                    │  │  - Load Balancers (ALB/NLB)                          │  │
                                    │  └─────────────────────────────────────────────────────┘  │
                                    │         │                                                   │
                                    │  ┌──────▼─────────────────────────────────────────────┐    │
                                    │  │           Private Subnets (per AZ)                  │    │
                                    │  │  - EKS Node Groups (worker EC2)                     │    │
                                    │  │  - Application Pods                                  │    │
                                    │  │  - Outbound via NAT                                  │    │
                                    │  └─────────────────────────────────────────────────────┘    │
                                    │         │                                                   │
                                    │  ┌──────▼─────────────────────────────────────────────┐    │
                                    │  │         Database Subnets (optional, per AZ)         │    │
                                    │  │  - RDS / Aurora (not part of EKS module)            │    │
                                    │  └─────────────────────────────────────────────────────┘    │
                                    └─────────────────────────────────────────────────────────────┘
```

---

## 2. Component Schema

### 2.1 VPC Layer

| Component        | Description | Source |
|-----------------|-------------|--------|
| **VPC**         | Single CIDR; DNS hostnames and DNS support enabled. | Created by [terraform-aws-vpc](https://github.com/timabiok/terraform-aws-vpc) when `create_vpc = true`, or supplied as `vpc_id` when `create_vpc = false`. |
| **Public subnets** | One per AZ; route to Internet Gateway. Used for NAT gateways and public load balancers. | From VPC module or `public_subnet_ids`. |
| **Private subnets** | One per AZ; route to NAT gateway(s). Used for EKS control plane and node groups. | From VPC module or `private_subnet_ids`. |
| **Database subnets** | Isolated subnets with dedicated route table; no direct internet. | Only when VPC is created by module; not required for EKS. |

### 2.2 EKS Control Plane

| Component | Description |
|----------|-------------|
| **API server endpoint** | Public and/or private. When both enabled, private is preferred from within VPC. |
| **Cluster security group** | Attached to control plane; allows node → API and (optional) public access. |
| **KMS key** | Optional envelope encryption for Kubernetes Secrets (`enable_cluster_encryption`). |
| **Control plane logs** | Optional CloudWatch log types: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`. |

### 2.3 Compute Layer (Node Groups)

| Component | Description |
|----------|-------------|
| **EKS Managed Node Groups** | One or more groups; each has instance types, min/max/desired size, disk size. |
| **Node security group** | Attached to nodes; allows cluster → nodes (443), nodes → cluster (ephemeral), and node-to-node. |
| **Subnet placement** | Nodes are placed in **private subnets** only. |

### 2.4 IAM and Auth

| Component | Description |
|----------|-------------|
| **Cluster creator admin** | Enabled so the applying identity has admin access to the cluster. |
| **IRSA (IAM Roles for Service Accounts)** | Optional OIDC provider; allows Pods to assume IAM roles via `eks.amazonaws.com/role-arn`. |

---

## 3. Data Flow

- **User / CI → API server**: Via public endpoint (if enabled) or from inside VPC via private endpoint.
- **Nodes → API server**: Always via private endpoint (nodes in private subnets).
- **Pods → Internet**: Node egress → NAT gateway → Internet Gateway.
- **Internet → Pods**: Through a load balancer (ALB/NLB) in public subnets or via Ingress.

---

## 4. Deployment Modes

### 4.1 New VPC + EKS (`create_vpc = true`)

- VPC is created in this repo using `terraform-aws-modules/vpc/aws` with the **same design** as [terraform-aws-vpc](https://github.com/timabiok/terraform-aws-vpc): same AZ layout, private/public/database subnets, NAT (single or per AZ), DNS, and an app security group (443, 22, DB ports). The upstream repo is not called directly because it contains a provider block and cannot be used with `count`.
- All VPC-related variables (`region`, `env`, `app`, `vpc_cidr`, `single_nat_gateway`, `allowed_*_cidr_blocks`, `db_ingress_ports`) are used here to create the VPC and app security group.
- EKS uses the resulting `vpc_id`, `private_subnet_ids`, and `public_subnet_ids`.

### 4.2 Existing VPC + EKS (`create_vpc = false`)

- User supplies: `vpc_id`, `private_subnet_ids`, and optionally `public_subnet_ids`, `vpc_cidr_block`.
- No VPC resources are created; EKS is placed into the existing subnets.
- Ensure existing subnets have appropriate routing (e.g. private subnets have route to NAT) and that they span at least two AZs for HA.

---

## 5. Security Summary

| Area | Implementation |
|------|----------------|
| **Network** | Control plane and nodes in private subnets; egress via NAT. |
| **Secrets** | Optional KMS envelope encryption for Kubernetes Secrets. |
| **Auth** | IAM + optional IRSA; cluster creator has admin by default. |
| **Logging** | Optional control plane logs to CloudWatch. |
| **VPC (when created)** | App security group restricts 443/22/DB to configurable CIDRs. |

---

## 6. Naming and Tagging

- **Cluster name**: From variable `cluster_name`; used as prefix for EKS-related resources.
- **Tags**: `Environment`, `Owner`, `Project`, `Terraform` applied via provider `default_tags`; extra tags from `var.tags`.
- **VPC (when created)**: Named by VPC module (e.g. `{app}-{env}-vpc`).

---

## 7. Module Dependencies

```
terraform-eks-cluster (this repo)
├── terraform-aws-vpc (optional, git::https://github.com/timabiok/terraform-aws-vpc.git)
│   └── terraform-aws-modules/vpc/aws
└── terraform-aws-modules/eks/aws
```

- **EKS module**: Requires `vpc_id`, `subnet_ids` (private), and supports `control_plane_subnet_ids`, managed node groups, IRSA, and encryption.
