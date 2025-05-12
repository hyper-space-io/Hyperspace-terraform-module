# Hyperspace Terraform Module

![Hyperspace Architecture](Hyperspace_architecture.png)

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Basic Module Usage](#basic-module-usage)
- [Variables](#variables)
- [Features](#features)
- [ACM Certificate Validation](#acm-certificate-validation)
- [Privatelink](#privatelink)
- [VPC Configuration](#vpc-configuration)
- [ArgoCD, Grafana & Prometheus Variables](#argocd-grafana--prometheus-variables)
- [Access Your Infrastructure](#access-your-infrastructure)

## Overview

This Terraform module provides a complete infrastructure setup for Hyperspace. It creates everything needed to run Hyperspace in your AWS account.

The module creates a production-ready infrastructure with:

- Amazon EKS cluster with managed and self-managed node groups
- VPC with public and private subnets (Optional: deployment into an existing VPC)
- AWS Load Balancer Controller
- Internal and external ingress controllers
- Monitoring stack (Prometheus, Grafana, Loki)
- Backup solution (Velero)
- [GitOps with ArgoCD](https://github.com/hyper-space-io/Hyperspace-Deployment)

After deploying this Terraform Module, Install The Hyperspace Helm Chart through ArgoCD using the [Hyperspace Deployment Repository](https://github.com/hyper-space-io/Hyperspace-Deployment)

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with admin access
- kubectl installed
- Helm 3.x
- AWS account with admin access
- Domain name (for Route53 setup)

## Basic Module Usage

1. Create a new Terraform configuration and call the module as follows:

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
      gitlab/github = {
        enabled = true
      }
    }
  }
}
```

2. Initialize and apply the Terraform configuration:
```bash
terraform init 
terraform apply
```

3. After the infrastructure is deployed, you can install Hyperspace Helm chart through [Hyperspace Deployment Repository](https://github.com/hyper-space-io/Hyperspace-Deployment)


## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| aws_account_id | AWS account ID | string | - | yes |
| hyperspace_account_id | The account ID of the hyperspace account (obtained from Hyperspace support) | string | - | yes |
| aws_region | AWS region | string | "us-east-1" | yes |
| domain_name | Main domain name for sub-domains | string | "" | yes |
| environment | Deployment environment | string | - | yes |
| vpc_cidr | CIDR block for the VPC | string | "10.10.0.0/16" | no |
| argocd_config | ArgoCD configuration. Required fields when enabled: vcs.organization, vcs.repository, and either vcs.github.enabled or vcs.gitlab.enabled | object | {vcs: {organization: "", repository: "", github: {enabled: false}, gitlab: {enabled: false}}} | yes |
| project | Name of the project | string | "hyperspace" | no |
| terraform_role | Terraform role to assume | string | null | no |
| tags | Map of tags to add to all resources | map(string) | {} | no |
| availability_zones | List of availability zones to deploy resources | list(string) | [] | no |
| create_vpc | Controls if VPC should be created | bool | true | no |
| existing_vpc_id | ID of an existing VPC to use instead of creating a new one | string | null | no |
| existing_private_subnets | The private subnets for the existing VPC | list(string) | [] | no |
| existing_public_subnets | The public subnets for the existing VPC | list(string) | [] | no |
| num_zones | Number of zones to utilize for EKS nodes | number | 2 | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway or one per AZ | bool | false | no |
| create_vpc_flow_logs | Enable VPC flow logs | bool | false | no |
| flow_logs_retention | Flow logs retention in days | number | 14 | no |
| flow_log_group_class | Flow logs log group class in CloudWatch | string | "STANDARD" | no |
| flow_log_file_format | Flow logs file format | string | "parquet" | no |
| create_eks | Should we create the EKS cluster? | bool | true | no |
| cluster_endpoint_public_access | Whether to enable public access to the EKS cluster endpoint | bool | false | no |
| enable_cluster_autoscaler | Enable and install cluster-autoscaler | bool | true | no |
| worker_nodes_max | Maximum amount of worker nodes allowed | number | 10 | no |
| worker_instance_type | Instance type for EKS worker nodes | list(string) | ["m5n.xlarge"] | no |
| eks_additional_admin_roles | Additional IAM roles to add as cluster administrators | list(string) | [] | no |
| eks_additional_admin_roles_policy | IAM policy for the EKS additional admin roles | string | "AmazonEKSClusterAdminPolicy" | no |
| create_public_zone | Whether to create the public Route 53 zone | bool | false | no |
| prometheus_endpoint_config | Prometheus endpoint configuration. Required when enabled: endpoint_service_name and endpoint_service_region | object | {enabled: false, endpoint_service_name: "", endpoint_service_region: ""} | no |
| grafana_privatelink_config | Grafana privatelink configuration. Required when enabled: endpoint_allowed_principals | object | {enabled: false, endpoint_allowed_principals: []} | no |

**Note**: 
The `hyperspace_account_id` is a required variable that you need to obtain from Hyperspace support. This ID is used to pull resources from Hyperspace like AMIs and other infrastructure components.

## VPC Configuration
The module can either create a new VPC or use an existing one. By default, it creates a new VPC with the following configuration:
- CIDR block: 10.0.0.0/16 (Configurable with var.vpc_cidr)
- Public and private subnets across 2 availability zones
- NAT Gateway for private subnet internet access

You can also choose to deploy the resource to an existing VPC by providing the following inputs:
```hcl
existing_vpc_id           = "vpc-1234567890abcdef0"
existing_private_subnets  = ["subnet-1234567890abcdef0", "subnet-0987654321fedcba0"]
existing_public_subnets   = ["subnet-abcdef1234567890", "subnet-fedcba0987654321"] # (Optional)
```

**Important**: When using an existing VPC:
1. The VPC must have DNS hostnames and DNS resolution enabled
2. The private subnets must have the following tags:
   - `kubernetes.io/role/internal-elb` = "1"
3. The public subnets must have the following tags:
   - `kubernetes.io/role/elb` = "1"

## ArgoCD, Grafana & Prometheus Variables

### ArgoCD Configuration
The `argocd_config` object configures ArgoCD installation and its integration with your version control system. Required fields:
- `vcs.organization`: Your Git organization/group name
- `vcs.repository`: The repository name where your ArgoCD applications are stored
- Either `vcs.github.enabled` or `vcs.gitlab.enabled`: Set to `true` based on your VCS provider

Complete configuration example:
```hcl
argocd_config = {
  enabled = true
  privatelink = {
    enabled                     = false
    endpoint_allowed_principals = []  # List of AWS account IDs allowed to connect
    additional_aws_regions      = []  # Additional AWS regions for the endpoint service
  }
  vcs = {
    organization = "<ORG>"
    repository   = "<REPO>"
    github = {
      enabled                   = true
      github_app_enabled        = false
      github_app_secret_name    = "argocd/github_app"
      github_private_key_secret = "argocd/github_app_private_key"
    }
    gitlab = {
      enabled                 = false
      oauth_enabled           = false
      oauth_secret_name       = "argocd/gitlab_oauth"
      credentials_secret_name = "argocd/gitlab_credentials"
    }
  }
  rbac = {
    sso_admin_group        = ""  # SSO admin group name
    users_rbac_rules       = []  # List of RBAC rules for users
    users_additional_rules = []  # Additional RBAC rules
  }
}
```

### Grafana Privatelink Configuration
The `grafana_privatelink_config` object enables secure access to Grafana through AWS PrivateLink:

```hcl
grafana_privatelink_config = {
  enabled                     = false
  endpoint_allowed_principals = []  # List of AWS account IDs allowed to connect
  additional_aws_regions      = []  # Additional AWS regions for the endpoint service
}
```

### Prometheus Endpoint Configuration
The `prometheus_endpoint_config` object configures the Prometheus endpoint service:

```hcl
prometheus_endpoint_config = {
  enabled                 = false
  endpoint_service_name   = ""  # Name of the endpoint service
  endpoint_service_region = ""  # Region for the endpoint service
  additional_cidr_blocks  = []  # Additional CIDR blocks allowed to access the endpoint
}
```

## ACM Certificate Validation
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


**Important**: The CNAME must be created in a public hosted zone, not private. Ensure you include the trailing dot in the Value field.

## Privatelink
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

#### Grafana with Privatelink
```hcl
grafana_privatelink_config = {
  enabled = true
  endpoint_allowed_principals = ["123456789012"]  # AWS account IDs allowed to connect
}
```

#### Prometheus Endpoint
```hcl
prometheus_endpoint_config = {
  enabled = true
  endpoint_service_name   = "prometheus-endpoint"
  endpoint_service_region = "us-east-1"
}
```

## Access Your Infrastructure
After successful deployment, you can access:
   - ArgoCD: `https://argocd.internal-<environment>.<your-domain>`
   - Grafana: `https://grafana.internal-<environment>.<your-domain>`

**ArgoCD Initial Login**:

1. **Username**: The default admin username is `admin`

2. **Password**: Retrieve it using:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

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

### GitOps
- ArgoCD installation and SSO integration
- ECR credentials sync to gain access to private hyperspace ECR repositories