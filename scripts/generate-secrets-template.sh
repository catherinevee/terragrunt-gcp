#!/bin/bash
# generate-secrets-template.sh
# Generates a template file showing all required secrets

set -e

OUTPUT_FILE="secrets.template.env"

cat > "$OUTPUT_FILE" << 'EOF'
# Secret Template for terragrunt-gcp
# Copy this file to .env and fill in actual values
# NEVER commit the .env file to version control

# =============================================================================
# DATABASE CREDENTIALS
# =============================================================================
export DB_PASSWORD=""
export DB_ROOT_PASSWORD=""
export DB_REPLICA_PASSWORD=""

# =============================================================================
# API KEYS - External Services
# =============================================================================
export STRIPE_API_KEY=""              # Format: sk_live_... or sk_test_...
export SENDGRID_API_KEY=""            # Format: SG....
export TWILIO_API_KEY=""              # Twilio API key
export TWILIO_AUTH_TOKEN=""           # Twilio auth token

# =============================================================================
# MONITORING & OBSERVABILITY
# =============================================================================
export DATADOG_API_KEY=""             # Datadog API key
export DATADOG_APP_KEY=""             # Datadog application key
export NEW_RELIC_LICENSE_KEY=""       # New Relic license key
export NEW_RELIC_API_KEY=""           # New Relic API key
export PAGERDUTY_API_KEY=""           # PagerDuty integration key
export GRAFANA_API_KEY=""             # Grafana API key
export ELASTIC_API_KEY=""             # Elasticsearch API key
export ELASTIC_CLOUD_ID=""            # Elasticsearch cloud ID

# =============================================================================
# NOTIFICATIONS
# =============================================================================
export SLACK_WEBHOOK_URL=""           # Format: https://hooks.slack.com/...
export SLACK_BOT_TOKEN=""             # Slack bot OAuth token

# =============================================================================
# OAUTH & AUTHENTICATION
# =============================================================================
export OAUTH_CLIENT_ID=""             # OAuth 2.0 client ID
export OAUTH_CLIENT_SECRET=""         # OAuth 2.0 client secret
export GITHUB_OAUTH_CLIENT_ID=""      # GitHub OAuth app client ID
export GITHUB_OAUTH_CLIENT_SECRET=""  # GitHub OAuth app secret

# =============================================================================
# TLS CERTIFICATES
# =============================================================================
# Base64 encoded certificate and key
export TLS_CERT=""                    # Base64 encoded certificate
export TLS_KEY=""                     # Base64 encoded private key
export TLS_CHAIN=""                   # Base64 encoded certificate chain

# Or provide file paths (will be read and encoded)
# export TLS_CERT_FILE="/path/to/cert.pem"
# export TLS_KEY_FILE="/path/to/key.pem"
# export TLS_CHAIN_FILE="/path/to/chain.pem"

# =============================================================================
# SERVICE ACCOUNT KEYS
# =============================================================================
export GCP_SERVICE_ACCOUNT_KEY=""     # Base64 encoded JSON key
export GCP_SERVICE_ACCOUNT_ID=""      # Service account private key ID
export GCP_SERVICE_ACCOUNT_EMAIL=""   # Service account email

# =============================================================================
# ENCRYPTION KEYS
# =============================================================================
# Must be exactly 32 bytes, base64 encoded
export MASTER_ENCRYPTION_KEY=""       # Application master encryption key
export DATA_ENCRYPTION_KEY=""         # Data encryption key
export TOKEN_SIGNING_KEY=""           # Token signing key
export SESSION_ENCRYPTION_KEY=""      # Session encryption key

# =============================================================================
# JWT & SIGNING KEYS
# =============================================================================
export JWT_PRIVATE_KEY=""             # Base64 encoded RSA private key
export JWT_PUBLIC_KEY=""              # Base64 encoded RSA public key
export JWT_SECRET=""                  # JWT secret for HMAC algorithms

# =============================================================================
# SSH KEYS
# =============================================================================
export SSH_PRIVATE_KEY=""             # Base64 encoded SSH private key
export SSH_PUBLIC_KEY=""              # SSH public key
export SSH_FINGERPRINT=""             # SSH key fingerprint

# =============================================================================
# VPN KEYS
# =============================================================================
export VPN_PSK=""                     # VPN pre-shared key (base64 encoded)
export VPN_SHARED_SECRET=""           # VPN shared secret

# =============================================================================
# GITHUB INTEGRATION
# =============================================================================
export GITHUB_PERSONAL_ACCESS_TOKEN=""  # GitHub PAT for API access
export GITHUB_APP_PRIVATE_KEY=""        # GitHub App private key
export GITHUB_WEBHOOK_SECRET=""         # GitHub webhook secret
export GITHUB_APP_ID=""                 # GitHub App ID

# =============================================================================
# CONTAINER REGISTRY
# =============================================================================
export DOCKER_REGISTRY_USERNAME=""    # Docker registry username
export DOCKER_REGISTRY_PASSWORD=""    # Docker registry password
export GCR_SERVICE_ACCOUNT_KEY=""     # GCR service account key

# =============================================================================
# PROMETHEUS & MONITORING
# =============================================================================
export PROMETHEUS_REMOTE_WRITE_USERNAME=""  # Prometheus remote write username
export PROMETHEUS_REMOTE_WRITE_PASSWORD=""  # Prometheus remote write password

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Generate random 32-byte key and base64 encode it
generate_key() {
  openssl rand -base64 32
}

# Encode file to base64
encode_file() {
  local file=$1
  if [ -f "$file" ]; then
    base64 -w 0 "$file"
  else
    echo "Error: File $file not found" >&2
    return 1
  fi
}

# Example usage:
# export MASTER_ENCRYPTION_KEY=$(generate_key)
# export TLS_CERT=$(encode_file /path/to/cert.pem)

EOF

echo "✅ Created $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Copy the template: cp $OUTPUT_FILE .env"
echo "2. Edit .env with your actual secret values"
echo "3. Load secrets: source .env"
echo "4. Verify: echo \$DB_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Never commit .env to version control!"
echo "    Add .env to .gitignore if not already present"