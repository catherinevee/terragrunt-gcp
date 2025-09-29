# Terragrunt GCP Infrastructure Makefile
# Comprehensive build automation for Terraform/Terragrunt deployments

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Configuration
PROJECT_NAME := terragrunt-gcp
TERRAFORM_VERSION := $(shell cat .terraform-version 2>/dev/null || echo "1.5.0")
TERRAGRUNT_VERSION := $(shell cat .terragrunt-version 2>/dev/null || echo "0.48.0")
GO_VERSION := 1.21

# Directories
ROOT_DIR := $(shell pwd)
INFRASTRUCTURE_DIR := $(ROOT_DIR)/infrastructure
MODULES_DIR := $(ROOT_DIR)/modules
DOCS_DIR := $(ROOT_DIR)/docs
TEST_DIR := $(ROOT_DIR)/tests
CMD_DIR := $(ROOT_DIR)/cmd
INTERNAL_DIR := $(ROOT_DIR)/internal

# Environment detection
ENV ?= dev
REGION ?= us-central1
ACCOUNT_ID ?= $(shell gcloud config get-value account 2>/dev/null)
PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)

# Tools
TERRAFORM := terraform
TERRAGRUNT := terragrunt
GO := go
GCLOUD := gcloud
DOCKER := docker
CHECKOV := checkov
TFLINT := tflint
TFSEC := tfsec
INFRACOST := infracost
TERRAFORM_DOCS := terraform-docs

# Terraform/Terragrunt settings
TF_PLUGIN_CACHE_DIR := $(HOME)/.terraform.d/plugin-cache
TF_LOG ?=
TERRAGRUNT_DOWNLOAD := $(ROOT_DIR)/.terragrunt-cache
TERRAGRUNT_SOURCE_UPDATE := true
TERRAGRUNT_FETCH_DEPENDENCY_OUTPUT_FROM_STATE := true

# Export environment variables
export TF_PLUGIN_CACHE_DIR
export TERRAGRUNT_DOWNLOAD
export TERRAGRUNT_SOURCE_UPDATE
export TERRAGRUNT_FETCH_DEPENDENCY_OUTPUT_FROM_STATE

# Default target
.DEFAULT_GOAL := help

# Phony targets
.PHONY: help init validate plan apply destroy test lint security cost docs clean \
        install-tools check-tools fmt console graph state-pull state-push backup \
        monitor deploy-dev deploy-staging deploy-prod ci cd release version \
        docker-build docker-push docker-run integration-test e2e-test unit-test \
        benchmark profile debug logs metrics alerts dashboards

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n${CYAN}Usage:${NC}\n  make ${GREEN}<target>${NC}\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  ${GREEN}%-20s${NC} %s\n", $$1, $$2 } /^##@/ { printf "\n${CYAN}%s${NC}\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

version: ## Show version information
	@echo "${CYAN}=== Version Information ===${NC}"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Terraform: $(TERRAFORM_VERSION)"
	@echo "Terragrunt: $(TERRAGRUNT_VERSION)"
	@echo "Go: $(GO_VERSION)"
	@echo "Account: $(ACCOUNT_ID)"
	@echo "Project ID: $(PROJECT_ID)"
	@echo "Environment: $(ENV)"
	@echo "Region: $(REGION)"

##@ Installation

install-tools: ## Install required tools
	@echo "${CYAN}=== Installing Required Tools ===${NC}"
	@echo "Installing Terraform $(TERRAFORM_VERSION)..."
	@curl -sL https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_linux_amd64.zip -o /tmp/terraform.zip
	@unzip -q -o /tmp/terraform.zip -d /tmp && sudo mv /tmp/terraform /usr/local/bin/ && rm /tmp/terraform.zip
	@echo "Installing Terragrunt $(TERRAGRUNT_VERSION)..."
	@curl -sL https://github.com/gruntwork-io/terragrunt/releases/download/v$(TERRAGRUNT_VERSION)/terragrunt_linux_amd64 -o /tmp/terragrunt
	@chmod +x /tmp/terragrunt && sudo mv /tmp/terragrunt /usr/local/bin/
	@echo "Installing TFLint..."
	@curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
	@echo "Installing tfsec..."
	@go install github.com/aquasecurity/tfsec/cmd/tfsec@latest
	@echo "Installing Checkov..."
	@pip3 install --user checkov
	@echo "Installing Infracost..."
	@curl -sL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
	@echo "Installing terraform-docs..."
	@go install github.com/terraform-docs/terraform-docs@latest
	@echo "${GREEN}✓ All tools installed successfully${NC}"

