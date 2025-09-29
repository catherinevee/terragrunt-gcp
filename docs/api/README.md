# API Documentation

This directory contains comprehensive API documentation for the terragrunt-gcp internal Go packages and services.

## Overview

The terragrunt-gcp project provides a robust Go library for managing Google Cloud Platform resources with enterprise-grade features including:

- **Client Management** - Secure authentication and connection handling
- **Service Abstractions** - High-level APIs for all major GCP services
- **Error Handling** - Comprehensive error classification and retry mechanisms
- **Monitoring & Observability** - Built-in metrics, logging, and tracing
- **Security** - End-to-end encryption, audit logging, and access controls
- **Performance** - Caching, rate limiting, and optimized operations

## API Structure

### Core Client (`internal/gcp`)

```go
// Primary client for all GCP operations
client, err := gcp.NewClient(ctx, &gcp.ClientConfig{
    ProjectID: "your-project-id",
    Region:    "us-central1",
    Zone:      "us-central1-a",
})
```

### Service APIs

#### Compute Service
```go
computeService, err := gcp.NewComputeService(client, computeConfig)

// Create VM instance
instance, err := computeService.CreateInstance(ctx, &gcp.InstanceConfig{
    Name:        "web-server-01",
    MachineType: "e2-medium",
    Zone:        "us-central1-a",
    BootDisk: &gcp.DiskConfig{
        SizeGB:      20,
        Type:        "pd-standard",
        SourceImage: "projects/debian-cloud/global/images/family/debian-11",
    },
    NetworkInterfaces: []*gcp.NetworkInterfaceConfig{
        {
            Network: "default",
            AccessConfigs: []*gcp.AccessConfig{
                {Type: "ONE_TO_ONE_NAT", NetworkTier: "STANDARD"},
            },
        },
    },
})
```

#### Storage Service
```go
storageService, err := gcp.NewStorageService(client, storageConfig)

// Create bucket
bucket, err := storageService.CreateBucket(ctx, &gcp.BucketConfig{
    Name:         "my-data-bucket",
    Location:     "US",
    StorageClass: "STANDARD",
    Versioning:   &gcp.VersioningConfig{Enabled: true},
    Lifecycle: &gcp.LifecycleConfig{
        Rules: []*gcp.LifecycleRule{
            {
                Action:    &gcp.LifecycleAction{Type: "Delete"},
                Condition: &gcp.LifecycleCondition{Age: 30},
            },
        },
    },
})
```

#### Network Service
```go
networkService, err := gcp.NewNetworkService(client, networkConfig)

// Create VPC network
network, err := networkService.CreateNetwork(ctx, &gcp.VPCNetworkConfig{
    Name:                  "custom-network",
    Description:           "Custom VPC for application",
    RoutingMode:          "REGIONAL",
    AutoCreateSubnetworks: false,
    MTU:                  1460,
})

// Create subnet
subnet, err := networkService.CreateSubnet(ctx, &gcp.SubnetworkConfig{
    Name:                        "app-subnet",
    Network:                     "custom-network",
    IPCidrRange:                 "10.0.0.0/24",
    Region:                      "us-central1",
    EnablePrivateIPGoogleAccess: true,
    EnableFlowLogs:              true,
})
```

#### IAM Service
```go
iamService, err := gcp.NewIAMService(client, iamConfig)

// Create service account
serviceAccount, err := iamService.CreateServiceAccount(ctx, &gcp.ServiceAccountConfig{
    AccountID:   "app-service-account",
    DisplayName: "Application Service Account",
    Description: "Service account for application workloads",
    Project:     "your-project-id",
})

// Create custom role
role, err := iamService.CreateCustomRole(ctx, &gcp.CustomRoleConfig{
    RoleID:      "app_operator",
    Title:       "Application Operator",
    Description: "Custom role for application operations",
    Permissions: []string{
        "compute.instances.get",
        "compute.instances.list",
        "storage.objects.get",
        "storage.objects.list",
    },
    Stage:   "GA",
    Project: "your-project-id",
})
```

#### Monitoring Service
```go
monitoringService, err := gcp.NewMonitoringService(client, monitoringConfig)

// Create alert policy
alertPolicy, err := monitoringService.CreateAlertPolicy(ctx, &gcp.AlertPolicyConfig{
    DisplayName: "High CPU Usage Alert",
    Conditions: []*gcp.AlertCondition{
        {
            DisplayName: "CPU Usage > 80%",
            ConditionThreshold: &gcp.MetricThreshold{
                Filter:         `resource.type="gce_instance"`,
                Comparison:     "COMPARISON_GREATER_THAN",
                ThresholdValue: 0.8,
                Duration:       300 * time.Second,
            },
        },
    },
    Enabled: true,
})

// Query metrics
result, err := monitoringService.QueryMetrics(ctx, &gcp.MetricQuery{
    Filter: `resource.type="gce_instance" metric.type="compute.googleapis.com/instance/cpu/utilization"`,
    Interval: &gcp.TimeInterval{
        StartTime: time.Now().Add(-time.Hour),
        EndTime:   time.Now(),
    },
})
```

