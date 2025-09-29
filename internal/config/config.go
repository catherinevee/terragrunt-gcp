package config

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/gohcl"
	"github.com/hashicorp/hcl/v2/hclparse"
	"github.com/hashicorp/terraform-config-inspect/tfconfig"
	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

type Config struct {
	mu sync.RWMutex

	Project           string                 `json:"project" yaml:"project" hcl:"project"`
	Region            string                 `json:"region" yaml:"region" hcl:"region"`
	Zone              string                 `json:"zone" yaml:"zone" hcl:"zone"`
	Environment       string                 `json:"environment" yaml:"environment" hcl:"environment"`
	ConfigPath        string                 `json:"config_path" yaml:"config_path" hcl:"config_path"`
	TerraformVersion  string                 `json:"terraform_version" yaml:"terraform_version" hcl:"terraform_version"`
	TerragruntVersion string                 `json:"terragrunt_version" yaml:"terragrunt_version" hcl:"terragrunt_version"`

	Terraform         TerraformConfig        `json:"terraform" yaml:"terraform" hcl:"terraform,block"`
	Terragrunt        TerragruntConfig       `json:"terragrunt" yaml:"terragrunt" hcl:"terragrunt,block"`
	Backend           BackendConfig          `json:"backend" yaml:"backend" hcl:"backend,block"`
	Providers         map[string]Provider    `json:"providers" yaml:"providers" hcl:"providers,block"`
	Modules           []ModuleConfig         `json:"modules" yaml:"modules" hcl:"modules,block"`
	Variables         map[string]interface{} `json:"variables" yaml:"variables" hcl:"variables,optional"`
	Outputs           map[string]Output      `json:"outputs" yaml:"outputs" hcl:"outputs,optional"`
	Authentication    AuthConfig             `json:"authentication" yaml:"authentication" hcl:"authentication,block"`
	Monitoring        MonitoringConfig       `json:"monitoring" yaml:"monitoring" hcl:"monitoring,block"`
	Security          SecurityConfig         `json:"security" yaml:"security" hcl:"security,block"`
	Network           NetworkConfig          `json:"network" yaml:"network" hcl:"network,block"`
	Tags              map[string]string      `json:"tags" yaml:"tags" hcl:"tags,optional"`
	Features          FeatureFlags           `json:"features" yaml:"features" hcl:"features,block"`

	loadTime          time.Time
	configHash        string
}

type TerraformConfig struct {
	Version           string            `json:"version" yaml:"version" hcl:"version"`
	WorkingDir        string            `json:"working_dir" yaml:"working_dir" hcl:"working_dir"`
	PlanFile          string            `json:"plan_file" yaml:"plan_file" hcl:"plan_file"`
	StateFile         string            `json:"state_file" yaml:"state_file" hcl:"state_file"`
	PluginDir         string            `json:"plugin_dir" yaml:"plugin_dir" hcl:"plugin_dir"`
	Parallelism       int               `json:"parallelism" yaml:"parallelism" hcl:"parallelism"`
	LockTimeout       string            `json:"lock_timeout" yaml:"lock_timeout" hcl:"lock_timeout"`
	BackendConfig     map[string]string `json:"backend_config" yaml:"backend_config" hcl:"backend_config,optional"`
	RequiredProviders map[string]string `json:"required_providers" yaml:"required_providers" hcl:"required_providers,optional"`
	ExtraArgs         []string          `json:"extra_args" yaml:"extra_args" hcl:"extra_args,optional"`
	AutoInit          bool              `json:"auto_init" yaml:"auto_init" hcl:"auto_init"`
	AutoPlan          bool              `json:"auto_plan" yaml:"auto_plan" hcl:"auto_plan"`
	AutoApprove       bool              `json:"auto_approve" yaml:"auto_approve" hcl:"auto_approve"`
	Color             bool              `json:"color" yaml:"color" hcl:"color"`
	Input             bool              `json:"input" yaml:"input" hcl:"input"`
	Refresh           bool              `json:"refresh" yaml:"refresh" hcl:"refresh"`
	Upgrade           bool              `json:"upgrade" yaml:"upgrade" hcl:"upgrade"`
	Reconfigure       bool              `json:"reconfigure" yaml:"reconfigure" hcl:"reconfigure"`
}

type TerragruntConfig struct {
	Version            string                `json:"version" yaml:"version" hcl:"version"`
	ConfigFile         string                `json:"config_file" yaml:"config_file" hcl:"config_file"`
	DownloadDir        string                `json:"download_dir" yaml:"download_dir" hcl:"download_dir"`
	IamRole            string                `json:"iam_role" yaml:"iam_role" hcl:"iam_role"`
	TerraformBinary    string                `json:"terraform_binary" yaml:"terraform_binary" hcl:"terraform_binary"`
	NonInteractive     bool                  `json:"non_interactive" yaml:"non_interactive" hcl:"non_interactive"`
	AutoRetry          bool                  `json:"auto_retry" yaml:"auto_retry" hcl:"auto_retry"`
	MaxRetries         int                   `json:"max_retries" yaml:"max_retries" hcl:"max_retries"`
	SleepInterval      int                   `json:"sleep_interval" yaml:"sleep_interval" hcl:"sleep_interval"`
	IgnoreDependencies bool                  `json:"ignore_dependencies" yaml:"ignore_dependencies" hcl:"ignore_dependencies"`
	IncludeExternalDependencies bool         `json:"include_external_dependencies" yaml:"include_external_dependencies" hcl:"include_external_dependencies"`
	Parallelism        int                   `json:"parallelism" yaml:"parallelism" hcl:"parallelism"`
	PreventDestroy     bool                  `json:"prevent_destroy" yaml:"prevent_destroy" hcl:"prevent_destroy"`
	Locals            map[string]interface{} `json:"locals" yaml:"locals" hcl:"locals,optional"`
	Dependencies      []Dependency           `json:"dependencies" yaml:"dependencies" hcl:"dependencies,block"`
	Hooks             []Hook                 `json:"hooks" yaml:"hooks" hcl:"hooks,block"`
	RetryableErrors   []string              `json:"retryable_errors" yaml:"retryable_errors" hcl:"retryable_errors,optional"`
	IncludeDir        string                `json:"include_dir" yaml:"include_dir" hcl:"include_dir"`
	ExtraArgs         map[string][]string   `json:"extra_args" yaml:"extra_args" hcl:"extra_args,optional"`
	GenerateBlocks    []GenerateBlock       `json:"generate_blocks" yaml:"generate_blocks" hcl:"generate,block"`
}