check-tools: ## Check if required tools are installed
	@echo "${CYAN}=== Checking Required Tools ===${NC}"
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo "${RED}✗ terraform not found${NC}"; exit 1; }
	@command -v $(TERRAGRUNT) >/dev/null 2>&1 || { echo "${RED}✗ terragrunt not found${NC}"; exit 1; }
	@command -v $(GO) >/dev/null 2>&1 || { echo "${RED}✗ go not found${NC}"; exit 1; }
	@command -v $(GCLOUD) >/dev/null 2>&1 || { echo "${RED}✗ gcloud not found${NC}"; exit 1; }
	@echo "${GREEN}✓ All required tools are installed${NC}"

##@ Initialization

init: check-tools ## Initialize Terraform/Terragrunt
	@echo "${CYAN}=== Initializing Terraform/Terragrunt ===${NC}"
	@mkdir -p $(TF_PLUGIN_CACHE_DIR)
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all init --terragrunt-non-interactive
	@echo "${GREEN}✓ Initialization complete${NC}"

init-backend: ## Initialize backend configuration
	@echo "${CYAN}=== Initializing Backend ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV)/global && \
		$(TERRAFORM) init -backend=true -reconfigure
	@echo "${GREEN}✓ Backend initialization complete${NC}"

init-upgrade: ## Upgrade providers and modules
	@echo "${CYAN}=== Upgrading Providers and Modules ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all init -upgrade --terragrunt-non-interactive
	@echo "${GREEN}✓ Upgrade complete${NC}"

##@ Validation

validate: ## Validate Terraform configuration
	@echo "${CYAN}=== Validating Configuration ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all validate --terragrunt-non-interactive
	@echo "${GREEN}✓ Validation successful${NC}"

fmt: ## Format Terraform files
	@echo "${CYAN}=== Formatting Terraform Files ===${NC}"
	@$(TERRAFORM) fmt -recursive $(ROOT_DIR)
	@$(TERRAGRUNT) hclfmt $(INFRASTRUCTURE_DIR)
	@echo "${GREEN}✓ Formatting complete${NC}"

fmt-check: ## Check Terraform formatting
	@echo "${CYAN}=== Checking Terraform Formatting ===${NC}"
	@$(TERRAFORM) fmt -check -recursive $(ROOT_DIR) || \
		{ echo "${RED}✗ Formatting issues found. Run 'make fmt' to fix.${NC}"; exit 1; }
	@echo "${GREEN}✓ All files properly formatted${NC}"

lint: fmt-check ## Run linting checks
	@echo "${CYAN}=== Running Linting Checks ===${NC}"
	@$(TFLINT) --init
	@find $(MODULES_DIR) -type f -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Linting $$dir..."; \
		$(TFLINT) --config=$(ROOT_DIR)/.tflint.hcl $$dir || exit 1; \
	done
	@echo "${GREEN}✓ Linting complete${NC}"

##@ Planning

plan: validate ## Create execution plan
	@echo "${CYAN}=== Creating Execution Plan ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all plan --terragrunt-non-interactive -out=tfplan
	@echo "${GREEN}✓ Plan created successfully${NC}"

plan-target: ## Plan specific resource (use TARGET=resource.name)
	@echo "${CYAN}=== Planning Target: $(TARGET) ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) plan -target=$(TARGET) --terragrunt-non-interactive
	@echo "${GREEN}✓ Target plan complete${NC}"

plan-destroy: ## Plan destroy operation
	@echo "${CYAN}=== Planning Destroy Operation ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all plan -destroy --terragrunt-non-interactive
	@echo "${GREEN}✓ Destroy plan complete${NC}"

##@ Deployment

apply: plan ## Apply Terraform changes
	@echo "${YELLOW}=== Applying Changes to $(ENV) ===${NC}"
	@read -p "Are you sure you want to apply changes? [y/N]: " confirm && \
		[[ $$confirm == [yY] ]] || exit 1
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all apply --terragrunt-non-interactive --terragrunt-parallelism 4
	@echo "${GREEN}✓ Apply complete${NC}"