#### Secrets Service
```go
secretsService, err := gcp.NewSecretsService(client, secretsConfig)

// Create secret
secret, err := secretsService.CreateSecret(ctx, &gcp.SecretConfig{
    SecretID:    "database-password",
    DisplayName: "Database Password",
    Description: "Password for application database",
    Replication: &gcp.ReplicationConfig{
        Policy: "automatic",
    },
    Rotation: &gcp.RotationConfig{
        RotationPeriod: 90 * 24 * time.Hour,
    },
})

// Add secret version
version, err := secretsService.AddSecretVersion(ctx, secret.Name, &gcp.SecretVersionConfig{
    Payload: &gcp.SecretPayload{
        Data: []byte("super-secure-password"),
    },
    State: "ENABLED",
})
```

#### Utils Service
```go
utilsService, err := gcp.NewUtilsService(client, utilsConfig)

// Validate resource configuration
result, err := utilsService.ValidateResource(ctx, instanceConfig, []gcp.ValidationRule{
    {
        Field:     "Name",
        Type:      "string",
        Required:  true,
        MinLength: 3,
        MaxLength: 50,
        Pattern:   `^[a-zA-Z0-9-]+$`,
    },
})

// Get project information
projectInfo, err := utilsService.GetProjectInfo(ctx, "your-project-id")

// Generate recommendations
recommendations, err := utilsService.GenerateRecommendations(ctx, "your-project-id")
```

## Configuration

### Client Configuration
```go
type ClientConfig struct {
    ProjectID         string
    Region           string
    Zone             string
    CredentialsPath  string
    UserAgent        string
    Timeout          time.Duration
    RetryAttempts    int
    RetryDelay       time.Duration
    RateLimitQPS     float64
    RateLimitBurst   int
    MetricsEnabled   bool
    AuditEnabled     bool
    LogLevel         string
}
```

### Service-Specific Configurations

Each service has its own detailed configuration structure allowing fine-grained control over:

- **Caching** - TTL settings, cache sizes, and invalidation policies
- **Retry Logic** - Backoff strategies, retry attempts, and timeout settings
- **Monitoring** - Metrics collection, audit logging, and observability
- **Security** - Encryption settings, access controls, and compliance features
- **Performance** - Concurrency limits, rate limiting, and optimization settings

## Error Handling

The library provides comprehensive error handling with structured error types:

```go
if err != nil {
    if gcpErr, ok := err.(*gcp.GCPError); ok {
        switch gcpErr.Code {
        case gcp.ErrorCodeNotFound:
            // Handle resource not found
        case gcp.ErrorCodePermissionDenied:
            // Handle permission errors
        case gcp.ErrorCodeQuotaExceeded:
            // Handle quota limits
        case gcp.ErrorCodeRateLimited:
            // Handle rate limiting
        default:
            // Handle other errors
        }
    }
}

// Check for specific error types
if gcp.IsRetryableError(err) {
    // Implement retry logic
}

if gcp.IsTimeoutError(err) {
    // Handle timeout scenarios
}
```

## Advanced Features

### Caching
All services support intelligent caching with configurable TTL and automatic invalidation.

### Rate Limiting
Built-in rate limiting prevents API quota exhaustion with configurable QPS and burst limits.

### Circuit Breakers
Automatic circuit breaker patterns prevent cascading failures and improve resilience.

### Metrics & Monitoring
Comprehensive metrics collection for all operations with Prometheus-compatible exports.

### Audit Logging
Complete audit trails for all operations with structured logging and compliance support.

### Security
End-to-end encryption, secure credential management, and comprehensive access controls.

## Best Practices

### Resource Management
```go
// Always use defer for cleanup
defer client.Close()

// Use contexts for cancellation
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
defer cancel()

// Handle errors appropriately
if err := operation(); err != nil {
    if gcp.IsRetryableError(err) {
        // Implement retry with backoff
    } else {
        // Log error and fail gracefully
    }
}
```

### Configuration Management
```go
// Use environment-specific configurations
config := &gcp.ClientConfig{
    ProjectID: os.Getenv("GCP_PROJECT_ID"),
    Region:    os.Getenv("GCP_REGION"),
    Zone:      os.Getenv("GCP_ZONE"),
}

// Validate configurations
if err := config.Validate(); err != nil {
    log.Fatalf("Invalid configuration: %v", err)
}

// Set appropriate defaults
config.SetDefaults()
```

### Performance Optimization
```go
// Enable caching for frequently accessed resources
config.CacheEnabled = true
config.CacheTTL = 30 * time.Minute

// Configure appropriate rate limits
config.RateLimitQPS = 100
config.RateLimitBurst = 200

// Use batch operations when available
results, err := service.BatchOperation(ctx, requests)
```

## API Reference

For detailed API reference documentation, see the individual service documentation files:

- [Client API](client.md) - Core client functionality
- [Compute API](compute.md) - Compute Engine operations
- [Storage API](storage.md) - Cloud Storage operations
- [Network API](network.md) - VPC and networking operations
- [IAM API](iam.md) - Identity and access management
- [Monitoring API](monitoring.md) - Monitoring and alerting
- [Secrets API](secrets.md) - Secret management
- [Utils API](utils.md) - Utility functions and helpers

## Examples

See the [examples directory](../examples/) for complete working examples demonstrating various use cases and integration patterns.

## Support

For questions, issues, or contributions, please refer to the main project documentation and contribution guidelines.