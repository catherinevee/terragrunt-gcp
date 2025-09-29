package config

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/hashicorp/go-version"
)

type Validator struct {
	config *Config
	errors []ValidationError
}

type ValidationError struct {
	Field    string
	Value    interface{}
	Message  string
	Severity string
}

type ValidationRule struct {
	Name      string
	Field     string
	Validator func(interface{}) error
	Severity  string
}

func NewValidator(cfg *Config) *Validator {
	return &Validator{
		config: cfg,
		errors: make([]ValidationError, 0),
	}
}

func (v *Validator) Validate(ctx context.Context) error {
	v.errors = make([]ValidationError, 0)

	rules := v.getValidationRules()
	for _, rule := range rules {
		if err := v.validateRule(rule); err != nil {
			v.addError(rule.Field, nil, err.Error(), rule.Severity)
		}
	}

	v.validateProject()
	v.validateRegion()
	v.validateZone()
	v.validateEnvironment()
	v.validateTerraform()
	v.validateTerragrunt()
	v.validateBackend()
	v.validateProviders()
	v.validateModules()
	v.validateAuthentication()
	v.validateMonitoring()
	v.validateSecurity()
	v.validateNetwork()
	v.validateFeatures()
	v.validateDependencies()
	v.validateHooks()
	v.validateOutputs()
	v.validateTags()

	if len(v.errors) > 0 {
		return v.formatErrors()
	}

	return nil
}

func (v *Validator) getValidationRules() []ValidationRule {
	return []ValidationRule{
		{
			Name:     "project_format",
			Field:    "project",
			Validator: v.validateProjectFormat,
			Severity: "error",
		},
		{
			Name:     "region_format",
			Field:    "region",
			Validator: v.validateRegionFormat,
			Severity: "error",
		},
		{
			Name:     "zone_format",
			Field:    "zone",
			Validator: v.validateZoneFormat,
			Severity: "error",
		},
		{
			Name:     "environment_format",
			Field:    "environment",
			Validator: v.validateEnvironmentFormat,
			Severity: "warning",
		},
		{
			Name:     "backend_bucket",
			Field:    "backend.bucket",
			Validator: v.validateBucketName,
			Severity: "error",
		},
		{
			Name:     "terraform_version",
			Field:    "terraform.version",
			Validator: v.validateVersion,
			Severity: "warning",
		},
		{
			Name:     "terragrunt_version",
			Field:    "terragrunt.version",
			Validator: v.validateVersion,
			Severity: "warning",
		},
	}
}

func (v *Validator) validateRule(rule ValidationRule) error {
	value := v.getFieldValue(rule.Field)
	if value == nil {
		return nil
	}
	return rule.Validator(value)
}

func (v *Validator) getFieldValue(field string) interface{} {
	parts := strings.Split(field, ".")
	if len(parts) == 0 {
		return nil
	}

	switch parts[0] {
	case "project":
		return v.config.Project
	case "region":
		return v.config.Region
	case "zone":
		return v.config.Zone
	case "environment":
		return v.config.Environment
	case "backend":
		if len(parts) > 1 && parts[1] == "bucket" {
			return v.config.Backend.Bucket
		}
	case "terraform":
		if len(parts) > 1 && parts[1] == "version" {
			return v.config.Terraform.Version
		}
	case "terragrunt":
		if len(parts) > 1 && parts[1] == "version" {
			return v.config.Terragrunt.Version
		}
	}

	return nil
}

func (v *Validator) validateProject() {
	if v.config.Project == "" {
		v.addError("project", "", "Project ID is required", "error")
		return
	}

	if len(v.config.Project) < 6 || len(v.config.Project) > 30 {
		v.addError("project", v.config.Project, "Project ID must be between 6 and 30 characters", "error")
	}

	if !regexp.MustCompile(`^[a-z][a-z0-9-]*[a-z0-9]$`).MatchString(v.config.Project) {
		v.addError("project", v.config.Project, "Project ID must start with lowercase letter and contain only lowercase letters, numbers, and hyphens", "error")
	}
}

func (v *Validator) validateRegion() {
	if v.config.Region == "" {
		v.addError("region", "", "Region is required", "error")
		return
	}

	validRegions := []string{
		"us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
		"europe-central2", "europe-north1", "europe-west1", "europe-west2", "europe-west3",
		"europe-west4", "europe-west6", "europe-west8", "europe-west9", "europe-west12",
		"asia-east1", "asia-east2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
		"asia-south1", "asia-south2", "asia-southeast1", "asia-southeast2",
		"australia-southeast1", "australia-southeast2",
		"northamerica-northeast1", "northamerica-northeast2",
		"southamerica-east1", "southamerica-west1",
		"africa-south1",
		"me-west1", "me-central1",
	}

	valid := false
	for _, r := range validRegions {
		if v.config.Region == r {
			valid = true
			break
		}
	}

	if !valid {
		v.addError("region", v.config.Region, "Invalid GCP region", "error")
	}
}

func (v *Validator) validateZone() {
	if v.config.Zone != "" {
		if !strings.HasPrefix(v.config.Zone, v.config.Region) {
			v.addError("zone", v.config.Zone, fmt.Sprintf("Zone must be in region %s", v.config.Region), "error")
		}

		if !regexp.MustCompile(`^[a-z]+-[a-z0-9]+-[a-z]$`).MatchString(v.config.Zone) {
			v.addError("zone", v.config.Zone, "Invalid zone format", "error")
		}
	}
}