apply-auto-approve: ## Apply changes without confirmation
	@echo "${YELLOW}=== Auto-Applying Changes to $(ENV) ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all apply --terragrunt-non-interactive --terragrunt-parallelism 4 -auto-approve
	@echo "${GREEN}✓ Apply complete${NC}"

apply-target: ## Apply specific resource (use TARGET=resource.name)
	@echo "${YELLOW}=== Applying Target: $(TARGET) ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) apply -target=$(TARGET) --terragrunt-non-interactive
	@echo "${GREEN}✓ Target apply complete${NC}"

destroy: ## Destroy infrastructure
	@echo "${RED}=== DESTROYING $(ENV) INFRASTRUCTURE ===${NC}"
	@read -p "Are you ABSOLUTELY sure you want to destroy $(ENV)? Type 'destroy-$(ENV)': " confirm && \
		[[ $$confirm == "destroy-$(ENV)" ]] || exit 1
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) run-all destroy --terragrunt-non-interactive
	@echo "${GREEN}✓ Destroy complete${NC}"

destroy-target: ## Destroy specific resource (use TARGET=resource.name)
	@echo "${RED}=== Destroying Target: $(TARGET) ===${NC}"
	@read -p "Are you sure you want to destroy $(TARGET)? [y/N]: " confirm && \
		[[ $$confirm == [yY] ]] || exit 1
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) destroy -target=$(TARGET) --terragrunt-non-interactive
	@echo "${GREEN}✓ Target destroy complete${NC}"

##@ Environment Deployment

deploy-dev: ## Deploy to development environment
	@$(MAKE) apply ENV=dev REGION=us-central1

deploy-staging: ## Deploy to staging environment
	@$(MAKE) apply ENV=staging REGION=us-east1

deploy-prod: ## Deploy to production environment
	@echo "${RED}=== PRODUCTION DEPLOYMENT ===${NC}"
	@read -p "Deploy to PRODUCTION? Type 'deploy-prod': " confirm && \
		[[ $$confirm == "deploy-prod" ]] || exit 1
	@$(MAKE) apply ENV=prod REGION=us-west1

##@ State Management

state-list: ## List resources in state
	@echo "${CYAN}=== State Resources ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state list

state-show: ## Show specific resource state (use RESOURCE=name)
	@echo "${CYAN}=== State for $(RESOURCE) ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state show $(RESOURCE)

state-pull: ## Pull and display remote state
	@echo "${CYAN}=== Pulling Remote State ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state pull > terraform.tfstate.backup
	@echo "${GREEN}✓ State pulled to terraform.tfstate.backup${NC}"

state-push: ## Push local state to remote
	@echo "${YELLOW}=== Pushing State ===${NC}"
	@read -p "Are you sure you want to push state? [y/N]: " confirm && \
		[[ $$confirm == [yY] ]] || exit 1
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state push terraform.tfstate.backup

state-rm: ## Remove resource from state (use RESOURCE=name)
	@echo "${YELLOW}=== Removing $(RESOURCE) from State ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state rm $(RESOURCE)

state-mv: ## Move resource in state (use SOURCE=old TARGET=new)
	@echo "${YELLOW}=== Moving $(SOURCE) to $(TARGET) ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state mv $(SOURCE) $(TARGET)

refresh: ## Refresh state with actual infrastructure
	@echo "${CYAN}=== Refreshing State ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) refresh --terragrunt-non-interactive
	@echo "${GREEN}✓ State refreshed${NC}"

##@ Security & Compliance

security: ## Run security scans
	@echo "${CYAN}=== Running Security Scans ===${NC}"
	@echo "Running tfsec..."
	@$(TFSEC) $(MODULES_DIR) --format default --soft-fail
	@echo "Running Checkov..."
	@$(CHECKOV) -d $(MODULES_DIR) --framework terraform --quiet --compact
	@echo "${GREEN}✓ Security scans complete${NC}"

compliance: ## Check compliance policies
	@echo "${CYAN}=== Checking Compliance ===${NC}"
	@cd $(ROOT_DIR) && \
		go run cmd/validate/main.go --compliance
	@echo "${GREEN}✓ Compliance check complete${NC}"

secrets-scan: ## Scan for exposed secrets
	@echo "${CYAN}=== Scanning for Secrets ===${NC}"
	@git secrets --scan -r $(ROOT_DIR) || true
	@echo "${GREEN}✓ Secrets scan complete${NC}"

