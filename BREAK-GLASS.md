# Break-Glass Emergency Access Procedures

## Overview

Break-glass procedures provide emergency access to critical systems when normal access methods fail. These procedures should only be used in genuine emergencies and all usage is audited.

---

## When to Use Break-Glass Access

### Qualifying Scenarios
- ✅ Production outage with normal access failure
- ✅ Security incident requiring immediate response
- ✅ Critical data recovery operation
- ✅ Compliance audit emergency request
- ✅ Disaster recovery activation

### NOT for These Scenarios
- ❌ Convenience or speed
- ❌ Bypassing change management
- ❌ Regular maintenance
- ❌ Development or testing
- ❌ Personal access issues (use IT support)

---

## Break-Glass Procedures by System

### 1. GCP Project Owner Access

#### Prerequisites
- Physical access to secure vault
- Two-person authentication
- Incident ticket number

#### Procedure
```bash
# Step 1: Retrieve emergency credentials from vault
# Location: Physical safe in Security Office
# Combination: Known to CTO and Security Lead

# Step 2: Document access reason
echo "$(date): Break-glass access initiated
Incident: INC-XXXXX
Reason: [Detailed reason]
Authorized by: [Name]
Witnessed by: [Name]" >> /secure/break-glass-log.txt

# Step 3: Activate emergency service account
gcloud auth activate-service-account \
  emergency-owner@project.iam.gserviceaccount.com \
  --key-file=/secure/emergency-key.json

# Step 4: Set project
gcloud config set project production-project

# Step 5: Perform emergency actions
# [Document all commands executed]

# Step 6: Deactivate access
gcloud auth revoke emergency-owner@project.iam.gserviceaccount.com

# Step 7: Rotate credentials
./scripts/security/rotate-emergency-credentials.sh
```

#### Post-Access
1. File incident report within 1 hour
2. Security review within 24 hours
3. Rotate all emergency credentials
4. Update audit log

---

### 2. Terraform State Emergency Access

#### Scenario: State Lock Override

```bash
#!/bin/bash
# DANGER: Only use when state is locked and blocking critical fixes

# Step 1: Verify lock status
gsutil cat gs://terraform-state-prod/.terraform.lock.hcl

# Step 2: Document override reason
cat << EOF > break-glass-override.log
Date: $(date)
Operator: $(whoami)
Reason: State locked, production down
Lock ID: [paste lock ID]
Incident: INC-XXXXX
EOF

# Step 3: Force unlock (requires approval)
read -p "Type 'OVERRIDE' to confirm: " confirmation
if [ "$confirmation" = "OVERRIDE" ]; then
  terragrunt force-unlock [LOCK_ID] \
    --terragrunt-working-dir=infrastructure/environments/prod
fi

# Step 4: Apply critical fix
terragrunt apply --auto-approve \
  --target=module.critical_fix

# Step 5: Notify team
./scripts/notify-team.sh "Break-glass state unlock used for INC-XXXXX"
```

#### Scenario: State Deletion (EXTREME CAUTION)

```bash
# LAST RESORT: Only when state is irreparably corrupted

# Requires two-person approval
echo "Enter approval codes:"
read -s -p "Approver 1: " code1
read -s -p "Approver 2: " code2

if [ "$code1" = "$EMERGENCY_CODE_1" ] && [ "$code2" = "$EMERGENCY_CODE_2" ]; then
  # Backup everything first
  gsutil -m cp -r gs://terraform-state-prod/* ./emergency-backup/
  
  # Delete corrupted state
  gsutil rm gs://terraform-state-prod/corrupted.tfstate
  
  # Rebuild from scratch
  terragrunt init -reconfigure
  ./scripts/import-all-resources.sh
fi
```

---

### 3. Database Emergency Access

#### Root Password Recovery

```sql
-- Prerequisites: Cloud SQL Admin API access

-- Step 1: Reset root password via API
gcloud sql users set-password postgres \
  --instance=prod-database \
  --password=$(openssl rand -base64 32)

-- Step 2: Connect with new password
gcloud sql connect prod-database --user=postgres

-- Step 3: Create temporary admin user
CREATE USER emergency_admin WITH 
  SUPERUSER 
  ENCRYPTED PASSWORD 'temp_password_change_immediately'
  VALID UNTIL 'tomorrow';

-- Step 4: Audit all actions
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

-- Step 5: After emergency
DROP USER emergency_admin;
ALTER SYSTEM RESET log_statement;
```

#### Bypass Row-Level Security

```sql
-- DANGER: Bypasses all security policies

-- Requires superuser access
SET LOCAL row_security = off;

-- Perform emergency operations
UPDATE critical_table SET status = 'recovered' 
WHERE corruption_flag = true;

-- Re-enable immediately
RESET row_security;

-- Audit log
INSERT INTO audit_log (action, user, timestamp, reason)
VALUES ('break_glass_rls_bypass', current_user, now(), 'INC-XXXXX');
```