type BackendConfig struct {
	Type       string                 `json:"type" yaml:"type" hcl:"type"`
	Bucket     string                 `json:"bucket" yaml:"bucket" hcl:"bucket"`
	Prefix     string                 `json:"prefix" yaml:"prefix" hcl:"prefix"`
	Project    string                 `json:"project" yaml:"project" hcl:"project"`
	Region     string                 `json:"region" yaml:"region" hcl:"region"`
	Encryption bool                   `json:"encryption" yaml:"encryption" hcl:"encryption"`
	KMSKeyID   string                 `json:"kms_key_id" yaml:"kms_key_id" hcl:"kms_key_id"`
	LockTable  string                 `json:"lock_table" yaml:"lock_table" hcl:"lock_table"`
	Extra      map[string]interface{} `json:"extra" yaml:"extra" hcl:"extra,optional"`
}

type Provider struct {
	Source           string                 `json:"source" yaml:"source" hcl:"source"`
	Version          string                 `json:"version" yaml:"version" hcl:"version"`
	Alias            string                 `json:"alias" yaml:"alias" hcl:"alias,optional"`
	Region           string                 `json:"region" yaml:"region" hcl:"region,optional"`
	Project          string                 `json:"project" yaml:"project" hcl:"project,optional"`
	Zone             string                 `json:"zone" yaml:"zone" hcl:"zone,optional"`
	Credentials      string                 `json:"credentials" yaml:"credentials" hcl:"credentials,optional"`
	AccessToken      string                 `json:"access_token" yaml:"access_token" hcl:"access_token,optional"`
	ImpersonateEmail string                 `json:"impersonate_service_account" yaml:"impersonate_service_account" hcl:"impersonate_service_account,optional"`
	Scopes           []string              `json:"scopes" yaml:"scopes" hcl:"scopes,optional"`
	UserProjectOverride bool               `json:"user_project_override" yaml:"user_project_override" hcl:"user_project_override"`
	BillingProject   string                 `json:"billing_project" yaml:"billing_project" hcl:"billing_project,optional"`
	DefaultLabels    map[string]string     `json:"default_labels" yaml:"default_labels" hcl:"default_labels,optional"`
	Configuration    map[string]interface{} `json:"configuration" yaml:"configuration" hcl:"configuration,optional"`
}

type ModuleConfig struct {
	Name           string                 `json:"name" yaml:"name" hcl:"name,label"`
	Source         string                 `json:"source" yaml:"source" hcl:"source"`
	Version        string                 `json:"version" yaml:"version" hcl:"version,optional"`
	Path           string                 `json:"path" yaml:"path" hcl:"path,optional"`
	Enabled        bool                   `json:"enabled" yaml:"enabled" hcl:"enabled"`
	DependsOn      []string              `json:"depends_on" yaml:"depends_on" hcl:"depends_on,optional"`
	Count          int                    `json:"count" yaml:"count" hcl:"count,optional"`
	ForEach        map[string]interface{} `json:"for_each" yaml:"for_each" hcl:"for_each,optional"`
	Providers      map[string]string     `json:"providers" yaml:"providers" hcl:"providers,optional"`
	Variables      map[string]interface{} `json:"variables" yaml:"variables" hcl:"variables,optional"`
	Outputs        []string              `json:"outputs" yaml:"outputs" hcl:"outputs,optional"`
	Tags           map[string]string     `json:"tags" yaml:"tags" hcl:"tags,optional"`
	Condition      string                `json:"condition" yaml:"condition" hcl:"condition,optional"`
	ErrorMessage   string                `json:"error_message" yaml:"error_message" hcl:"error_message,optional"`
}

type Output struct {
	Value       interface{} `json:"value" yaml:"value" hcl:"value"`
	Description string      `json:"description" yaml:"description" hcl:"description,optional"`
	Sensitive   bool        `json:"sensitive" yaml:"sensitive" hcl:"sensitive"`
	DependsOn   []string    `json:"depends_on" yaml:"depends_on" hcl:"depends_on,optional"`
}

type AuthConfig struct {
	Type               string            `json:"type" yaml:"type" hcl:"type"`
	ServiceAccountKey  string            `json:"service_account_key" yaml:"service_account_key" hcl:"service_account_key,optional"`
	ServiceAccountEmail string           `json:"service_account_email" yaml:"service_account_email" hcl:"service_account_email,optional"`
	ImpersonateEmail   string            `json:"impersonate_email" yaml:"impersonate_email" hcl:"impersonate_email,optional"`
	AccessToken        string            `json:"access_token" yaml:"access_token" hcl:"access_token,optional"`
	RefreshToken       string            `json:"refresh_token" yaml:"refresh_token" hcl:"refresh_token,optional"`
	ClientID           string            `json:"client_id" yaml:"client_id" hcl:"client_id,optional"`
	ClientSecret       string            `json:"client_secret" yaml:"client_secret" hcl:"client_secret,optional"`
	TokenURI           string            `json:"token_uri" yaml:"token_uri" hcl:"token_uri,optional"`
	AuthURI            string            `json:"auth_uri" yaml:"auth_uri" hcl:"auth_uri,optional"`
	RedirectURI        string            `json:"redirect_uri" yaml:"redirect_uri" hcl:"redirect_uri,optional"`
	Scopes             []string          `json:"scopes" yaml:"scopes" hcl:"scopes,optional"`
	OIDC               OIDCConfig        `json:"oidc" yaml:"oidc" hcl:"oidc,block"`
	Metadata           map[string]string `json:"metadata" yaml:"metadata" hcl:"metadata,optional"`
}

type OIDCConfig struct {
	Enabled             bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	Provider            string            `json:"provider" yaml:"provider" hcl:"provider"`
	Issuer              string            `json:"issuer" yaml:"issuer" hcl:"issuer"`
	ClientID            string            `json:"client_id" yaml:"client_id" hcl:"client_id"`
	ClientSecret        string            `json:"client_secret" yaml:"client_secret" hcl:"client_secret,optional"`
	Audience            string            `json:"audience" yaml:"audience" hcl:"audience"`
	RedirectURI         string            `json:"redirect_uri" yaml:"redirect_uri" hcl:"redirect_uri"`
	ResponseType        string            `json:"response_type" yaml:"response_type" hcl:"response_type"`
	GrantType           string            `json:"grant_type" yaml:"grant_type" hcl:"grant_type"`
	Scopes              []string          `json:"scopes" yaml:"scopes" hcl:"scopes,optional"`
	WorkloadIdentityPool string           `json:"workload_identity_pool" yaml:"workload_identity_pool" hcl:"workload_identity_pool,optional"`
	WorkloadIdentityProvider string       `json:"workload_identity_provider" yaml:"workload_identity_provider" hcl:"workload_identity_provider,optional"`
	ServiceAccount      string            `json:"service_account" yaml:"service_account" hcl:"service_account,optional"`
	TokenURL            string            `json:"token_url" yaml:"token_url" hcl:"token_url,optional"`
	AuthURL             string            `json:"auth_url" yaml:"auth_url" hcl:"auth_url,optional"`
	UserInfoURL         string            `json:"userinfo_url" yaml:"userinfo_url" hcl:"userinfo_url,optional"`
	JWKSURI             string            `json:"jwks_uri" yaml:"jwks_uri" hcl:"jwks_uri,optional"`
	Claims              map[string]string `json:"claims" yaml:"claims" hcl:"claims,optional"`
}

