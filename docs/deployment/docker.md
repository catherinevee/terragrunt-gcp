# Docker Deployment Guide

This guide covers deploying DriftMgr using Docker containers, including single-container deployments, Docker Compose setups, and production configurations.

## Prerequisites

- Docker 20.10+ installed
- Docker Compose 2.0+ (for multi-container setups)
- At least 4GB RAM available
- 10GB free disk space

## Quick Start

### Single Container Deployment

```bash
# Pull the latest image
docker pull catherinevee/driftmgr:latest

# Run DriftMgr
docker run -d \
  --name driftmgr \
  -p 8080:8080 \
  -v ~/.aws:/root/.aws \
  -v ~/.driftmgr:/root/.driftmgr \
  catherinevee/driftmgr:latest
```

### Docker Compose Deployment

```yaml
# docker-compose.yml
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    container_name: driftmgr
    ports:
      - "8080:8080"
    volumes:
      - ~/.aws:/root/.aws:ro
      - ~/.driftmgr:/root/.driftmgr
      - ./config:/app/config:ro
    environment:
      - DRIFTMGR_CONFIG_PATH=/app/config/config.yaml
      - DRIFTMGR_LOG_LEVEL=info
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

```bash
# Start with Docker Compose
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f driftmgr
```

## Production Deployment

### Multi-Service Setup

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  # DriftMgr API Server
  driftmgr-api:
    image: catherinevee/driftmgr:latest
    container_name: driftmgr-api
    ports:
      - "8080:8080"
    volumes:
      - ~/.aws:/root/.aws:ro
      - ~/.azure:/root/.azure:ro
      - ~/.gcp:/root/.gcp:ro
      - ./config:/app/config:ro
      - driftmgr-data:/app/data
    environment:
      - DRIFTMGR_CONFIG_PATH=/app/config/config.yaml
      - DRIFTMGR_DATABASE_URL=postgres://driftmgr:password@postgres:5432/driftmgr
      - DRIFTMGR_REDIS_URL=redis://redis:6379
      - DRIFTMGR_LOG_LEVEL=info
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    networks:
      - driftmgr-network

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: driftmgr-postgres
    environment:
      - POSTGRES_DB=driftmgr
      - POSTGRES_USER=driftmgr
      - POSTGRES_PASSWORD=secure_password_here
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    restart: unless-stopped
    networks:
      - driftmgr-network

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: driftmgr-redis
    command: redis-server --appendonly yes --requirepass secure_redis_password
    volumes:
      - redis-data:/data
    restart: unless-stopped
    networks:
      - driftmgr-network

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: driftmgr-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - driftmgr-api
    restart: unless-stopped
    networks:
      - driftmgr-network

volumes:
  postgres-data:
  redis-data:
  driftmgr-data:

networks:
  driftmgr-network:
    driver: bridge
```

### Nginx Configuration

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream driftmgr {
        server driftmgr-api:8080;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

        # Rate limiting
        limit_req zone=api burst=20 nodelay;

        location / {
            proxy_pass http://driftmgr;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check endpoint
        location /health {
            proxy_pass http://driftmgr/health;
            access_log off;
        }
    }
}
```

## Configuration

### Environment Variables

```bash
# Core Configuration
DRIFTMGR_CONFIG_PATH=/app/config/config.yaml
DRIFTMGR_LOG_LEVEL=info
DRIFTMGR_DEBUG=false

# Database Configuration
DRIFTMGR_DATABASE_URL=postgres://user:pass@host:port/db
DRIFTMGR_DATABASE_MAX_CONNECTIONS=100
DRIFTMGR_DATABASE_SSL_MODE=require

# Redis Configuration
DRIFTMGR_REDIS_URL=redis://host:port
DRIFTMGR_REDIS_PASSWORD=password
DRIFTMGR_REDIS_DB=0

# Server Configuration
DRIFTMGR_HOST=0.0.0.0
DRIFTMGR_PORT=8080
DRIFTMGR_TLS_CERT=/app/ssl/cert.pem
DRIFTMGR_TLS_KEY=/app/ssl/key.pem

# Authentication
DRIFTMGR_JWT_SECRET=your-jwt-secret
DRIFTMGR_AUTH_ENABLED=true
DRIFTMGR_AUTH_PROVIDER=ldap

# Cloud Provider Credentials
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1

AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
AZURE_TENANT_ID=your-tenant-id

GCP_PROJECT_ID=your-project-id
GCP_CREDENTIALS_FILE=/app/credentials/gcp.json
```

### Configuration File

```yaml
# config/config.yaml
server:
  host: "0.0.0.0"
  port: 8080
  tls:
    enabled: false
    cert_file: "/app/ssl/cert.pem"
    key_file: "/app/ssl/key.pem"

database:
  url: "postgres://driftmgr:password@postgres:5432/driftmgr"
  max_connections: 100
  ssl_mode: "require"
  migrations_path: "/app/migrations"

redis:
  url: "redis://redis:6379"
  password: "secure_redis_password"
  db: 0
  pool_size: 10

auth:
  enabled: true
  provider: "jwt"
  jwt_secret: "your-jwt-secret"
  session_timeout: "24h"

providers:
  aws:
    enabled: true
    regions: ["us-east-1", "us-west-2"]
    credentials:
      type: "env"  # env, file, iam
  azure:
    enabled: true
    subscriptions: ["subscription-id"]
    credentials:
      type: "env"
  gcp:
    enabled: true
    projects: ["project-id"]
    credentials:
      type: "file"
      path: "/app/credentials/gcp.json"

