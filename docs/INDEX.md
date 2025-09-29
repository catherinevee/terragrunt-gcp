# DriftMgr Documentation Index

Welcome to the DriftMgr documentation! This index provides quick access to all documentation sections.

## 🚀 Quick Start

- **[Getting Started](user-guide/getting-started.md)** - New to DriftMgr? Start here!
- **[Installation Guide](user-guide/installation.md)** - Install DriftMgr on your system
- **[CLI Reference](user-guide/cli-reference.md)** - Complete command reference

## 📖 User Documentation

### User Guide
- [Getting Started](user-guide/getting-started.md) - Quick start guide
- [Installation](user-guide/installation.md) - Installation instructions
- [Configuration](user-guide/configuration.md) - Configuration options
- [CLI Reference](user-guide/cli-reference.md) - Command reference
- [Web Dashboard](user-guide/web-dashboard.md) - Web interface guide
- [Troubleshooting](user-guide/troubleshooting.md) - Common issues and solutions

### API Documentation
- [REST API Reference](api/rest-api.md) - Complete API documentation
- [Authentication](api/authentication.md) - API authentication
- [Rate Limiting](api/rate-limiting.md) - Rate limiting policies
- [Error Codes](api/error-codes.md) - Error handling

## 🏗️ Architecture & Development

### Architecture
- [System Overview](architecture/system-overview.md) - High-level architecture
- [Component Design](architecture/component-design.md) - Detailed components
- [Data Models](architecture/data-models.md) - Data structures
- [Security Architecture](architecture/security.md) - Security design
- [Performance Considerations](architecture/performance.md) - Performance guide

### Development
- [Development Setup](development/setup.md) - Development environment
- [Contributing Guide](development/contributing.md) - How to contribute
- [Code Style](development/code-style.md) - Coding standards
- [Testing Guide](development/testing.md) - Testing strategies
- [Release Process](development/release-process.md) - Release procedures

## 🚀 Deployment

### Deployment Guides
- [Docker Deployment](deployment/docker.md) - Docker setup
- [Kubernetes Deployment](deployment/kubernetes.md) - K8s deployment
- [Production Setup](deployment/production.md) - Production deployment
- [Monitoring Setup](deployment/monitoring.md) - Monitoring configuration
- [Backup & Recovery](deployment/backup-recovery.md) - Backup strategies

## 💡 Examples

### Usage Examples
- [Basic Usage](examples/basic-usage.md) - Basic examples
- [Advanced Scenarios](examples/advanced-scenarios.md) - Complex use cases
- [Integration Examples](examples/integrations.md) - Third-party integrations
- [Configuration Examples](examples/configuration.md) - Config examples

## 📋 Quick Reference

### Common Commands
```bash
# Initialize DriftMgr
driftmgr init

# Configure provider
driftmgr config provider aws --access-key-id KEY --secret-access-key SECRET

# Run drift detection
driftmgr detect --provider aws --region us-east-1

# View results
driftmgr results list

# Start web dashboard
driftmgr web --port 8080
```

### Configuration File
```yaml
# ~/.driftmgr/config.yaml
server:
  host: "localhost"
  port: 8080

providers:
  aws:
    enabled: true
    regions: ["us-east-1", "us-west-2"]

detection:
  schedule: "0 */6 * * *"
  quick_scan_timeout: "30s"
```

## 🔗 External Resources

- **GitHub Repository**: [catherinevee/driftmgr](https://github.com/catherinevee/driftmgr)
- **Issue Tracker**: [GitHub Issues](https://github.com/catherinevee/driftmgr/issues)
- **Discussions**: [GitHub Discussions](https://github.com/catherinevee/driftmgr/discussions)
- **Releases**: [GitHub Releases](https://github.com/catherinevee/driftmgr/releases)

## 📞 Support

- **Documentation Issues**: Open an issue in the repository
- **Feature Requests**: Use the GitHub issue tracker
- **Bug Reports**: Follow the bug report template
- **Community**: Join our discussions for community support

## 📝 Contributing

We welcome contributions! Please see our [Contributing Guide](development/contributing.md) for details on how to contribute to the project.

---

**Last Updated**: September 2025  
**Version**: Latest  
**Maintainer**: DriftMgr Team