type MonitoringConfig struct {
	Enabled           bool                  `json:"enabled" yaml:"enabled" hcl:"enabled"`
	Provider          string                `json:"provider" yaml:"provider" hcl:"provider"`
	ProjectID         string                `json:"project_id" yaml:"project_id" hcl:"project_id"`
	MetricsEnabled    bool                  `json:"metrics_enabled" yaml:"metrics_enabled" hcl:"metrics_enabled"`
	LoggingEnabled    bool                  `json:"logging_enabled" yaml:"logging_enabled" hcl:"logging_enabled"`
	TracingEnabled    bool                  `json:"tracing_enabled" yaml:"tracing_enabled" hcl:"tracing_enabled"`
	AlertingEnabled   bool                  `json:"alerting_enabled" yaml:"alerting_enabled" hcl:"alerting_enabled"`
	DashboardEnabled  bool                  `json:"dashboard_enabled" yaml:"dashboard_enabled" hcl:"dashboard_enabled"`
	MetricsRetention  int                   `json:"metrics_retention_days" yaml:"metrics_retention_days" hcl:"metrics_retention_days"`
	LogsRetention     int                   `json:"logs_retention_days" yaml:"logs_retention_days" hcl:"logs_retention_days"`
	TracesRetention   int                   `json:"traces_retention_days" yaml:"traces_retention_days" hcl:"traces_retention_days"`
	SamplingRate      float64               `json:"sampling_rate" yaml:"sampling_rate" hcl:"sampling_rate"`
	AlertChannels     []AlertChannel        `json:"alert_channels" yaml:"alert_channels" hcl:"alert_channels,block"`
	CustomMetrics     []CustomMetric        `json:"custom_metrics" yaml:"custom_metrics" hcl:"custom_metrics,block"`
	LogFilters        []LogFilter           `json:"log_filters" yaml:"log_filters" hcl:"log_filters,block"`
	TracingConfig     TracingConfig         `json:"tracing_config" yaml:"tracing_config" hcl:"tracing_config,block"`
	Labels            map[string]string     `json:"labels" yaml:"labels" hcl:"labels,optional"`
	Exporters         []ExporterConfig      `json:"exporters" yaml:"exporters" hcl:"exporters,block"`
}

type SecurityConfig struct {
	Enabled              bool                  `json:"enabled" yaml:"enabled" hcl:"enabled"`
	EncryptionEnabled    bool                  `json:"encryption_enabled" yaml:"encryption_enabled" hcl:"encryption_enabled"`
	KMSKeyID             string                `json:"kms_key_id" yaml:"kms_key_id" hcl:"kms_key_id,optional"`
	TLSEnabled           bool                  `json:"tls_enabled" yaml:"tls_enabled" hcl:"tls_enabled"`
	TLSMinVersion        string                `json:"tls_min_version" yaml:"tls_min_version" hcl:"tls_min_version"`
	MutualTLSEnabled     bool                  `json:"mutual_tls_enabled" yaml:"mutual_tls_enabled" hcl:"mutual_tls_enabled"`
	CertificatePath      string                `json:"certificate_path" yaml:"certificate_path" hcl:"certificate_path,optional"`
	PrivateKeyPath       string                `json:"private_key_path" yaml:"private_key_path" hcl:"private_key_path,optional"`
	CACertificatePath    string                `json:"ca_certificate_path" yaml:"ca_certificate_path" hcl:"ca_certificate_path,optional"`
	IAMPolicies          []IAMPolicy           `json:"iam_policies" yaml:"iam_policies" hcl:"iam_policies,block"`
	FirewallRules        []FirewallRule        `json:"firewall_rules" yaml:"firewall_rules" hcl:"firewall_rules,block"`
	SecurityGroups       []SecurityGroup       `json:"security_groups" yaml:"security_groups" hcl:"security_groups,block"`
	ComplianceStandards  []string              `json:"compliance_standards" yaml:"compliance_standards" hcl:"compliance_standards,optional"`
	VulnerabilityScan    bool                  `json:"vulnerability_scan" yaml:"vulnerability_scan" hcl:"vulnerability_scan"`
	SecretManagement     SecretManagement      `json:"secret_management" yaml:"secret_management" hcl:"secret_management,block"`
	AuditLogging         AuditLogging          `json:"audit_logging" yaml:"audit_logging" hcl:"audit_logging,block"`
	DataProtection       DataProtection        `json:"data_protection" yaml:"data_protection" hcl:"data_protection,block"`
	AccessControl        AccessControl         `json:"access_control" yaml:"access_control" hcl:"access_control,block"`
}

type NetworkConfig struct {
	VPCName              string                `json:"vpc_name" yaml:"vpc_name" hcl:"vpc_name"`
	VPCNetwork           string                `json:"vpc_network" yaml:"vpc_network" hcl:"vpc_network"`
	SubnetMode           string                `json:"subnet_mode" yaml:"subnet_mode" hcl:"subnet_mode"`
	RoutingMode          string                `json:"routing_mode" yaml:"routing_mode" hcl:"routing_mode"`
	AutoCreateSubnets    bool                  `json:"auto_create_subnets" yaml:"auto_create_subnets" hcl:"auto_create_subnets"`
	DeleteDefaultRoutes  bool                  `json:"delete_default_routes" yaml:"delete_default_routes" hcl:"delete_default_routes"`
	MTU                  int                   `json:"mtu" yaml:"mtu" hcl:"mtu"`
	EnableFlowLogs       bool                  `json:"enable_flow_logs" yaml:"enable_flow_logs" hcl:"enable_flow_logs"`
	PrivateGoogleAccess  bool                  `json:"private_google_access" yaml:"private_google_access" hcl:"private_google_access"`
	Subnets              []SubnetConfig        `json:"subnets" yaml:"subnets" hcl:"subnets,block"`
	Routes               []RouteConfig         `json:"routes" yaml:"routes" hcl:"routes,block"`
	Peerings             []PeeringConfig       `json:"peerings" yaml:"peerings" hcl:"peerings,block"`
	NATGateways          []NATGateway          `json:"nat_gateways" yaml:"nat_gateways" hcl:"nat_gateways,block"`
	LoadBalancers        []LoadBalancerConfig  `json:"load_balancers" yaml:"load_balancers" hcl:"load_balancers,block"`
	DNSConfig            DNSConfig             `json:"dns_config" yaml:"dns_config" hcl:"dns_config,block"`
	CDNConfig            CDNConfig             `json:"cdn_config" yaml:"cdn_config" hcl:"cdn_config,block"`
}