##@ Cost Management

cost: ## Estimate infrastructure costs
	@echo "${CYAN}=== Estimating Costs ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(INFRACOST) breakdown --path . \
			--format table \
			--show-skipped
	@echo "${GREEN}✓ Cost estimation complete${NC}"

cost-diff: ## Show cost difference
	@echo "${CYAN}=== Calculating Cost Difference ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(INFRACOST) diff --path .
	@echo "${GREEN}✓ Cost diff complete${NC}"

##@ Testing

test: unit-test integration-test ## Run all tests
	@echo "${GREEN}✓ All tests complete${NC}"

unit-test: ## Run unit tests
	@echo "${CYAN}=== Running Unit Tests ===${NC}"
	@cd $(ROOT_DIR) && \
		go test -v -race -coverprofile=coverage.out ./...
	@echo "${GREEN}✓ Unit tests complete${NC}"

integration-test: ## Run integration tests
	@echo "${CYAN}=== Running Integration Tests ===${NC}"
	@cd $(TEST_DIR)/integration && \
		go test -v -tags=integration -timeout 30m ./...
	@echo "${GREEN}✓ Integration tests complete${NC}"

e2e-test: ## Run end-to-end tests
	@echo "${CYAN}=== Running E2E Tests ===${NC}"
	@cd $(TEST_DIR)/e2e && \
		go test -v -tags=e2e -timeout 60m ./...
	@echo "${GREEN}✓ E2E tests complete${NC}"

test-modules: ## Test Terraform modules
	@echo "${CYAN}=== Testing Terraform Modules ===${NC}"
	@cd $(TEST_DIR) && \
		go test -v -timeout 30m ./unit/...
	@echo "${GREEN}✓ Module tests complete${NC}"

benchmark: ## Run performance benchmarks
	@echo "${CYAN}=== Running Benchmarks ===${NC}"
	@cd $(ROOT_DIR) && \
		go test -bench=. -benchmem ./...
	@echo "${GREEN}✓ Benchmarks complete${NC}"

##@ Documentation

docs: ## Generate documentation
	@echo "${CYAN}=== Generating Documentation ===${NC}"
	@for dir in $(shell find $(MODULES_DIR) -type f -name "*.tf" -exec dirname {} \; | sort -u); do \
		echo "Generating docs for $$dir..."; \
		$(TERRAFORM_DOCS) markdown table --output-file README.md $$dir; \
	done
	@echo "${GREEN}✓ Documentation generated${NC}"

docs-serve: ## Serve documentation locally
	@echo "${CYAN}=== Serving Documentation ===${NC}"
	@cd $(DOCS_DIR) && \
		python3 -m http.server 8000

graph: ## Generate dependency graph
	@echo "${CYAN}=== Generating Dependency Graph ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) graph | dot -Tsvg > $(DOCS_DIR)/graph-$(ENV).svg
	@echo "${GREEN}✓ Graph saved to docs/graph-$(ENV).svg${NC}"

##@ Monitoring

monitor: ## Check infrastructure health
	@echo "${CYAN}=== Checking Infrastructure Health ===${NC}"
	@cd $(ROOT_DIR) && \
		go run cmd/monitor/main.go --env $(ENV)
	@echo "${GREEN}✓ Health check complete${NC}"

logs: ## Tail infrastructure logs
	@echo "${CYAN}=== Tailing Logs ===${NC}"
	@gcloud logging tail "resource.type=gce_instance" --format=json --project=$(PROJECT_ID)

metrics: ## Display key metrics
	@echo "${CYAN}=== Key Metrics ===${NC}"
	@cd $(ROOT_DIR) && \
		go run cmd/analyze/main.go --metrics --env $(ENV)

alerts: ## Check active alerts
	@echo "${CYAN}=== Active Alerts ===${NC}"
	@gcloud alpha monitoring policies list --filter="enabled=true" --project=$(PROJECT_ID)

dashboards: ## Open monitoring dashboards
	@echo "${CYAN}=== Opening Dashboards ===${NC}"
	@open "https://console.cloud.google.com/monitoring/dashboards?project=$(PROJECT_ID)"

##@ Docker

docker-build: ## Build Docker images
	@echo "${CYAN}=== Building Docker Images ===${NC}"
	@$(DOCKER) build -t $(PROJECT_NAME):latest -t $(PROJECT_NAME):$(shell git rev-parse --short HEAD) .
	@echo "${GREEN}✓ Docker build complete${NC}"

