# Installation Guide

This guide covers various methods to install DriftMgr on different platforms and environments.

## System Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 10GB free space
- **Network**: Internet access for cloud provider APIs

### Recommended Requirements
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 50GB+ free space
- **Network**: Stable internet connection

### Supported Platforms
- **Linux**: x86_64, ARM64
- **macOS**: x86_64, ARM64 (Apple Silicon)
- **Windows**: x86_64
- **Docker**: All platforms with Docker support

## Installation Methods

### Method 1: Download Pre-built Binary (Recommended)

#### Linux

```bash
# Download latest release
curl -L https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-linux-amd64 -o driftmgr

# Make executable
chmod +x driftmgr

# Move to PATH
sudo mv driftmgr /usr/local/bin/

# Verify installation
driftmgr version
```

#### macOS

```bash
# Download latest release
curl -L https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-darwin-amd64 -o driftmgr

# Make executable
chmod +x driftmgr

# Move to PATH
sudo mv driftmgr /usr/local/bin/

# Verify installation
driftmgr version
```

#### Apple Silicon (M1/M2)

```bash
# Download ARM64 version
curl -L https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-darwin-arm64 -o driftmgr

# Make executable
chmod +x driftmgr

# Move to PATH
sudo mv driftmgr /usr/local/bin/

# Verify installation
driftmgr version
```

#### Windows

```powershell
# Download using PowerShell
Invoke-WebRequest -Uri "https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-windows-amd64.exe" -OutFile "driftmgr.exe"

# Move to PATH (optional)
Move-Item driftmgr.exe C:\Windows\System32\

# Verify installation
driftmgr version
```

### Method 2: Package Managers

#### Homebrew (macOS/Linux)

```bash
# Add tap (if not already added)
brew tap catherinevee/driftmgr

# Install
brew install driftmgr

# Verify installation
driftmgr version
```

#### Chocolatey (Windows)

```powershell
# Install
choco install driftmgr

# Verify installation
driftmgr version
```

#### Snap (Linux)

```bash
# Install
sudo snap install driftmgr

# Verify installation
driftmgr version
```

### Method 3: Build from Source

#### Prerequisites
- Go 1.21 or later
- Git
- Make (optional)

#### Build Steps

```bash
# Clone repository
git clone https://github.com/catherinevee/driftmgr.git
cd driftmgr

# Install dependencies
go mod download

# Build binary
go build -o driftmgr ./cmd/driftmgr

# Or use Make
make build

# Install to system
sudo make install
```

### Method 4: Docker

#### Pull and Run

```bash
# Pull latest image
docker pull catherinevee/driftmgr:latest

# Run container
docker run -it --rm \
  -v ~/.aws:/root/.aws \
  -v ~/.driftmgr:/root/.driftmgr \
  catherinevee/driftmgr:latest
```

#### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  driftmgr:
    image: catherinevee/driftmgr:latest
    ports:
      - "8080:8080"
    volumes:
      - ~/.aws:/root/.aws
      - ~/.driftmgr:/root/.driftmgr
      - ./config:/app/config
    environment:
      - DRIFTMGR_CONFIG_PATH=/app/config/config.yaml
```

```bash
# Start with Docker Compose
docker-compose up -d
```

## Post-Installation Setup

### 1. Initialize Configuration

```bash
# Initialize DriftMgr
driftmgr init

# This creates the configuration directory
ls -la ~/.driftmgr/
```

### 2. Configure Cloud Providers

#### AWS Configuration

```bash
# Using AWS CLI credentials
aws configure

# Or configure directly in DriftMgr
driftmgr config provider aws \
  --access-key-id YOUR_ACCESS_KEY \
  --secret-access-key YOUR_SECRET_KEY \
  --region us-east-1
```

#### Azure Configuration

```bash
# Login to Azure
az login

# Configure DriftMgr
driftmgr config provider azure \
  --subscription-id YOUR_SUBSCRIPTION_ID \
  --tenant-id YOUR_TENANT_ID
```

#### GCP Configuration

```bash
# Authenticate with GCP
gcloud auth application-default login

# Configure DriftMgr
driftmgr config provider gcp \
  --project-id YOUR_PROJECT_ID
```

### 3. Verify Installation

```bash
# Check version
driftmgr version

# Test configuration
driftmgr config validate

# Test cloud provider connections
driftmgr test connection --provider aws
driftmgr test connection --provider azure
driftmgr test connection --provider gcp
```

## Development Installation

For developers who want to contribute or modify DriftMgr:

### Prerequisites
- Go 1.21+
- Node.js 18+ (for web dashboard)
- Docker (for testing)
- Make

### Setup Development Environment

```bash
# Clone repository
git clone https://github.com/catherinevee/driftmgr.git
cd driftmgr

# Install Go dependencies
go mod download

# Install Node.js dependencies (for web dashboard)
cd web
npm install
cd ..

# Install pre-commit hooks
pre-commit install

# Run tests
make test

# Build development version
make build-dev
```

## Upgrading DriftMgr

### Binary Upgrade

```bash
# Download new version
curl -L https://github.com/catherinevee/driftmgr/releases/latest/download/driftmgr-linux-amd64 -o driftmgr-new

# Replace old binary
sudo mv driftmgr-new /usr/local/bin/driftmgr

# Verify upgrade
driftmgr version
```

### Package Manager Upgrade

```bash
# Homebrew
brew upgrade driftmgr

# Chocolatey
choco upgrade driftmgr

# Snap
sudo snap refresh driftmgr
```

### Docker Upgrade

```bash
# Pull new image
docker pull catherinevee/driftmgr:latest

# Restart container
docker-compose down
docker-compose up -d
```

## Uninstallation

### Binary Removal

```bash
# Remove binary
sudo rm /usr/local/bin/driftmgr

# Remove configuration (optional)
rm -rf ~/.driftmgr/
```

### Package Manager Removal

```bash
# Homebrew
brew uninstall driftmgr

# Chocolatey
choco uninstall driftmgr

# Snap
sudo snap remove driftmgr
```

### Docker Removal

```bash
# Remove image
docker rmi catherinevee/driftmgr:latest

# Remove container
docker rm driftmgr-container
```

## Troubleshooting Installation

### Common Issues

#### Permission Denied
```bash
# Fix permissions
chmod +x driftmgr
sudo chown root:root /usr/local/bin/driftmgr
```

#### Binary Not Found
```bash
# Check PATH
echo $PATH

# Add to PATH
export PATH=$PATH:/usr/local/bin
```

#### Go Build Issues
```bash
# Check Go version
go version

# Clean module cache
go clean -modcache

# Rebuild
go build -v ./cmd/driftmgr
```

#### Docker Issues
```bash
# Check Docker status
docker --version
docker info

# Restart Docker service
sudo systemctl restart docker
```

### Getting Help

If you encounter installation issues:

1. **Check system requirements**
2. **Verify network connectivity**
3. **Check file permissions**
4. **Review error messages**
5. **Open an issue on GitHub**

## Next Steps

After successful installation:

1. **[Getting Started Guide](getting-started.md)** - Learn the basics
2. **[Configuration Guide](configuration.md)** - Configure DriftMgr
3. **[CLI Reference](cli-reference.md)** - Command reference
4. **[Examples](../examples/basic-usage.md)** - Usage examples

## Security Considerations

- **Use least privilege** for cloud provider credentials
- **Store credentials securely** (use environment variables or credential files)
- **Enable authentication** in production environments
- **Keep DriftMgr updated** to latest version
- **Review security policies** before deployment

---

**Installation complete!** 🎉  
Proceed to the [Getting Started Guide](getting-started.md) to begin using DriftMgr.
