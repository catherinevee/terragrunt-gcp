# Architecture Documentation

This directory contains comprehensive architecture documentation for the terragrunt-gcp project, detailing system design, component relationships, and architectural decisions.

## System Overview

The terragrunt-gcp project implements a layered architecture designed for enterprise-scale Google Cloud Platform resource management with Terragrunt integration.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
├─────────────────────────────────────────────────────────────────┤
│                  Terragrunt Modules                            │
├─────────────────────────────────────────────────────────────────┤
│                  Terraform Modules                             │
├─────────────────────────────────────────────────────────────────┤
│                  Go Services Layer                             │
├─────────────────────────────────────────────────────────────────┤
│                  Google Cloud APIs                             │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Client Layer (`internal/gcp`)

The foundation layer providing secure, authenticated access to Google Cloud Platform services.

#### Key Components:
- **Client Manager** - Centralized authentication and connection management
- **Credential Handler** - Multiple authentication methods (ADC, Service Account, OAuth)
- **Connection Pool** - Efficient connection reuse and lifecycle management
- **Rate Limiter** - Quota-aware request throttling
- **Circuit Breaker** - Fault tolerance and resilience patterns

#### Architecture:
```go
type Client struct {
    ProjectID     string
    Region        string
    Zone          string
    Credentials   *google.Credentials
    HTTPClient    *http.Client
    TokenSource   oauth2.TokenSource
    Metrics       *ServiceMetrics
    RateLimiter   *RateLimiter
    CircuitBreaker *CircuitBreaker
}
```

### 2. Service Layer

Enterprise-grade service abstractions for major GCP service categories.

#### Compute Service (`compute.go`)
- **Instance Management** - Complete VM lifecycle operations
- **Disk Operations** - Persistent disk creation, attachment, snapshots
- **Image Management** - Custom image creation and management
- **Machine Type Discovery** - Dynamic machine type enumeration
- **Operation Monitoring** - Long-running operation tracking

#### Storage Service (`storage.go`)
- **Bucket Operations** - Bucket lifecycle, policies, versioning
- **Object Management** - Upload, download, streaming operations
- **Signed URLs** - Secure temporary access generation
- **Lifecycle Policies** - Automated data lifecycle management
- **IAM Integration** - Fine-grained access controls

#### Network Service (`network.go`)
- **VPC Management** - Network creation, configuration, peering
- **Subnet Operations** - Subnet creation, secondary ranges, flow logs
- **Firewall Rules** - Security rule management and validation
- **Load Balancing** - Load balancer configuration and monitoring
- **Connectivity Testing** - Network path analysis and troubleshooting

#### IAM Service (`iam.go`)
- **Service Accounts** - Identity creation and key management
- **Role Management** - Custom role creation and assignment
- **Policy Operations** - IAM policy binding and condition management
- **Access Token Generation** - Short-lived token creation for impersonation
- **Audit Integration** - Comprehensive access logging

#### Monitoring Service (`monitoring.go`)
- **Metrics Collection** - Custom and system metric ingestion
- **Alert Management** - Policy creation, notification channels
- **Dashboard Creation** - Programmatic dashboard generation
- **Log Analysis** - Advanced log querying and pattern detection
- **Anomaly Detection** - Statistical anomaly identification
- **SLO Monitoring** - Service level objective tracking

#### Secrets Service (`secrets.go`)
- **Secret Lifecycle** - Creation, versioning, rotation, destruction
- **Access Controls** - Fine-grained permission management
- **Encryption** - Customer-managed encryption key integration
- **Rotation Automation** - Automated secret rotation workflows
- **Compliance Monitoring** - Audit trails and compliance reporting

#### Utils Service (`utils.go`)
- **Validation Framework** - Configurable resource validation
- **Cost Analysis** - Resource cost calculation and optimization
- **Quota Monitoring** - Real-time quota usage tracking
- **Project Analysis** - Comprehensive project health assessment
- **Recommendation Engine** - AI-driven optimization suggestions

### 3. Error Handling System

Comprehensive error classification and handling framework.

