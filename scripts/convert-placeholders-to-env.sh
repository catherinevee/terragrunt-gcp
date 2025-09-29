#!/bin/bash
# convert-placeholders-to-env.sh
# Converts PLACEHOLDER values in secret-manager config to use get_env()

set -e

TARGET_FILE="infrastructure/environments/prod/us-central1/security/secret-manager/terragrunt.hcl"
BACKUP_FILE="${TARGET_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Create backup
cp "$TARGET_FILE" "$BACKUP_FILE"
echo "✅ Created backup: $BACKUP_FILE"

# Create a temporary file for the conversion
TEMP_FILE=$(mktemp)

# Read the file and convert placeholders to get_env() calls
cat > "$TEMP_FILE" << 'CONVERSION_SCRIPT'
BEGIN {
    in_secret_data = 0
    brace_count = 0
}

# Track when we enter jsonencode({ ... })
/jsonencode\({/ {
    in_secret_data = 1
    brace_count = 1
    print $0
    next
}

# Count braces to know when we exit jsonencode
in_secret_data {
    for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") brace_count++
        if (c == "}") brace_count--
    }

    # If we're in the secret_data block, convert placeholders
    if (brace_count > 0) {
        # Database password
        if ($0 ~ /password = "PLACEHOLDER/) {
            gsub(/"PLACEHOLDER[^"]*"/, "get_env(\"DB_PASSWORD\", \"\")")
        }
        # Stripe key
        else if ($0 ~ /stripe_key = "sk_live_PLACEHOLDER/) {
            gsub(/"sk_live_PLACEHOLDER"/, "get_env(\"STRIPE_API_KEY\", \"\")")
        }
        # SendGrid key
        else if ($0 ~ /sendgrid_key = "SG\.PLACEHOLDER/) {
            gsub(/"SG\.PLACEHOLDER"/, "get_env(\"SENDGRID_API_KEY\", \"\")")
        }
        # Twilio key
        else if ($0 ~ /twilio_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"TWILIO_API_KEY\", \"\")")
        }
        # Datadog API key
        else if ($0 ~ /datadog_api_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"DATADOG_API_KEY\", \"\")")
        }
        # Datadog App key
        else if ($0 ~ /datadog_app_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"DATADOG_APP_KEY\", \"\")")
        }
        # PagerDuty key
        else if ($0 ~ /pagerduty_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"PAGERDUTY_API_KEY\", \"\")")
        }
        # Slack webhook
        else if ($0 ~ /slack_webhook = "https:\/\/hooks\.slack\.com\/PLACEHOLDER"/) {
            gsub(/"https:\/\/hooks\.slack\.com\/PLACEHOLDER"/, "get_env(\"SLACK_WEBHOOK_URL\", \"\")")
        }
        # OAuth client ID
        else if ($0 ~ /client_id = "PLACEHOLDER\.apps\.googleusercontent\.com"/) {
            gsub(/"PLACEHOLDER\.apps\.googleusercontent\.com"/, "get_env(\"OAUTH_CLIENT_ID\", \"\")")
        }
        # OAuth client secret
        else if ($0 ~ /client_secret = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"OAUTH_CLIENT_SECRET\", \"\")")
        }
        # TLS cert
        else if ($0 ~ /cert = "-----BEGIN CERTIFICATE-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN CERTIFICATE-----\\nPLACEHOLDER[^"]*"/, "get_env(\"TLS_CERT\", \"\")")
        }
        # TLS key
        else if ($0 ~ /key = "-----BEGIN PRIVATE KEY-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN PRIVATE KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"TLS_KEY\", \"\")")
        }
        # TLS chain
        else if ($0 ~ /chain = "-----BEGIN CERTIFICATE-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN CERTIFICATE-----\\nPLACEHOLDER[^"]*"/, "get_env(\"TLS_CHAIN\", \"\")")
        }
        # GCP service account private key ID
        else if ($0 ~ /private_key_id = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"GCP_SERVICE_ACCOUNT_ID\", \"\")")
        }
        # GCP service account private key
        else if ($0 ~ /private_key = "-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"GCP_SERVICE_ACCOUNT_KEY\", \"\")")
        }
        # Encryption keys
        else if ($0 ~ /master_key = base64encode\("PLACEHOLDER/) {
            gsub(/base64encode\("PLACEHOLDER[^"]*"\)/, "get_env(\"MASTER_ENCRYPTION_KEY\", \"\")")
        }
        else if ($0 ~ /data_key = base64encode\("PLACEHOLDER/) {
            gsub(/base64encode\("PLACEHOLDER[^"]*"\)/, "get_env(\"DATA_ENCRYPTION_KEY\", \"\")")
        }
        else if ($0 ~ /token_key = base64encode\("PLACEHOLDER/) {
            gsub(/base64encode\("PLACEHOLDER[^"]*"\)/, "get_env(\"TOKEN_SIGNING_KEY\", \"\")")
        }
        else if ($0 ~ /session_key = base64encode\("PLACEHOLDER/) {
            gsub(/base64encode\("PLACEHOLDER[^"]*"\)/, "get_env(\"SESSION_ENCRYPTION_KEY\", \"\")")
        }
        # JWT keys
        else if ($0 ~ /private_key = "-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER/ && prev_line ~ /jwt_signing/) {
            gsub(/"-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"JWT_PRIVATE_KEY\", \"\")")
        }
        else if ($0 ~ /public_key = "-----BEGIN PUBLIC KEY-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN PUBLIC KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"JWT_PUBLIC_KEY\", \"\")")
        }
        # SSH keys
        else if ($0 ~ /private_key = "-----BEGIN OPENSSH PRIVATE KEY-----\\nPLACEHOLDER/) {
            gsub(/"-----BEGIN OPENSSH PRIVATE KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"SSH_PRIVATE_KEY\", \"\")")
        }
        else if ($0 ~ /public_key = "ssh-rsa PLACEHOLDER"/) {
            gsub(/"ssh-rsa PLACEHOLDER"/, "get_env(\"SSH_PUBLIC_KEY\", \"\")")
        }
        else if ($0 ~ /fingerprint = "SHA256:PLACEHOLDER"/) {
            gsub(/"SHA256:PLACEHOLDER"/, "get_env(\"SSH_FINGERPRINT\", \"\")")
        }
        # VPN PSK
        else if ($0 ~ /preshared_key = base64encode\("PLACEHOLDER/) {
            gsub(/base64encode\("PLACEHOLDER[^"]*"\)/, "get_env(\"VPN_PSK\", \"\")")
        }
        # GitHub tokens
        else if ($0 ~ /personal_access_token = "ghp_PLACEHOLDER"/) {
            gsub(/"ghp_PLACEHOLDER"/, "get_env(\"GITHUB_PERSONAL_ACCESS_TOKEN\", \"\")")
        }
        else if ($0 ~ /app_private_key = "-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER/ && prev_line ~ /github/) {
            gsub(/"-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER[^"]*"/, "get_env(\"GITHUB_APP_PRIVATE_KEY\", \"\")")
        }
        else if ($0 ~ /webhook_secret = "PLACEHOLDER"/ && prev_line ~ /github/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"GITHUB_WEBHOOK_SECRET\", \"\")")
        }
        else if ($0 ~ /oauth_client_id = "PLACEHOLDER"/ && prev_line ~ /github/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"GITHUB_OAUTH_CLIENT_ID\", \"\")")
        }
        else if ($0 ~ /oauth_client_secret = "PLACEHOLDER"/ && prev_line ~ /github/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"GITHUB_OAUTH_CLIENT_SECRET\", \"\")")
        }
        # Monitoring keys
        else if ($0 ~ /new_relic_license_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"NEW_RELIC_LICENSE_KEY\", \"\")")
        }
        else if ($0 ~ /new_relic_api_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"NEW_RELIC_API_KEY\", \"\")")
        }
        else if ($0 ~ /prometheus_remote_write_username = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"PROMETHEUS_REMOTE_WRITE_USERNAME\", \"\")")
        }
        else if ($0 ~ /prometheus_remote_write_password = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"PROMETHEUS_REMOTE_WRITE_PASSWORD\", \"\")")
        }
        else if ($0 ~ /grafana_api_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"GRAFANA_API_KEY\", \"\")")
        }
        else if ($0 ~ /elastic_cloud_id = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"ELASTIC_CLOUD_ID\", \"\")")
        }
        else if ($0 ~ /elastic_api_key = "PLACEHOLDER"/) {
            gsub(/"PLACEHOLDER"/, "get_env(\"ELASTIC_API_KEY\", \"\")")
        }
    }

    if (brace_count == 0) {
        in_secret_data = 0
    }
}

{
    prev_line = $0
    print $0
}
CONVERSION_SCRIPT

# Apply the conversion
awk -f <(cat "$TEMP_FILE") "$TARGET_FILE" > "${TARGET_FILE}.new"

# Replace original with converted file
mv "${TARGET_FILE}.new" "$TARGET_FILE"

# Clean up
rm "$TEMP_FILE"

echo "✅ Converted placeholders to get_env() calls"
echo ""
echo "Backup saved to: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "1. Generate secrets template: ./scripts/generate-secrets-template.sh"
echo "2. Create .env file with actual values"
echo "3. Load environment: source .env"
echo "4. Test configuration: terragrunt validate"