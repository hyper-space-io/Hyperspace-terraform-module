# Hyperspace Infrastructure Terraform Module

## Overview

This Terraform module provides a complete infrastructure setup for the Hyperspace project, including EKS cluster deployment, networking, security configurations, and various application components. The module is split into two main parts:
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
- AWS CLI configured with appropriate credentials
- kubectl installed
- Helm 3.x
- AWS account with appropriate permissions
- Domain name (optional, for Route53 setup)

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
│ └── locals.tf # Local variables
└── app-module/
├── argocd.tf # ArgoCD installation
├── loki.tf # Logging stack
├── velero.tf # Backup solution
├── Route53.tf # DNS configuration
├── variables.tf # Input variables
└── providers.tf # Provider configuration
```


### Infrastructure Module Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Name of the project | string | "hyperspace" | no |
| environment | Deployment environment | string | "development" | no |
| aws_region | AWS region | string | "us-east-1" | no |
| worker_nodes_max | Maximum number of worker nodes | number | - | yes |
| worker_instance_type | List of allowed instance types | list(string) | ["m5n.xlarge"] | no |
| vpc_cidr | CIDR block for VPC | string | - | yes |
| availability_zones | List of AZs | list(string) | [] | no |
| create_vpc_flow_logs | Enable VPC flow logs | bool | false | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway | bool | false | no |

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

## Features

### EKS Cluster
- Managed node groups with Bottlerocket OS
- Self-managed node groups for specialized workloads
- Cluster autoscaling
- IRSA (IAM Roles for Service Accounts)
- EBS CSI Driver integration
- VPC CNI plugin
- CoreDNS
- Kube-proxy

### Networking
- VPC with public and private subnets
- NAT Gateways
- VPC Endpoints
- Internal and external ALB ingress controllers
- Network policies
- VPC flow logs (optional)

### Security
- Network policies
- Security groups
- KMS encryption for secrets
- IAM roles and policies
- OIDC integration
- AWS Secrets Manager integration
- TLS termination

### Monitoring and Logging
- Prometheus and Grafana
- Loki for log aggregation
- OpenTelemetry for observability
- CloudWatch integration
- Core dump handling

### Backup and Disaster Recovery
- Velero for cluster backup
- S3 buckets for backup storage
- Cross-region replication support
- EBS volume snapshots

### GitOps and CI/CD
- ArgoCD installation
- External Secrets Operator
- ECR credentials sync
- Terraform Cloud Agent

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
- VPC CNI plugin
- CoreDNS
- Kube-proxy

### Networking
- VPC with public and private subnets
- NAT Gateways
- VPC Endpoints
- Internal and external ALB ingress controllers
- Network policies
- VPC flow logs (optional)

### Security
- Network policies
- Security groups
- KMS encryption for secrets
- IAM roles and policies
- OIDC integration
- AWS Secrets Manager integration
- TLS termination

### Monitoring and Logging
- Prometheus and Grafana
- Loki for log aggregation
- OpenTelemetry for observability
- CloudWatch integration
- Core dump handling

### Backup and Disaster Recovery
- Velero for cluster backup
- S3 buckets for backup storage
- Cross-region replication support
- EBS volume snapshots

### GitOps and CI/CD
- ArgoCD installation
- External Secrets Operator
- ECR credentials sync
- Terraform Cloud Agent

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