#### Error Classification:
```go
type ErrorCode int

const (
    ErrorCodeUnknown ErrorCode = iota
    ErrorCodeInvalidArgument
    ErrorCodeDeadlineExceeded
    ErrorCodeNotFound
    ErrorCodeAlreadyExists
    ErrorCodePermissionDenied
    ErrorCodeResourceExhausted
    ErrorCodeQuotaExceeded
    ErrorCodeRateLimited
    ErrorCodeTimeout
    ErrorCodeNetworkError
    ErrorCodeCancelled
)
```

#### Error Context:
```go
type GCPError struct {
    Code          ErrorCode
    Operation     string
    Resource      string
    Message       string
    OriginalError error
    Details       map[string]interface{}
    Context       map[string]interface{}
    Timestamp     time.Time
    RequestID     string
    Retryable     bool
}
```

### 4. Retry and Resilience System

Advanced retry mechanisms with intelligent backoff strategies.

#### Retry Configuration:
```go
type RetryConfig struct {
    MaxAttempts       int
    InitialDelay      time.Duration
    MaxDelay          time.Duration
    BackoffMultiplier float64
    Jitter            float64
    MaxElapsedTime    time.Duration
}
```

#### Circuit Breaker Pattern:
```go
type CircuitBreaker struct {
    Name           string
    MaxFailures    int
    ResetTimeout   time.Duration
    State          CircuitState
    FailureCount   int
    LastFailureTime time.Time
    Metrics        *CircuitBreakerMetrics
}
```

## Data Flow Architecture

### Request Flow
```
User Request → Client → Service → GCP API
     ↓             ↓         ↓         ↓
  Validation → Auth → Transform → Execute
     ↓             ↓         ↓         ↓
   Response ← Cache ← Process ← Response
```

### Error Flow
```
GCP Error → Classification → Context → Retry Logic
    ↓              ↓            ↓          ↓
 Logging ← Metrics ← Audit ← Decision
```

### Monitoring Flow
```
Operations → Metrics → Aggregation → Alerting
     ↓          ↓          ↓           ↓
  Traces → Logs → Analysis → Dashboards
```

## Security Architecture

### Authentication Layer
- **Application Default Credentials** - Automatic credential discovery
- **Service Account Keys** - Explicit key-based authentication
- **Workload Identity** - Kubernetes service account binding
- **User Credentials** - OAuth2 flow for user impersonation

### Authorization Model
- **Role-Based Access Control** - IAM role and permission management
- **Resource-Level Permissions** - Fine-grained resource access
- **Conditional Access** - Time and IP-based access restrictions
- **Audit Logging** - Comprehensive access trail recording

### Encryption Strategy
- **Data in Transit** - TLS 1.3 for all API communications
- **Data at Rest** - Customer-managed encryption keys (CMEK)
- **Secret Management** - Secret Manager integration with rotation
- **Key Management** - Cloud KMS integration for key lifecycle

## Scalability Architecture

### Horizontal Scaling
- **Stateless Design** - No server-side state for easy scaling
- **Connection Pooling** - Efficient resource utilization
- **Load Distribution** - Request distribution across regions
- **Auto-scaling** - Dynamic resource allocation based on demand

### Vertical Scaling
- **Resource Optimization** - Intelligent resource allocation
- **Cache Optimization** - Multi-level caching strategies
- **Batch Operations** - Bulk operation support for efficiency
- **Streaming Operations** - Large data handling with streaming

### Performance Optimization
- **Caching Strategy** - Multi-tier caching with intelligent invalidation
- **Rate Limiting** - Quota-aware request throttling
- **Compression** - Data compression for bandwidth optimization
- **Parallelization** - Concurrent operation execution

## Observability Architecture

### Metrics Collection
```go
type ServiceMetrics struct {
    OperationCounters    map[string]*Counter
    OperationDurations   map[string]*Histogram
    ErrorCounters        map[string]*Counter
    CacheHitRatio        *Gauge
    ConnectionPoolStats  *GaugeVec
    RateLimitMetrics     *CounterVec
}
```

