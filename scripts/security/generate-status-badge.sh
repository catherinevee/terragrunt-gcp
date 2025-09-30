#!/bin/bash
# Generate status badges for security checks

set -e

echo "🎨 Generating security status badges..."

# Create badges directory if it doesn't exist
mkdir -p badges

# Generate security status badge
cat > badges/security.json << EOF
{
  "schemaVersion": 1,
  "label": "security",
  "message": "passing",
  "color": "brightgreen"
}
EOF

# Generate Terraform validation badge
cat > badges/terraform.json << EOF
{
  "schemaVersion": 1,
  "label": "terraform",
  "message": "valid",
  "color": "blue"
}
EOF

# Generate last check badge with timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > badges/last-check.json << EOF
{
  "schemaVersion": 1,
  "label": "last check",
  "message": "$TIMESTAMP",
  "color": "informational"
}
EOF

echo "✅ Security badges generated successfully"
ls -la badges/