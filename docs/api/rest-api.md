# REST API Reference

DriftMgr provides a comprehensive REST API for programmatic access to all features. This document covers all available endpoints, request/response formats, and authentication methods.

## Base URL

```
http://localhost:8080/api/v1
```

## Authentication

DriftMgr supports multiple authentication methods:

### API Key Authentication

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/health
```

### JWT Token Authentication

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:8080/api/v1/health
```

### Basic Authentication

```bash
curl -u username:password \
  http://localhost:8080/api/v1/health
```

## Common Response Formats

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed successfully"
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request parameters",
    "details": { ... }
  }
}
```

### Paginated Response

```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

## Core Endpoints

### Health Check

#### GET /health

Check the health status of the DriftMgr service.

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "version": "latest",
    "uptime": "2h30m15s",
    "services": {
      "database": "healthy",
      "providers": {
        "aws": "healthy",
        "azure": "healthy",
        "gcp": "healthy"
      }
    }
  }
}
```

### Drift Detection

#### POST /drift/detect

Start a drift detection scan.

**Request Body:**
```json
{
  "provider": "aws",
  "region": "us-east-1",
  "scan_type": "quick",
  "options": {
    "include_deleted": false,
    "parallel_workers": 10
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "scan_id": "scan_123456789",
    "status": "started",
    "estimated_duration": "2m30s"
  }
}
```

#### GET /drift/scans

List all drift detection scans.

**Query Parameters:**
- `page` (int): Page number (default: 1)
- `per_page` (int): Items per page (default: 20)
- `status` (string): Filter by status
- `provider` (string): Filter by provider

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "scan_id": "scan_123456789",
      "provider": "aws",
      "region": "us-east-1",
      "status": "completed",
      "started_at": "2025-09-23T10:00:00Z",
      "completed_at": "2025-09-23T10:02:30Z",
      "drift_count": 5
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 1,
    "total_pages": 1
  }
}
```

#### GET /drift/scans/{scan_id}

Get details of a specific drift detection scan.

**Response:**
```json
{
  "success": true,
  "data": {
    "scan_id": "scan_123456789",
    "provider": "aws",
    "region": "us-east-1",
    "status": "completed",
    "started_at": "2025-09-23T10:00:00Z",
    "completed_at": "2025-09-23T10:02:30Z",
    "drift_count": 5,
    "drifts": [
      {
        "drift_id": "drift_001",
        "resource_type": "aws_s3_bucket",
        "resource_id": "my-bucket",
        "severity": "medium",
        "drift_type": "configuration",
        "detected_at": "2025-09-23T10:01:15Z"
      }
    ]
  }
}
```

### Drift Results

#### GET /drift/results

List drift detection results.

**Query Parameters:**
- `page` (int): Page number
- `per_page` (int): Items per page
- `severity` (string): Filter by severity
- `resource_type` (string): Filter by resource type
- `status` (string): Filter by status

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "drift_id": "drift_001",
      "scan_id": "scan_123456789",
      "resource_type": "aws_s3_bucket",
      "resource_id": "my-bucket",
      "severity": "medium",
      "drift_type": "configuration",
      "status": "detected",
      "detected_at": "2025-09-23T10:01:15Z",
      "details": {
        "expected": { ... },
        "actual": { ... }
      }
    }
  ],
  "pagination": { ... }
}
```

#### GET /drift/results/{drift_id}

Get detailed information about a specific drift result.

**Response:**
```json
{
  "success": true,
  "data": {
    "drift_id": "drift_001",
    "scan_id": "scan_123456789",
    "resource_type": "aws_s3_bucket",
    "resource_id": "my-bucket",
    "severity": "medium",
    "drift_type": "configuration",
    "status": "detected",
    "detected_at": "2025-09-23T10:01:15Z",
    "details": {
      "expected": {
        "versioning": {
          "enabled": true
        }
      },
      "actual": {
        "versioning": {
          "enabled": false
        }
      }
    },
    "remediation": {
      "available": true,
      "strategies": ["terraform_apply", "manual_review"]
    }
  }
}
```

### Remediation

#### POST /remediation/jobs

Create a new remediation job.

**Request Body:**
```json
{
  "drift_id": "drift_001",
  "strategy": "terraform_apply",
  "auto_approve": false,
  "options": {
    "dry_run": true,
    "timeout": "10m"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "job_id": "job_123456789",
    "drift_id": "drift_001",
    "strategy": "terraform_apply",
    "status": "pending_approval",
    "created_at": "2025-09-23T10:05:00Z"
  }
}
```

#### GET /remediation/jobs

List remediation jobs.

**Query Parameters:**
- `page` (int): Page number
- `per_page` (int): Items per page
- `status` (string): Filter by status
- `strategy` (string): Filter by strategy

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "job_id": "job_123456789",
      "drift_id": "drift_001",
      "strategy": "terraform_apply",
      "status": "completed",
      "created_at": "2025-09-23T10:05:00Z",
      "completed_at": "2025-09-23T10:07:30Z"
    }
  ],
  "pagination": { ... }
}
```

