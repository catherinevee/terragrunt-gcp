#!/bin/bash
# fix-composer-module.sh - Fix Cloud Composer module issues

set -e

COMPOSER_MODULE="modules/compute/cloud-composer/main.tf"

echo "Fixing Cloud Composer module..."

# Backup original file
cp "$COMPOSER_MODULE" "$COMPOSER_MODULE.backup"

# Fix disk_type issue
sed -i 's/disk_type *= *local\.node_config\.disk_type/# disk_type not supported in current provider version/' "$COMPOSER_MODULE"

# Fix enable_ip_alias issue
sed -i 's/enable_ip_alias *= *local\.node_config\.enable_ip_alias/# enable_ip_alias not supported in current provider version/' "$COMPOSER_MODULE"

# Fix scheduler_count - convert from dynamic block to direct assignment
sed -i '/dynamic "scheduler_count"/,/^      }/d' "$COMPOSER_MODULE"
sed -i 's/scheduler_count {/# scheduler_count configuration\n      scheduler_count = var.scheduler_count/' "$COMPOSER_MODULE"

# Remove web_server_network_access_control block
sed -i '/dynamic "web_server_network_access_control"/,/^        }/d' "$COMPOSER_MODULE"

echo "✅ Cloud Composer module fixed"
echo "Backup saved to: $COMPOSER_MODULE.backup"

# Validate the fixed module
echo "Validating module..."
terraform -chdir="modules/compute/cloud-composer" init -backend=false
terraform -chdir="modules/compute/cloud-composer" validate

echo "✅ Module validation successful"