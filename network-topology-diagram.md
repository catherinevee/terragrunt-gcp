# Network Topology Diagram

This diagram shows the VPC, subnets, and security architecture for the Terragrunt AWS infrastructure.

```mermaid
graph TB
    subgraph "VPC Architecture"
        subgraph "Public Subnets"
            PUB_SUB1[Public Subnet 1<br/>us-east-1a]
            PUB_SUB2[Public Subnet 2<br/>us-east-1b]
            IGW[Internet Gateway]
            ALB[Application Load Balancer]
        end
        
        subgraph "Private Subnets"
            PRIV_SUB1[Private Subnet 1<br/>us-east-1a]
            PRIV_SUB2[Private Subnet 2<br/>us-east-1b]
            NAT[NAT Gateway]
            EKS[EKS Cluster]
            RDS[RDS Aurora]
        end
        
        subgraph "Database Subnets"
            DB_SUB1[Database Subnet 1<br/>us-east-1a]
            DB_SUB2[Database Subnet 2<br/>us-east-1b]
            RDS_PRIMARY[RDS Primary]
            RDS_REPLICA[RDS Replica]
        end
    end
    
    subgraph "Security Groups"
        ALB_SG[ALB Security Group<br/>Port 80/443]
        EKS_SG[EKS Security Group<br/>Port 443]
        RDS_SG[RDS Security Group<br/>Port 5432]
        NAT_SG[NAT Security Group<br/>Port 443]
    end
    
    subgraph "Route Tables"
        PUB_RT[Public Route Table]
        PRIV_RT[Private Route Table]
        DB_RT[Database Route Table]
    end
    
    IGW --> PUB_RT
    PUB_RT --> PUB_SUB1
    PUB_RT --> PUB_SUB2
    
    NAT --> PRIV_RT
    PRIV_RT --> PRIV_SUB1
    PRIV_RT --> PRIV_SUB2
    
    DB_RT --> DB_SUB1
    DB_RT --> DB_SUB2
    
    PUB_SUB1 --> ALB
    PUB_SUB2 --> ALB
    
    PRIV_SUB1 --> EKS
    PRIV_SUB2 --> EKS
    
    DB_SUB1 --> RDS_PRIMARY
    DB_SUB2 --> RDS_REPLICA
    
    ALB_SG --> ALB
    EKS_SG --> EKS
    RDS_SG --> RDS_PRIMARY
    RDS_SG --> RDS_REPLICA
    NAT_SG --> NAT
    
    ALB --> EKS
    EKS --> RDS_PRIMARY
    EKS --> RDS_REPLICA
```

## Network Security

- **Public Subnets**: Host load balancers and NAT gateways
- **Private Subnets**: Host application workloads (EKS)
- **Database Subnets**: Host RDS instances with no internet access
- **Security Groups**: Control traffic between components
- **Route Tables**: Manage traffic routing within VPC
- **NAT Gateway**: Provides outbound internet access for private subnets