type FeatureFlags struct {
	EnableCaching        bool                  `json:"enable_caching" yaml:"enable_caching" hcl:"enable_caching"`
	EnableParallelExec   bool                  `json:"enable_parallel_exec" yaml:"enable_parallel_exec" hcl:"enable_parallel_exec"`
	EnableAutoRetry      bool                  `json:"enable_auto_retry" yaml:"enable_auto_retry" hcl:"enable_auto_retry"`
	EnableDryRun         bool                  `json:"enable_dry_run" yaml:"enable_dry_run" hcl:"enable_dry_run"`
	EnableDebugMode      bool                  `json:"enable_debug_mode" yaml:"enable_debug_mode" hcl:"enable_debug_mode"`
	EnableMetrics        bool                  `json:"enable_metrics" yaml:"enable_metrics" hcl:"enable_metrics"`
	EnableTracing        bool                  `json:"enable_tracing" yaml:"enable_tracing" hcl:"enable_tracing"`
	EnableProfiling      bool                  `json:"enable_profiling" yaml:"enable_profiling" hcl:"enable_profiling"`
	EnableValidation     bool                  `json:"enable_validation" yaml:"enable_validation" hcl:"enable_validation"`
	EnableOptimization   bool                  `json:"enable_optimization" yaml:"enable_optimization" hcl:"enable_optimization"`
	EnableCompression    bool                  `json:"enable_compression" yaml:"enable_compression" hcl:"enable_compression"`
	EnableEncryption     bool                  `json:"enable_encryption" yaml:"enable_encryption" hcl:"enable_encryption"`
	EnableBackup         bool                  `json:"enable_backup" yaml:"enable_backup" hcl:"enable_backup"`
	EnableRecovery       bool                  `json:"enable_recovery" yaml:"enable_recovery" hcl:"enable_recovery"`
	EnableMonitoring     bool                  `json:"enable_monitoring" yaml:"enable_monitoring" hcl:"enable_monitoring"`
	EnableAlerting       bool                  `json:"enable_alerting" yaml:"enable_alerting" hcl:"enable_alerting"`
	EnableReporting      bool                  `json:"enable_reporting" yaml:"enable_reporting" hcl:"enable_reporting"`
	EnableAnalytics      bool                  `json:"enable_analytics" yaml:"enable_analytics" hcl:"enable_analytics"`
	CustomFlags          map[string]bool       `json:"custom_flags" yaml:"custom_flags" hcl:"custom_flags,optional"`
}

type Dependency struct {
	Name      string   `json:"name" yaml:"name" hcl:"name,label"`
	Path      string   `json:"path" yaml:"path" hcl:"path"`
	ConfigPath string  `json:"config_path" yaml:"config_path" hcl:"config_path,optional"`
	Outputs   []string `json:"outputs" yaml:"outputs" hcl:"outputs,optional"`
	MockOutputs map[string]interface{} `json:"mock_outputs" yaml:"mock_outputs" hcl:"mock_outputs,optional"`
	Skip      bool     `json:"skip" yaml:"skip" hcl:"skip"`
}

type Hook struct {
	Name         string   `json:"name" yaml:"name" hcl:"name,label"`
	Commands     []string `json:"commands" yaml:"commands" hcl:"commands"`
	ExecuteOn    string   `json:"execute_on" yaml:"execute_on" hcl:"execute_on"`
	RunOn        []string `json:"run_on" yaml:"run_on" hcl:"run_on,optional"`
	WorkingDir   string   `json:"working_dir" yaml:"working_dir" hcl:"working_dir,optional"`
	Env          map[string]string `json:"env" yaml:"env" hcl:"env,optional"`
	ErrorMessage string   `json:"error_message" yaml:"error_message" hcl:"error_message,optional"`
	Suppress     bool     `json:"suppress" yaml:"suppress" hcl:"suppress"`
}

type GenerateBlock struct {
	Name       string `json:"name" yaml:"name" hcl:"name,label"`
	Path       string `json:"path" yaml:"path" hcl:"path"`
	IfExists   string `json:"if_exists" yaml:"if_exists" hcl:"if_exists"`
	Contents   string `json:"contents" yaml:"contents" hcl:"contents"`
	CommentPrefix string `json:"comment_prefix" yaml:"comment_prefix" hcl:"comment_prefix,optional"`
	DisableSignature bool `json:"disable_signature" yaml:"disable_signature" hcl:"disable_signature"`
}

type AlertChannel struct {
	Name     string                 `json:"name" yaml:"name" hcl:"name,label"`
	Type     string                 `json:"type" yaml:"type" hcl:"type"`
	Enabled  bool                   `json:"enabled" yaml:"enabled" hcl:"enabled"`
	Config   map[string]interface{} `json:"config" yaml:"config" hcl:"config"`
}

type CustomMetric struct {
	Name        string                 `json:"name" yaml:"name" hcl:"name,label"`
	Type        string                 `json:"type" yaml:"type" hcl:"type"`
	Description string                 `json:"description" yaml:"description" hcl:"description,optional"`
	Unit        string                 `json:"unit" yaml:"unit" hcl:"unit,optional"`
	Labels      map[string]string      `json:"labels" yaml:"labels" hcl:"labels,optional"`
	Query       string                 `json:"query" yaml:"query" hcl:"query,optional"`
	Interval    string                 `json:"interval" yaml:"interval" hcl:"interval,optional"`
	Aggregation string                 `json:"aggregation" yaml:"aggregation" hcl:"aggregation,optional"`
	Filters     map[string]interface{} `json:"filters" yaml:"filters" hcl:"filters,optional"`
}

type LogFilter struct {
	Name         string   `json:"name" yaml:"name" hcl:"name,label"`
	Filter       string   `json:"filter" yaml:"filter" hcl:"filter"`
	Severity     []string `json:"severity" yaml:"severity" hcl:"severity,optional"`
	ResourceType []string `json:"resource_type" yaml:"resource_type" hcl:"resource_type,optional"`
	LogName      string   `json:"log_name" yaml:"log_name" hcl:"log_name,optional"`
	Description  string   `json:"description" yaml:"description" hcl:"description,optional"`
}

type TracingConfig struct {
	Enabled          bool                   `json:"enabled" yaml:"enabled" hcl:"enabled"`
	Provider         string                 `json:"provider" yaml:"provider" hcl:"provider"`
	Endpoint         string                 `json:"endpoint" yaml:"endpoint" hcl:"endpoint"`
	ServiceName      string                 `json:"service_name" yaml:"service_name" hcl:"service_name"`
	SamplingRate     float64                `json:"sampling_rate" yaml:"sampling_rate" hcl:"sampling_rate"`
	Propagators      []string               `json:"propagators" yaml:"propagators" hcl:"propagators,optional"`
	ResourceAttributes map[string]string    `json:"resource_attributes" yaml:"resource_attributes" hcl:"resource_attributes,optional"`
	Headers          map[string]string      `json:"headers" yaml:"headers" hcl:"headers,optional"`
}

type ExporterConfig struct {
	Name     string                 `json:"name" yaml:"name" hcl:"name,label"`
	Type     string                 `json:"type" yaml:"type" hcl:"type"`
	Endpoint string                 `json:"endpoint" yaml:"endpoint" hcl:"endpoint"`
	Format   string                 `json:"format" yaml:"format" hcl:"format,optional"`
	Headers  map[string]string      `json:"headers" yaml:"headers" hcl:"headers,optional"`
	Config   map[string]interface{} `json:"config" yaml:"config" hcl:"config,optional"`
}