---

### 4. Kubernetes Emergency Access

#### Cluster Admin Access

```bash
# When RBAC is blocking critical fixes

# Step 1: Create emergency context
kubectl config set-context emergency --cluster=prod-cluster

# Step 2: Apply emergency admin binding
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: emergency-admin-access
  annotations:
    expires: "$(date -d '+1 hour' --iso-8601)"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: emergency@company.com
  apiGroup: rbac.authorization.k8s.io
EOF

# Step 3: Perform emergency actions
kubectl --context=emergency [emergency commands]

# Step 4: Revoke access
kubectl delete clusterrolebinding emergency-admin-access

# Step 5: Audit
kubectl get events --all-namespaces \
  --field-selector reason=EmergencyAccess \
  -o json > emergency-audit.json
```

#### Pod Security Policy Override

```yaml
# emergency-psp-override.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: emergency-privileged
  annotations:
    emergency-use-only: "true"
    expires: "1h"
    incident: "INC-XXXXX"
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

---

### 5. Network Emergency Access

#### Firewall Rule Override

```bash
# When locked out of systems

# Step 1: Create emergency ingress rule
gcloud compute firewall-rules create emergency-access \
  --direction=INGRESS \
  --priority=0 \
  --action=ALLOW \
  --rules=tcp:22,tcp:443 \
  --source-ranges=$(curl -s ifconfig.me)/32 \
  --target-tags=emergency \
  --description="Emergency access for INC-XXXXX. Expires: $(date -d '+1 hour')"

# Step 2: Apply tag to instance
gcloud compute instances add-tags problem-instance \
  --tags=emergency \
  --zone=us-central1-a

# Step 3: Connect and fix
ssh emergency@instance

# Step 4: Remove access
gcloud compute firewall-rules delete emergency-access
gcloud compute instances remove-tags problem-instance \
  --tags=emergency \
  --zone=us-central1-a
```

---

## Emergency Codes and Credentials

### Secure Storage Locations

| Credential Type | Location | Access Required |
|----------------|----------|-----------------|
| GCP Emergency SA Key | Physical Vault | CTO + Security Lead |
| Database Root Password | HSM | DBA Lead + CTO |
| Kubernetes Break-Glass Token | Encrypted USB | Platform Lead + Security |
| Network Override Codes | Safety Deposit Box | CEO + CTO |
| State Unlock Codes | Distributed (3 parts) | Any 2 of 3 executives |

### Code Generation

```bash
#!/bin/bash
# Generate new emergency codes (run quarterly)

# Generate codes
CODE1=$(openssl rand -hex 32)
CODE2=$(openssl rand -hex 32)
CODE3=$(openssl rand -hex 32)

# Encrypt and distribute
echo $CODE1 | gpg --encrypt -r cto@company.com > code1.gpg
echo $CODE2 | gpg --encrypt -r security@company.com > code2.gpg
echo $CODE3 | gpg --encrypt -r platform@company.com > code3.gpg

# Store hashes for verification
echo $CODE1 | sha256sum > /secure/code1.hash
echo $CODE2 | sha256sum > /secure/code2.hash
echo $CODE3 | sha256sum > /secure/code3.hash

# Clean up
unset CODE1 CODE2 CODE3
```

---

## Audit and Compliance

### Required Documentation

For EVERY break-glass access:

1. **Pre-Access**
   - Incident ticket number
   - Business justification
   - Risk assessment
   - Approval evidence

2. **During Access**
   - Start/end timestamps
   - All commands executed
   - Systems accessed
   - Data modified

3. **Post-Access**
   - Changes made
   - Systems affected
   - Credentials rotated
   - Lessons learned

### Audit Log Template

```json
{
  "event": "break-glass-access",
  "timestamp": "2024-01-15T14:30:00Z",
  "incident_id": "INC-12345",
  "operator": "john.doe@company.com",
  "approvers": [
    "cto@company.com",
    "security@company.com"
  ],
  "system": "gcp-production",
  "access_type": "project-owner",
  "duration_minutes": 45,
  "actions": [
    "Reset service account key",
    "Modified firewall rule",
    "Restarted compute instances"
  ],
  "justification": "Production database unreachable, normal access methods failed",
  "outcome": "successful",
  "follow_up_required": true,
  "post_incident_review": "2024-01-16T10:00:00Z"
}
```

---

## Automation Scripts

### Break-Glass Access Logger

```python
#!/usr/bin/env python3
# scripts/break-glass-logger.py

import json
import time
import subprocess
from datetime import datetime
import hashlib

