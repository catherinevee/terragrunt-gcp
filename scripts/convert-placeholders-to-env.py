#!/usr/bin/env python3
"""
convert-placeholders-to-env.py
Converts PLACEHOLDER values in secret-manager config to use get_env()
"""

import re
import sys
from pathlib import Path
from datetime import datetime

# Mapping of placeholder patterns to environment variable names
REPLACEMENTS = [
    # Database
    (r'password = "PLACEHOLDER_WILL_BE_REPLACED"', r'password = get_env("DB_PASSWORD", "")'),

    # API Keys
    (r'"sk_live_PLACEHOLDER"', r'get_env("STRIPE_API_KEY", "")'),
    (r'"SG\.PLACEHOLDER"', r'get_env("SENDGRID_API_KEY", "")'),
    (r'twilio_key = "PLACEHOLDER"', r'twilio_key = get_env("TWILIO_API_KEY", "")'),
    (r'datadog_api_key = "PLACEHOLDER"', r'datadog_api_key = get_env("DATADOG_API_KEY", "")'),
    (r'datadog_app_key = "PLACEHOLDER"', r'datadog_app_key = get_env("DATADOG_APP_KEY", "")'),
    (r'pagerduty_key = "PLACEHOLDER"', r'pagerduty_key = get_env("PAGERDUTY_API_KEY", "")'),
    (r'"https://hooks\.slack\.com/PLACEHOLDER"', r'get_env("SLACK_WEBHOOK_URL", "")'),

    # OAuth
    (r'"PLACEHOLDER\.apps\.googleusercontent\.com"', r'get_env("OAUTH_CLIENT_ID", "")'),
    (r'client_secret = "PLACEHOLDER"', r'client_secret = get_env("OAUTH_CLIENT_SECRET", "")'),

    # TLS Certificates
    (r'"-----BEGIN CERTIFICATE-----\\nPLACEHOLDER\\n-----END CERTIFICATE-----"', r'get_env("TLS_CERT", "")'),
    (r'"-----BEGIN PRIVATE KEY-----\\nPLACEHOLDER\\n-----END PRIVATE KEY-----"', r'get_env("TLS_KEY", "")'),
    (r'chain = "-----BEGIN CERTIFICATE-----\\nPLACEHOLDER\\n-----END CERTIFICATE-----"', r'chain = get_env("TLS_CHAIN", "")'),

    # Service Account
    (r'private_key_id = "PLACEHOLDER"', r'private_key_id = get_env("GCP_SERVICE_ACCOUNT_ID", "")'),
    (r'"-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER\\n-----END RSA PRIVATE KEY-----"', r'get_env("GCP_SERVICE_ACCOUNT_KEY", "")'),
    (r'client_id = "PLACEHOLDER"', r'client_id = get_env("GCP_CLIENT_ID", "")'),

    # Encryption Keys
    (r'master_key = base64encode\("PLACEHOLDER_32_BYTE_KEY_HERE_\.\.\."\)', r'master_key = get_env("MASTER_ENCRYPTION_KEY", "")'),
    (r'data_key = base64encode\("PLACEHOLDER_32_BYTE_KEY_HERE_\.\.\."\)', r'data_key = get_env("DATA_ENCRYPTION_KEY", "")'),
    (r'token_key = base64encode\("PLACEHOLDER_32_BYTE_KEY_HERE_\.\.\."\)', r'token_key = get_env("TOKEN_SIGNING_KEY", "")'),
    (r'session_key = base64encode\("PLACEHOLDER_32_BYTE_KEY_HERE_\.\.\."\)', r'session_key = get_env("SESSION_ENCRYPTION_KEY", "")'),

    # JWT Keys
    (r'private_key = "-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER\\n-----END RSA PRIVATE KEY-----"', r'private_key = get_env("JWT_PRIVATE_KEY", "")'),
    (r'"-----BEGIN PUBLIC KEY-----\\nPLACEHOLDER\\n-----END PUBLIC KEY-----"', r'get_env("JWT_PUBLIC_KEY", "")'),

    # SSH Keys
    (r'"-----BEGIN OPENSSH PRIVATE KEY-----\\nPLACEHOLDER\\n-----END OPENSSH PRIVATE KEY-----"', r'get_env("SSH_PRIVATE_KEY", "")'),
    (r'"ssh-rsa PLACEHOLDER"', r'get_env("SSH_PUBLIC_KEY", "")'),
    (r'"SHA256:PLACEHOLDER"', r'get_env("SSH_FINGERPRINT", "")'),

    # VPN
    (r'preshared_key = base64encode\("PLACEHOLDER_PSK_HERE"\)', r'preshared_key = get_env("VPN_PSK", "")'),

    # GitHub
    (r'"ghp_PLACEHOLDER"', r'get_env("GITHUB_PERSONAL_ACCESS_TOKEN", "")'),
    (r'app_private_key = "-----BEGIN RSA PRIVATE KEY-----\\nPLACEHOLDER\\n-----END RSA PRIVATE KEY-----"', r'app_private_key = get_env("GITHUB_APP_PRIVATE_KEY", "")'),
    (r'webhook_secret = "PLACEHOLDER"', r'webhook_secret = get_env("GITHUB_WEBHOOK_SECRET", "")'),
    (r'oauth_client_id = "PLACEHOLDER"', r'oauth_client_id = get_env("GITHUB_OAUTH_CLIENT_ID", "")'),
    (r'oauth_client_secret = "PLACEHOLDER"', r'oauth_client_secret = get_env("GITHUB_OAUTH_CLIENT_SECRET", "")'),

    # Monitoring
    (r'new_relic_license_key = "PLACEHOLDER"', r'new_relic_license_key = get_env("NEW_RELIC_LICENSE_KEY", "")'),
    (r'new_relic_api_key = "PLACEHOLDER"', r'new_relic_api_key = get_env("NEW_RELIC_API_KEY", "")'),
    (r'prometheus_remote_write_username = "PLACEHOLDER"', r'prometheus_remote_write_username = get_env("PROMETHEUS_REMOTE_WRITE_USERNAME", "")'),
    (r'prometheus_remote_write_password = "PLACEHOLDER"', r'prometheus_remote_write_password = get_env("PROMETHEUS_REMOTE_WRITE_PASSWORD", "")'),
    (r'grafana_api_key = "PLACEHOLDER"', r'grafana_api_key = get_env("GRAFANA_API_KEY", "")'),
    (r'elastic_cloud_id = "PLACEHOLDER"', r'elastic_cloud_id = get_env("ELASTIC_CLOUD_ID", "")'),
    (r'elastic_api_key = "PLACEHOLDER"', r'elastic_api_key = get_env("ELASTIC_API_KEY", "")'),
]


