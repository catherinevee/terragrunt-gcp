# Simple Infrastructure Overview

This diagram shows the core components and data flow for the Terragrunt AWS infrastructure.

```mermaid
graph LR
    subgraph "Core Infrastructure"
        VPC[VPC]
        SUBNETS[Subnets]
        IGW[Internet Gateway]
        NAT[NAT Gateway]
        ALB[Application Load Balancer]
        EKS[EKS Cluster]
        RDS[RDS Aurora]
        S3[S3 Buckets]
    end
    
    subgraph "Security & Monitoring"
        SG[Security Groups]
        IAM[IAM Roles]
        CW[CloudWatch]
        KMS[KMS Keys]
    end
    
    subgraph "External Access"
        USERS[Users]
        CDN[CloudFront CDN]
    end
    
    USERS --> CDN
    CDN --> ALB
    ALB --> EKS
    EKS --> RDS
    EKS --> S3
    
    VPC --> SUBNETS
    VPC --> IGW
    VPC --> NAT
    VPC --> ALB
    VPC --> EKS
    VPC --> RDS
    
    SG --> EKS
    SG --> RDS
    SG --> ALB
    
    IAM --> EKS
    IAM --> RDS
    IAM --> S3
    
    CW --> EKS
    CW --> RDS
    CW --> ALB
    
    KMS --> RDS
    KMS --> S3
```

## Data Flow

1. **Users** access the application through **CloudFront CDN**
2. **CloudFront** routes requests to **Application Load Balancer**
3. **ALB** distributes traffic to **EKS Cluster** pods
4. **EKS** applications connect to **RDS Aurora** for data
5. **EKS** applications store files in **S3 Buckets**
6. **Security Groups** control network access
7. **IAM Roles** manage permissions
8. **CloudWatch** monitors all components
9. **KMS** encrypts data at rest
