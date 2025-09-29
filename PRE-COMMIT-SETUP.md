# Pre-Commit Hooks Setup Guide

This guide explains how to set up and use pre-commit hooks for the terragrunt-gcp project.

## Overview

Pre-commit hooks automatically run checks before each commit to ensure:
- Code formatting consistency
- No secrets committed
- Terraform/Go code validity
- Documentation quality

## Installation

### Prerequisites

```bash
# Python 3.11+ required
python --version

# Install pre-commit
pip install pre-commit

# Install Terraform tools (optional but recommended)
# On macOS
brew install tflint terraform-docs tfsec

# On Linux
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

### Setup

```bash
# Navigate to project root
cd /path/to/terragrunt-gcp

# Install the git hooks
pre-commit install

# Install commit-msg hook
pre-commit install --hook-type commit-msg

# (Optional) Install for pre-push
pre-commit install --hook-type pre-push
```

## Usage

### Automatic Runs

Once installed, hooks run automatically on `git commit`:

```bash
# Hooks run automatically
git add .
git commit -m "feat: add new feature"

# If hooks fail, fix issues and recommit
git add .
git commit -m "feat: add new feature"
```

### Manual Runs

Run hooks manually on all files:

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
pre-commit run go-fmt --all-files

# Run on specific files
pre-commit run --files infrastructure/environments/dev/terragrunt.hcl
```

### Skip Hooks (Use Sparingly)

```bash
# Skip all hooks (not recommended)
git commit --no-verify -m "emergency fix"

# Skip specific hook
SKIP=go-unit-tests git commit -m "wip: work in progress"
```

## Hooks Included

### Terraform Hooks
- **terraform_fmt**: Formats Terraform files
- **terraform_validate**: Validates Terraform syntax
- **terraform_docs**: Generates/updates documentation
- **terraform_tflint**: Lints Terraform code
- **terraform_tfsec**: Security scanning

### Go Hooks
- **go-fmt**: Formats Go code
- **go-vet**: Analyzes Go code for errors
- **go-imports**: Organizes imports
- **go-unit-tests**: Runs unit tests
- **go-build**: Verifies code compiles
- **go-mod-tidy**: Cleans go.mod

### General Hooks
- **trailing-whitespace**: Removes trailing spaces
- **end-of-file-fixer**: Ensures files end with newline
- **check-yaml**: Validates YAML syntax
- **check-json**: Validates JSON syntax
- **check-added-large-files**: Prevents large files
- **detect-private-key**: Detects private keys
- **gitleaks**: Scans for secrets

### Code Quality
- **shellcheck**: Validates shell scripts
- **mdformat**: Formats markdown
- **conventional-pre-commit**: Enforces commit message format

## Commit Message Format

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation
- **style**: Formatting
- **refactor**: Code restructuring
- **perf**: Performance
- **test**: Tests
- **build**: Build system
- **ci**: CI/CD
- **chore**: Maintenance

### Examples

```bash
# Good commit messages
git commit -m "feat: add KMS encryption support"
git commit -m "fix: resolve quota retrieval bug"
git commit -m "docs: update README with examples"

# With scope
git commit -m "feat(secrets): add rotation helper methods"
git commit -m "fix(auth): correct AWS metadata parsing"

# With body
git commit -m "feat: add cost calculator

Implements GCP Billing API integration with:
- Price caching (24h TTL)
- Multi-service support
- Monthly projections"
```

## Troubleshooting

### Hook Fails on Every Commit

```bash
# Update hooks to latest version
pre-commit autoupdate

# Reinstall hooks
pre-commit uninstall
pre-commit install
```

### Terraform Tools Missing

```bash
# Check what's missing
which terraform
which tflint
which terraform-docs
which tfsec

# Install missing tools
# See https://github.com/antonbabenko/pre-commit-terraform#1-install-dependencies
```

### Go Hooks Fail

```bash
# Ensure Go is installed
go version

# Update Go modules
go mod download
go mod tidy

# Verify build works
go build ./...
```

### Gitleaks False Positives

Add `# gitleaks:allow` comment on the line:

```go
apiKey := "test-key-12345" // gitleaks:allow
```

Or add pattern to `.gitleaks.toml`:

```toml
[allowlist]
regexes = [
  '''your-false-positive-pattern''',
]
```

### Skip Specific Files

Edit `.pre-commit-config.yaml`:

```yaml
- id: terraform_fmt
  exclude: ^legacy/
```

## Configuration Files

- `.pre-commit-config.yaml`: Main configuration
- `.tflint.hcl`: TFLint rules
- `.gitleaks.toml`: Secret detection rules

## CI/CD Integration

Hooks automatically run in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run pre-commit
  uses: pre-commit/action@v3.0.0
```

Some hooks are skipped in CI (see `ci.skip` in `.pre-commit-config.yaml`).

## Best Practices

1. **Run Before Committing**: `pre-commit run --all-files`
2. **Keep Hooks Updated**: `pre-commit autoupdate` monthly
3. **Don't Skip Hooks**: Fix issues instead of using `--no-verify`
4. **Add Exceptions Carefully**: Only for legitimate false positives
5. **Test After Updates**: Run full suite after hook updates

## Performance Tips

```bash
# Run only fast hooks during development
SKIP=go-unit-tests,terraform_tfsec git commit -m "wip"

# Run full suite before pushing
pre-commit run --all-files
git push
```

## Getting Help

- Pre-commit docs: https://pre-commit.com/
- Terraform hooks: https://github.com/antonbabenko/pre-commit-terraform
- Gitleaks: https://github.com/gitleaks/gitleaks
- Project issues: https://github.com/your-org/terragrunt-gcp/issues

## Uninstalling

```bash
# Remove hooks
pre-commit uninstall

# Remove all hook types
pre-commit uninstall --hook-type pre-commit
pre-commit uninstall --hook-type commit-msg
pre-commit uninstall --hook-type pre-push
```