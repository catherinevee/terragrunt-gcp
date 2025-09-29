# Contributing to DriftMgr

Thank you for your interest in contributing to DriftMgr! This guide will help you get started with contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Process](#contributing-process)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Guidelines](#documentation-guidelines)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

## Getting Started

### Prerequisites

- Go 1.21 or later
- Node.js 18+ (for web dashboard development)
- Docker and Docker Compose
- Git
- Make

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/driftmgr.git
cd driftmgr
```

3. Add the upstream repository:

```bash
git remote add upstream https://github.com/catherinevee/driftmgr.git
```

## Development Setup

### 1. Install Dependencies

```bash
# Install Go dependencies
go mod download

# Install Node.js dependencies (for web dashboard)
cd web
npm install
cd ..

# Install pre-commit hooks
pre-commit install
```

### 2. Build the Project

```bash
# Build the main binary
make build

# Build the web dashboard
make build-web

# Build everything
make build-all
```

### 3. Run Tests

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run specific test packages
go test ./internal/drift/...
```

### 4. Start Development Environment

```bash
# Start development services
docker-compose -f docker-compose.dev.yml up -d

# Run DriftMgr in development mode
make dev
```

## Contributing Process

### 1. Create a Branch

```bash
# Create a new branch for your feature
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/your-bug-description
```

### 2. Make Changes

- Write your code following the [Code Style Guidelines](#code-style-guidelines)
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Commit Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "feat: add new drift detection strategy

- Implement custom drift detection for S3 buckets
- Add configuration options for detection sensitivity
- Include comprehensive tests for new functionality

Closes #123"
```

### 4. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create a pull request on GitHub
```

## Code Style Guidelines

### Go Code Style

We follow the standard Go formatting and style guidelines:

```bash
# Format code
go fmt ./...

# Run linter
golangci-lint run

# Run all style checks
make lint
```

### Naming Conventions

- **Packages**: Use lowercase, single-word names
- **Functions**: Use camelCase, descriptive names
- **Variables**: Use camelCase, descriptive names
- **Constants**: Use UPPER_SNAKE_CASE
- **Types**: Use PascalCase

### Code Organization

```go
// Package declaration
package drift

// Imports (standard, third-party, local)
import (
    "context"
    "fmt"
    
    "github.com/aws/aws-sdk-go-v2/service/s3"
    
    "github.com/catherinevee/driftmgr/internal/models"
)

// Constants
const (
    DefaultTimeout = 30 * time.Second
    MaxRetries     = 3
)

// Types
type Detector struct {
    client s3.Client
    config *Config
}

// Methods
func (d *Detector) Detect(ctx context.Context) (*models.DriftResult, error) {
    // Implementation
}
```

### Error Handling

```go
// Use wrapped errors for context
if err != nil {
    return fmt.Errorf("failed to detect drift: %w", err)
}

// Use custom error types for specific cases
if !resource.Exists() {
    return &ErrResourceNotFound{ResourceID: resource.ID}
}
```

### Logging

```go
import "log/slog"

// Use structured logging
slog.Info("drift detection started",
    "provider", "aws",
    "region", "us-east-1",
    "scan_id", scanID)

// Use appropriate log levels
slog.Debug("processing resource", "resource_id", resourceID)
slog.Warn("configuration issue", "issue", "missing required field")
slog.Error("detection failed", "error", err)
```

## Testing Guidelines

### Unit Tests

```go
func TestDetector_Detect(t *testing.T) {
    tests := []struct {
        name     string
        setup    func() *Detector
        expected *models.DriftResult
        wantErr  bool
    }{
        {
            name: "successful detection",
            setup: func() *Detector {
                return &Detector{
                    client: mockClient,
                    config: &Config{Timeout: 30 * time.Second},
                }
            },
            expected: &models.DriftResult{
                Status: "completed",
                DriftCount: 0,
            },
            wantErr: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            detector := tt.setup()
            result, err := detector.Detect(context.Background())
            
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.expected, result)
            }
        })
    }
}
```

### Integration Tests

```go
func TestIntegration_DetectDrift(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    // Setup test environment
    testEnv := setupTestEnvironment(t)
    defer testEnv.Cleanup()

    // Run integration test
    detector := NewDetector(testEnv.Config)
    result, err := detector.Detect(context.Background())
    
    assert.NoError(t, err)
    assert.NotNil(t, result)
}
```

### Test Coverage

```bash
# Generate coverage report
go test -coverprofile=coverage.out ./...

# View coverage in browser
go tool cover -html=coverage.out

# Check coverage threshold
make test-coverage
```

## Documentation Guidelines

### Code Documentation

```go
// Detector handles drift detection for cloud resources.
// It compares the current state of resources with their expected
// configuration defined in Terraform state files.
type Detector struct {
    client s3.Client
    config *Config
}

// Detect performs drift detection on the configured resources.
// It returns a DriftResult containing information about any
// detected configuration drift.
//
// The context parameter is used for cancellation and timeout control.
// If the context is cancelled, the detection will be aborted.
func (d *Detector) Detect(ctx context.Context) (*models.DriftResult, error) {
    // Implementation
}
```

### README Updates

When adding new features, update the relevant README files:

- `README.md` - Main project documentation
- `docs/user-guide/` - User documentation
- `docs/api/` - API documentation
- `docs/examples/` - Usage examples

### API Documentation

For API changes, update the OpenAPI specification:

```yaml
# api/openapi.yaml
paths:
  /api/v1/drift/detect:
    post:
      summary: Start drift detection
      description: Initiates a drift detection scan for the specified provider and region
      parameters:
        - name: provider
          in: query
          required: true
          schema:
            type: string
            enum: [aws, azure, gcp]
```

## Pull Request Guidelines

### PR Title Format

Use conventional commit format:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Build process or auxiliary tool changes

### PR Description Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows the project's style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes (or breaking changes documented)

## Related Issues
Closes #123
```

### Review Process

1. **Automated Checks**: All CI/CD checks must pass
2. **Code Review**: At least one maintainer must approve
3. **Testing**: Manual testing may be required for complex changes
4. **Documentation**: Documentation must be updated if needed

## Release Process

### Versioning

We use semantic versioning (SemVer):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Steps

1. **Update Version**: Update version in relevant files
2. **Update Changelog**: Document changes in CHANGELOG.md
3. **Create Release**: Create GitHub release with release notes
4. **Build Artifacts**: Build and upload release artifacts
5. **Update Documentation**: Update documentation for new features

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Version bumped
- [ ] Release notes prepared
- [ ] Artifacts built and uploaded
- [ ] Docker images pushed

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Code contributions and reviews

### Resources

- [Go Documentation](https://golang.org/doc/)
- [Testing in Go](https://golang.org/pkg/testing/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

## Recognition

Contributors will be recognized in:

- CONTRIBUTORS.md file
- Release notes
- Project documentation

Thank you for contributing to DriftMgr! 🚀