type IAMPolicy struct {
	Name      string   `json:"name" yaml:"name" hcl:"name,label"`
	Resource  string   `json:"resource" yaml:"resource" hcl:"resource"`
	Members   []string `json:"members" yaml:"members" hcl:"members"`
	Role      string   `json:"role" yaml:"role" hcl:"role"`
	Condition string   `json:"condition" yaml:"condition" hcl:"condition,optional"`
}

type FirewallRule struct {
	Name           string   `json:"name" yaml:"name" hcl:"name,label"`
	Direction      string   `json:"direction" yaml:"direction" hcl:"direction"`
	Priority       int      `json:"priority" yaml:"priority" hcl:"priority"`
	SourceRanges   []string `json:"source_ranges" yaml:"source_ranges" hcl:"source_ranges,optional"`
	DestRanges     []string `json:"destination_ranges" yaml:"destination_ranges" hcl:"destination_ranges,optional"`
	SourceTags     []string `json:"source_tags" yaml:"source_tags" hcl:"source_tags,optional"`
	TargetTags     []string `json:"target_tags" yaml:"target_tags" hcl:"target_tags,optional"`
	Protocol       string   `json:"protocol" yaml:"protocol" hcl:"protocol"`
	Ports          []string `json:"ports" yaml:"ports" hcl:"ports,optional"`
	Action         string   `json:"action" yaml:"action" hcl:"action"`
	Disabled       bool     `json:"disabled" yaml:"disabled" hcl:"disabled"`
	LogConfig      bool     `json:"log_config" yaml:"log_config" hcl:"log_config"`
}

type SecurityGroup struct {
	Name        string              `json:"name" yaml:"name" hcl:"name,label"`
	Description string              `json:"description" yaml:"description" hcl:"description,optional"`
	VPC         string              `json:"vpc" yaml:"vpc" hcl:"vpc"`
	Rules       []SecurityGroupRule `json:"rules" yaml:"rules" hcl:"rules,block"`
}

type SecurityGroupRule struct {
	Type        string   `json:"type" yaml:"type" hcl:"type"`
	FromPort    int      `json:"from_port" yaml:"from_port" hcl:"from_port"`
	ToPort      int      `json:"to_port" yaml:"to_port" hcl:"to_port"`
	Protocol    string   `json:"protocol" yaml:"protocol" hcl:"protocol"`
	CIDRBlocks  []string `json:"cidr_blocks" yaml:"cidr_blocks" hcl:"cidr_blocks,optional"`
	Description string   `json:"description" yaml:"description" hcl:"description,optional"`
}

type SecretManagement struct {
	Provider      string            `json:"provider" yaml:"provider" hcl:"provider"`
	ProjectID     string            `json:"project_id" yaml:"project_id" hcl:"project_id"`
	AutoRotation  bool              `json:"auto_rotation" yaml:"auto_rotation" hcl:"auto_rotation"`
	RotationDays  int               `json:"rotation_days" yaml:"rotation_days" hcl:"rotation_days"`
	EncryptionKey string            `json:"encryption_key" yaml:"encryption_key" hcl:"encryption_key,optional"`
	Labels        map[string]string `json:"labels" yaml:"labels" hcl:"labels,optional"`
}

type AuditLogging struct {
	Enabled       bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	LogType       string            `json:"log_type" yaml:"log_type" hcl:"log_type"`
	DataAccess    bool              `json:"data_access" yaml:"data_access" hcl:"data_access"`
	AdminActivity bool              `json:"admin_activity" yaml:"admin_activity" hcl:"admin_activity"`
	SystemEvent   bool              `json:"system_event" yaml:"system_event" hcl:"system_event"`
	PolicyDenied  bool              `json:"policy_denied" yaml:"policy_denied" hcl:"policy_denied"`
	Retention     int               `json:"retention_days" yaml:"retention_days" hcl:"retention_days"`
	Destination   string            `json:"destination" yaml:"destination" hcl:"destination"`
	Filters       []string          `json:"filters" yaml:"filters" hcl:"filters,optional"`
	ExemptMembers []string          `json:"exempt_members" yaml:"exempt_members" hcl:"exempt_members,optional"`
}

type DataProtection struct {
	Enabled             bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	ClassificationLevel string            `json:"classification_level" yaml:"classification_level" hcl:"classification_level"`
	DLPEnabled          bool              `json:"dlp_enabled" yaml:"dlp_enabled" hcl:"dlp_enabled"`
	EncryptionAtRest    bool              `json:"encryption_at_rest" yaml:"encryption_at_rest" hcl:"encryption_at_rest"`
	EncryptionInTransit bool              `json:"encryption_in_transit" yaml:"encryption_in_transit" hcl:"encryption_in_transit"`
	BackupEnabled       bool              `json:"backup_enabled" yaml:"backup_enabled" hcl:"backup_enabled"`
	BackupRetention     int               `json:"backup_retention_days" yaml:"backup_retention_days" hcl:"backup_retention_days"`
	DataResidency       string            `json:"data_residency" yaml:"data_residency" hcl:"data_residency,optional"`
	RetentionPolicy     string            `json:"retention_policy" yaml:"retention_policy" hcl:"retention_policy,optional"`
	Labels              map[string]string `json:"labels" yaml:"labels" hcl:"labels,optional"`
}

type AccessControl struct {
	Enabled               bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	MFARequired           bool              `json:"mfa_required" yaml:"mfa_required" hcl:"mfa_required"`
	SessionTimeout        int               `json:"session_timeout_minutes" yaml:"session_timeout_minutes" hcl:"session_timeout_minutes"`
	IPWhitelist           []string          `json:"ip_whitelist" yaml:"ip_whitelist" hcl:"ip_whitelist,optional"`
	IPBlacklist           []string          `json:"ip_blacklist" yaml:"ip_blacklist" hcl:"ip_blacklist,optional"`
	RequireApproval       bool              `json:"require_approval" yaml:"require_approval" hcl:"require_approval"`
	ApprovalGroups        []string          `json:"approval_groups" yaml:"approval_groups" hcl:"approval_groups,optional"`
	PrivilegedAccessMode  string            `json:"privileged_access_mode" yaml:"privileged_access_mode" hcl:"privileged_access_mode,optional"`
	JustInTimeAccess      bool              `json:"just_in_time_access" yaml:"just_in_time_access" hcl:"just_in_time_access"`
	MaxSessionDuration    int               `json:"max_session_duration_hours" yaml:"max_session_duration_hours" hcl:"max_session_duration_hours"`
}

