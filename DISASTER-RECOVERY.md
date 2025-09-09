# Disaster Recovery Procedures

## Table of Contents
1. [Overview](#overview)
2. [RTO/RPO Targets](#rtorpo-targets)
3. [Backup Strategies](#backup-strategies)
4. [Recovery Procedures](#recovery-procedures)
5. [State Recovery](#state-recovery)
6. [Database Recovery](#database-recovery)
7. [Network Recovery](#network-recovery)
8. [Testing Procedures](#testing-procedures)
9. [Runbooks](#runbooks)

---

## Overview

This document outlines disaster recovery procedures for the GCP Terragrunt infrastructure. All procedures are designed to minimize data loss and service downtime.

### Key Principles
- **Automation First**: Automated recovery where possible
- **Regular Testing**: Quarterly DR drills
- **Documentation**: Clear, actionable runbooks
- **Communication**: Defined escalation paths

---

## RTO/RPO Targets

| Service | Environment | RPO | RTO | Priority |
|---------|------------|-----|-----|----------|
| Core Database | Production | 5 min | 30 min | P0 |
| API Services | Production | 15 min | 1 hour | P0 |
| Web Applications | Production | 30 min | 2 hours | P1 |
| Analytics Platform | Production | 1 hour | 4 hours | P2 |
| Development Infrastructure | Dev/Staging | 24 hours | 48 hours | P3 |

---

## Backup Strategies

### Terraform State Backup
```bash
# Automated daily backups
gsutil -m cp -r gs://terraform-state-prod/* gs://terraform-state-backup-prod/$(date +%Y%m%d)/

# Retention: 30 days for prod, 7 days for non-prod
```

### Database Backups
```yaml
cloud_sql:
  production:
    automated_backups:
      enabled: true
      start_time: "02:00"
      location: "us-central1"
      retention_days: 30
    point_in_time_recovery:
      enabled: true
      transaction_log_retention_days: 7
  
  staging:
    automated_backups:
      enabled: true
      start_time: "03:00"
      retention_days: 7
```

### Application Data
```yaml
storage_buckets:
  versioning: enabled
  lifecycle_rules:
    - action: 
        type: "SetStorageClass"
        storage_class: "NEARLINE"
      condition:
        age: 30
    - action:
        type: "SetStorageClass"
        storage_class: "COLDLINE"
      condition:
        age: 90
```

---

## Recovery Procedures

### Scenario 1: Complete Region Failure

#### Detection
```bash
# Automated monitoring
gcloud monitoring alerts list --filter="name:region-failure"
```

#### Response Steps
1. **Confirm Failure** (5 minutes)
   ```bash
   ./scripts/dr/check-region-health.sh us-central1
   ```

2. **Initiate Failover** (10 minutes)
   ```bash
   cd infrastructure/dr
   terragrunt run-all apply --terragrunt-working-dir=us-east1 \
     --var="failover_mode=true"
   ```

3. **Update DNS** (5 minutes)
   ```bash
   gcloud dns record-sets transaction start --zone=prod-zone
   gcloud dns record-sets transaction add \
     --name=api.example.com. \
     --ttl=60 \
     --type=A \
     --zone=prod-zone \
     34.102.136.180  # DR region IP
   gcloud dns record-sets transaction execute --zone=prod-zone
   ```

4. **Verify Services** (10 minutes)
   ```bash
   ./scripts/dr/verify-services.sh --region=us-east1
   ```

### Scenario 2: Data Corruption

#### Detection
```sql
-- Check data integrity
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT id) as unique_ids,
  MAX(updated_at) as last_update
FROM critical_table
WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour';
```

#### Recovery Steps
1. **Isolate Affected Systems**
   ```bash
   # Disable write traffic
   kubectl scale deployment api-server --replicas=0 -n production
   ```

2. **Restore from Backup**
   ```bash
   # Point-in-time recovery
   gcloud sql backups restore BACKUP_ID \
     --backup-instance=prod-db-instance \
     --restore-instance=prod-db-instance-recovered \
     --backup-configuration=prod-backup-config
   ```

3. **Validate Data**
   ```bash
   ./scripts/dr/validate-database.sh \
     --instance=prod-db-instance-recovered \
     --validation-suite=full
   ```

4. **Cutover**
   ```bash
   # Update connection strings
   kubectl set env deployment/api-server \
     DB_HOST=prod-db-instance-recovered.c.project.internal \
     -n production
   
   # Scale back up
   kubectl scale deployment api-server --replicas=10 -n production
   ```

---

## State Recovery

### Corrupted Terraform State

#### Symptoms
- `Error loading state: state data in S3 does not have the expected content`
- Inconsistent resource tracking
- Plan shows recreation of existing resources

#### Recovery Process
1. **Backup Current State**
   ```bash
   gsutil cp gs://terraform-state-prod/env/terraform.tfstate \
     ./backup/corrupted-state-$(date +%Y%m%d-%H%M%S).tfstate
   ```

2. **Restore from Backup**
   ```bash
   # List available backups
   gsutil ls gs://terraform-state-backup-prod/
   
   # Restore specific backup
   gsutil cp gs://terraform-state-backup-prod/20240115/env/terraform.tfstate \
     gs://terraform-state-prod/env/terraform.tfstate
   ```

3. **Reconcile State**
   ```bash
   cd infrastructure/environments/prod
   
   # Refresh state against actual resources
   terragrunt refresh
   
   # Import any missing resources
   terragrunt import google_compute_instance.web web-instance-1
   ```

4. **Validate**
   ```bash
   terragrunt plan
   # Should show no changes if state is correct
   ```

### Lost State File

#### Recovery without Backup
1. **Recreate State Structure**
   ```bash
   # Initialize empty state
   cd infrastructure/environments/prod
   terragrunt init -reconfigure
   ```

2. **Import Resources**
   ```bash
   # Generate import commands
   ./scripts/dr/generate-imports.sh --project=prod-project
   
   # Execute imports
   ./scripts/dr/execute-imports.sh --batch-size=10
   ```

3. **Verify Completeness**
   ```bash
   # Compare with actual resources
   ./scripts/dr/verify-state-completeness.sh
   ```

---

## Database Recovery

### Point-in-Time Recovery

```bash
#!/bin/bash
# scripts/dr/database-pitr.sh

INSTANCE_ID=$1
TARGET_TIME=$2

echo "Starting point-in-time recovery for $INSTANCE_ID to $TARGET_TIME"

# Create recovery instance
gcloud sql instances clone $INSTANCE_ID ${INSTANCE_ID}-pitr \
  --point-in-time=$TARGET_TIME \
  --async

# Wait for operation
gcloud sql operations wait --project=prod-project

# Verify data
gcloud sql connect ${INSTANCE_ID}-pitr --user=postgres << EOF
SELECT COUNT(*) FROM information_schema.tables;
SELECT MAX(created_at) FROM audit_log;
EOF

# Promote to primary (if validated)
read -p "Promote recovered instance to primary? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Update DNS/connection strings
  kubectl set env deployment/api-server \
    DB_HOST=${INSTANCE_ID}-pitr.c.prod-project.internal \
    -n production
fi
```

### Cross-Region Replication Failover

```yaml
# terragrunt.hcl for DR region
dependency "primary_db" {
  config_path = "../../us-central1/database"
  
  mock_outputs = {
    connection_name = "mock-connection"
    replica_configuration = {
      failover_target = false
    }
  }
}

inputs = {
  database_version = "POSTGRES_14"
  tier = "db-n1-standard-4"
  
  replica_configuration = {
    master_instance_name = dependency.primary_db.outputs.name
    failover_target = true
  }
  
  backup_configuration = {
    enabled = true
    start_time = "03:00"
    location = "us-east1"
  }
}
```

---

## Network Recovery

### VPC Recovery

```bash
#!/bin/bash
# scripts/dr/recover-network.sh

# Recreate VPC if deleted
terragrunt apply --target=module.vpc --auto-approve

# Restore firewall rules
terragrunt apply --target=module.firewall_rules --auto-approve

# Recreate NAT gateways
terragrunt apply --target=module.nat --auto-approve

# Verify connectivity
gcloud compute ssh test-instance --zone=us-central1-a \
  --command="ping -c 4 google.com"
```

### Load Balancer Recovery

```bash
# Recreate backend services
gcloud compute backend-services create web-backend \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-health-check \
  --global

# Add instance groups
gcloud compute backend-services add-backend web-backend \
  --instance-group=web-ig-us-central1 \
  --instance-group-zone=us-central1-a \
  --global

# Recreate URL map
gcloud compute url-maps create web-map \
  --default-service=web-backend

# Recreate HTTPS proxy
gcloud compute target-https-proxies create web-https-proxy \
  --url-map=web-map \
  --ssl-certificates=web-cert

# Recreate forwarding rule
gcloud compute forwarding-rules create web-https-rule \
  --target-https-proxy=web-https-proxy \
  --ports=443 \
  --global
```

---

## Testing Procedures

### Quarterly DR Drill

```yaml
dr_drill_checklist:
  preparation:
    - Notify stakeholders 1 week in advance
    - Review and update runbooks
    - Prepare test data set
    - Configure monitoring dashboards
  
  execution:
    - Simulate failure scenario
    - Execute recovery procedures
    - Measure recovery time
    - Document issues encountered
  
  validation:
    - Verify data integrity
    - Test application functionality
    - Check performance metrics
    - Confirm backup systems
  
  post_drill:
    - Restore to normal operations
    - Document lessons learned
    - Update procedures
    - Schedule improvements
```

### Automated Testing

```bash
#!/bin/bash
# scripts/dr/automated-dr-test.sh

# Test backup creation
echo "Testing backup creation..."
./scripts/backup/create-backup.sh --type=full --verify=true

# Test state recovery
echo "Testing state recovery..."
./scripts/dr/test-state-recovery.sh --non-destructive=true

# Test database failover
echo "Testing database failover..."
./scripts/dr/test-db-failover.sh --dry-run=true

# Test network resilience
echo "Testing network resilience..."
./scripts/dr/test-network-failover.sh --region=us-east1

# Generate report
./scripts/dr/generate-dr-report.sh --output=./reports/dr-test-$(date +%Y%m%d).html
```

---

## Runbooks

### Runbook: Emergency Infrastructure Recovery

```markdown
## EMERGENCY CONTACT LIST
- On-Call Engineer: +1-xxx-xxx-xxxx
- Platform Lead: +1-xxx-xxx-xxxx
- VP Engineering: +1-xxx-xxx-xxxx
- Google Cloud Support: +1-xxx-xxx-xxxx (Priority Support)

## IMMEDIATE ACTIONS (First 15 minutes)

1. **ASSESS** (5 min)
   - Check monitoring dashboards
   - Identify affected services
   - Determine scope of impact

2. **COMMUNICATE** (5 min)
   - Post in #incidents Slack channel
   - Create incident in PagerDuty
   - Send initial stakeholder notification

3. **STABILIZE** (5 min)
   - Activate disaster recovery mode
   - Redirect traffic if needed
   - Enable read-only mode if applicable

## RECOVERY PHASE (15-60 minutes)

4. **EXECUTE RECOVERY**
   - Follow specific scenario runbook
   - Document all actions in incident log
   - Coordinate with team members

5. **VALIDATE**
   - Test critical user journeys
   - Verify data consistency
   - Check integration points

6. **COMMUNICATE UPDATE**
   - Update status page
   - Send stakeholder update
   - Update incident severity if needed

## POST-RECOVERY (After 60 minutes)

7. **MONITOR**
   - Watch error rates
   - Check performance metrics
   - Monitor user feedback

8. **DOCUMENT**
   - Complete incident report
   - Schedule post-mortem
   - Create follow-up tickets
```

### Runbook: Terraform State Corruption

```bash
#!/bin/bash
# Runbook: Fix Corrupted Terraform State

set -e

echo "=== Terraform State Corruption Recovery ==="
echo "Environment: $1"
echo "Started at: $(date)"

ENV=$1
BACKUP_DIR="./state-backups/$(date +%Y%m%d-%H%M%S)"

# Step 1: Create backup directory
mkdir -p $BACKUP_DIR

# Step 2: Backup current corrupted state
echo "Backing up current state..."
gsutil cp gs://terraform-state-${ENV}/*.tfstate $BACKUP_DIR/ || true

# Step 3: List available backups
echo "Available backups:"
gsutil ls gs://terraform-state-backup-${ENV}/ | tail -10

# Step 4: Select backup to restore
read -p "Enter backup date (YYYYMMDD): " BACKUP_DATE

# Step 5: Restore backup
echo "Restoring backup from $BACKUP_DATE..."
gsutil cp -r gs://terraform-state-backup-${ENV}/${BACKUP_DATE}/* \
  gs://terraform-state-${ENV}/

# Step 6: Refresh state
echo "Refreshing state..."
cd infrastructure/environments/${ENV}
terragrunt refresh -lock=false

# Step 7: Validate
echo "Validating state..."
terragrunt plan -detailed-exitcode
PLAN_EXIT=$?

if [ $PLAN_EXIT -eq 0 ]; then
  echo "✅ State recovered successfully - no changes detected"
elif [ $PLAN_EXIT -eq 2 ]; then
  echo "⚠️  State recovered but changes detected - review required"
else
  echo "❌ State recovery failed - manual intervention required"
fi

echo "Recovery completed at: $(date)"
```

---

## Communication Templates

### Initial Incident Notification
```
🚨 INCIDENT DETECTED

Severity: [P0/P1/P2]
Services Affected: [List services]
User Impact: [Describe impact]
Start Time: [Time]

Current Status: Investigating
Next Update: In 15 minutes

Incident Commander: [Name]
Slack Channel: #incident-[number]
```

### Recovery Completion
```
✅ INCIDENT RESOLVED

Incident Duration: [Duration]
Root Cause: [Brief description]
Resolution: [What was done]

Services Restored: [List]
Data Loss: [None/Minimal/Description]

Post-Mortem: Scheduled for [Date/Time]
```

---

## Appendix: Critical Commands Reference

```bash
# State Management
terragrunt state pull > current.tfstate
terragrunt state push fixed.tfstate
terragrunt state rm google_compute_instance.corrupted
terragrunt import google_compute_instance.new existing-instance

# Backup Operations
gsutil -m rsync -r gs://prod-data gs://backup-prod-data
gcloud sql backups create --instance=prod-db --async

# Monitoring
gcloud monitoring dashboards list
gcloud logging read "severity>=ERROR" --limit=50
gcloud compute operations list --filter="status!=DONE"

# Emergency Access
gcloud auth login --no-launch-browser
gcloud config set project emergency-project
kubectl config use-context disaster-recovery
```

---

*Document Version: 1.0.0*
*Last Updated: 2024-01-15*
*Next Review: 2024-04-15*