def convert_file(filepath: Path) -> int:
    """Convert placeholders in file to get_env() calls.

    Returns:
        Number of replacements made
    """
    if not filepath.exists():
        print(f"Error: File {filepath} not found")
        return 0

    # Create backup
    backup_path = filepath.with_suffix(f".backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}.hcl")
    backup_path.write_text(filepath.read_text())
    print(f"[OK] Created backup: {backup_path}")

    # Read content
    content = filepath.read_text()
    original_content = content

    # Apply replacements
    replacements_made = 0
    for pattern, replacement in REPLACEMENTS:
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            replacements_made += matches
            print(f"  Replaced {matches}x: {pattern[:50]}...")

    # Write back if changes were made
    if content != original_content:
        filepath.write_text(content)
        print(f"\n[OK] Converted {replacements_made} placeholders to get_env() calls")
        print(f"     File updated: {filepath}")
    else:
        print("\n[WARNING] No placeholders found to replace")

    return replacements_made


def main():
    target_file = Path("infrastructure/environments/prod/us-central1/security/secret-manager/terragrunt.hcl")

    if not target_file.exists():
        print(f"Error: {target_file} not found")
        print("Please run this script from the repository root")
        return 1

    print("Converting placeholders to environment variables...")
    print(f"Target: {target_file}\n")

    count = convert_file(target_file)

    if count > 0:
        print("\nNext steps:")
        print("1. Generate secrets template: ./scripts/generate-secrets-template.sh")
        print("2. Create .env file: cp secrets.template.env .env")
        print("3. Edit .env with actual secret values")
        print("4. Load environment: source .env")
        print("5. Test configuration: cd infrastructure/environments/prod && terragrunt validate")
        print("\n[IMPORTANT] Never commit .env to version control!")

    return 0


if __name__ == "__main__":
    sys.exit(main())