type SubnetConfig struct {
	Name                 string            `json:"name" yaml:"name" hcl:"name,label"`
	CIDR                 string            `json:"cidr" yaml:"cidr" hcl:"cidr"`
	Region               string            `json:"region" yaml:"region" hcl:"region"`
	PrivateGoogleAccess  bool              `json:"private_google_access" yaml:"private_google_access" hcl:"private_google_access"`
	FlowLogs             bool              `json:"flow_logs" yaml:"flow_logs" hcl:"flow_logs"`
	SecondaryRanges      []SecondaryRange  `json:"secondary_ranges" yaml:"secondary_ranges" hcl:"secondary_ranges,block"`
	Purpose              string            `json:"purpose" yaml:"purpose" hcl:"purpose,optional"`
	Role                 string            `json:"role" yaml:"role" hcl:"role,optional"`
}

type SecondaryRange struct {
	Name string `json:"name" yaml:"name" hcl:"name,label"`
	CIDR string `json:"cidr" yaml:"cidr" hcl:"cidr"`
}

type RouteConfig struct {
	Name            string   `json:"name" yaml:"name" hcl:"name,label"`
	DestRange       string   `json:"dest_range" yaml:"dest_range" hcl:"dest_range"`
	NextHopGateway  string   `json:"next_hop_gateway" yaml:"next_hop_gateway" hcl:"next_hop_gateway,optional"`
	NextHopInstance string   `json:"next_hop_instance" yaml:"next_hop_instance" hcl:"next_hop_instance,optional"`
	NextHopIP       string   `json:"next_hop_ip" yaml:"next_hop_ip" hcl:"next_hop_ip,optional"`
	NextHopVPN      string   `json:"next_hop_vpn" yaml:"next_hop_vpn" hcl:"next_hop_vpn,optional"`
	Priority        int      `json:"priority" yaml:"priority" hcl:"priority"`
	Tags            []string `json:"tags" yaml:"tags" hcl:"tags,optional"`
}

type PeeringConfig struct {
	Name                    string `json:"name" yaml:"name" hcl:"name,label"`
	PeerNetwork             string `json:"peer_network" yaml:"peer_network" hcl:"peer_network"`
	AutoCreateRoutes        bool   `json:"auto_create_routes" yaml:"auto_create_routes" hcl:"auto_create_routes"`
	ExportCustomRoutes      bool   `json:"export_custom_routes" yaml:"export_custom_routes" hcl:"export_custom_routes"`
	ImportCustomRoutes      bool   `json:"import_custom_routes" yaml:"import_custom_routes" hcl:"import_custom_routes"`
	ExportSubnetRoutesWithPublicIP bool `json:"export_subnet_routes_with_public_ip" yaml:"export_subnet_routes_with_public_ip" hcl:"export_subnet_routes_with_public_ip"`
	ImportSubnetRoutesWithPublicIP bool `json:"import_subnet_routes_with_public_ip" yaml:"import_subnet_routes_with_public_ip" hcl:"import_subnet_routes_with_public_ip"`
}

type NATGateway struct {
	Name                    string   `json:"name" yaml:"name" hcl:"name,label"`
	Region                  string   `json:"region" yaml:"region" hcl:"region"`
	Router                  string   `json:"router" yaml:"router" hcl:"router"`
	IPAllocationOption      string   `json:"ip_allocation_option" yaml:"ip_allocation_option" hcl:"ip_allocation_option"`
	SourceSubnetworkIPRanges string  `json:"source_subnetwork_ip_ranges" yaml:"source_subnetwork_ip_ranges" hcl:"source_subnetwork_ip_ranges"`
	Subnetworks            []string  `json:"subnetworks" yaml:"subnetworks" hcl:"subnetworks,optional"`
	NATIPs                 []string  `json:"nat_ips" yaml:"nat_ips" hcl:"nat_ips,optional"`
	MinPortsPerVM          int       `json:"min_ports_per_vm" yaml:"min_ports_per_vm" hcl:"min_ports_per_vm"`
	LogConfig              bool      `json:"log_config" yaml:"log_config" hcl:"log_config"`
}

type LoadBalancerConfig struct {
	Name            string                 `json:"name" yaml:"name" hcl:"name,label"`
	Type            string                 `json:"type" yaml:"type" hcl:"type"`
	Scheme          string                 `json:"scheme" yaml:"scheme" hcl:"scheme"`
	IPAddress       string                 `json:"ip_address" yaml:"ip_address" hcl:"ip_address,optional"`
	IPProtocol      string                 `json:"ip_protocol" yaml:"ip_protocol" hcl:"ip_protocol"`
	Port            int                    `json:"port" yaml:"port" hcl:"port"`
	BackendService  string                 `json:"backend_service" yaml:"backend_service" hcl:"backend_service"`
	HealthCheck     string                 `json:"health_check" yaml:"health_check" hcl:"health_check"`
	SSLCertificates []string               `json:"ssl_certificates" yaml:"ssl_certificates" hcl:"ssl_certificates,optional"`
	SSLPolicy       string                 `json:"ssl_policy" yaml:"ssl_policy" hcl:"ssl_policy,optional"`
	CDNEnabled      bool                   `json:"cdn_enabled" yaml:"cdn_enabled" hcl:"cdn_enabled"`
	LogConfig       bool                   `json:"log_config" yaml:"log_config" hcl:"log_config"`
	Labels          map[string]string      `json:"labels" yaml:"labels" hcl:"labels,optional"`
}

type DNSConfig struct {
	Enabled          bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	ManagedZones     []ManagedZone     `json:"managed_zones" yaml:"managed_zones" hcl:"managed_zones,block"`
	RecordSets       []RecordSet       `json:"record_sets" yaml:"record_sets" hcl:"record_sets,block"`
	Policies         []DNSPolicy       `json:"policies" yaml:"policies" hcl:"policies,block"`
}

type ManagedZone struct {
	Name         string            `json:"name" yaml:"name" hcl:"name,label"`
	DNSName      string            `json:"dns_name" yaml:"dns_name" hcl:"dns_name"`
	Description  string            `json:"description" yaml:"description" hcl:"description,optional"`
	Visibility   string            `json:"visibility" yaml:"visibility" hcl:"visibility"`
	Networks     []string          `json:"networks" yaml:"networks" hcl:"networks,optional"`
	DNSSEC       bool              `json:"dnssec" yaml:"dnssec" hcl:"dnssec"`
	Labels       map[string]string `json:"labels" yaml:"labels" hcl:"labels,optional"`
}

type RecordSet struct {
	Name    string   `json:"name" yaml:"name" hcl:"name,label"`
	Type    string   `json:"type" yaml:"type" hcl:"type"`
	TTL     int      `json:"ttl" yaml:"ttl" hcl:"ttl"`
	Records []string `json:"records" yaml:"records" hcl:"records"`
	Zone    string   `json:"zone" yaml:"zone" hcl:"zone"`
}

type DNSPolicy struct {
	Name               string                 `json:"name" yaml:"name" hcl:"name,label"`
	EnableInbound      bool                   `json:"enable_inbound" yaml:"enable_inbound" hcl:"enable_inbound"`
	EnableLogging      bool                   `json:"enable_logging" yaml:"enable_logging" hcl:"enable_logging"`
	Networks           []string               `json:"networks" yaml:"networks" hcl:"networks"`
	AlternativeNameServers []string          `json:"alternative_name_servers" yaml:"alternative_name_servers" hcl:"alternative_name_servers,optional"`
}