### Logging Framework
```go
type ServiceLogger struct {
    ServiceName   string
    LogLevel     string
    Format       string
    Output       io.Writer
    Fields       map[string]interface{}
    Hooks        []LogHook
}
```

### Audit System
```go
type AuditLogger struct {
    ServiceName string
    ProjectID   string
    Destination string
    Format      string
    Encryption  bool
    Retention   time.Duration
}
```

### Tracing Integration
- **Distributed Tracing** - Request flow tracking across services
- **Performance Profiling** - CPU and memory usage analysis
- **Dependency Mapping** - Service dependency visualization
- **Latency Analysis** - End-to-end latency measurement

## Configuration Management

### Environment-Based Configuration
```yaml
# Development Environment
development:
  project_id: "dev-project"
  region: "us-central1"
  zone: "us-central1-a"
  cache_enabled: true
  cache_ttl: "5m"
  rate_limit_qps: 10
  retry_attempts: 3

# Production Environment
production:
  project_id: "prod-project"
  region: "us-east1"
  zone: "us-east1-a"
  cache_enabled: true
  cache_ttl: "30m"
  rate_limit_qps: 1000
  retry_attempts: 5
  encryption_enabled: true
  audit_enabled: true
```

### Feature Flags
```go
type FeatureFlags struct {
    ExperimentalFeatures map[string]bool
    FeatureToggles      map[string]bool
    PercentageRollouts  map[string]float64
    UserTargeting       map[string][]string
}
```

## Integration Patterns

### Terragrunt Integration
```hcl
# terragrunt.hcl
terraform {
  source = "../../modules/compute/instance"
}

dependencies {
  paths = ["../network", "../iam"]
}

inputs = {
  instance_name = "web-server-${local.environment}"
  machine_type  = "e2-medium"
  zone         = "us-central1-a"

  # Custom configuration from Go services
  monitoring_config = dependency.monitoring.outputs.config
  security_config   = dependency.iam.outputs.service_account
}
```

### Terraform Module Integration
```hcl
# main.tf
module "compute_instance" {
  source = "./modules/compute/instance"

  # Configuration validated by Go services
  instance_config = var.instance_config

  # Dependencies managed by Go services
  network_config = var.network_config
  iam_config     = var.iam_config
}

# Use Go service for validation
data "external" "config_validation" {
  program = ["go", "run", "./cmd/validate", "--config", jsonencode(var.instance_config)]
}
```

## Deployment Architecture

### Multi-Environment Support
```
Development → Staging → Production
     ↓           ↓          ↓
  Testing → Integration → Validation
     ↓           ↓          ↓
  Rollback ← Monitoring → Alerting
```

### CI/CD Integration
- **Automated Testing** - Comprehensive test suite execution
- **Security Scanning** - Vulnerability and compliance checking
- **Performance Testing** - Load and stress testing validation
- **Deployment Automation** - Blue-green and canary deployments

### Infrastructure as Code
- **Version Control** - All infrastructure definitions in Git
- **State Management** - Centralized Terraform state management
- **Change Management** - Automated change approval workflows
- **Rollback Capabilities** - Automated rollback on failure detection

## Future Architecture Considerations

### Microservices Evolution
- **Service Decomposition** - Breaking monolithic services into microservices
- **Event-Driven Architecture** - Asynchronous event processing
- **API Gateway Integration** - Centralized API management
- **Service Mesh** - Advanced traffic management and security

### Cloud-Native Patterns
- **Kubernetes Integration** - Native Kubernetes resource management
- **Serverless Computing** - Function-as-a-Service integration
- **Edge Computing** - Edge location resource management
- **Multi-Cloud Support** - Cross-cloud resource orchestration

### Advanced Analytics
- **Machine Learning Integration** - AI-driven optimization
- **Predictive Analytics** - Proactive issue detection
- **Cost Optimization** - Intelligent resource right-sizing
- **Capacity Planning** - Automated capacity management

This architecture provides a solid foundation for enterprise-scale Google Cloud Platform resource management while maintaining flexibility for future evolution and enhancement.