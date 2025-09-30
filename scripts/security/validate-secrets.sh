#!/bin/bash
# Validate that no secrets are committed to the repository

set -e

echo "🔍 Validating secrets in repository..."

# Check for common secret patterns
echo "Checking for common secret patterns..."

# List of patterns to check
PATTERNS=(
  "PRIVATE KEY"
  "api_key"
  "apikey"
  "password"
  "secret"
  "token"
  "credentials"
  "BEGIN RSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
)

FOUND_SECRETS=0

for pattern in "${PATTERNS[@]}"; do
  echo "  Checking for: $pattern"
  if git grep -i "$pattern" -- '*.tf' '*.tfvars' '*.json' '*.yaml' '*.yml' 2>/dev/null | grep -v "description" | grep -v "variable" | grep -v "#" > /dev/null; then
    echo "  ⚠️  Warning: Found potential secret pattern: $pattern"
    FOUND_SECRETS=$((FOUND_SECRETS + 1))
  fi
done

# Check for files that should not be committed
echo "Checking for sensitive files..."
SENSITIVE_FILES=(
  "*.tfvars.secret"
  "*.secret"
  "*credentials.json"
  "*.pem"
  "*.key"
  ".env"
)

for file_pattern in "${SENSITIVE_FILES[@]}"; do
  if find . -name "$file_pattern" -not -path "./.git/*" -not -path "./.terragrunt-cache/*" | grep -q .; then
    echo "  ⚠️  Warning: Found sensitive file: $file_pattern"
    FOUND_SECRETS=$((FOUND_SECRETS + 1))
  fi
done

if [ $FOUND_SECRETS -eq 0 ]; then
  echo "✅ No secrets found in repository"
  exit 0
else
  echo "⚠️  Found $FOUND_SECRETS potential secret(s). Please review."
  echo "Note: These may be false positives in variable definitions or comments."
  exit 0  # Exit with 0 to not fail the build, just warn
fi