type CDNConfig struct {
	Enabled           bool              `json:"enabled" yaml:"enabled" hcl:"enabled"`
	CacheMode         string            `json:"cache_mode" yaml:"cache_mode" hcl:"cache_mode"`
	DefaultTTL        int               `json:"default_ttl" yaml:"default_ttl" hcl:"default_ttl"`
	MaxTTL            int               `json:"max_ttl" yaml:"max_ttl" hcl:"max_ttl"`
	ClientTTL         int               `json:"client_ttl" yaml:"client_ttl" hcl:"client_ttl"`
	NegativeCaching   bool              `json:"negative_caching" yaml:"negative_caching" hcl:"negative_caching"`
	CacheKeyPolicy    CacheKeyPolicy    `json:"cache_key_policy" yaml:"cache_key_policy" hcl:"cache_key_policy,block"`
	SignedURLKeys     []string          `json:"signed_url_keys" yaml:"signed_url_keys" hcl:"signed_url_keys,optional"`
}

type CacheKeyPolicy struct {
	IncludeHost        bool     `json:"include_host" yaml:"include_host" hcl:"include_host"`
	IncludeProtocol    bool     `json:"include_protocol" yaml:"include_protocol" hcl:"include_protocol"`
	IncludeQueryString bool     `json:"include_query_string" yaml:"include_query_string" hcl:"include_query_string"`
	QueryStringWhitelist []string `json:"query_string_whitelist" yaml:"query_string_whitelist" hcl:"query_string_whitelist,optional"`
	QueryStringBlacklist []string `json:"query_string_blacklist" yaml:"query_string_blacklist" hcl:"query_string_blacklist,optional"`
}

type Loader struct {
	v        *viper.Viper
	parser   *hclparse.Parser
	tfLoader *tfconfig.Module
}

func NewLoader() *Loader {
	return &Loader{
		v:      viper.New(),
		parser: hclparse.NewParser(),
	}
}

func (l *Loader) LoadConfig(ctx context.Context, path string) (*Config, error) {
	cfg := &Config{
		loadTime: time.Now(),
	}

	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".json":
		return l.loadJSON(path, cfg)
	case ".yaml", ".yml":
		return l.loadYAML(path, cfg)
	case ".hcl", ".tf", ".tfvars":
		return l.loadHCL(path, cfg)
	default:
		return l.loadFromEnvAndFlags(cfg)
	}
}

func (l *Loader) loadJSON(path string, cfg *Config) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading JSON config: %w", err)
	}

	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parsing JSON config: %w", err)
	}

	cfg.ConfigPath = path
	return cfg, nil
}

func (l *Loader) loadYAML(path string, cfg *Config) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading YAML config: %w", err)
	}

	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("parsing YAML config: %w", err)
	}

	cfg.ConfigPath = path
	return cfg, nil
}

func (l *Loader) loadHCL(path string, cfg *Config) (*Config, error) {
	src, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading HCL config: %w", err)
	}

	file, diags := l.parser.ParseHCL(src, path)
	if diags.HasErrors() {
		return nil, fmt.Errorf("parsing HCL: %w", diags)
	}

	evalCtx := &hcl.EvalContext{}
	if err := gohcl.DecodeBody(file.Body, evalCtx, cfg); err != nil {
		return nil, fmt.Errorf("decoding HCL: %w", err)
	}

	cfg.ConfigPath = path
	return cfg, nil
}

func (l *Loader) loadFromEnvAndFlags(cfg *Config) (*Config, error) {
	l.v.SetEnvPrefix("TERRAGRUNT")
	l.v.AutomaticEnv()
	l.v.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))

	l.v.SetDefault("project", os.Getenv("GOOGLE_PROJECT"))
	l.v.SetDefault("region", os.Getenv("GOOGLE_REGION"))
	l.v.SetDefault("zone", os.Getenv("GOOGLE_ZONE"))
	l.v.SetDefault("environment", "dev")
	l.v.SetDefault("terraform.parallelism", 10)
	l.v.SetDefault("terraform.color", true)
	l.v.SetDefault("terragrunt.non_interactive", false)
	l.v.SetDefault("terragrunt.auto_retry", true)
	l.v.SetDefault("terragrunt.max_retries", 3)

	if err := l.v.Unmarshal(cfg); err != nil {
		return nil, fmt.Errorf("unmarshaling config: %w", err)
	}

	return cfg, nil
}

func (c *Config) Validate() error {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.Project == "" {
		return fmt.Errorf("project is required")
	}

	if c.Backend.Type == "" {
		c.Backend.Type = "gcs"
	}

	if c.Terraform.Parallelism <= 0 {
		c.Terraform.Parallelism = 10
	}

	if c.Terragrunt.MaxRetries <= 0 {
		c.Terragrunt.MaxRetries = 3
	}

	for name, module := range c.Modules {
		if module.Source == "" {
			return fmt.Errorf("module %s: source is required", module.Name)
		}
		if module.Count < 0 {
			return fmt.Errorf("module %s: count cannot be negative", module.Name)
		}
	}

	return nil
}

func (c *Config) SaveAs(path string) error {
	c.mu.RLock()
	defer c.mu.RUnlock()

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("creating config directory: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(path))
	var data []byte
	var err error

	switch ext {
	case ".json":
		data, err = json.MarshalIndent(c, "", "  ")
	case ".yaml", ".yml":
		data, err = yaml.Marshal(c)
	case ".hcl", ".tf", ".tfvars":
		data, err = c.marshalHCL()
	default:
		return fmt.Errorf("unsupported config format: %s", ext)
	}

	if err != nil {
		return fmt.Errorf("marshaling config: %w", err)
	}

	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("writing config file: %w", err)
	}

	return nil
}

func (c *Config) marshalHCL() ([]byte, error) {
	return []byte(fmt.Sprintf(`project = "%s"
region = "%s"
zone = "%s"
environment = "%s"

terraform {
  version = "%s"
  working_dir = "%s"
  parallelism = %d
  auto_init = %t
  color = %t
}

terragrunt {
  version = "%s"
  config_file = "%s"
  non_interactive = %t
  auto_retry = %t
  max_retries = %d
}

backend {
  type = "%s"
  bucket = "%s"
  prefix = "%s"
  project = "%s"
}
`, c.Project, c.Region, c.Zone, c.Environment,
		c.Terraform.Version, c.Terraform.WorkingDir, c.Terraform.Parallelism,
		c.Terraform.AutoInit, c.Terraform.Color,
		c.Terragrunt.Version, c.Terragrunt.ConfigFile,
		c.Terragrunt.NonInteractive, c.Terragrunt.AutoRetry, c.Terragrunt.MaxRetries,
		c.Backend.Type, c.Backend.Bucket, c.Backend.Prefix, c.Backend.Project)), nil
}