docker-push: ## Push Docker images
	@echo "${CYAN}=== Pushing Docker Images ===${NC}"
	@$(DOCKER) push $(PROJECT_NAME):latest
	@$(DOCKER) push $(PROJECT_NAME):$(shell git rev-parse --short HEAD)
	@echo "${GREEN}✓ Docker push complete${NC}"

docker-run: ## Run Docker container locally
	@echo "${CYAN}=== Running Docker Container ===${NC}"
	@$(DOCKER) run -it --rm \
		-v $(ROOT_DIR):/workspace \
		-e ENV=$(ENV) \
		$(PROJECT_NAME):latest

##@ Utilities

console: ## Open Terraform console
	@echo "${CYAN}=== Opening Terraform Console ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) console

shell: ## Open interactive shell
	@echo "${CYAN}=== Opening Interactive Shell ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		bash

clean: ## Clean temporary files
	@echo "${CYAN}=== Cleaning Temporary Files ===${NC}"
	@find $(ROOT_DIR) -type f -name "*.tfplan" -delete
	@find $(ROOT_DIR) -type f -name "*.tfstate.backup" -delete
	@find $(ROOT_DIR) -type f -name ".terraform.lock.hcl" -delete
	@find $(ROOT_DIR) -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find $(ROOT_DIR) -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf $(ROOT_DIR)/.infracost
	@echo "${GREEN}✓ Cleanup complete${NC}"

backup: ## Backup state and configuration
	@echo "${CYAN}=== Creating Backup ===${NC}"
	@mkdir -p $(ROOT_DIR)/backups/$(shell date +%Y%m%d_%H%M%S)
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		$(TERRAGRUNT) state pull > $(ROOT_DIR)/backups/$(shell date +%Y%m%d_%H%M%S)/terraform.tfstate
	@tar czf $(ROOT_DIR)/backups/backup-$(ENV)-$(shell date +%Y%m%d_%H%M%S).tar.gz \
		--exclude='.terragrunt-cache' \
		--exclude='.terraform' \
		$(INFRASTRUCTURE_DIR)
	@echo "${GREEN}✓ Backup created in backups/${NC}"

restore: ## Restore from backup (use BACKUP=filename)
	@echo "${YELLOW}=== Restoring from Backup ===${NC}"
	@read -p "Are you sure you want to restore from $(BACKUP)? [y/N]: " confirm && \
		[[ $$confirm == [yY] ]] || exit 1
	@tar xzf $(ROOT_DIR)/backups/$(BACKUP) -C /
	@echo "${GREEN}✓ Restore complete${NC}"

##@ CI/CD

ci: fmt-check lint security test ## Run CI pipeline
	@echo "${GREEN}✓ CI pipeline complete${NC}"

cd: ci deploy-$(ENV) ## Run CD pipeline
	@echo "${GREEN}✓ CD pipeline complete${NC}"

release: ## Create release
	@echo "${CYAN}=== Creating Release ===${NC}"
	@read -p "Release version (e.g., v1.0.0): " version && \
		git tag -a $$version -m "Release $$version" && \
		git push origin $$version
	@echo "${GREEN}✓ Release created${NC}"

##@ Development

dev-setup: install-tools ## Setup development environment
	@echo "${CYAN}=== Setting Up Development Environment ===${NC}"
	@go mod download
	@pre-commit install
	@echo "${GREEN}✓ Development environment ready${NC}"

debug: ## Enable debug mode
	@echo "${CYAN}=== Debug Mode Enabled ===${NC}"
	@export TF_LOG=DEBUG
	@export TERRAGRUNT_DEBUG=true
	@$(MAKE) plan

profile: ## Profile Terraform execution
	@echo "${CYAN}=== Profiling Terraform ===${NC}"
	@cd $(INFRASTRUCTURE_DIR)/environments/$(ENV) && \
		TF_LOG=TRACE $(TERRAGRUNT) plan --terragrunt-log-level debug 2>&1 | tee profile.log
	@echo "${GREEN}✓ Profile saved to profile.log${NC}"

watch: ## Watch for changes and validate
	@echo "${CYAN}=== Watching for Changes ===${NC}"
	@while true; do \
		find $(MODULES_DIR) -name "*.tf" | entr -d make validate; \
	done