func (v *Validator) validateEnvironment() {
	validEnvs := []string{"dev", "development", "test", "testing", "qa", "staging", "prod", "production"}
	if v.config.Environment != "" {
		valid := false
		for _, env := range validEnvs {
			if strings.ToLower(v.config.Environment) == env {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("environment", v.config.Environment, "Environment should be one of: dev, test, qa, staging, prod", "warning")
		}
	}
}

func (v *Validator) validateTerraform() {
	tf := &v.config.Terraform

	if tf.Version != "" {
		if err := v.validateVersion(tf.Version); err != nil {
			v.addError("terraform.version", tf.Version, err.Error(), "warning")
		}
	}

	if tf.WorkingDir != "" && !filepath.IsAbs(tf.WorkingDir) {
		if _, err := os.Stat(tf.WorkingDir); os.IsNotExist(err) {
			v.addError("terraform.working_dir", tf.WorkingDir, "Working directory does not exist", "warning")
		}
	}

	if tf.Parallelism < 1 || tf.Parallelism > 1000 {
		v.addError("terraform.parallelism", tf.Parallelism, "Parallelism must be between 1 and 1000", "error")
	}

	if tf.LockTimeout != "" {
		if _, err := time.ParseDuration(tf.LockTimeout); err != nil {
			v.addError("terraform.lock_timeout", tf.LockTimeout, "Invalid duration format", "error")
		}
	}

	if tf.StateFile != "" && !strings.HasSuffix(tf.StateFile, ".tfstate") {
		v.addError("terraform.state_file", tf.StateFile, "State file should have .tfstate extension", "warning")
	}

	if tf.PlanFile != "" && !strings.HasSuffix(tf.PlanFile, ".tfplan") {
		v.addError("terraform.plan_file", tf.PlanFile, "Plan file should have .tfplan extension", "warning")
	}
}

func (v *Validator) validateTerragrunt() {
	tg := &v.config.Terragrunt

	if tg.Version != "" {
		if err := v.validateVersion(tg.Version); err != nil {
			v.addError("terragrunt.version", tg.Version, err.Error(), "warning")
		}
	}

	if tg.ConfigFile != "" && !strings.HasSuffix(tg.ConfigFile, ".hcl") {
		v.addError("terragrunt.config_file", tg.ConfigFile, "Config file should have .hcl extension", "warning")
	}

	if tg.MaxRetries < 0 || tg.MaxRetries > 100 {
		v.addError("terragrunt.max_retries", tg.MaxRetries, "Max retries must be between 0 and 100", "error")
	}

	if tg.SleepInterval < 0 || tg.SleepInterval > 3600 {
		v.addError("terragrunt.sleep_interval", tg.SleepInterval, "Sleep interval must be between 0 and 3600 seconds", "error")
	}

	if tg.Parallelism < 1 || tg.Parallelism > 100 {
		v.addError("terragrunt.parallelism", tg.Parallelism, "Parallelism must be between 1 and 100", "error")
	}

	for _, err := range tg.RetryableErrors {
		if _, compileErr := regexp.Compile(err); compileErr != nil {
			v.addError("terragrunt.retryable_errors", err, fmt.Sprintf("Invalid regex pattern: %v", compileErr), "error")
		}
	}
}

func (v *Validator) validateBackend() {
	b := &v.config.Backend

	if b.Type == "" {
		v.addError("backend.type", "", "Backend type is required", "error")
		return
	}

	validTypes := []string{"gcs", "local", "remote", "s3", "azurerm", "consul", "etcd", "http"}
	valid := false
	for _, t := range validTypes {
		if b.Type == t {
			valid = true
			break
		}
	}

	if !valid {
		v.addError("backend.type", b.Type, "Invalid backend type", "error")
	}

	if b.Type == "gcs" {
		if b.Bucket == "" {
			v.addError("backend.bucket", "", "Bucket is required for GCS backend", "error")
		} else if err := v.validateBucketName(b.Bucket); err != nil {
			v.addError("backend.bucket", b.Bucket, err.Error(), "error")
		}

		if b.Prefix != "" && strings.HasPrefix(b.Prefix, "/") {
			v.addError("backend.prefix", b.Prefix, "Prefix should not start with /", "warning")
		}

		if b.KMSKeyID != "" && !strings.HasPrefix(b.KMSKeyID, "projects/") {
			v.addError("backend.kms_key_id", b.KMSKeyID, "KMS key should be in format: projects/PROJECT/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY", "warning")
		}
	}
}

func (v *Validator) validateProviders() {
	for name, provider := range v.config.Providers {
		if provider.Source == "" {
			v.addError(fmt.Sprintf("providers.%s.source", name), "", "Provider source is required", "error")
		}

		if provider.Version != "" {
			if _, err := version.NewConstraint(provider.Version); err != nil {
				v.addError(fmt.Sprintf("providers.%s.version", name), provider.Version, "Invalid version constraint", "error")
			}
		}

		if provider.Credentials != "" {
			if !filepath.IsAbs(provider.Credentials) {
				if _, err := os.Stat(provider.Credentials); os.IsNotExist(err) {
					v.addError(fmt.Sprintf("providers.%s.credentials", name), provider.Credentials, "Credentials file not found", "warning")
				}
			}
		}

		if provider.ImpersonateEmail != "" {
			if err := v.validateEmail(provider.ImpersonateEmail); err != nil {
				v.addError(fmt.Sprintf("providers.%s.impersonate_service_account", name), provider.ImpersonateEmail, err.Error(), "error")
			}
		}

		if provider.Region != "" {
			if err := v.validateRegionFormat(provider.Region); err != nil {
				v.addError(fmt.Sprintf("providers.%s.region", name), provider.Region, err.Error(), "error")
			}
		}
	}
}

func (v *Validator) validateModules() {
	moduleNames := make(map[string]bool)

	for i, module := range v.config.Modules {
		if module.Name == "" {
			v.addError(fmt.Sprintf("modules[%d].name", i), "", "Module name is required", "error")
			continue
		}

		if moduleNames[module.Name] {
			v.addError(fmt.Sprintf("modules[%d].name", i), module.Name, "Duplicate module name", "error")
		}
		moduleNames[module.Name] = true

		if module.Source == "" {
			v.addError(fmt.Sprintf("modules[%d].source", i), "", "Module source is required", "error")
		} else {
			v.validateModuleSource(module.Name, module.Source)
		}

		if module.Version != "" {
			if _, err := version.NewConstraint(module.Version); err != nil {
				v.addError(fmt.Sprintf("modules[%d].version", i), module.Version, "Invalid version constraint", "error")
			}
		}

		if module.Count < 0 {
			v.addError(fmt.Sprintf("modules[%d].count", i), module.Count, "Count cannot be negative", "error")
		}

		for _, dep := range module.DependsOn {
			if dep == module.Name {
				v.addError(fmt.Sprintf("modules[%d].depends_on", i), dep, "Module cannot depend on itself", "error")
			}
		}

		if module.Condition != "" {
			v.validateConditionExpression(fmt.Sprintf("modules[%d].condition", i), module.Condition)
		}
	}
}

func (v *Validator) validateAuthentication() {
	auth := &v.config.Authentication

	validTypes := []string{"service_account", "application_default", "oauth", "oidc", "access_token"}
	if auth.Type != "" {
		valid := false
		for _, t := range validTypes {
			if auth.Type == t {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("authentication.type", auth.Type, "Invalid authentication type", "error")
		}
	}

	if auth.Type == "service_account" {
		if auth.ServiceAccountKey == "" && auth.ServiceAccountEmail == "" {
			v.addError("authentication", auth.Type, "Service account key or email is required", "error")
		}

		if auth.ServiceAccountKey != "" {
			if _, err := os.Stat(auth.ServiceAccountKey); os.IsNotExist(err) && !strings.HasPrefix(auth.ServiceAccountKey, "gs://") {
				v.addError("authentication.service_account_key", auth.ServiceAccountKey, "Service account key file not found", "error")
			}
		}

		if auth.ServiceAccountEmail != "" {
			if err := v.validateEmail(auth.ServiceAccountEmail); err != nil {
				v.addError("authentication.service_account_email", auth.ServiceAccountEmail, err.Error(), "error")
			}
		}
	}

	if auth.Type == "oidc" {
		v.validateOIDCConfig(&auth.OIDC)
	}

	if auth.ImpersonateEmail != "" {
		if err := v.validateEmail(auth.ImpersonateEmail); err != nil {
			v.addError("authentication.impersonate_email", auth.ImpersonateEmail, err.Error(), "error")
		}
	}
}

func (v *Validator) validateOIDCConfig(oidc *OIDCConfig) {
	if !oidc.Enabled {
		return
	}

	if oidc.Provider == "" {
		v.addError("authentication.oidc.provider", "", "OIDC provider is required", "error")
	}

	if oidc.Issuer == "" {
		v.addError("authentication.oidc.issuer", "", "OIDC issuer is required", "error")
	} else {
		if _, err := url.Parse(oidc.Issuer); err != nil {
			v.addError("authentication.oidc.issuer", oidc.Issuer, "Invalid issuer URL", "error")
		}
	}

	if oidc.ClientID == "" {
		v.addError("authentication.oidc.client_id", "", "OIDC client ID is required", "error")
	}

	if oidc.RedirectURI != "" {
		if _, err := url.Parse(oidc.RedirectURI); err != nil {
			v.addError("authentication.oidc.redirect_uri", oidc.RedirectURI, "Invalid redirect URI", "error")
		}
	}

	if oidc.WorkloadIdentityPool != "" {
		if !strings.HasPrefix(oidc.WorkloadIdentityPool, "projects/") {
			v.addError("authentication.oidc.workload_identity_pool", oidc.WorkloadIdentityPool, "Workload identity pool should be in format: projects/PROJECT_ID/locations/global/workloadIdentityPools/POOL_ID", "error")
		}
	}

	if oidc.ServiceAccount != "" {
		if err := v.validateEmail(oidc.ServiceAccount); err != nil {
			v.addError("authentication.oidc.service_account", oidc.ServiceAccount, err.Error(), "error")
		}
	}
}

func (v *Validator) validateMonitoring() {
	mon := &v.config.Monitoring

	if !mon.Enabled {
		return
	}

	validProviders := []string{"stackdriver", "prometheus", "datadog", "newrelic", "elastic"}
	if mon.Provider != "" {
		valid := false
		for _, p := range validProviders {
			if mon.Provider == p {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("monitoring.provider", mon.Provider, "Invalid monitoring provider", "error")
		}
	}

	if mon.SamplingRate < 0 || mon.SamplingRate > 1 {
		v.addError("monitoring.sampling_rate", mon.SamplingRate, "Sampling rate must be between 0 and 1", "error")
	}

	if mon.MetricsRetention < 0 || mon.MetricsRetention > 3650 {
		v.addError("monitoring.metrics_retention_days", mon.MetricsRetention, "Metrics retention must be between 0 and 3650 days", "warning")
	}

	if mon.LogsRetention < 0 || mon.LogsRetention > 3650 {
		v.addError("monitoring.logs_retention_days", mon.LogsRetention, "Logs retention must be between 0 and 3650 days", "warning")
	}

	for i, channel := range mon.AlertChannels {
		if channel.Name == "" {
			v.addError(fmt.Sprintf("monitoring.alert_channels[%d].name", i), "", "Alert channel name is required", "error")
		}

		validChannelTypes := []string{"email", "slack", "pagerduty", "webhook", "sms"}
		valid := false
		for _, t := range validChannelTypes {
			if channel.Type == t {
				valid = true
				break
			}
		}
		if !valid {
			v.addError(fmt.Sprintf("monitoring.alert_channels[%d].type", i), channel.Type, "Invalid alert channel type", "error")
		}
	}
}

func (v *Validator) validateSecurity() {
	sec := &v.config.Security

	if !sec.Enabled {
		return
	}

	if sec.TLSMinVersion != "" {
		validVersions := []string{"1.0", "1.1", "1.2", "1.3"}
		valid := false
		for _, ver := range validVersions {
			if sec.TLSMinVersion == ver {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("security.tls_min_version", sec.TLSMinVersion, "Invalid TLS version", "error")
		}
	}

	if sec.CertificatePath != "" {
		if _, err := os.Stat(sec.CertificatePath); os.IsNotExist(err) {
			v.addError("security.certificate_path", sec.CertificatePath, "Certificate file not found", "error")
		}
	}

	if sec.PrivateKeyPath != "" {
		if _, err := os.Stat(sec.PrivateKeyPath); os.IsNotExist(err) {
			v.addError("security.private_key_path", sec.PrivateKeyPath, "Private key file not found", "error")
		}
	}

	v.validateFirewallRules(sec.FirewallRules)
	v.validateIAMPolicies(sec.IAMPolicies)
	v.validateSecurityGroups(sec.SecurityGroups)
	v.validateSecretManagement(&sec.SecretManagement)
	v.validateAuditLogging(&sec.AuditLogging)
	v.validateDataProtection(&sec.DataProtection)
	v.validateAccessControl(&sec.AccessControl)
}

func (v *Validator) validateNetwork() {
	net := &v.config.Network

	if net.VPCName != "" {
		if !regexp.MustCompile(`^[a-z][a-z0-9-]*$`).MatchString(net.VPCName) {
			v.addError("network.vpc_name", net.VPCName, "VPC name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens", "error")
		}
	}

	validSubnetModes := []string{"custom", "auto", "legacy"}
	if net.SubnetMode != "" {
		valid := false
		for _, mode := range validSubnetModes {
			if net.SubnetMode == mode {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("network.subnet_mode", net.SubnetMode, "Invalid subnet mode", "error")
		}
	}

	validRoutingModes := []string{"regional", "global"}
	if net.RoutingMode != "" {
		valid := false
		for _, mode := range validRoutingModes {
			if net.RoutingMode == mode {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("network.routing_mode", net.RoutingMode, "Invalid routing mode", "error")
		}
	}

	if net.MTU != 0 && (net.MTU < 1460 || net.MTU > 1500) {
		v.addError("network.mtu", net.MTU, "MTU must be between 1460 and 1500", "error")
	}

	v.validateSubnets(net.Subnets)
	v.validateRoutes(net.Routes)
	v.validatePeerings(net.Peerings)
	v.validateNATGateways(net.NATGateways)
	v.validateLoadBalancers(net.LoadBalancers)
}

func (v *Validator) validateFeatures() {
	// No specific validation needed for feature flags
}

func (v *Validator) validateDependencies() {
	deps := v.config.Terragrunt.Dependencies
	depNames := make(map[string]bool)

	for i, dep := range deps {
		if dep.Name == "" {
			v.addError(fmt.Sprintf("terragrunt.dependencies[%d].name", i), "", "Dependency name is required", "error")
			continue
		}

		if depNames[dep.Name] {
			v.addError(fmt.Sprintf("terragrunt.dependencies[%d].name", i), dep.Name, "Duplicate dependency name", "error")
		}
		depNames[dep.Name] = true

		if dep.Path == "" {
			v.addError(fmt.Sprintf("terragrunt.dependencies[%d].path", i), "", "Dependency path is required", "error")
		} else if !filepath.IsAbs(dep.Path) && !strings.HasPrefix(dep.Path, "../") && !strings.HasPrefix(dep.Path, "./") {
			v.addError(fmt.Sprintf("terragrunt.dependencies[%d].path", i), dep.Path, "Dependency path should be absolute or relative", "warning")
		}
	}
}

func (v *Validator) validateHooks() {
	hooks := v.config.Terragrunt.Hooks
	hookNames := make(map[string]bool)

	for i, hook := range hooks {
		if hook.Name == "" {
			v.addError(fmt.Sprintf("terragrunt.hooks[%d].name", i), "", "Hook name is required", "error")
			continue
		}

		if hookNames[hook.Name] {
			v.addError(fmt.Sprintf("terragrunt.hooks[%d].name", i), hook.Name, "Duplicate hook name", "error")
		}
		hookNames[hook.Name] = true

		if len(hook.Commands) == 0 {
			v.addError(fmt.Sprintf("terragrunt.hooks[%d].commands", i), "", "Hook must have at least one command", "error")
		}

		validExecuteOn := []string{"before", "after", "error"}
		valid := false
		for _, exec := range validExecuteOn {
			if hook.ExecuteOn == exec {
				valid = true
				break
			}
		}
		if !valid {
			v.addError(fmt.Sprintf("terragrunt.hooks[%d].execute_on", i), hook.ExecuteOn, "ExecuteOn must be 'before', 'after', or 'error'", "error")
		}

		validRunOn := []string{"apply", "plan", "destroy", "init", "validate", "import", "push", "refresh"}
		for _, cmd := range hook.RunOn {
			valid := false
			for _, validCmd := range validRunOn {
				if cmd == validCmd {
					valid = true
					break
				}
			}
			if !valid {
				v.addError(fmt.Sprintf("terragrunt.hooks[%d].run_on", i), cmd, fmt.Sprintf("Invalid run_on command: %s", cmd), "error")
			}
		}
	}
}

func (v *Validator) validateOutputs() {
	for name, output := range v.config.Outputs {
		if name == "" {
			v.addError("outputs", "", "Output name cannot be empty", "error")
			continue
		}

		if !regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_]*$`).MatchString(name) {
			v.addError(fmt.Sprintf("outputs.%s", name), name, "Output name must start with letter and contain only letters, numbers, and underscores", "error")
		}

		for _, dep := range output.DependsOn {
			if dep == name {
				v.addError(fmt.Sprintf("outputs.%s.depends_on", name), dep, "Output cannot depend on itself", "error")
			}
		}
	}
}

func (v *Validator) validateTags() {
	for key, value := range v.config.Tags {
		if key == "" {
			v.addError("tags", "", "Tag key cannot be empty", "error")
			continue
		}

		if len(key) > 128 {
			v.addError(fmt.Sprintf("tags.%s", key), key, "Tag key cannot exceed 128 characters", "error")
		}

		if len(value) > 256 {
			v.addError(fmt.Sprintf("tags.%s", key), value, "Tag value cannot exceed 256 characters", "error")
		}

		if !regexp.MustCompile(`^[a-zA-Z0-9+\-=._:/@]*$`).MatchString(key) {
			v.addError(fmt.Sprintf("tags.%s", key), key, "Tag key contains invalid characters", "error")
		}

		if !regexp.MustCompile(`^[a-zA-Z0-9+\-=._:/@\s]*$`).MatchString(value) {
			v.addError(fmt.Sprintf("tags.%s", key), value, "Tag value contains invalid characters", "error")
		}
	}
}

func (v *Validator) validateProjectFormat(value interface{}) error {
	project, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	if len(project) < 6 || len(project) > 30 {
		return fmt.Errorf("project ID must be between 6 and 30 characters")
	}

	if !regexp.MustCompile(`^[a-z][a-z0-9-]*[a-z0-9]$`).MatchString(project) {
		return fmt.Errorf("project ID must start with lowercase letter and contain only lowercase letters, numbers, and hyphens")
	}

	return nil
}

func (v *Validator) validateRegionFormat(value interface{}) error {
	region, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	if !regexp.MustCompile(`^[a-z]+-[a-z0-9]+$`).MatchString(region) {
		return fmt.Errorf("invalid region format")
	}

	return nil
}

func (v *Validator) validateZoneFormat(value interface{}) error {
	zone, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	if !regexp.MustCompile(`^[a-z]+-[a-z0-9]+-[a-z]$`).MatchString(zone) {
		return fmt.Errorf("invalid zone format")
	}

	return nil
}

func (v *Validator) validateEnvironmentFormat(value interface{}) error {
	env, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	validEnvs := []string{"dev", "development", "test", "testing", "qa", "staging", "prod", "production"}
	for _, validEnv := range validEnvs {
		if strings.ToLower(env) == validEnv {
			return nil
		}
	}

	return fmt.Errorf("environment should be one of: dev, test, qa, staging, prod")
}

func (v *Validator) validateBucketName(value interface{}) error {
	bucket, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	if len(bucket) < 3 || len(bucket) > 63 {
		return fmt.Errorf("bucket name must be between 3 and 63 characters")
	}

	if !regexp.MustCompile(`^[a-z0-9][a-z0-9.\-_]*[a-z0-9]$`).MatchString(bucket) {
		return fmt.Errorf("bucket name must start and end with lowercase letter or number")
	}

	if strings.Contains(bucket, "..") {
		return fmt.Errorf("bucket name cannot contain consecutive dots")
	}

	if strings.Contains(bucket, "goog") || strings.Contains(bucket, "g00g") {
		return fmt.Errorf("bucket name cannot contain 'goog' or close variants")
	}

	if net.ParseIP(bucket) != nil {
		return fmt.Errorf("bucket name cannot be an IP address")
	}

	return nil
}

func (v *Validator) validateVersion(value interface{}) error {
	ver, ok := value.(string)
	if !ok {
		return fmt.Errorf("invalid type")
	}

	if _, err := version.NewVersion(ver); err != nil {
		return fmt.Errorf("invalid version format: %w", err)
	}

	return nil
}

func (v *Validator) validateEmail(email string) error {
	if !strings.Contains(email, "@") {
		return fmt.Errorf("invalid email format")
	}

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return fmt.Errorf("invalid email format")
	}

	if len(parts[0]) == 0 || len(parts[1]) == 0 {
		return fmt.Errorf("invalid email format")
	}

	if !strings.Contains(parts[1], ".") {
		return fmt.Errorf("invalid email domain")
	}

	return nil
}

func (v *Validator) validateModuleSource(name, source string) {
	if strings.HasPrefix(source, "./") || strings.HasPrefix(source, "../") {
		if _, err := os.Stat(source); os.IsNotExist(err) {
			v.addError(fmt.Sprintf("modules.%s.source", name), source, "Local module source does not exist", "error")
		}
	} else if strings.HasPrefix(source, "git::") || strings.HasPrefix(source, "github.com/") {
		// Git source - basic validation
		if !strings.Contains(source, "/") {
			v.addError(fmt.Sprintf("modules.%s.source", name), source, "Invalid Git repository format", "error")
		}
	} else if strings.HasPrefix(source, "gs://") {
		// GCS source
		if err := v.validateBucketName(strings.TrimPrefix(source, "gs://")); err != nil {
			v.addError(fmt.Sprintf("modules.%s.source", name), source, "Invalid GCS bucket in source", "error")
		}
	} else if !strings.Contains(source, "/") {
		// Registry source
		parts := strings.Split(source, "/")
		if len(parts) < 3 {
			v.addError(fmt.Sprintf("modules.%s.source", name), source, "Invalid registry module format", "error")
		}
	}
}

func (v *Validator) validateConditionExpression(field, expr string) {
	// Basic validation of condition expressions
	if strings.Count(expr, "(") != strings.Count(expr, ")") {
		v.addError(field, expr, "Unbalanced parentheses in condition", "error")
	}

	if strings.Count(expr, "{") != strings.Count(expr, "}") {
		v.addError(field, expr, "Unbalanced braces in condition", "error")
	}

	if strings.Count(expr, "[") != strings.Count(expr, "]") {
		v.addError(field, expr, "Unbalanced brackets in condition", "error")
	}
}

func (v *Validator) validateFirewallRules(rules []FirewallRule) {
	for i, rule := range rules {
		if rule.Name == "" {
			v.addError(fmt.Sprintf("security.firewall_rules[%d].name", i), "", "Firewall rule name is required", "error")
		}

		if rule.Direction != "INGRESS" && rule.Direction != "EGRESS" {
			v.addError(fmt.Sprintf("security.firewall_rules[%d].direction", i), rule.Direction, "Direction must be INGRESS or EGRESS", "error")
		}

		if rule.Priority < 0 || rule.Priority > 65535 {
			v.addError(fmt.Sprintf("security.firewall_rules[%d].priority", i), rule.Priority, "Priority must be between 0 and 65535", "error")
		}

		if rule.Action != "allow" && rule.Action != "deny" {
			v.addError(fmt.Sprintf("security.firewall_rules[%d].action", i), rule.Action, "Action must be 'allow' or 'deny'", "error")
		}

		for _, cidr := range rule.SourceRanges {
			if _, _, err := net.ParseCIDR(cidr); err != nil {
				v.addError(fmt.Sprintf("security.firewall_rules[%d].source_ranges", i), cidr, "Invalid CIDR format", "error")
			}
		}
	}
}

func (v *Validator) validateIAMPolicies(policies []IAMPolicy) {
	for i, policy := range policies {
		if policy.Name == "" {
			v.addError(fmt.Sprintf("security.iam_policies[%d].name", i), "", "IAM policy name is required", "error")
		}

		if policy.Resource == "" {
			v.addError(fmt.Sprintf("security.iam_policies[%d].resource", i), "", "IAM policy resource is required", "error")
		}

		if policy.Role == "" {
			v.addError(fmt.Sprintf("security.iam_policies[%d].role", i), "", "IAM policy role is required", "error")
		}

		if len(policy.Members) == 0 {
			v.addError(fmt.Sprintf("security.iam_policies[%d].members", i), "", "IAM policy must have at least one member", "error")
		}

		for _, member := range policy.Members {
			if !strings.HasPrefix(member, "user:") && !strings.HasPrefix(member, "serviceAccount:") &&
				!strings.HasPrefix(member, "group:") && !strings.HasPrefix(member, "domain:") {
				v.addError(fmt.Sprintf("security.iam_policies[%d].members", i), member, "Invalid member format", "error")
			}
		}
	}
}

func (v *Validator) validateSecurityGroups(groups []SecurityGroup) {
	for i, group := range groups {
		if group.Name == "" {
			v.addError(fmt.Sprintf("security.security_groups[%d].name", i), "", "Security group name is required", "error")
		}

		if group.VPC == "" {
			v.addError(fmt.Sprintf("security.security_groups[%d].vpc", i), "", "Security group VPC is required", "error")
		}

		for j, rule := range group.Rules {
			if rule.Type != "ingress" && rule.Type != "egress" {
				v.addError(fmt.Sprintf("security.security_groups[%d].rules[%d].type", i, j), rule.Type, "Rule type must be 'ingress' or 'egress'", "error")
			}

			if rule.FromPort > rule.ToPort {
				v.addError(fmt.Sprintf("security.security_groups[%d].rules[%d]", i, j), "", "FromPort cannot be greater than ToPort", "error")
			}

			for _, cidr := range rule.CIDRBlocks {
				if _, _, err := net.ParseCIDR(cidr); err != nil {
					v.addError(fmt.Sprintf("security.security_groups[%d].rules[%d].cidr_blocks", i, j), cidr, "Invalid CIDR format", "error")
				}
			}
		}
	}
}

func (v *Validator) validateSecretManagement(sm *SecretManagement) {
	if sm.Provider == "" {
		return
	}

	validProviders := []string{"google-secret-manager", "vault", "aws-secrets-manager", "azure-key-vault"}
	valid := false
	for _, p := range validProviders {
		if sm.Provider == p {
			valid = true
			break
		}
	}
	if !valid {
		v.addError("security.secret_management.provider", sm.Provider, "Invalid secret management provider", "error")
	}

	if sm.AutoRotation && sm.RotationDays <= 0 {
		v.addError("security.secret_management.rotation_days", sm.RotationDays, "Rotation days must be positive when auto-rotation is enabled", "error")
	}
}

func (v *Validator) validateAuditLogging(al *AuditLogging) {
	if !al.Enabled {
		return
	}

	validLogTypes := []string{"data_access", "admin_activity", "system_event", "policy_denied", "all"}
	if al.LogType != "" {
		valid := false
		for _, t := range validLogTypes {
			if al.LogType == t {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("security.audit_logging.log_type", al.LogType, "Invalid audit log type", "error")
		}
	}

	if al.Retention < 0 || al.Retention > 3650 {
		v.addError("security.audit_logging.retention_days", al.Retention, "Retention days must be between 0 and 3650", "warning")
	}
}

func (v *Validator) validateDataProtection(dp *DataProtection) {
	if !dp.Enabled {
		return
	}

	validLevels := []string{"public", "internal", "confidential", "restricted"}
	if dp.ClassificationLevel != "" {
		valid := false
		for _, level := range validLevels {
			if dp.ClassificationLevel == level {
				valid = true
				break
			}
		}
		if !valid {
			v.addError("security.data_protection.classification_level", dp.ClassificationLevel, "Invalid classification level", "error")
		}
	}

	if dp.BackupEnabled && dp.BackupRetention <= 0 {
		v.addError("security.data_protection.backup_retention_days", dp.BackupRetention, "Backup retention days must be positive", "error")
	}
}

func (v *Validator) validateAccessControl(ac *AccessControl) {
	if !ac.Enabled {
		return
	}

	if ac.SessionTimeout < 0 || ac.SessionTimeout > 1440 {
		v.addError("security.access_control.session_timeout_minutes", ac.SessionTimeout, "Session timeout must be between 0 and 1440 minutes", "error")
	}

	if ac.MaxSessionDuration < 0 || ac.MaxSessionDuration > 12 {
		v.addError("security.access_control.max_session_duration_hours", ac.MaxSessionDuration, "Max session duration must be between 0 and 12 hours", "error")
	}

	for _, ip := range ac.IPWhitelist {
		if _, _, err := net.ParseCIDR(ip); err != nil {
			if net.ParseIP(ip) == nil {
				v.addError("security.access_control.ip_whitelist", ip, "Invalid IP or CIDR format", "error")
			}
		}
	}

	for _, ip := range ac.IPBlacklist {
		if _, _, err := net.ParseCIDR(ip); err != nil {
			if net.ParseIP(ip) == nil {
				v.addError("security.access_control.ip_blacklist", ip, "Invalid IP or CIDR format", "error")
			}
		}
	}
}

func (v *Validator) validateSubnets(subnets []SubnetConfig) {
	subnetNames := make(map[string]bool)
	cidrs := make(map[string]string)

	for i, subnet := range subnets {
		if subnet.Name == "" {
			v.addError(fmt.Sprintf("network.subnets[%d].name", i), "", "Subnet name is required", "error")
			continue
		}

		if subnetNames[subnet.Name] {
			v.addError(fmt.Sprintf("network.subnets[%d].name", i), subnet.Name, "Duplicate subnet name", "error")
		}
		subnetNames[subnet.Name] = true

		if subnet.CIDR == "" {
			v.addError(fmt.Sprintf("network.subnets[%d].cidr", i), "", "Subnet CIDR is required", "error")
		} else {
			if _, _, err := net.ParseCIDR(subnet.CIDR); err != nil {
				v.addError(fmt.Sprintf("network.subnets[%d].cidr", i), subnet.CIDR, "Invalid CIDR format", "error")
			} else if existing, exists := cidrs[subnet.CIDR]; exists {
				v.addError(fmt.Sprintf("network.subnets[%d].cidr", i), subnet.CIDR, fmt.Sprintf("CIDR overlap with subnet %s", existing), "error")
			} else {
				cidrs[subnet.CIDR] = subnet.Name
			}
		}

		if subnet.Region == "" {
			v.addError(fmt.Sprintf("network.subnets[%d].region", i), "", "Subnet region is required", "error")
		}

		for j, secondary := range subnet.SecondaryRanges {
			if secondary.Name == "" {
				v.addError(fmt.Sprintf("network.subnets[%d].secondary_ranges[%d].name", i, j), "", "Secondary range name is required", "error")
			}

			if _, _, err := net.ParseCIDR(secondary.CIDR); err != nil {
				v.addError(fmt.Sprintf("network.subnets[%d].secondary_ranges[%d].cidr", i, j), secondary.CIDR, "Invalid CIDR format", "error")
			}
		}
	}
}

func (v *Validator) validateRoutes(routes []RouteConfig) {
	routeNames := make(map[string]bool)

	for i, route := range routes {
		if route.Name == "" {
			v.addError(fmt.Sprintf("network.routes[%d].name", i), "", "Route name is required", "error")
			continue
		}

		if routeNames[route.Name] {
			v.addError(fmt.Sprintf("network.routes[%d].name", i), route.Name, "Duplicate route name", "error")
		}
		routeNames[route.Name] = true

		if route.DestRange == "" {
			v.addError(fmt.Sprintf("network.routes[%d].dest_range", i), "", "Route destination range is required", "error")
		} else if _, _, err := net.ParseCIDR(route.DestRange); err != nil {
			v.addError(fmt.Sprintf("network.routes[%d].dest_range", i), route.DestRange, "Invalid destination CIDR format", "error")
		}

		nextHopCount := 0
		if route.NextHopGateway != "" {
			nextHopCount++
		}
		if route.NextHopInstance != "" {
			nextHopCount++
		}
		if route.NextHopIP != "" {
			nextHopCount++
		}
		if route.NextHopVPN != "" {
			nextHopCount++
		}

		if nextHopCount == 0 {
			v.addError(fmt.Sprintf("network.routes[%d]", i), "", "Route must have exactly one next hop", "error")
		} else if nextHopCount > 1 {
			v.addError(fmt.Sprintf("network.routes[%d]", i), "", "Route can only have one next hop", "error")
		}

		if route.Priority < 0 || route.Priority > 65535 {
			v.addError(fmt.Sprintf("network.routes[%d].priority", i), route.Priority, "Priority must be between 0 and 65535", "error")
		}
	}
}

func (v *Validator) validatePeerings(peerings []PeeringConfig) {
	peeringNames := make(map[string]bool)

	for i, peering := range peerings {
		if peering.Name == "" {
			v.addError(fmt.Sprintf("network.peerings[%d].name", i), "", "Peering name is required", "error")
			continue
		}

		if peeringNames[peering.Name] {
			v.addError(fmt.Sprintf("network.peerings[%d].name", i), peering.Name, "Duplicate peering name", "error")
		}
		peeringNames[peering.Name] = true

		if peering.PeerNetwork == "" {
			v.addError(fmt.Sprintf("network.peerings[%d].peer_network", i), "", "Peer network is required", "error")
		}
	}
}

func (v *Validator) validateNATGateways(gateways []NATGateway) {
	gatewayNames := make(map[string]bool)

	for i, gateway := range gateways {
		if gateway.Name == "" {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].name", i), "", "NAT gateway name is required", "error")
			continue
		}

		if gatewayNames[gateway.Name] {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].name", i), gateway.Name, "Duplicate NAT gateway name", "error")
		}
		gatewayNames[gateway.Name] = true

		if gateway.Region == "" {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].region", i), "", "NAT gateway region is required", "error")
		}

		if gateway.Router == "" {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].router", i), "", "NAT gateway router is required", "error")
		}

		validAllocOptions := []string{"AUTO_ONLY", "MANUAL_ONLY"}
		valid := false
		for _, opt := range validAllocOptions {
			if gateway.IPAllocationOption == opt {
				valid = true
				break
			}
		}
		if !valid && gateway.IPAllocationOption != "" {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].ip_allocation_option", i), gateway.IPAllocationOption, "Invalid IP allocation option", "error")
		}

		if gateway.MinPortsPerVM < 0 || gateway.MinPortsPerVM > 65536 {
			v.addError(fmt.Sprintf("network.nat_gateways[%d].min_ports_per_vm", i), gateway.MinPortsPerVM, "Min ports per VM must be between 0 and 65536", "error")
		}
	}
}

func (v *Validator) validateLoadBalancers(lbs []LoadBalancerConfig) {
	lbNames := make(map[string]bool)

	for i, lb := range lbs {
		if lb.Name == "" {
			v.addError(fmt.Sprintf("network.load_balancers[%d].name", i), "", "Load balancer name is required", "error")
			continue
		}

		if lbNames[lb.Name] {
			v.addError(fmt.Sprintf("network.load_balancers[%d].name", i), lb.Name, "Duplicate load balancer name", "error")
		}
		lbNames[lb.Name] = true

		validTypes := []string{"APPLICATION", "NETWORK", "CLASSIC"}
		valid := false
		for _, t := range validTypes {
			if lb.Type == t {
				valid = true
				break
			}
		}
		if !valid && lb.Type != "" {
			v.addError(fmt.Sprintf("network.load_balancers[%d].type", i), lb.Type, "Invalid load balancer type", "error")
		}

		validSchemes := []string{"EXTERNAL", "INTERNAL", "EXTERNAL_MANAGED"}
		valid = false
		for _, s := range validSchemes {
			if lb.Scheme == s {
				valid = true
				break
			}
		}
		if !valid && lb.Scheme != "" {
			v.addError(fmt.Sprintf("network.load_balancers[%d].scheme", i), lb.Scheme, "Invalid load balancer scheme", "error")
		}

		if lb.Port < 1 || lb.Port > 65535 {
			v.addError(fmt.Sprintf("network.load_balancers[%d].port", i), lb.Port, "Port must be between 1 and 65535", "error")
		}
	}
}

func (v *Validator) addError(field string, value interface{}, message string, severity string) {
	v.errors = append(v.errors, ValidationError{
		Field:    field,
		Value:    value,
		Message:  message,
		Severity: severity,
	})
}

func (v *Validator) formatErrors() error {
	if len(v.errors) == 0 {
		return nil
	}

	var errorMessages []string
	var warningMessages []string

	for _, err := range v.errors {
		msg := fmt.Sprintf("%s: %s", err.Field, err.Message)
		if err.Value != nil && err.Value != "" {
			msg = fmt.Sprintf("%s (value: %v)", msg, err.Value)
		}

		if err.Severity == "error" {
			errorMessages = append(errorMessages, msg)
		} else {
			warningMessages = append(warningMessages, msg)
		}
	}

	var result string
	if len(errorMessages) > 0 {
		result = fmt.Sprintf("Validation errors:\n%s", strings.Join(errorMessages, "\n"))
	}

	if len(warningMessages) > 0 {
		if result != "" {
			result += "\n\n"
		}
		result += fmt.Sprintf("Validation warnings:\n%s", strings.Join(warningMessages, "\n"))
	}

	return fmt.Errorf(result)
}

func (v *Validator) GetErrors() []ValidationError {
	return v.errors
}

func (v *Validator) HasErrors() bool {
	for _, err := range v.errors {
		if err.Severity == "error" {
			return true
		}
	}
	return false
}

func (v *Validator) HasWarnings() bool {
	for _, err := range v.errors {
		if err.Severity == "warning" {
			return true
		}
	}
	return false
}