#### POST /remediation/jobs/{job_id}/approve

Approve a pending remediation job.

**Response:**
```json
{
  "success": true,
  "data": {
    "job_id": "job_123456789",
    "status": "approved",
    "approved_at": "2025-09-23T10:06:00Z"
  }
}
```

#### POST /remediation/jobs/{job_id}/execute

Execute a remediation job.

**Response:**
```json
{
  "success": true,
  "data": {
    "job_id": "job_123456789",
    "status": "executing",
    "started_at": "2025-09-23T10:07:00Z"
  }
}
```

### State Management

#### GET /state/files

List Terraform state files.

**Query Parameters:**
- `backend_type` (string): Filter by backend type
- `provider` (string): Filter by provider

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "file_id": "state_001",
      "backend_type": "s3",
      "backend_config": {
        "bucket": "my-terraform-state",
        "key": "prod/terraform.tfstate"
      },
      "provider": "aws",
      "resource_count": 25,
      "last_updated": "2025-09-23T09:30:00Z"
    }
  ]
}
```

#### GET /state/files/{file_id}

Get details of a specific state file.

**Response:**
```json
{
  "success": true,
  "data": {
    "file_id": "state_001",
    "backend_type": "s3",
    "backend_config": {
      "bucket": "my-terraform-state",
      "key": "prod/terraform.tfstate"
    },
    "provider": "aws",
    "resource_count": 25,
    "last_updated": "2025-09-23T09:30:00Z",
    "resources": [
      {
        "type": "aws_s3_bucket",
        "name": "my_bucket",
        "id": "my-bucket",
        "attributes": { ... }
      }
    ]
  }
}
```

#### POST /state/files/{file_id}/import

Import a resource into the state file.

**Request Body:**
```json
{
  "resource_type": "aws_s3_bucket",
  "resource_name": "imported_bucket",
  "resource_id": "imported-bucket-123",
  "attributes": {
    "bucket": "imported-bucket-123"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "import_id": "import_123456789",
    "status": "completed",
    "imported_at": "2025-09-23T10:10:00Z"
  }
}
```

### Discovery

#### POST /discovery/scan

Start a resource discovery scan.

**Request Body:**
```json
{
  "provider": "aws",
  "account_id": "123456789012",
  "region": "us-east-1",
  "services": ["ec2", "s3", "rds"],
  "options": {
    "include_deleted": false,
    "parallel_workers": 5
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "scan_id": "discovery_123456789",
    "status": "started",
    "estimated_duration": "5m"
  }
}
```

#### GET /discovery/resources

List discovered resources.

**Query Parameters:**
- `provider` (string): Filter by provider
- `resource_type` (string): Filter by resource type
- `region` (string): Filter by region

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "resource_id": "res_001",
      "provider": "aws",
      "resource_type": "aws_s3_bucket",
      "resource_name": "my-bucket",
      "region": "us-east-1",
      "account_id": "123456789012",
      "discovered_at": "2025-09-23T10:00:00Z",
      "tags": {
        "Environment": "production",
        "Owner": "team-a"
      }
    }
  ],
  "pagination": { ... }
}
```

### Analytics

#### GET /analytics/dashboard

Get analytics dashboard data.

**Query Parameters:**
- `time_range` (string): Time range (1h, 24h, 7d, 30d)
- `provider` (string): Filter by provider

