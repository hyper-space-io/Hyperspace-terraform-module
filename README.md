# Hyperspace Terraform Module

![Hyperspace Architecture](Hyperspace_architecture.png)

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Module Structure](#module-structure)
- [Variables](#variables)
  - [Infrastructure Module Variables](#infrastructure-module-variables)
  - [Application Module Variables](#application-module-variables)
- [Features](#features)
  - [EKS Cluster](#eks-cluster)
  - [Networking](#networking)
  - [Security](#security)
  - [Monitoring and Logging](#monitoring-and-logging)
  - [Backup and Disaster Recovery](#backup-and-disaster-recovery)
  - [GitOps and CI/CD](#gitops-and-cicd)
- [Outputs](#outputs)
  - [Infrastructure Module Outputs](#infrastructure-module-outputs)
  - [Application Module Outputs](#application-module-outputs)
- [Getting Started](#getting-started)
- [Important Notes](#important-notes)
  - [Terraform Cloud Token Setup](#terraform-cloud-token-setup)
  - [ACM Certificate Validation](#acm-certificate-validation)
  - [Privatelink](#privatelink)
  - [Access Your Infrastructure](#access-your-infrastructure)

## Overview

This Terraform module provides a complete infrastructure setup for the Hyperspace project, including EKS cluster deployment, networking, security configurations, and various application components.
The module is split into two main parts:
- Infrastructure Module (`Infra-module`)
- Application Module (`app-module`)

## Architecture

The module creates a production-ready infrastructure with:

- Amazon EKS cluster with managed and self-managed node groups
- VPC with public and private subnets
- AWS Load Balancer Controller
- Internal and external ingress controllers
- Monitoring stack (Prometheus, Grafana, Loki)
- Backup solution (Velero)
- GitOps with ArgoCD
- Terraform Cloud Agent for remote operations

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with admin access
- kubectl installed
- Helm 3.x
- AWS account with admin access
- Domain name (for Route53 setup)
- Terraform cloud account

## Module Structure 
```
.
├── Infra-module/
│ ├── eks.tf # EKS cluster configuration
│ ├── network.tf # VPC and networking setup
│ ├── S3.tf # S3 buckets configuration
│ ├── tfc_agent.tf # Terraform Cloud agent setup
│ ├── variables.tf # Input variables
│ ├── outputs.tf # Output values
│ ├── locals.tf # Local variables
│ ├── providers.tf # Provider configuration
│ └── user_data.sh.tpl # User data for EC2 instances
├── app-module/
│ ├── argocd.tf # ArgoCD installation
│ ├── loki.tf # Logging stack
│ ├── velero.tf # Backup solution
│ ├── Route53.tf # DNS configuration
│ ├── variables.tf # Input variables
│ └── providers.tf # Provider configuration
```


### Infrastructure Module Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Name of the project | string | "hyperspace" | no |
| environment | Deployment environment | string | "development" | no |
| aws_region | AWS region | string | "us-east-1" | no |
| vpc_cidr | CIDR block for the VPC | string | 10.10.0.0/16 | yes |
| availability_zones | List of AZs | list(string) | [] | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway OR one per AZ | bool | false | no |
| num_zones | Number of AZs to use | number | 2 | no |
| create_eks | Create EKS cluster | bool | true | no |
| worker_nodes_max | Maximum number of worker nodes | number | - | yes |
| worker_instance_type | List of allowed instance types | list(string) | ["m5n.xlarge"] | no |
| create_vpc_flow_logs | Enable VPC flow logs | bool | false | no |
| flow_logs_retention | Flow logs retention in days | number | 14 | no |
| flow_log_group_class | Flow logs log group class in CloudWatch | string | STANDARD | no |
| flow_log_file_format | Flow logs file format | string | parquet | no |


### Application Module Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| organization | Terraform Cloud organization name | string | - | yes |
| infra_workspace_name | Infrastructure workspace name | string | - | yes |
| domain_name | Main domain name for sub-domains | string | "" | no |
| enable_argocd | Enable ArgoCD installation | bool | true | no |
| enable_ha_argocd | Enable HA for ArgoCD | bool | true | no |
| create_public_zone | Create public Route53 zone | bool | false | no |
| enable_cluster_autoscaler | Enable cluster autoscaler | bool | true | no |

## Outputs

### Infrastructure Module Outputs

| Name | Description |
|------|-------------|
| aws_region | The AWS region where resources are deployed |
| eks_cluster | Complete EKS cluster object |
| vpc | Complete VPC object |
| tags | Map of tags applied to resources |
| s3_buckets | Map of S3 buckets created |

### Application Module Outputs
The application module primarily manages Kubernetes resources and doesn't expose specific outputs.


## Features

### EKS Cluster
- Managed node groups with Bottlerocket OS
- Self-managed node groups for specialized workloads
- Cluster autoscaling
- IRSA (IAM Roles for Service Accounts)
- EBS CSI Driver integration
- EKS Managed Addons

### Networking
- VPC with public and private subnets
- NAT Gateways
- VPC Endpoints
- Internal and external ALB ingress controllers
- Network policies
- VPC flow logs (optional)
- Connectivity to Auth0

### Security
- Network policies
- Security groups
- IAM roles and policies
- OIDC integration

### Monitoring and Logging
- Prometheus and Grafana
- Loki for log aggregation
- OpenTelemetry for observability
- CloudWatch integration
- Core dump handling

### Backup and Disaster Recovery
- Velero for cluster backup
- EBS volume snapshots

### GitOps and CI/CD
- ArgoCD installation and SSO integration
- ECR credentials sync to gain access to private hyperspace ECR repositories
- Terraform Cloud Agent to gain access to private EKS cluster

## Outputs

### Infrastructure Module Outputs

| Name | Description |
|------|-------------|
| aws_region | The AWS region where resources are deployed |
| eks_cluster | Complete EKS cluster object |
| vpc | Complete VPC object |
| tags | Map of tags applied to resources |
| s3_buckets | Map of S3 buckets created |

### Application Module Outputs
The application module primarily manages Kubernetes resources and doesn't expose specific outputs.

> **Note**: This module is currently under active development and may undergo significant changes. Not all features are fully implemented yet.


# Getting Started

- Create a new workspace in Terraform Cloud
- Name it according to your infrastructure needs (e.g., "hyperspace-infra-module")

- Create a new Terraform configuration and use the module as follows:

```hcl
module "hyperspace" {
  source = "github.com/hyper-space-io/Hyperspace-terraform-module/Infra-module?ref=setup-cluster-tools"
  
  # Required variables
  domain_name         = "your-domain.com"
  environment         = "development"
  vpc_cidr            = "10.0.0.0/16"
  worker_nodes_max    = 10
  
  # Optional variables with defaults
  project               = "hyperspace"
  aws_region            = "us-east-1"
  create_public_zone    = true
  enable_ha_argocd      = true
  worker_instance_type  = ["m5n.xlarge"]
  
  # Additional configurations
  flow_log_group_class = "INFREQUENT_ACCESS"
  dex_connectors       = [] # Add your authentication connectors here
}
```

# Important Notes

### Terraform Cloud Token Setup
To enable the creation of workspaces, agent pools, and agent tokens via the Terraform Enterprise provider, you need to configure a Terraform Cloud API token:

1. Generate a Terraform Cloud API token:
   - Log in to your Terraform Cloud account
   - Go to User Settings > Tokens
   - Click "Create an API token"
   - Give it a descriptive name (e.g., "Hyperspace Infrastructure")
   - Copy the generated token (you won't be able to see it again)

2. Configure the token in your infrastructure workspace:
   - Navigate to your infrastructure workspace in Terraform Cloud
   - Go to "Variables" under workspace settings
   - Click "Add variable"
   - Configure the variable with these settings:
     - Key: `TFE_TOKEN`
     - Value: Your API token
     - Category: Environment variable
     - Sensitive: Yes

### ACM Certificate Validation
During deployment, Terraform will pause for ACM certificate validation:

1. In AWS Console > Certificate Manager, find your pending certificate
2. Copy the validation record name and value
3. Create CNAME records in your **public** Route 53 hosted zone:
   ```
   Name:  <RANDOM_STRING>.<environment>.<your-domain>
   Value: _<RANDOM_STRING>.validations.aws.
   ```
3. Wait for validation (5-30 minutes)
4. Terraform will automatically continue once validated
> **Important**: The CNAME must be created in a public hosted zone, not private. Ensure you include the trailing dot in the Value field.

### Privatelink
After deploying the infrastructure, you'll need to verify your VPC Endpoint Service by creating a DNS record. 
This verification allows Hyperspace to establish a secure connection to collect essential metrics from your environment through AWS PrivateLink:

### 1. Get Verification Details
1. Open AWS Console and navigate to VPC Services
2. Go to **Endpoint Services** in the left sidebar
3. Find your endpoint service named `<your-domain>.<environment> ArgoCD Endpoint Service`
4. In the service details, locate:
   - **Domain verification name**
   - **Domain verification value**

### 2. Create DNS Verification Record
1. In AWS Console, navigate to **Route 53**
2. Go to **Hosted zones**
3. Select your public hosted zone
4. Click **Create record** and configure:
   - **Record type**: TXT
   - **Record name**: Paste the domain verification name from step 1
   - **Value**: Paste the domain verification value from step 1
   - **TTL**: 1800 seconds (30 minutes)
5. Click **Create records**

### 3. Wait for Verification
- In the VPC Endpoint Service console, select your endpoint service
- Click Actions -> Verify domain ownership for private DNS name
- The verification process may take up to 30 minutes
- You can monitor the status in the VPC Endpoint Service console
- The status will change to "Available" once verification is complete

## Access Your Infrastructure
After successful deployment, you can access:
   - ArgoCD: `https://argocd.internal-<environment>.<your-domain>`
   - Grafana: `https://grafana.internal-<environment>.<your-domain>`

**Initial ArgoCD Password**: Retrieve it using:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```
For detailed configuration options, refer to the [Infrastructure Module Variables](#Infrastructure-Module-Variables).