func (c *Config) Merge(other *Config) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if other == nil {
		return
	}

	if other.Project != "" {
		c.Project = other.Project
	}
	if other.Region != "" {
		c.Region = other.Region
	}
	if other.Zone != "" {
		c.Zone = other.Zone
	}
	if other.Environment != "" {
		c.Environment = other.Environment
	}

	if other.Terraform.Version != "" {
		c.Terraform = other.Terraform
	}
	if other.Terragrunt.Version != "" {
		c.Terragrunt = other.Terragrunt
	}
	if other.Backend.Type != "" {
		c.Backend = other.Backend
	}

	for k, v := range other.Providers {
		if c.Providers == nil {
			c.Providers = make(map[string]Provider)
		}
		c.Providers[k] = v
	}

	for k, v := range other.Variables {
		if c.Variables == nil {
			c.Variables = make(map[string]interface{})
		}
		c.Variables[k] = v
	}

	for k, v := range other.Tags {
		if c.Tags == nil {
			c.Tags = make(map[string]string)
		}
		c.Tags[k] = v
	}

	if len(other.Modules) > 0 {
		c.Modules = append(c.Modules, other.Modules...)
	}
}

func (c *Config) GetString(key string) string {
	c.mu.RLock()
	defer c.mu.RUnlock()

	parts := strings.Split(key, ".")
	if len(parts) == 0 {
		return ""
	}

	switch parts[0] {
	case "project":
		return c.Project
	case "region":
		return c.Region
	case "zone":
		return c.Zone
	case "environment":
		return c.Environment
	case "terraform":
		if len(parts) > 1 {
			return c.getTerraformValue(parts[1])
		}
	case "terragrunt":
		if len(parts) > 1 {
			return c.getTerragruntValue(parts[1])
		}
	case "backend":
		if len(parts) > 1 {
			return c.getBackendValue(parts[1])
		}
	}

	if v, ok := c.Variables[key]; ok {
		return fmt.Sprintf("%v", v)
	}

	return ""
}

func (c *Config) getTerraformValue(key string) string {
	switch key {
	case "version":
		return c.Terraform.Version
	case "working_dir":
		return c.Terraform.WorkingDir
	case "plan_file":
		return c.Terraform.PlanFile
	case "state_file":
		return c.Terraform.StateFile
	case "plugin_dir":
		return c.Terraform.PluginDir
	case "lock_timeout":
		return c.Terraform.LockTimeout
	case "parallelism":
		return fmt.Sprintf("%d", c.Terraform.Parallelism)
	}
	return ""
}

func (c *Config) getTerragruntValue(key string) string {
	switch key {
	case "version":
		return c.Terragrunt.Version
	case "config_file":
		return c.Terragrunt.ConfigFile
	case "download_dir":
		return c.Terragrunt.DownloadDir
	case "iam_role":
		return c.Terragrunt.IamRole
	case "terraform_binary":
		return c.Terragrunt.TerraformBinary
	case "parallelism":
		return fmt.Sprintf("%d", c.Terragrunt.Parallelism)
	case "max_retries":
		return fmt.Sprintf("%d", c.Terragrunt.MaxRetries)
	}
	return ""
}

func (c *Config) getBackendValue(key string) string {
	switch key {
	case "type":
		return c.Backend.Type
	case "bucket":
		return c.Backend.Bucket
	case "prefix":
		return c.Backend.Prefix
	case "project":
		return c.Backend.Project
	case "region":
		return c.Backend.Region
	case "kms_key_id":
		return c.Backend.KMSKeyID
	case "lock_table":
		return c.Backend.LockTable
	}
	return ""
}

func (c *Config) SetString(key, value string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	parts := strings.Split(key, ".")
	if len(parts) == 0 {
		return
	}

	switch parts[0] {
	case "project":
		c.Project = value
	case "region":
		c.Region = value
	case "zone":
		c.Zone = value
	case "environment":
		c.Environment = value
	default:
		if c.Variables == nil {
			c.Variables = make(map[string]interface{})
		}
		c.Variables[key] = value
	}
}

func (c *Config) LoadTerraformModule(path string) error {
	module, diags := tfconfig.LoadModule(path)
	if diags.HasErrors() {
		return fmt.Errorf("loading Terraform module: %w", diags.Err())
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	c.tfLoader = module

	for name, provider := range module.RequiredProviders {
		if c.Providers == nil {
			c.Providers = make(map[string]Provider)
		}
		c.Providers[name] = Provider{
			Source:  provider.Source,
			Version: strings.Join(provider.VersionConstraints, ", "),
		}
	}

	for name, variable := range module.Variables {
		if c.Variables == nil {
			c.Variables = make(map[string]interface{})
		}
		if variable.Default != nil {
			c.Variables[name] = variable.Default
		}
	}

	for name, output := range module.Outputs {
		if c.Outputs == nil {
			c.Outputs = make(map[string]Output)
		}
		c.Outputs[name] = Output{
			Description: output.Description,
			Sensitive:   output.Sensitive,
		}
	}

	return nil
}

func (c *Config) GetModuleByName(name string) *ModuleConfig {
	c.mu.RLock()
	defer c.mu.RUnlock()

	for _, module := range c.Modules {
		if module.Name == name {
			return &module
		}
	}
	return nil
}

func (c *Config) GetProviderByName(name string) *Provider {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if provider, ok := c.Providers[name]; ok {
		return &provider
	}
	return nil
}

func (c *Config) IsFeatureEnabled(feature string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	switch feature {
	case "caching":
		return c.Features.EnableCaching
	case "parallel_exec":
		return c.Features.EnableParallelExec
	case "auto_retry":
		return c.Features.EnableAutoRetry
	case "dry_run":
		return c.Features.EnableDryRun
	case "debug":
		return c.Features.EnableDebugMode
	case "metrics":
		return c.Features.EnableMetrics
	case "tracing":
		return c.Features.EnableTracing
	case "profiling":
		return c.Features.EnableProfiling
	case "validation":
		return c.Features.EnableValidation
	case "optimization":
		return c.Features.EnableOptimization
	case "compression":
		return c.Features.EnableCompression
	case "encryption":
		return c.Features.EnableEncryption
	case "backup":
		return c.Features.EnableBackup
	case "recovery":
		return c.Features.EnableRecovery
	case "monitoring":
		return c.Features.EnableMonitoring
	case "alerting":
		return c.Features.EnableAlerting
	case "reporting":
		return c.Features.EnableReporting
	case "analytics":
		return c.Features.EnableAnalytics
	default:
		if c.Features.CustomFlags != nil {
			return c.Features.CustomFlags[feature]
		}
		return false
	}
}

func (c *Config) Clone() *Config {
	c.mu.RLock()
	defer c.mu.RUnlock()

	data, _ := json.Marshal(c)
	var clone Config
	json.Unmarshal(data, &clone)
	return &clone
}