**Response:**
```json
{
  "success": true,
  "data": {
    "summary": {
      "total_resources": 150,
      "drift_count": 12,
      "remediation_jobs": 8,
      "compliance_score": 85
    },
    "trends": {
      "drift_detection": [
        { "timestamp": "2025-09-23T09:00:00Z", "count": 5 },
        { "timestamp": "2025-09-23T10:00:00Z", "count": 7 }
      ]
    },
    "top_drift_types": [
      { "type": "configuration", "count": 8 },
      { "type": "deletion", "count": 4 }
    ]
  }
}
```

#### GET /analytics/reports

Generate analytics reports.

**Query Parameters:**
- `report_type` (string): Report type (compliance, drift, cost)
- `format` (string): Output format (json, csv, pdf)
- `start_date` (string): Start date (ISO 8601)
- `end_date` (string): End date (ISO 8601)

**Response:**
```json
{
  "success": true,
  "data": {
    "report_id": "report_123456789",
    "report_type": "compliance",
    "format": "pdf",
    "status": "generating",
    "estimated_completion": "2025-09-23T10:15:00Z"
  }
}
```

## Error Codes

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Validation Error
- `429` - Rate Limited
- `500` - Internal Server Error

### Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Request validation failed |
| `AUTHENTICATION_ERROR` | Authentication failed |
| `AUTHORIZATION_ERROR` | Insufficient permissions |
| `RESOURCE_NOT_FOUND` | Requested resource not found |
| `CONFLICT_ERROR` | Resource conflict |
| `RATE_LIMIT_EXCEEDED` | Rate limit exceeded |
| `PROVIDER_ERROR` | Cloud provider error |
| `INTERNAL_ERROR` | Internal server error |

## Rate Limiting

DriftMgr implements rate limiting to ensure fair usage:

- **Default**: 1000 requests per hour per API key
- **Burst**: 100 requests per minute
- **Headers**: Rate limit information in response headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## SDKs and Libraries

### Go SDK

```go
package main

import (
    "github.com/catherinevee/driftmgr-sdk-go"
)

func main() {
    client := driftmgr.NewClient("http://localhost:8080", "your-api-key")
    
    // Start drift detection
    scan, err := client.Drift.Detect(&driftmgr.DetectRequest{
        Provider: "aws",
        Region:   "us-east-1",
        ScanType: "quick",
    })
    
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("Scan started: %s\n", scan.ScanID)
}
```

### Python SDK

```python
import driftmgr

client = driftmgr.Client(
    base_url="http://localhost:8080",
    api_key="your-api-key"
)

# Start drift detection
scan = client.drift.detect(
    provider="aws",
    region="us-east-1",
    scan_type="quick"
)

print(f"Scan started: {scan.scan_id}")
```

### JavaScript SDK

```javascript
const DriftMgr = require('driftmgr-sdk-js');

const client = new DriftMgr.Client({
    baseUrl: 'http://localhost:8080',
    apiKey: 'your-api-key'
});

// Start drift detection
client.drift.detect({
    provider: 'aws',
    region: 'us-east-1',
    scanType: 'quick'
}).then(scan => {
    console.log(`Scan started: ${scan.scanId}`);
});
```

## Webhooks

DriftMgr supports webhooks for real-time notifications:

### Configure Webhook

```json
{
  "url": "https://your-app.com/webhooks/driftmgr",
  "events": ["drift.detected", "remediation.completed"],
  "secret": "your-webhook-secret"
}
```

### Webhook Payload

```json
{
  "event": "drift.detected",
  "timestamp": "2025-09-23T10:00:00Z",
  "data": {
    "drift_id": "drift_001",
    "resource_type": "aws_s3_bucket",
    "severity": "medium"
  }
}
```

## Examples

### Complete Drift Detection Workflow

```bash
# 1. Start drift detection
curl -X POST http://localhost:8080/api/v1/drift/detect \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "aws",
    "region": "us-east-1",
    "scan_type": "quick"
  }'

# 2. Check scan status
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/drift/scans/scan_123456789

# 3. List drift results
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8080/api/v1/drift/results

# 4. Create remediation job
curl -X POST http://localhost:8080/api/v1/remediation/jobs \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "drift_id": "drift_001",
    "strategy": "terraform_apply",
    "auto_approve": false
  }'
```

## Next Steps

- **[Authentication Guide](authentication.md)** - Detailed authentication setup
- **[Rate Limiting Guide](rate-limiting.md)** - Rate limiting policies
- **[Error Handling Guide](error-codes.md)** - Error handling best practices
- **[Webhooks Guide](webhooks.md)** - Webhook configuration and usage
