# Hyperspace Terraform Module.

![Hyperspace Architecture](Hyperspace_architecture.png)

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Module Structure](#module-structure)
- [Variables](#variables)
- [Features](#features)
  - [EKS Cluster](#eks-cluster)
  - [Networking](#networking)
  - [Security](#security)
  - [Monitoring and Logging](#monitoring-and-logging)
  - [Backup and Disaster Recovery](#backup-and-disaster-recovery)
  - [GitOps and CI/CD](#gitops-and-cicd)
- [Outputs](#outputs)
- [Getting Started](#getting-started)
- [Important Notes](#important-notes)
  - [ACM Certificate Validation](#acm-certificate-validation)
  - [Privatelink](#privatelink)
  - [Access Your Infrastructure](#access-your-infrastructure)
  - [ArgoCD and Grafana Privatelink](#argocd-and-grafana-privatelink)

## Overview

This Terraform module provides a complete infrastructure setup for Hyperspace. It creates everything needed to run your applications in AWS, including networking, Kubernetes cluster, security settings, and monitoring tools.

## Architecture

The module creates a production-ready infrastructure with:

- Amazon EKS cluster with managed and self-managed node groups
- VPC with public and private subnets
- AWS Load Balancer Controller
- Internal and external ingress controllers
- Monitoring stack (Prometheus, Grafana, Loki)
- Backup solution (Velero)
- [GitOps with ArgoCD](https://github.com/hyper-space-io/Hyperspace-Deployment)

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with admin access
- kubectl installed
- Helm 3.x
- AWS account with admin access
- Domain name (for Route53 setup)

## Module Structure 
```
.
├── eks.tf           # EKS cluster configuration
├── network.tf       # VPC and networking setup
├── S3.tf            # S3 buckets configuration
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── locals.tf        # Local variables
├── providers.tf     # Provider configuration
├── argocd.tf        # ArgoCD installation
├── loki.tf          # Logging stack
├── velero.tf        # Backup solution
├── Route53.tf       # DNS configuration
└── user_data.sh.tpl # User data for EC2 instances
```


# Getting Started

1. Create a new Terraform configuration and use the module as follows:

```hcl
module "hyperspace" {
  source                = "github.com/hyper-space-io/Hyperspace-terraform-module"
  aws_region            = "REGION"
  domain_name           = "DOMAIN.com"
  environment           = "ENVIRONMENT"
  vpc_cidr              = "10.50.0.0/16"
  aws_account_id        = "AWS_ACCOUNT_ID"
  hyperspace_account_id = "HYPERSPACE_ACCOUNT_ID"

  argocd_config = {
    vcs = {
      organization = "<org>"
      repository   = "<repo>"
      gitlab = {
        enabled = true
      }
    }
  }
}

terraform {
  backend "s3" {
    bucket       = "hyperspace-terraform-state-<random-string>"
    key          = "terraform.tfstate"
    region       = "REGION"
    encrypt      = true
    use_lockfile = true
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "REGION"
}
```

2. Initialize Terraform:
```bash
terraform init
```

3. Apply the configuration:
```bash
terraform apply
```

4. After the infrastructure is deployed, you can set up your ArgoCD applications using the [Hyperspace Deployment Repository](https://github.com/hyper-space-io/Hyperspace-Deployment) as a template.

# Important Notes

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

### ArgoCD and Grafana Privatelink
When using ArgoCD or Grafana with privatelink enabled, there are some important considerations:

1. **Privatelink Configuration**:
   - Both ArgoCD and Grafana can be configured to use AWS Privatelink for secure access
   - This is controlled by the `argocd_config.privatelink.enabled` and `grafana_privatelink_config.enabled` variables
   - When enabled, the services will be accessible through consumer VPC endpoints in allowed accounts controlled by `argocd_config.privatelink.endpoint_allowed_principals` and `grafana_privatelink_config.endpoint_allowed_principals`

2. **Deletion Process**:
   - Before deleting changing argocd_config.privatelink.enabled or grafana_privatelink_config.enabled to false, you must first remove all active VPC endpoint connections
   - To delete the endpoint services:
     1. Go to AWS VPC Console > Endpoint Services
     2. Find the ArgoCD or Grafana endpoint service
     3. Select all endpoint connections
     4. Click "Reject" to deny the connections
     5. After all connections are rejected, you can delete the endpoint service
   - This is required because AWS prevents deletion of endpoint services that have active connections

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| aws_account_id | AWS account ID | string | - | yes |
| hyperspace_account_id | The account ID of the hyperspace account (obtained from Hyperspace support) | string | - | yes |
| aws_region | AWS region | string | "us-east-1" | yes |
| domain_name | Main domain name for sub-domains | string | "" | yes |
| environment | Deployment environment | string | "development" | yes |
| vpc_cidr | CIDR block for the VPC | string | "10.10.0.0/16" | yes |
| project | Name of the project | string | "hyperspace" | no |
| terraform_role | Terraform role to assume | string | "PlatformAdmin" | no |
| tags | Map of tags to add to all resources | map(string) | {} | no |
| hyperspace_aws_region | The region of the hyperspace account | string | "us-east-1" | no |
| availability_zones | List of availability zones to deploy resources | list(string) | [] | no |
| create_vpc | Controls if VPC should be created | bool | true | no |
| existing_vpc_config | Configuration for using an existing VPC | object | {vpc_id: null, vpc_cidr: null, private_subnets: [], public_subnets: []} | no |
| num_zones | Number of zones to utilize for EKS nodes | number | 2 | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway or one per AZ | bool | false | no |
| create_vpc_flow_logs | Enable VPC flow logs | bool | false | no |
| flow_logs_retention | Flow logs retention in days | number | 14 | no |
| flow_log_group_class | Flow logs log group class in CloudWatch | string | "STANDARD" | no |
| flow_log_file_format | Flow logs file format | string | "parquet" | no |
| create_eks | Should we create the EKS cluster? | bool | true | no |
| enable_cluster_autoscaler | Enable and install cluster-autoscaler | bool | true | no |
| worker_nodes_max | Maximum amount of worker nodes allowed | number | 10 | no |
| worker_instance_type | Instance type for EKS worker nodes | list(string) | ["m5n.xlarge"] | no |
| eks_additional_admin_roles | Additional IAM roles to add as cluster administrators | list(string) | [] | no |
| create_public_zone | Whether to create the public Route 53 zone | bool | false | no |
| existing_public_zone_id | Existing public Route 53 zone ID (optional) | string | "" | no |
| existing_private_zone_id | Existing private Route 53 zone ID (optional) | string | "" | no |
| domain_hosted_zone_id | Hosted zone ID for ACM validation (optional, for cross-account or root domain validation) | string | "" | no |
| argocd_config | ArgoCD configuration | object | {enabled: true, privatelink: {enabled: true, endpoint_allowed_principals: [], additional_aws_regions: []}, vcs: {organization: "", repository: ""}, rbac: {sso_admin_group: "", users_rbac_rules: [], users_additional_rules: []}} | no |
| prometheus_endpoint_config | Prometheus endpoint configuration | object | {enabled: false, endpoint_service_name: "", endpoint_service_region: "", additional_cidr_blocks: []} | no |
| grafana_privatelink_config | Grafana privatelink configuration | object | {enabled: true, endpoint_allowed_principals: [], additional_aws_regions: []} | no |

**Note**: The `hyperspace_account_id` is a required variable that you need to obtain from Hyperspace support. This ID is used to pull resources from Hyperspace like AMIs and other infrastructure components.

**Note**: 
When using `domain_hosted_zone_id` for ACM validation in a different AWS account, ensure that the Terraform role (or the underlying machine) has the necessary permissions to create and manage DNS records in that zone. The role must have at least the following permissions in the target account:
> ```json
> {
>   "Version": "2012-10-17",
>   "Statement": [
>     {
>       "Effect": "Allow",
>       "Action": [
>         "route53:ChangeResourceRecordSets",
>         "route53:ListResourceRecordSets",
>         "route53:GetHostedZone"
>       ],
>       "Resource": "arn:aws:route53:::hostedzone/*"
>     }
>   ]
> }
> ```

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

## Outputs

| Name | Description |
|------|-------------|
| aws_region | The AWS region where resources are deployed |
| eks_cluster | Complete EKS cluster object |
| vpc | Complete VPC object |
| tags | Map of tags applied to resources |
| s3_buckets | Map of S3 buckets created |
| argocd_vpc_endpoint_service_domain_verification_name | Domain verification name for ArgoCD VPC endpoint service |
| argocd_vpc_endpoint_service_domain_verification_value | Domain verification value for ArgoCD VPC endpoint service |
| grafana_vpc_endpoint_service_domain_verification_name | Domain verification name for Grafana VPC endpoint service |
| grafana_vpc_endpoint_service_domain_verification_value | Domain verification value for Grafana VPC endpoint service |
| acm_certificate_domain_validation_options | ACM certificate domain validation options for internal and external certificates |

> **Note**: The domain verification outputs are only available when privatelink is enabled for the respective service (ArgoCD or Grafana).