detection:
  schedule: "0 */6 * * *"
  quick_scan_timeout: "30s"
  full_scan_timeout: "10m"
  parallel_workers: 10

remediation:
  auto_approve: false
  strategies:
    - "terraform_apply"
    - "terraform_import"
    - "manual_review"

logging:
  level: "info"
  format: "json"
  output: "stdout"
  file:
    enabled: false
    path: "/app/logs/driftmgr.log"
    max_size: "100MB"
    max_backups: 5
    max_age: 30

monitoring:
  metrics:
    enabled: true
    path: "/metrics"
  health:
    enabled: true
    path: "/health"
  tracing:
    enabled: false
    jaeger_endpoint: "http://jaeger:14268/api/traces"
```

## Security Considerations

### Container Security

```dockerfile
# Use non-root user
FROM alpine:latest
RUN adduser -D -s /bin/sh driftmgr
USER driftmgr

# Use specific image tags
FROM catherinevee/driftmgr:v1.2.3

# Scan for vulnerabilities
RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

### Secrets Management

```yaml
# docker-compose.yml with secrets
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    secrets:
      - db_password
      - jwt_secret
      - aws_credentials
    environment:
      - DRIFTMGR_DATABASE_PASSWORD_FILE=/run/secrets/db_password
      - DRIFTMGR_JWT_SECRET_FILE=/run/secrets/jwt_secret

secrets:
  db_password:
    file: ./secrets/db_password.txt
  jwt_secret:
    file: ./secrets/jwt_secret.txt
  aws_credentials:
    file: ./secrets/aws_credentials.json
```

### Network Security

```yaml
# docker-compose.yml with network isolation
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    networks:
      - frontend
      - backend
    ports:
      - "8080:8080"

  postgres:
    image: postgres:15-alpine
    networks:
      - backend
    # No ports exposed to host

  redis:
    image: redis:7-alpine
    networks:
      - backend
    # No ports exposed to host

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

## Monitoring & Logging

### Logging Configuration

```yaml
# docker-compose.yml with logging
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    environment:
      - DRIFTMGR_LOG_LEVEL=info
      - DRIFTMGR_LOG_FORMAT=json

  # ELK Stack for log aggregation
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.5.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro

  kibana:
    image: docker.elastic.co/kibana/kibana:8.5.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200

volumes:
  elasticsearch-data:
```

### Health Checks

```yaml
# docker-compose.yml with health checks
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  postgres:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U driftmgr"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Backup & Recovery

### Database Backup

```bash
#!/bin/bash
# backup.sh

# Create backup
docker exec driftmgr-postgres pg_dump -U driftmgr driftmgr > backup_$(date +%Y%m%d_%H%M%S).sql

# Compress backup
gzip backup_$(date +%Y%m%d_%H%M%S).sql

# Upload to S3
aws s3 cp backup_$(date +%Y%m%d_%H%M%S).sql.gz s3://your-backup-bucket/
```

### Volume Backup

```yaml
# docker-compose.yml with backup service
version: '3.8'

services:
  backup:
    image: alpine:latest
    volumes:
      - postgres-data:/data/postgres:ro
      - redis-data:/data/redis:ro
      - ./backups:/backups
    command: |
      sh -c "
        tar -czf /backups/postgres_$(date +%Y%m%d_%H%M%S).tar.gz -C /data postgres &&
        tar -czf /backups/redis_$(date +%Y%m%d_%H%M%S).tar.gz -C /data redis &&
        find /backups -name '*.tar.gz' -mtime +7 -delete
      "
    restart: "no"
```

## Troubleshooting

### Common Issues

#### Container Won't Start

```bash
# Check container logs
docker logs driftmgr

# Check container status
docker ps -a

# Check resource usage
docker stats driftmgr
```

#### Database Connection Issues

```bash
# Test database connectivity
docker exec driftmgr-postgres pg_isready -U driftmgr

# Check database logs
docker logs driftmgr-postgres

# Connect to database
docker exec -it driftmgr-postgres psql -U driftmgr -d driftmgr
```

#### Performance Issues

```bash
# Check resource usage
docker stats

# Check container health
docker inspect driftmgr | grep Health

# Monitor logs
docker logs -f driftmgr
```

### Debug Mode

```yaml
# docker-compose.debug.yml
version: '3.8'

services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    environment:
      - DRIFTMGR_DEBUG=true
      - DRIFTMGR_LOG_LEVEL=debug
    volumes:
      - ./debug-config:/app/config:ro
    command: ["driftmgr", "server", "--debug"]
```

## Production Checklist

- [ ] Use specific image tags (not `latest`)
- [ ] Configure proper secrets management
- [ ] Set up SSL/TLS certificates
- [ ] Configure reverse proxy (Nginx)
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Set up backup and recovery
- [ ] Configure health checks
- [ ] Set resource limits
- [ ] Configure network security
- [ ] Set up auto-scaling
- [ ] Configure update strategy

## Next Steps

- **[Kubernetes Deployment](kubernetes.md)** - Deploy on Kubernetes
- **[Production Setup](production.md)** - Production deployment guide
- **[Monitoring Setup](monitoring.md)** - Monitoring and observability
- **[Backup & Recovery](backup-recovery.md)** - Backup strategies
