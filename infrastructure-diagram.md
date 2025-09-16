# Complete Infrastructure Diagram

This diagram shows the comprehensive multi-region architecture for the Terragrunt AWS infrastructure.

```mermaid
graph TB
    subgraph "Multi-Region Architecture"
        subgraph "us-east-1 (Dev)"
            DEV_VPC[Dev VPC]
            DEV_EKS[Dev EKS Cluster]
            DEV_RDS[Dev RDS Aurora]
            DEV_S3[Dev S3 Buckets]
        end
        
        subgraph "us-west-2 (Staging)"
            STAGE_VPC[Staging VPC]
            STAGE_EKS[Staging EKS Cluster]
            STAGE_RDS[Staging RDS Aurora]
            STAGE_S3[Staging S3 Buckets]
        end
        
        subgraph "eu-west-1 (Prod)"
            PROD_VPC[Prod VPC]
            PROD_EKS[Prod EKS Cluster]
            PROD_RDS[Prod RDS Aurora]
            PROD_S3[Prod S3 Buckets]
        end
    end
    
    subgraph "Shared Services"
        CLOUDFRONT[CloudFront CDN]
        ROUTE53[Route 53 DNS]
        WAF[AWS WAF]
        KMS[KMS Keys]
    end
    
    subgraph "Monitoring & Security"
        CLOUDWATCH[CloudWatch]
        XRAY[X-Ray Tracing]
        SECRETS[Secrets Manager]
        IAM[IAM Roles]
    end
    
    CLOUDFRONT --> DEV_VPC
    CLOUDFRONT --> STAGE_VPC
    CLOUDFRONT --> PROD_VPC
    
    ROUTE53 --> CLOUDFRONT
    WAF --> CLOUDFRONT
    
    DEV_VPC --> DEV_EKS
    DEV_VPC --> DEV_RDS
    DEV_VPC --> DEV_S3
    
    STAGE_VPC --> STAGE_EKS
    STAGE_VPC --> STAGE_RDS
    STAGE_VPC --> STAGE_S3
    
    PROD_VPC --> PROD_EKS
    PROD_VPC --> PROD_RDS
    PROD_VPC --> PROD_S3
    
    CLOUDWATCH --> DEV_VPC
    CLOUDWATCH --> STAGE_VPC
    CLOUDWATCH --> PROD_VPC
    
    XRAY --> DEV_EKS
    XRAY --> STAGE_EKS
    XRAY --> PROD_EKS
    
    KMS --> DEV_RDS
    KMS --> STAGE_RDS
    KMS --> PROD_RDS
    
    SECRETS --> DEV_EKS
    SECRETS --> STAGE_EKS
    SECRETS --> PROD_EKS
```

## Components

- **VPCs**: Isolated network environments per environment
- **EKS Clusters**: Kubernetes clusters for containerized applications
- **RDS Aurora**: Managed PostgreSQL/MySQL databases
- **S3 Buckets**: Object storage for static assets and backups
- **CloudFront**: Global CDN for content delivery
- **Route 53**: DNS management and health checks
- **AWS WAF**: Web application firewall
- **KMS**: Encryption key management
- **CloudWatch**: Monitoring and logging
- **X-Ray**: Distributed tracing
- **Secrets Manager**: Secure credential storage
- **IAM**: Identity and access management
