# Scripts

## Available Scripts

### setup-secrets.sh / setup-secrets.ps1
Configure GitHub secrets for the repository.

```bash
# Linux/Mac
./scripts/setup-secrets.sh

# Windows
.\scripts\setup-secrets.ps1
```

### test-workflows.sh
Test all GitHub workflows for validity.

```bash
./scripts/test-workflows.sh
```

### cleanup-repository.sh
Reorganize repository structure (this script).

```bash
DRY_RUN=true ./scripts/cleanup-repository.sh  # Preview changes
DRY_RUN=false ./scripts/cleanup-repository.sh # Execute changes
```