class BreakGlassLogger:
    def __init__(self, incident_id):
        self.incident_id = incident_id
        self.start_time = datetime.utcnow()
        self.actions = []
        self.session_id = hashlib.sha256(
            f"{incident_id}{time.time()}".encode()
        ).hexdigest()[:8]
    
    def log_action(self, action, result="success"):
        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "action": action,
            "result": result
        }
        self.actions.append(entry)
        
        # Real-time logging
        with open(f"/var/log/break-glass/{self.session_id}.log", "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def execute_with_audit(self, command):
        """Execute command with full auditing"""
        self.log_action(f"Executing: {command}")
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True
            )
            
            self.log_action(
                f"Command completed: {command}",
                "success" if result.returncode == 0 else "failed"
            )
            
            return result
        except Exception as e:
            self.log_action(f"Command failed: {command}", f"error: {str(e)}")
            raise
    
    def finalize(self):
        """Complete audit log and trigger notifications"""
        duration = (datetime.utcnow() - self.start_time).seconds
        
        final_log = {
            "session_id": self.session_id,
            "incident_id": self.incident_id,
            "start_time": self.start_time.isoformat(),
            "duration_seconds": duration,
            "total_actions": len(self.actions),
            "actions": self.actions
        }
        
        # Store permanent record
        with open(f"/secure/audit/break-glass-{self.session_id}.json", "w") as f:
            json.dump(final_log, f, indent=2)
        
        # Send notifications
        self._notify_security_team(final_log)
        
        return self.session_id
    
    def _notify_security_team(self, log_data):
        """Send audit notification to security team"""
        # Implementation would send to SIEM, email, Slack, etc.
        pass

# Usage
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: break-glass-logger.py <incident-id>")
        sys.exit(1)
    
    logger = BreakGlassLogger(sys.argv[1])
    
    try:
        # Wrap all emergency commands
        logger.execute_with_audit("gcloud config set project production")
        logger.execute_with_audit("kubectl get pods --all-namespaces")
        # ... more emergency commands
    finally:
        session_id = logger.finalize()
        print(f"Break-glass session logged: {session_id}")
```

---

## Recovery Procedures

### After Break-Glass Usage

1. **Immediate (Within 1 Hour)**
   - Revoke emergency access
   - Document all changes
   - Notify security team
   - Begin credential rotation

2. **Short-term (Within 24 Hours)**
   - Complete incident report
   - Rotate all affected credentials
   - Review audit logs
   - Patch normal access methods

3. **Long-term (Within 1 Week)**
   - Post-incident review
   - Update procedures if needed
   - Security assessment
   - Compliance reporting

### Credential Rotation Checklist

- [ ] Service account keys
- [ ] Database passwords
- [ ] API tokens
- [ ] SSH keys
- [ ] TLS certificates
- [ ] Kubernetes tokens
- [ ] Emergency access codes
- [ ] Vault passwords

---

## Testing and Validation

### Quarterly Break-Glass Drill

```bash
#!/bin/bash
# Quarterly test of break-glass procedures

echo "=== Break-Glass Drill ==="
echo "Date: $(date)"
echo "Tester: $USER"

# Test 1: Verify emergency credentials exist
echo "Test 1: Checking emergency credentials..."
if [ -f /secure/emergency-key.json.gpg ]; then
  echo "✅ Emergency key file exists"
else
  echo "❌ Emergency key file missing"
fi

# Test 2: Validate approval process
echo "Test 2: Testing approval workflow..."
./scripts/test-approval-workflow.sh

# Test 3: Audit logging
echo "Test 3: Testing audit logging..."
./scripts/break-glass-logger.py TEST-DRILL

# Test 4: Notification system
echo "Test 4: Testing notifications..."
./scripts/test-notifications.sh

# Generate report
echo "Generating drill report..."
./scripts/generate-drill-report.sh > drill-report-$(date +%Y%m%d).txt

echo "Drill completed. Review report for any issues."
```

---

## Contact Information

### Emergency Contacts (24/7)

| Role | Primary | Secondary |
|------|---------|-----------|
| Incident Commander | +1-xxx-xxx-xxxx | +1-xxx-xxx-xxxx |
| Security Lead | +1-xxx-xxx-xxxx | +1-xxx-xxx-xxxx |
| Platform Lead | +1-xxx-xxx-xxxx | +1-xxx-xxx-xxxx |
| Database Admin | +1-xxx-xxx-xxxx | +1-xxx-xxx-xxxx |
| Network Admin | +1-xxx-xxx-xxxx | +1-xxx-xxx-xxxx |
| Google Cloud Support | +1-xxx-xxx-xxxx | (Priority Support) |

### Escalation Path

1. Team Lead (5 minutes)
2. Department Head (10 minutes)
3. CTO (15 minutes)
4. CEO (30 minutes)

---

*Document Classification: CONFIDENTIAL*
*Version: 1.0.0*
*Last Updated: 2024-01-15*
*Next Review: 2024-04-15*
*Owner: Security Team*