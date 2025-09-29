package gcp

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/big"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/compute/metadata"
	"cloud.google.com/go/logging"
	// "cloud.google.com/go/resourcemanager/apiv1/resourcemanagerpb"
	// "cloud.google.com/go/serviceusage/apiv1/serviceusagepb"
	"google.golang.org/api/cloudbilling/v1"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/serviceusage/v1"
	// "google.golang.org/protobuf/types/known/fieldmaskpb"
)

type UtilsService struct {
	client                 *Client
	projectID              string
	billingService         *cloudbilling.APIService
	resourceManagerService *cloudresourcemanager.Service
	serviceUsageService    *serviceusage.Service
	bigQueryClient         *bigquery.Client
	loggingClient          *logging.Client
	metadataCache          map[string]interface{}
	quotaCache             map[string]*QuotaInfo
	costCache              map[string]*CostInfo
	cacheMutex             sync.RWMutex
	lastCacheUpdate        time.Time
	cacheExpiry            time.Duration
	metrics                *ServiceMetrics
	logger                 *ServiceLogger
	circuitBreaker         *CircuitBreaker
	rateLimiter            *RateLimiter
	auditLogger            *AuditLogger
}

type ValidationRule struct {
	Field       string                 `json:"field"`
	Type        string                 `json:"type"`
	Required    bool                   `json:"required"`
	Pattern     string                 `json:"pattern,omitempty"`
	MinLength   int                    `json:"min_length,omitempty"`
	MaxLength   int                    `json:"max_length,omitempty"`
	MinValue    float64                `json:"min_value,omitempty"`
	MaxValue    float64                `json:"max_value,omitempty"`
	AllowedVals []string               `json:"allowed_values,omitempty"`
	Custom      func(interface{}) bool `json:"-"`
}

type ValidationResult struct {
	Valid   bool                   `json:"valid"`
	Errors  []ValidationError      `json:"errors,omitempty"`
	Context map[string]interface{} `json:"context,omitempty"`
}

type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Code    string `json:"code"`
	Value   string `json:"value,omitempty"`
}

type ResourceQuota struct {
	Name        string  `json:"name"`
	Limit       int64   `json:"limit"`
	Usage       int64   `json:"usage"`
	Available   int64   `json:"available"`
	Percentage  float64 `json:"percentage"`
	Region      string  `json:"region,omitempty"`
	Service     string  `json:"service"`
	Unit        string  `json:"unit"`
	Renewable   bool    `json:"renewable"`
	ResetPeriod string  `json:"reset_period,omitempty"`
}

type QuotaInfo struct {
	ProjectID     string           `json:"project_id"`
	Quotas        []*ResourceQuota `json:"quotas"`
	LastUpdated   time.Time        `json:"last_updated"`
	Warnings      []string         `json:"warnings,omitempty"`
	Errors        []string         `json:"errors,omitempty"`
	TotalQuotas   int              `json:"total_quotas"`
	ExceededCount int              `json:"exceeded_count"`
	WarningCount  int              `json:"warning_count"`
}

type CostBreakdown struct {
	Service     string            `json:"service"`
	SKU         string            `json:"sku"`
	Amount      float64           `json:"amount"`
	Currency    string            `json:"currency"`
	Usage       CostUsage         `json:"usage"`
	Credits     []CostCredit      `json:"credits,omitempty"`
	Labels      map[string]string `json:"labels,omitempty"`
	Region      string            `json:"region,omitempty"`
	ProjectName string            `json:"project_name,omitempty"`
}

type CostUsage struct {
	Amount     float64 `json:"amount"`
	Unit       string  `json:"unit"`
	AmountInPricingUnits float64 `json:"amount_in_pricing_units"`
	PricingUnit string  `json:"pricing_unit"`
}

type CostCredit struct {
	Name   string  `json:"name"`
	Amount float64 `json:"amount"`
	Type   string  `json:"type"`
}

type CostInfo struct {
	ProjectID      string           `json:"project_id"`
	TimeRange      TimeRange        `json:"time_range"`
	TotalCost      float64          `json:"total_cost"`
	Currency       string           `json:"currency"`
	Breakdown      []*CostBreakdown `json:"breakdown"`
	Forecast       *CostForecast    `json:"forecast,omitempty"`
	Budget         *BudgetInfo      `json:"budget,omitempty"`
	Trends         *CostTrends      `json:"trends,omitempty"`
	Recommendations []CostRecommendation `json:"recommendations,omitempty"`
	LastUpdated    time.Time        `json:"last_updated"`
}

type CostForecast struct {
	PredictedCost     float64   `json:"predicted_cost"`
	ConfidenceLevel   float64   `json:"confidence_level"`
	ForecastHorizon   string    `json:"forecast_horizon"`
	Model             string    `json:"model"`
	Factors           []string  `json:"factors"`
	LastTrained       time.Time `json:"last_trained"`
	Accuracy          float64   `json:"accuracy"`
}

type BudgetInfo struct {
	Name            string            `json:"name"`
	Amount          float64           `json:"amount"`
	Currency        string            `json:"currency"`
	Spent           float64           `json:"spent"`
	Remaining       float64           `json:"remaining"`
	Percentage      float64           `json:"percentage"`
	AlertThresholds []float64         `json:"alert_thresholds"`
	Filters         map[string]string `json:"filters,omitempty"`
	Period          string            `json:"period"`
	Status          string            `json:"status"`
}

type CostTrends struct {
	DailyAverage    float64           `json:"daily_average"`
	WeeklyTrend     float64           `json:"weekly_trend"`
	MonthlyTrend    float64           `json:"monthly_trend"`
	SeasonalFactors map[string]float64 `json:"seasonal_factors"`
	GrowthRate      float64           `json:"growth_rate"`
	Volatility      float64           `json:"volatility"`
	PeakUsageTimes  []string          `json:"peak_usage_times"`
}

type CostRecommendation struct {
	Type        string            `json:"type"`
	Resource    string            `json:"resource"`
	Description string            `json:"description"`
	Savings     float64           `json:"savings"`
	Effort      string            `json:"effort"`
	Impact      string            `json:"impact"`
	Steps       []string          `json:"steps"`
	Links       []string          `json:"links,omitempty"`
	Tags        map[string]string `json:"tags,omitempty"`
	Priority    int               `json:"priority"`
}

type TimeRange struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
}

type ProjectInfo struct {
	ProjectID       string            `json:"project_id"`
	ProjectNumber   string            `json:"project_number"`
	Name            string            `json:"name"`
	Parent          string            `json:"parent,omitempty"`
	State           string            `json:"state"`
	CreateTime      time.Time         `json:"create_time"`
	Labels          map[string]string `json:"labels,omitempty"`
	BillingAccount  string            `json:"billing_account,omitempty"`
	OrganizationID  string            `json:"organization_id,omitempty"`
	FolderID        string            `json:"folder_id,omitempty"`
	EnabledServices []string          `json:"enabled_services"`
	Quotas          *QuotaInfo        `json:"quotas,omitempty"`
	Costs           *CostInfo         `json:"costs,omitempty"`
	Metadata        map[string]interface{} `json:"metadata,omitempty"`
}

type ServiceInfo struct {
	Name        string            `json:"name"`
	Title       string            `json:"title"`
	State       string            `json:"state"`
	Config      *ServiceConfig    `json:"config,omitempty"`
	Usage       *ServiceUsage     `json:"usage,omitempty"`
	Quotas      []*ResourceQuota  `json:"quotas,omitempty"`
	Labels      map[string]string `json:"labels,omitempty"`
	Parent      string            `json:"parent"`
	EnableTime  time.Time         `json:"enable_time,omitempty"`
	DisableTime time.Time         `json:"disable_time,omitempty"`
}

type ServiceConfig struct {
	Name         string            `json:"name"`
	Title        string            `json:"title"`
	Documentation *ServiceDocs     `json:"documentation,omitempty"`
	Quota        *ServiceQuota     `json:"quota,omitempty"`
	Authentication *ServiceAuth    `json:"authentication,omitempty"`
	Usage        *ServiceUsageConfig `json:"usage,omitempty"`
	Endpoints    []ServiceEndpoint `json:"endpoints,omitempty"`
	Apis         []ServiceAPI      `json:"apis,omitempty"`
	Types        []ServiceType     `json:"types,omitempty"`
	Enums        []ServiceEnum     `json:"enums,omitempty"`
	Http         *ServiceHTTP      `json:"http,omitempty"`
	Backend      *ServiceBackend   `json:"backend,omitempty"`
	Logging      *ServiceLogging   `json:"logging,omitempty"`
	Monitoring   *ServiceMonitoring `json:"monitoring,omitempty"`
}

type ServiceDocs struct {
	Summary     string `json:"summary"`
	Overview    string `json:"overview"`
	Rules       []DocumentationRule `json:"rules,omitempty"`
	Pages       []DocumentationPage `json:"pages,omitempty"`
	ServiceRootUrl string `json:"service_root_url,omitempty"`
}

type DocumentationRule struct {
	Selector             string `json:"selector"`
	Description          string `json:"description"`
	DeprecationDescription string `json:"deprecation_description,omitempty"`
}

type DocumentationPage struct {
	Name    string `json:"name"`
	Content string `json:"content"`
	Subpages []DocumentationPage `json:"subpages,omitempty"`
}

type ServiceQuota struct {
	Limits         []QuotaLimit      `json:"limits,omitempty"`
	MetricRules    []MetricRule      `json:"metric_rules,omitempty"`
	QuotaCounters  []QuotaCounter    `json:"quota_counters,omitempty"`
}

type QuotaLimit struct {
	Name         string            `json:"name"`
	Description  string            `json:"description"`
	DefaultLimit int64             `json:"default_limit"`
	MaxLimit     int64             `json:"max_limit,omitempty"`
	FreeTier     int64             `json:"free_tier,omitempty"`
	Duration     string            `json:"duration,omitempty"`
	Metric       string            `json:"metric"`
	Unit         string            `json:"unit"`
	Values       map[string]int64  `json:"values,omitempty"`
	DisplayName  string            `json:"display_name,omitempty"`
}

type MetricRule struct {
	Selector         string            `json:"selector"`
	MetricCosts      map[string]int64  `json:"metric_costs,omitempty"`
}

type QuotaCounter struct {
	Name   string `json:"name"`
	Metric string `json:"metric"`
}

type ServiceAuth struct {
	Rules    []AuthRule    `json:"rules,omitempty"`
	Providers []AuthProvider `json:"providers,omitempty"`
}

type AuthRule struct {
	Selector     string               `json:"selector"`
	OAuth        *OAuthRequirement    `json:"oauth,omitempty"`
	AllowWithoutCredential bool       `json:"allow_without_credential,omitempty"`
	Requirements []AuthRequirement    `json:"requirements,omitempty"`
}

type OAuthRequirement struct {
	CanonicalScopes string `json:"canonical_scopes,omitempty"`
}

type AuthRequirement struct {
	ProviderId  string `json:"provider_id,omitempty"`
	Audiences   string `json:"audiences,omitempty"`
}

type AuthProvider struct {
	Id                string `json:"id"`
	Issuer            string `json:"issuer"`
	JwksUri           string `json:"jwks_uri,omitempty"`
	Audiences         string `json:"audiences,omitempty"`
	AuthorizationUrl  string `json:"authorization_url,omitempty"`
	JwtLocations      []JwtLocation `json:"jwt_locations,omitempty"`
}

type JwtLocation struct {
	Header        *JwtHeader `json:"header,omitempty"`
	Query         *JwtQuery  `json:"query,omitempty"`
	Cookie        *JwtCookie `json:"cookie,omitempty"`
	ValuePrefix   string     `json:"value_prefix,omitempty"`
}

type JwtHeader struct {
	Name        string `json:"name"`
	ValuePrefix string `json:"value_prefix,omitempty"`
}

type JwtQuery struct {
	Name        string `json:"name"`
	ValuePrefix string `json:"value_prefix,omitempty"`
}

type JwtCookie struct {
	Name string `json:"name"`
}

type ServiceUsageConfig struct {
	Requirements []string `json:"requirements,omitempty"`
	Rules        []UsageRule `json:"rules,omitempty"`
	ProducerNotificationChannel string `json:"producer_notification_channel,omitempty"`
}

type UsageRule struct {
	Selector               string `json:"selector"`
	AllowUnregisteredCalls bool   `json:"allow_unregistered_calls,omitempty"`
	SkipServiceControl     bool   `json:"skip_service_control,omitempty"`
}

type ServiceEndpoint struct {
	Name      string   `json:"name"`
	Aliases   []string `json:"aliases,omitempty"`
	Target    string   `json:"target"`
	AllowCors bool     `json:"allow_cors,omitempty"`
}

type ServiceAPI struct {
	Name    string          `json:"name"`
	Methods []ServiceMethod `json:"methods,omitempty"`
	Options []ServiceOption `json:"options,omitempty"`
	Version string          `json:"version,omitempty"`
	SourceContext *SourceContext `json:"source_context,omitempty"`
	Mixins  []ServiceMixin  `json:"mixins,omitempty"`
	Syntax  string          `json:"syntax,omitempty"`
}

type ServiceMethod struct {
	Name              string          `json:"name"`
	RequestTypeUrl    string          `json:"request_type_url"`
	RequestStreaming  bool            `json:"request_streaming,omitempty"`
	ResponseTypeUrl   string          `json:"response_type_url"`
	ResponseStreaming bool            `json:"response_streaming,omitempty"`
	Options           []ServiceOption `json:"options,omitempty"`
	Syntax            string          `json:"syntax,omitempty"`
}

type ServiceOption struct {
	Name  string      `json:"name"`
	Value interface{} `json:"value"`
}

type SourceContext struct {
	FileName string `json:"file_name"`
}

type ServiceMixin struct {
	Name string `json:"name"`
	Root string `json:"root,omitempty"`
}

type ServiceType struct {
	Name      string            `json:"name"`
	Fields    []ServiceField    `json:"fields,omitempty"`
	Oneofs    []string          `json:"oneofs,omitempty"`
	Options   []ServiceOption   `json:"options,omitempty"`
	SourceContext *SourceContext `json:"source_context,omitempty"`
	Syntax    string            `json:"syntax,omitempty"`
}

type ServiceField struct {
	Kind         string          `json:"kind"`
	Cardinality  string          `json:"cardinality"`
	Number       int32           `json:"number"`
	Name         string          `json:"name"`
	TypeUrl      string          `json:"type_url,omitempty"`
	OneofIndex   int32           `json:"oneof_index,omitempty"`
	Packed       bool            `json:"packed,omitempty"`
	Options      []ServiceOption `json:"options,omitempty"`
	JsonName     string          `json:"json_name,omitempty"`
	DefaultValue string          `json:"default_value,omitempty"`
}

type ServiceEnum struct {
	Name        string            `json:"name"`
	Enumvalue   []ServiceEnumValue `json:"enumvalue,omitempty"`
	Options     []ServiceOption   `json:"options,omitempty"`
	SourceContext *SourceContext `json:"source_context,omitempty"`
	Syntax      string            `json:"syntax,omitempty"`
}

type ServiceEnumValue struct {
	Name    string          `json:"name"`
	Number  int32           `json:"number"`
	Options []ServiceOption `json:"options,omitempty"`
}

type ServiceHTTP struct {
	Rules                   []HTTPRule `json:"rules,omitempty"`
	FullyDecodeReservedExpansion bool  `json:"fully_decode_reserved_expansion,omitempty"`
}

type HTTPRule struct {
	Selector                 string     `json:"selector"`
	Get                      string     `json:"get,omitempty"`
	Put                      string     `json:"put,omitempty"`
	Post                     string     `json:"post,omitempty"`
	Delete                   string     `json:"delete,omitempty"`
	Patch                    string     `json:"patch,omitempty"`
	Custom                   *CustomHTTPPattern `json:"custom,omitempty"`
	Body                     string     `json:"body,omitempty"`
	ResponseBody             string     `json:"response_body,omitempty"`
	AdditionalBindings       []HTTPRule `json:"additional_bindings,omitempty"`
}

type CustomHTTPPattern struct {
	Kind string `json:"kind"`
	Path string `json:"path"`
}

type ServiceBackend struct {
	Rules []BackendRule `json:"rules,omitempty"`
}

type BackendRule struct {
	Selector         string  `json:"selector"`
	Address          string  `json:"address,omitempty"`
	Deadline         float64 `json:"deadline,omitempty"`
	MinDeadline      float64 `json:"min_deadline,omitempty"`
	OperationDeadline float64 `json:"operation_deadline,omitempty"`
	PathTranslation  string  `json:"path_translation,omitempty"`
	JwtAudience      string  `json:"jwt_audience,omitempty"`
	DisableAuth      bool    `json:"disable_auth,omitempty"`
	Protocol         string  `json:"protocol,omitempty"`
}

type ServiceLogging struct {
	ProducerDestinations []LoggingDestination `json:"producer_destinations,omitempty"`
	ConsumerDestinations []LoggingDestination `json:"consumer_destinations,omitempty"`
}

type LoggingDestination struct {
	MonitoredResource string   `json:"monitored_resource"`
	Logs              []string `json:"logs,omitempty"`
}

type ServiceMonitoring struct {
	ProducerDestinations []MonitoringDestination `json:"producer_destinations,omitempty"`
	ConsumerDestinations []MonitoringDestination `json:"consumer_destinations,omitempty"`
	ProducerMetrics      []MetricDescriptor      `json:"producer_metrics,omitempty"`
	ConsumerMetrics      []MetricDescriptor      `json:"consumer_metrics,omitempty"`
}

type MonitoringDestination struct {
	MonitoredResource string   `json:"monitored_resource"`
	Metrics           []string `json:"metrics,omitempty"`
}

type MetricDescriptor struct {
	Name         string        `json:"name"`
	Type         string        `json:"type"`
	Labels       []LabelDescriptor `json:"labels,omitempty"`
	MetricKind   string        `json:"metric_kind"`
	ValueType    string        `json:"value_type"`
	Unit         string        `json:"unit,omitempty"`
	Description  string        `json:"description,omitempty"`
	DisplayName  string        `json:"display_name,omitempty"`
	Metadata     *MetricDescriptorMetadata `json:"metadata,omitempty"`
	LaunchStage  string        `json:"launch_stage,omitempty"`
	MonitoredResourceTypes []string `json:"monitored_resource_types,omitempty"`
}

type LabelDescriptor struct {
	Key         string `json:"key"`
	ValueType   string `json:"value_type"`
	Description string `json:"description,omitempty"`
}

type MetricDescriptorMetadata struct {
	LaunchStage    string        `json:"launch_stage,omitempty"`
	SamplePeriod   time.Duration `json:"sample_period,omitempty"`
	IngestDelay    time.Duration `json:"ingest_delay,omitempty"`
}

type ServiceUsage struct {
	ServiceName string            `json:"service_name"`
	Metrics     []UsageMetric     `json:"metrics"`
	Quotas      []*ResourceQuota  `json:"quotas,omitempty"`
	Costs       *CostInfo         `json:"costs,omitempty"`
	Alerts      []UsageAlert      `json:"alerts,omitempty"`
	Trends      *UsageTrends      `json:"trends,omitempty"`
	LastUpdated time.Time         `json:"last_updated"`
}

type UsageMetric struct {
	Name        string            `json:"name"`
	Value       float64           `json:"value"`
	Unit        string            `json:"unit"`
	Labels      map[string]string `json:"labels,omitempty"`
	Timestamp   time.Time         `json:"timestamp"`
	MetricKind  string            `json:"metric_kind"`
	ValueType   string            `json:"value_type"`
	Resource    map[string]string `json:"resource,omitempty"`
}

type UsageAlert struct {
	Type        string    `json:"type"`
	Severity    string    `json:"severity"`
	Message     string    `json:"message"`
	Resource    string    `json:"resource"`
	Threshold   float64   `json:"threshold"`
	CurrentValue float64   `json:"current_value"`
	Timestamp   time.Time `json:"timestamp"`
	Resolved    bool      `json:"resolved"`
	Actions     []string  `json:"actions,omitempty"`
}

type UsageTrends struct {
	Daily       map[string]float64 `json:"daily"`
	Weekly      map[string]float64 `json:"weekly"`
	Monthly     map[string]float64 `json:"monthly"`
	Growth      float64            `json:"growth"`
	Seasonality map[string]float64 `json:"seasonality"`
	Predictions map[string]float64 `json:"predictions"`
}

type ResourceRecommendation struct {
	Type        string            `json:"type"`
	Resource    string            `json:"resource"`
	Current     ResourceState     `json:"current"`
	Recommended ResourceState     `json:"recommended"`
	Savings     float64           `json:"savings"`
	Effort      string            `json:"effort"`
	Confidence  float64           `json:"confidence"`
	Impact      ImpactAnalysis    `json:"impact"`
	Steps       []ActionStep      `json:"steps"`
	Timeline    string            `json:"timeline"`
	Tags        map[string]string `json:"tags,omitempty"`
	Priority    int               `json:"priority"`
	Category    string            `json:"category"`
}

type ResourceState struct {
	Configuration map[string]interface{} `json:"configuration"`
	Utilization   map[string]float64     `json:"utilization"`
	Performance   map[string]float64     `json:"performance"`
	Cost          float64                `json:"cost"`
	Metadata      map[string]interface{} `json:"metadata,omitempty"`
}

type ImpactAnalysis struct {
	Performance   string   `json:"performance"`
	Availability  string   `json:"availability"`
	Security      string   `json:"security"`
	Compliance    string   `json:"compliance"`
	RiskFactors   []string `json:"risk_factors,omitempty"`
	Benefits      []string `json:"benefits"`
	Dependencies  []string `json:"dependencies,omitempty"`
}

type ActionStep struct {
	Order       int               `json:"order"`
	Description string            `json:"description"`
	Command     string            `json:"command,omitempty"`
	Duration    string            `json:"duration"`
	Risk        string            `json:"risk"`
	Rollback    string            `json:"rollback,omitempty"`
	Validation  string            `json:"validation,omitempty"`
	Dependencies []string         `json:"dependencies,omitempty"`
	Automated   bool              `json:"automated"`
	Parameters  map[string]string `json:"parameters,omitempty"`
}

type UtilsConfig struct {
	CacheExpiry        time.Duration `json:"cache_expiry"`
	MetricsEnabled     bool          `json:"metrics_enabled"`
	AuditEnabled       bool          `json:"audit_enabled"`
	ValidationEnabled  bool          `json:"validation_enabled"`
	RecommendationsEnabled bool      `json:"recommendations_enabled"`
	CostTrackingEnabled bool         `json:"cost_tracking_enabled"`
	QuotaMonitoringEnabled bool      `json:"quota_monitoring_enabled"`
	ServiceDiscoveryEnabled bool     `json:"service_discovery_enabled"`
	ProjectAnalysisEnabled bool      `json:"project_analysis_enabled"`
	SecurityScanningEnabled bool     `json:"security_scanning_enabled"`
	ComplianceCheckingEnabled bool   `json:"compliance_checking_enabled"`
	AutoOptimizationEnabled bool     `json:"auto_optimization_enabled"`
	RealTimeMonitoringEnabled bool   `json:"real_time_monitoring_enabled"`
	PredictiveAnalyticsEnabled bool  `json:"predictive_analytics_enabled"`
	CustomMetricsEnabled bool        `json:"custom_metrics_enabled"`
	DefaultRegion      string        `json:"default_region"`
	DefaultZone        string        `json:"default_zone"`
	ParallelOperations int           `json:"parallel_operations"`
	RetryAttempts      int           `json:"retry_attempts"`
	RetryDelay         time.Duration `json:"retry_delay"`
	Timeout            time.Duration `json:"timeout"`
	RateLimitQPS       float64       `json:"rate_limit_qps"`
	RateLimitBurst     int           `json:"rate_limit_burst"`
	MaxCacheSize       int           `json:"max_cache_size"`
	BackupEnabled      bool          `json:"backup_enabled"`
	BackupInterval     time.Duration `json:"backup_interval"`
	BackupRetention    time.Duration `json:"backup_retention"`
	EncryptionEnabled  bool          `json:"encryption_enabled"`
	CompressionEnabled bool          `json:"compression_enabled"`
	LogLevel           string        `json:"log_level"`
	LogFormat          string        `json:"log_format"`
	AlertThresholds    map[string]float64 `json:"alert_thresholds"`
	NotificationChannels []string    `json:"notification_channels"`
	CustomValidators   map[string]ValidationRule `json:"custom_validators"`
	FeatureFlags       map[string]bool `json:"feature_flags"`
	ExperimentalFeatures map[string]bool `json:"experimental_features"`
	IntegrationSettings map[string]interface{} `json:"integration_settings"`
	SecurityPolicies   map[string]interface{} `json:"security_policies"`
	CompliancePolicies map[string]interface{} `json:"compliance_policies"`
	OptimizationPolicies map[string]interface{} `json:"optimization_policies"`
}

func NewUtilsService(client *Client, config *UtilsConfig) (*UtilsService, error) {
	ctx := context.Background()

	if config == nil {
		config = &UtilsConfig{
			CacheExpiry:        30 * time.Minute,
			MetricsEnabled:     true,
			AuditEnabled:       true,
			ValidationEnabled:  true,
			DefaultRegion:      "us-central1",
			DefaultZone:        "us-central1-a",
			ParallelOperations: 10,
			RetryAttempts:      3,
			RetryDelay:         time.Second,
			Timeout:            5 * time.Minute,
			RateLimitQPS:       100,
			RateLimitBurst:     200,
			MaxCacheSize:       1000,
			LogLevel:           "INFO",
			LogFormat:          "json",
		}
	}

	projectID := client.ProjectID
	if projectID == "" {
		if metadata.OnGCE() {
			var err error
			projectID, err = metadata.ProjectID()
			if err != nil {
				return nil, fmt.Errorf("failed to get project ID from metadata: %w", err)
			}
		} else {
			return nil, fmt.Errorf("project ID not provided and not running on GCE")
		}
	}

	billingService, err := cloudbilling.NewService(ctx, option.WithCredentials(client.Credentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create billing service: %w", err)
	}

	resourceManagerService, err := cloudresourcemanager.NewService(ctx, option.WithCredentials(client.Credentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create resource manager service: %w", err)
	}

	serviceUsageService, err := serviceusage.NewService(ctx, option.WithCredentials(client.Credentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create service usage service: %w", err)
	}

	bigQueryClient, err := bigquery.NewClient(ctx, projectID, option.WithCredentials(client.Credentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create BigQuery client: %w", err)
	}

	loggingClient, err := logging.NewClient(ctx, projectID, option.WithCredentials(client.Credentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create logging client: %w", err)
	}

	rateLimiter := NewRateLimiter(config.RateLimitQPS, config.RateLimitBurst)
	circuitBreaker := NewCircuitBreaker("utils-service", 5, time.Minute)

	var metrics *ServiceMetrics
	if config.MetricsEnabled {
		metrics = NewServiceMetrics("utils")
	}

	var logger *ServiceLogger
	if config.LogLevel != "" {
		logger = NewServiceLogger("utils", config.LogLevel, config.LogFormat)
	}

	var auditLogger *AuditLogger
	if config.AuditEnabled {
		auditLogger = NewAuditLogger("utils", projectID)
	}

	service := &UtilsService{
		client:                 client,
		projectID:              projectID,
		billingService:         billingService,
		resourceManagerService: resourceManagerService,
		serviceUsageService:    serviceUsageService,
		bigQueryClient:         bigQueryClient,
		loggingClient:          loggingClient,
		metadataCache:          make(map[string]interface{}),
		quotaCache:             make(map[string]*QuotaInfo),
		costCache:              make(map[string]*CostInfo),
		cacheExpiry:            config.CacheExpiry,
		metrics:                metrics,
		logger:                 logger,
		circuitBreaker:         circuitBreaker,
		rateLimiter:            rateLimiter,
		auditLogger:            auditLogger,
	}

	return service, nil
}

func (s *UtilsService) ValidateResource(ctx context.Context, resource interface{}, rules []ValidationRule) (*ValidationResult, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	operation := func() (interface{}, error) {
		result := &ValidationResult{
			Valid:   true,
			Errors:  []ValidationError{},
			Context: make(map[string]interface{}),
		}

		resourceValue := reflect.ValueOf(resource)
		resourceType := reflect.TypeOf(resource)

		if resourceValue.Kind() == reflect.Ptr {
			resourceValue = resourceValue.Elem()
			resourceType = resourceType.Elem()
		}

		if resourceValue.Kind() != reflect.Struct && resourceValue.Kind() != reflect.Map {
			return nil, fmt.Errorf("resource must be a struct or map")
		}

		for _, rule := range rules {
			if err := s.validateField(resourceValue, resourceType, rule, result); err != nil {
				if s.logger != nil {
					s.logger.Error("Validation error", map[string]interface{}{
						"field": rule.Field,
						"error": err.Error(),
					})
				}
				return nil, err
			}
		}

		result.Valid = len(result.Errors) == 0
		result.Context["validation_time"] = time.Since(startTime).String()
		result.Context["rules_checked"] = len(rules)
		result.Context["errors_found"] = len(result.Errors)

		return result, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	result := resultInterface.(*ValidationResult)

	if s.metrics != nil {
		s.metrics.RecordOperation("validate_resource", time.Since(startTime), err)
		if !result.Valid {
			s.metrics.IncrementCounter("validation_failures")
		}
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("ValidateResource", map[string]interface{}{
			"resource_type": resourceType.String(),
			"rules_count":   len(rules),
			"valid":         result.Valid,
			"errors_count":  len(result.Errors),
		})
	}

	return result, nil
}

func (s *UtilsService) validateField(resourceValue reflect.Value, resourceType reflect.Type, rule ValidationRule, result *ValidationResult) error {
	var fieldValue interface{}
	var exists bool

	if resourceValue.Kind() == reflect.Map {
		mapValue := resourceValue.Interface().(map[string]interface{})
		fieldValue, exists = mapValue[rule.Field]
	} else {
		field, found := resourceType.FieldByName(rule.Field)
		if !found {
			return fmt.Errorf("field %s not found", rule.Field)
		}

		fieldVal := resourceValue.FieldByName(rule.Field)
		if !fieldVal.IsValid() {
			exists = false
		} else {
			exists = true
			fieldValue = fieldVal.Interface()
		}
	}

	if rule.Required && !exists {
		result.Errors = append(result.Errors, ValidationError{
			Field:   rule.Field,
			Message: fmt.Sprintf("Field %s is required", rule.Field),
			Code:    "REQUIRED_FIELD_MISSING",
		})
		return nil
	}

	if !exists {
		return nil
	}

	if rule.Custom != nil {
		if !rule.Custom(fieldValue) {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Custom validation failed for field %s", rule.Field),
				Code:    "CUSTOM_VALIDATION_FAILED",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
		}
		return nil
	}

	switch rule.Type {
	case "string":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		if rule.MinLength > 0 && len(strVal) < rule.MinLength {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be at least %d characters", rule.Field, rule.MinLength),
				Code:    "MIN_LENGTH_VIOLATION",
				Value:   strVal,
			})
		}

		if rule.MaxLength > 0 && len(strVal) > rule.MaxLength {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be at most %d characters", rule.Field, rule.MaxLength),
				Code:    "MAX_LENGTH_VIOLATION",
				Value:   strVal,
			})
		}

		if rule.Pattern != "" {
			matched, err := regexp.MatchString(rule.Pattern, strVal)
			if err != nil {
				return fmt.Errorf("invalid pattern for field %s: %w", rule.Field, err)
			}
			if !matched {
				result.Errors = append(result.Errors, ValidationError{
					Field:   rule.Field,
					Message: fmt.Sprintf("Field %s does not match required pattern", rule.Field),
					Code:    "PATTERN_MISMATCH",
					Value:   strVal,
				})
			}
		}

		if len(rule.AllowedVals) > 0 {
			allowed := false
			for _, allowedVal := range rule.AllowedVals {
				if strVal == allowedVal {
					allowed = true
					break
				}
			}
			if !allowed {
				result.Errors = append(result.Errors, ValidationError{
					Field:   rule.Field,
					Message: fmt.Sprintf("Field %s has invalid value, allowed values: %v", rule.Field, rule.AllowedVals),
					Code:    "INVALID_VALUE",
					Value:   strVal,
				})
			}
		}

	case "number", "int", "float":
		var numVal float64
		var ok bool

		switch v := fieldValue.(type) {
		case int:
			numVal = float64(v)
			ok = true
		case int32:
			numVal = float64(v)
			ok = true
		case int64:
			numVal = float64(v)
			ok = true
		case float32:
			numVal = float64(v)
			ok = true
		case float64:
			numVal = v
			ok = true
		}

		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a number", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		if rule.MinValue != 0 && numVal < rule.MinValue {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be at least %f", rule.Field, rule.MinValue),
				Code:    "MIN_VALUE_VIOLATION",
				Value:   fmt.Sprintf("%f", numVal),
			})
		}

		if rule.MaxValue != 0 && numVal > rule.MaxValue {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be at most %f", rule.Field, rule.MaxValue),
				Code:    "MAX_VALUE_VIOLATION",
				Value:   fmt.Sprintf("%f", numVal),
			})
		}

	case "bool", "boolean":
		_, ok := fieldValue.(bool)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a boolean", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
		}

	case "array", "slice":
		val := reflect.ValueOf(fieldValue)
		if val.Kind() != reflect.Slice && val.Kind() != reflect.Array {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be an array", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		length := val.Len()
		if rule.MinLength > 0 && length < rule.MinLength {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must have at least %d elements", rule.Field, rule.MinLength),
				Code:    "MIN_LENGTH_VIOLATION",
				Value:   fmt.Sprintf("length: %d", length),
			})
		}

		if rule.MaxLength > 0 && length > rule.MaxLength {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must have at most %d elements", rule.Field, rule.MaxLength),
				Code:    "MAX_LENGTH_VIOLATION",
				Value:   fmt.Sprintf("length: %d", length),
			})
		}

	case "email":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		emailRegex := `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
		matched, err := regexp.MatchString(emailRegex, strVal)
		if err != nil {
			return fmt.Errorf("email validation error for field %s: %w", rule.Field, err)
		}
		if !matched {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid email address", rule.Field),
				Code:    "INVALID_EMAIL",
				Value:   strVal,
			})
		}

	case "url":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		_, err := url.Parse(strVal)
		if err != nil {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid URL", rule.Field),
				Code:    "INVALID_URL",
				Value:   strVal,
			})
		}

	case "ip":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		if net.ParseIP(strVal) == nil {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid IP address", rule.Field),
				Code:    "INVALID_IP",
				Value:   strVal,
			})
		}

	case "cidr":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		_, _, err := net.ParseCIDR(strVal)
		if err != nil {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid CIDR notation", rule.Field),
				Code:    "INVALID_CIDR",
				Value:   strVal,
			})
		}

	case "uuid":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		uuidRegex := `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`
		matched, err := regexp.MatchString(uuidRegex, strVal)
		if err != nil {
			return fmt.Errorf("UUID validation error for field %s: %w", rule.Field, err)
		}
		if !matched {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid UUID", rule.Field),
				Code:    "INVALID_UUID",
				Value:   strVal,
			})
		}

	case "date", "datetime":
		strVal, ok := fieldValue.(string)
		if !ok {
			if _, ok := fieldValue.(time.Time); !ok {
				result.Errors = append(result.Errors, ValidationError{
					Field:   rule.Field,
					Message: fmt.Sprintf("Field %s must be a string or time.Time", rule.Field),
					Code:    "TYPE_MISMATCH",
					Value:   fmt.Sprintf("%v", fieldValue),
				})
			}
			return nil
		}

		formats := []string{
			time.RFC3339,
			time.RFC3339Nano,
			"2006-01-02",
			"2006-01-02T15:04:05",
			"2006-01-02 15:04:05",
			"01/02/2006",
			"01-02-2006",
		}

		parsed := false
		for _, format := range formats {
			if _, err := time.Parse(format, strVal); err == nil {
				parsed = true
				break
			}
		}

		if !parsed {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a valid date/time", rule.Field),
				Code:    "INVALID_DATE",
				Value:   strVal,
			})
		}

	case "json":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		var js json.RawMessage
		if err := json.Unmarshal([]byte(strVal), &js); err != nil {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be valid JSON", rule.Field),
				Code:    "INVALID_JSON",
				Value:   strVal,
			})
		}

	case "base64":
		strVal, ok := fieldValue.(string)
		if !ok {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be a string", rule.Field),
				Code:    "TYPE_MISMATCH",
				Value:   fmt.Sprintf("%v", fieldValue),
			})
			return nil
		}

		if _, err := base64.StdEncoding.DecodeString(strVal); err != nil {
			result.Errors = append(result.Errors, ValidationError{
				Field:   rule.Field,
				Message: fmt.Sprintf("Field %s must be valid base64", rule.Field),
				Code:    "INVALID_BASE64",
				Value:   strVal,
			})
		}
	}

	return nil
}

func (s *UtilsService) GetProjectInfo(ctx context.Context, projectID string) (*ProjectInfo, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	cacheKey := fmt.Sprintf("project_info:%s", projectID)

	s.cacheMutex.RLock()
	if cachedInfo, exists := s.metadataCache[cacheKey]; exists {
		if info, ok := cachedInfo.(*ProjectInfo); ok {
			s.cacheMutex.RUnlock()
			return info, nil
		}
	}
	s.cacheMutex.RUnlock()

	operation := func() (interface{}, error) {
		project, err := s.resourceManagerService.Projects.Get(projectID).Context(ctx).Do()
		if err != nil {
			return nil, fmt.Errorf("failed to get project: %w", err)
		}

		info := &ProjectInfo{
			ProjectID:     project.ProjectId,
			ProjectNumber: strconv.FormatInt(project.ProjectNumber, 10),
			Name:          project.Name,
			State:         project.LifecycleState,
			Labels:        project.Labels,
		}

		if project.Parent != nil {
			info.Parent = fmt.Sprintf("%s:%s", project.Parent.Type, project.Parent.Id)
			if project.Parent.Type == "organization" {
				info.OrganizationID = project.Parent.Id
			} else if project.Parent.Type == "folder" {
				info.FolderID = project.Parent.Id
			}
		}

		if project.CreateTime != "" {
			if createTime, err := time.Parse(time.RFC3339, project.CreateTime); err == nil {
				info.CreateTime = createTime
			}
		}

		enabledServices, err := s.getEnabledServices(ctx, projectID)
		if err != nil {
			if s.logger != nil {
				s.logger.Warn("Failed to get enabled services", map[string]interface{}{
					"project_id": projectID,
					"error":      err.Error(),
				})
			}
		} else {
			info.EnabledServices = enabledServices
		}

		billingAccount, err := s.getBillingAccount(ctx, projectID)
		if err != nil {
			if s.logger != nil {
				s.logger.Warn("Failed to get billing account", map[string]interface{}{
					"project_id": projectID,
					"error":      err.Error(),
				})
			}
		} else {
			info.BillingAccount = billingAccount
		}

		quotas, err := s.GetQuotaInfo(ctx, projectID)
		if err != nil {
			if s.logger != nil {
				s.logger.Warn("Failed to get quota info", map[string]interface{}{
					"project_id": projectID,
					"error":      err.Error(),
				})
			}
		} else {
			info.Quotas = quotas
		}

		costs, err := s.GetCostInfo(ctx, projectID, TimeRange{
			Start: time.Now().AddDate(0, -1, 0),
			End:   time.Now(),
		})
		if err != nil {
			if s.logger != nil {
				s.logger.Warn("Failed to get cost info", map[string]interface{}{
					"project_id": projectID,
					"error":      err.Error(),
				})
			}
		} else {
			info.Costs = costs
		}

		metadata, err := s.getProjectMetadata(ctx, projectID)
		if err != nil {
			if s.logger != nil {
				s.logger.Warn("Failed to get project metadata", map[string]interface{}{
					"project_id": projectID,
					"error":      err.Error(),
				})
			}
		} else {
			info.Metadata = metadata
		}

		return info, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("failed to get project info: %w", err)
	}

	info := resultInterface.(*ProjectInfo)

	s.cacheMutex.Lock()
	s.metadataCache[cacheKey] = info
	s.cacheMutex.Unlock()

	if s.metrics != nil {
		s.metrics.RecordOperation("get_project_info", time.Since(startTime), err)
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("GetProjectInfo", map[string]interface{}{
			"project_id": projectID,
			"success":    true,
		})
	}

	return info, nil
}

func (s *UtilsService) getEnabledServices(ctx context.Context, projectID string) ([]string, error) {
	parent := fmt.Sprintf("projects/%s", projectID)

	resp, err := s.serviceUsageService.Services.List(parent).Context(ctx).Filter("state:ENABLED").Do()
	if err != nil {
		return nil, fmt.Errorf("failed to list enabled services: %w", err)
	}

	var services []string
	for _, service := range resp.Services {
		serviceName := strings.TrimPrefix(service.Name, parent+"/services/")
		services = append(services, serviceName)
	}

	return services, nil
}

func (s *UtilsService) getBillingAccount(ctx context.Context, projectID string) (string, error) {
	resp, err := s.billingService.Projects.GetBillingInfo(fmt.Sprintf("projects/%s", projectID)).Context(ctx).Do()
	if err != nil {
		return "", fmt.Errorf("failed to get billing info: %w", err)
	}

	if resp.BillingAccountName == "" {
		return "", nil
	}

	return strings.TrimPrefix(resp.BillingAccountName, "billingAccounts/"), nil
}

func (s *UtilsService) getProjectMetadata(ctx context.Context, projectID string) (map[string]interface{}, error) {
	metadata := make(map[string]interface{})

	if metadata.OnGCE() {
		if zone, err := metadata.Zone(); err == nil {
			metadata["zone"] = zone
		}
		if region, err := metadata.Get("instance/region"); err == nil {
			metadata["region"] = region
		}
		if machineType, err := metadata.Get("instance/machine-type"); err == nil {
			metadata["machine_type"] = machineType
		}
		if instanceID, err := metadata.Get("instance/id"); err == nil {
			metadata["instance_id"] = instanceID
		}
		if instanceName, err := metadata.Get("instance/name"); err == nil {
			metadata["instance_name"] = instanceName
		}
		if hostname, err := metadata.Get("instance/hostname"); err == nil {
			metadata["hostname"] = hostname
		}
		if serviceAccounts, err := metadata.Get("instance/service-accounts/"); err == nil {
			metadata["service_accounts"] = strings.Split(serviceAccounts, "\n")
		}
		if attributes, err := metadata.Get("instance/attributes/"); err == nil {
			metadata["attributes"] = strings.Split(attributes, "\n")
		}
		if tags, err := metadata.Get("instance/tags"); err == nil {
			metadata["tags"] = strings.Split(tags, "\n")
		}
		if networkInterfaces, err := metadata.Get("instance/network-interfaces/"); err == nil {
			metadata["network_interfaces"] = strings.Split(networkInterfaces, "\n")
		}
	}

	if s.bigQueryClient != nil {
		datasets := s.bigQueryClient.Datasets(ctx)
		var datasetList []string
		for {
			dataset, err := datasets.Next()
			if err != nil {
				break
			}
			datasetList = append(datasetList, dataset.DatasetID)
		}
		if len(datasetList) > 0 {
			metadata["bigquery_datasets"] = datasetList
		}
	}

	return metadata, nil
}

func (s *UtilsService) GetQuotaInfo(ctx context.Context, projectID string) (*QuotaInfo, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	cacheKey := fmt.Sprintf("quota_info:%s", projectID)

	s.cacheMutex.RLock()
	if cachedInfo, exists := s.quotaCache[cacheKey]; exists {
		if time.Since(s.lastCacheUpdate) < s.cacheExpiry {
			s.cacheMutex.RUnlock()
			return cachedInfo, nil
		}
	}
	s.cacheMutex.RUnlock()

	operation := func() (interface{}, error) {
		quotaInfo := &QuotaInfo{
			ProjectID:   projectID,
			Quotas:      []*ResourceQuota{},
			LastUpdated: time.Now(),
			Warnings:    []string{},
			Errors:      []string{},
		}

		// Placeholder for actual quota retrieval
		// In a real implementation, this would query various GCP services for quota information

		quotaInfo.TotalQuotas = len(quotaInfo.Quotas)

		exceededCount := 0
		warningCount := 0

		for _, quota := range quotaInfo.Quotas {
			quota.Available = quota.Limit - quota.Usage
			if quota.Limit > 0 {
				quota.Percentage = float64(quota.Usage) / float64(quota.Limit) * 100
			}

			if quota.Percentage >= 100 {
				exceededCount++
				quotaInfo.Errors = append(quotaInfo.Errors,
					fmt.Sprintf("Quota %s is exceeded: %d/%d", quota.Name, quota.Usage, quota.Limit))
			} else if quota.Percentage >= 80 {
				warningCount++
				quotaInfo.Warnings = append(quotaInfo.Warnings,
					fmt.Sprintf("Quota %s is near limit: %d/%d (%.1f%%)", quota.Name, quota.Usage, quota.Limit, quota.Percentage))
			}
		}

		quotaInfo.ExceededCount = exceededCount
		quotaInfo.WarningCount = warningCount

		return quotaInfo, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("failed to get quota info: %w", err)
	}

	quotaInfo := resultInterface.(*QuotaInfo)

	s.cacheMutex.Lock()
	s.quotaCache[cacheKey] = quotaInfo
	s.lastCacheUpdate = time.Now()
	s.cacheMutex.Unlock()

	if s.metrics != nil {
		s.metrics.RecordOperation("get_quota_info", time.Since(startTime), err)
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("GetQuotaInfo", map[string]interface{}{
			"project_id":      projectID,
			"total_quotas":    quotaInfo.TotalQuotas,
			"exceeded_count":  quotaInfo.ExceededCount,
			"warning_count":   quotaInfo.WarningCount,
		})
	}

	return quotaInfo, nil
}

func (s *UtilsService) GetCostInfo(ctx context.Context, projectID string, timeRange TimeRange) (*CostInfo, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	cacheKey := fmt.Sprintf("cost_info:%s:%s-%s", projectID, timeRange.Start.Format("2006-01-02"), timeRange.End.Format("2006-01-02"))

	s.cacheMutex.RLock()
	if cachedInfo, exists := s.costCache[cacheKey]; exists {
		if time.Since(cachedInfo.LastUpdated) < s.cacheExpiry {
			s.cacheMutex.RUnlock()
			return cachedInfo, nil
		}
	}
	s.cacheMutex.RUnlock()

	operation := func() (interface{}, error) {
		costInfo := &CostInfo{
			ProjectID:   projectID,
			TimeRange:   timeRange,
			TotalCost:   0.0,
			Currency:    "USD",
			Breakdown:   []*CostBreakdown{},
			LastUpdated: time.Now(),
		}

		// Placeholder for actual cost retrieval
		// In a real implementation, this would query the Cloud Billing API

		forecast := &CostForecast{
			PredictedCost:   costInfo.TotalCost * 1.1,
			ConfidenceLevel: 0.85,
			ForecastHorizon: "30d",
			Model:           "linear_regression",
			Factors:         []string{"historical_usage", "seasonal_trends"},
			LastTrained:     time.Now().AddDate(0, 0, -1),
			Accuracy:        0.92,
		}
		costInfo.Forecast = forecast

		budget := &BudgetInfo{
			Name:       "Default Budget",
			Amount:     1000.0,
			Currency:   "USD",
			Spent:      costInfo.TotalCost,
			Remaining:  1000.0 - costInfo.TotalCost,
			Period:     "monthly",
			Status:     "active",
		}
		if budget.Amount > 0 {
			budget.Percentage = budget.Spent / budget.Amount * 100
		}
		costInfo.Budget = budget

		trends := &CostTrends{
			DailyAverage:   costInfo.TotalCost / float64(timeRange.End.Sub(timeRange.Start).Hours()/24),
			WeeklyTrend:    0.05,
			MonthlyTrend:   0.15,
			GrowthRate:     0.12,
			Volatility:     0.08,
			PeakUsageTimes: []string{"09:00-17:00 UTC"},
		}
		costInfo.Trends = trends

		recommendations := []CostRecommendation{
			{
				Type:        "right_sizing",
				Resource:    "compute_instances",
				Description: "Right-size underutilized Compute Engine instances",
				Savings:     150.0,
				Effort:      "low",
				Impact:      "medium",
				Priority:    1,
				Steps:       []string{"Analyze instance utilization", "Identify candidates", "Apply right-sizing"},
			},
		}
		costInfo.Recommendations = recommendations

		return costInfo, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("failed to get cost info: %w", err)
	}

	costInfo := resultInterface.(*CostInfo)

	s.cacheMutex.Lock()
	s.costCache[cacheKey] = costInfo
	s.cacheMutex.Unlock()

	if s.metrics != nil {
		s.metrics.RecordOperation("get_cost_info", time.Since(startTime), err)
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("GetCostInfo", map[string]interface{}{
			"project_id":   projectID,
			"total_cost":   costInfo.TotalCost,
			"time_range":   fmt.Sprintf("%s to %s", timeRange.Start.Format("2006-01-02"), timeRange.End.Format("2006-01-02")),
			"breakdown_count": len(costInfo.Breakdown),
		})
	}

	return costInfo, nil
}

func (s *UtilsService) GetServiceInfo(ctx context.Context, projectID string, serviceName string) (*ServiceInfo, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	operation := func() (interface{}, error) {
		parent := fmt.Sprintf("projects/%s", projectID)
		fullServiceName := fmt.Sprintf("%s/services/%s", parent, serviceName)

		service, err := s.serviceUsageService.Services.Get(fullServiceName).Context(ctx).Do()
		if err != nil {
			return nil, fmt.Errorf("failed to get service: %w", err)
		}

		serviceInfo := &ServiceInfo{
			Name:   service.Name,
			State:  service.State,
			Parent: service.Parent,
		}

		if service.Config != nil {
			serviceInfo.Config = &ServiceConfig{
				Name:  service.Config.Name,
				Title: service.Config.Title,
			}
		}

		if service.Config != nil && service.Config.Usage != nil {
			usage := &ServiceUsage{
				ServiceName: serviceName,
				Metrics:     []UsageMetric{},
				LastUpdated: time.Now(),
			}
			serviceInfo.Usage = usage
		}

		return serviceInfo, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("failed to get service info: %w", err)
	}

	serviceInfo := resultInterface.(*ServiceInfo)

	if s.metrics != nil {
		s.metrics.RecordOperation("get_service_info", time.Since(startTime), err)
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("GetServiceInfo", map[string]interface{}{
			"project_id":   projectID,
			"service_name": serviceName,
			"state":        serviceInfo.State,
		})
	}

	return serviceInfo, nil
}

func (s *UtilsService) GenerateRecommendations(ctx context.Context, projectID string) ([]*ResourceRecommendation, error) {
	startTime := time.Now()

	if s.rateLimiter != nil {
		if err := s.rateLimiter.Wait(ctx); err != nil {
			return nil, fmt.Errorf("rate limit exceeded: %w", err)
		}
	}

	operation := func() (interface{}, error) {
		recommendations := []*ResourceRecommendation{}

		projectInfo, err := s.GetProjectInfo(ctx, projectID)
		if err != nil {
			return nil, fmt.Errorf("failed to get project info for recommendations: %w", err)
		}

		if projectInfo.Quotas != nil {
			for _, quota := range projectInfo.Quotas.Quotas {
				if quota.Percentage > 80 {
					recommendation := &ResourceRecommendation{
						Type:     "quota_increase",
						Resource: quota.Name,
						Current: ResourceState{
							Configuration: map[string]interface{}{
								"current_limit": quota.Limit,
								"current_usage": quota.Usage,
							},
							Utilization: map[string]float64{
								"percentage": quota.Percentage,
							},
							Cost: 0,
						},
						Recommended: ResourceState{
							Configuration: map[string]interface{}{
								"recommended_limit": quota.Limit * 2,
							},
							Utilization: map[string]float64{
								"percentage": quota.Percentage / 2,
							},
							Cost: 0,
						},
						Savings:    0,
						Effort:     "medium",
						Confidence: 0.9,
						Impact: ImpactAnalysis{
							Performance:  "improved",
							Availability: "improved",
							Security:     "neutral",
							Compliance:   "neutral",
							Benefits:     []string{"Avoid quota exhaustion", "Improve service reliability"},
						},
						Steps: []ActionStep{
							{
								Order:       1,
								Description: "Request quota increase",
								Duration:    "1-3 business days",
								Risk:        "low",
								Automated:   false,
							},
						},
						Timeline: "1-3 days",
						Priority: 1,
						Category: "capacity",
					}
					recommendations = append(recommendations, recommendation)
				}
			}
		}

		if projectInfo.Costs != nil {
			for _, breakdown := range projectInfo.Costs.Breakdown {
				if breakdown.Amount > 100 {
					recommendation := &ResourceRecommendation{
						Type:     "cost_optimization",
						Resource: breakdown.Service,
						Current: ResourceState{
							Cost: breakdown.Amount,
						},
						Recommended: ResourceState{
							Cost: breakdown.Amount * 0.8,
						},
						Savings:    breakdown.Amount * 0.2,
						Effort:     "medium",
						Confidence: 0.7,
						Impact: ImpactAnalysis{
							Performance: "neutral",
							Benefits:    []string{"Reduce costs", "Improve resource efficiency"},
						},
						Steps: []ActionStep{
							{
								Order:       1,
								Description: "Analyze resource utilization",
								Duration:    "1 hour",
								Risk:        "low",
								Automated:   true,
							},
							{
								Order:       2,
								Description: "Apply right-sizing recommendations",
								Duration:    "2 hours",
								Risk:        "medium",
								Automated:   false,
							},
						},
						Timeline: "1 week",
						Priority: 2,
						Category: "cost",
					}
					recommendations = append(recommendations, recommendation)
				}
			}
		}

		sort.Slice(recommendations, func(i, j int) bool {
			return recommendations[i].Priority < recommendations[j].Priority
		})

		return recommendations, nil
	}

	resultInterface, err := s.circuitBreaker.Execute(operation)
	if err != nil {
		return nil, fmt.Errorf("failed to generate recommendations: %w", err)
	}

	recommendations := resultInterface.([]*ResourceRecommendation)

	if s.metrics != nil {
		s.metrics.RecordOperation("generate_recommendations", time.Since(startTime), err)
		s.metrics.RecordGauge("recommendations_generated", float64(len(recommendations)))
	}

	if s.auditLogger != nil {
		s.auditLogger.LogOperation("GenerateRecommendations", map[string]interface{}{
			"project_id":           projectID,
			"recommendations_count": len(recommendations),
		})
	}

	return recommendations, nil
}

func (s *UtilsService) GenerateUniqueID() string {
	timestamp := time.Now().UnixNano()
	randomBytes := make([]byte, 8)
	rand.Read(randomBytes)

	combined := fmt.Sprintf("%d-%x", timestamp, randomBytes)
	hash := sha256.Sum256([]byte(combined))
	return hex.EncodeToString(hash[:16])
}

func (s *UtilsService) GenerateSecureToken(length int) (string, error) {
	if length <= 0 {
		return "", fmt.Errorf("token length must be positive")
	}

	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	token := make([]byte, length)

	for i := range token {
		randomIndex, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", fmt.Errorf("failed to generate secure token: %w", err)
		}
		token[i] = charset[randomIndex.Int64()]
	}

	return string(token), nil
}

func (s *UtilsService) HashString(input string, salt string) string {
	data := input + salt
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

func (s *UtilsService) EncodeBase64(data []byte) string {
	return base64.StdEncoding.EncodeToString(data)
}

func (s *UtilsService) DecodeBase64(encoded string) ([]byte, error) {
	return base64.StdEncoding.DecodeString(encoded)
}

func (s *UtilsService) FormatFileSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}

	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}

	units := []string{"KB", "MB", "GB", "TB", "PB", "EB"}
	return fmt.Sprintf("%.1f %s", float64(bytes)/float64(div), units[exp])
}

func (s *UtilsService) FormatDuration(duration time.Duration) string {
	if duration < time.Minute {
		return fmt.Sprintf("%.0fs", duration.Seconds())
	}
	if duration < time.Hour {
		return fmt.Sprintf("%.0fm", duration.Minutes())
	}
	if duration < 24*time.Hour {
		return fmt.Sprintf("%.1fh", duration.Hours())
	}
	days := duration.Hours() / 24
	return fmt.Sprintf("%.1fd", days)
}

func (s *UtilsService) CalculatePercentage(part, total float64) float64 {
	if total == 0 {
		return 0
	}
	return (part / total) * 100
}

func (s *UtilsService) RoundToDecimals(value float64, decimals int) float64 {
	multiplier := math.Pow(10, float64(decimals))
	return math.Round(value*multiplier) / multiplier
}

func (s *UtilsService) IsValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

func (s *UtilsService) IsValidURL(urlStr string) bool {
	_, err := url.Parse(urlStr)
	return err == nil
}

func (s *UtilsService) IsValidIP(ip string) bool {
	return net.ParseIP(ip) != nil
}

func (s *UtilsService) IsValidCIDR(cidr string) bool {
	_, _, err := net.ParseCIDR(cidr)
	return err == nil
}

func (s *UtilsService) SanitizeString(input string) string {
	reg := regexp.MustCompile(`[^\w\s-.]`)
	return reg.ReplaceAllString(input, "")
}

func (s *UtilsService) EscapeHTML(input string) string {
	replacer := strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		"\"", "&quot;",
		"'", "&#39;",
	)
	return replacer.Replace(input)
}

func (s *UtilsService) TruncateString(input string, maxLength int) string {
	if len(input) <= maxLength {
		return input
	}
	if maxLength <= 3 {
		return input[:maxLength]
	}
	return input[:maxLength-3] + "..."
}

func (s *UtilsService) SlugifyString(input string) string {
	input = strings.ToLower(input)
	reg := regexp.MustCompile(`[^\w\s-]`)
	input = reg.ReplaceAllString(input, "")
	input = regexp.MustCompile(`[\s_-]+`).ReplaceAllString(input, "-")
	input = strings.Trim(input, "-")
	return input
}

func (s *UtilsService) ParseTemplate(template string, data map[string]interface{}) (string, error) {
	result := template

	for key, value := range data {
		placeholder := fmt.Sprintf("{{%s}}", key)
		valueStr := fmt.Sprintf("%v", value)
		result = strings.ReplaceAll(result, placeholder, valueStr)
	}

	remainingPlaceholders := regexp.MustCompile(`\{\{[^}]+\}\}`)
	if matches := remainingPlaceholders.FindAllString(result, -1); len(matches) > 0 {
		return "", fmt.Errorf("unresolved placeholders: %v", matches)
	}

	return result, nil
}

func (s *UtilsService) ConvertToJSON(data interface{}) (string, error) {
	jsonBytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to convert to JSON: %w", err)
	}
	return string(jsonBytes), nil
}

func (s *UtilsService) ParseJSON(jsonStr string, target interface{}) error {
	if err := json.Unmarshal([]byte(jsonStr), target); err != nil {
		return fmt.Errorf("failed to parse JSON: %w", err)
	}
	return nil
}

func (s *UtilsService) MergeStructs(base, override interface{}) (interface{}, error) {
	baseValue := reflect.ValueOf(base)
	overrideValue := reflect.ValueOf(override)

	if baseValue.Type() != overrideValue.Type() {
		return nil, fmt.Errorf("structs must be of the same type")
	}

	result := reflect.New(baseValue.Type()).Elem()

	for i := 0; i < baseValue.NumField(); i++ {
		baseField := baseValue.Field(i)
		overrideField := overrideValue.Field(i)

		if !overrideField.IsZero() {
			result.Field(i).Set(overrideField)
		} else {
			result.Field(i).Set(baseField)
		}
	}

	return result.Interface(), nil
}

func (s *UtilsService) GetFileExtension(filename string) string {
	return filepath.Ext(filename)
}

func (s *UtilsService) GetMimeType(filename string) string {
	ext := strings.ToLower(filepath.Ext(filename))

	mimeTypes := map[string]string{
		".txt":  "text/plain",
		".html": "text/html",
		".css":  "text/css",
		".js":   "application/javascript",
		".json": "application/json",
		".xml":  "application/xml",
		".pdf":  "application/pdf",
		".zip":  "application/zip",
		".jpg":  "image/jpeg",
		".jpeg": "image/jpeg",
		".png":  "image/png",
		".gif":  "image/gif",
		".svg":  "image/svg+xml",
		".mp3":  "audio/mpeg",
		".mp4":  "video/mp4",
		".avi":  "video/x-msvideo",
		".webm": "video/webm",
	}

	if mimeType, exists := mimeTypes[ext]; exists {
		return mimeType
	}

	return "application/octet-stream"
}

func (s *UtilsService) FileExists(filepath string) bool {
	_, err := os.Stat(filepath)
	return !os.IsNotExist(err)
}

func (s *UtilsService) CreateDirectory(path string) error {
	return os.MkdirAll(path, 0755)
}

func (s *UtilsService) CopyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return fmt.Errorf("failed to copy file content: %w", err)
	}

	return nil
}

func (s *UtilsService) GetServiceMetrics() map[string]interface{} {
	if s.metrics == nil {
		return nil
	}
	return s.metrics.GetMetrics()
}

func (s *UtilsService) ClearCache() {
	s.cacheMutex.Lock()
	defer s.cacheMutex.Unlock()

	s.metadataCache = make(map[string]interface{})
	s.quotaCache = make(map[string]*QuotaInfo)
	s.costCache = make(map[string]*CostInfo)
	s.lastCacheUpdate = time.Time{}

	if s.logger != nil {
		s.logger.Info("Cache cleared", nil)
	}
}

func (s *UtilsService) GetCacheStats() map[string]interface{} {
	s.cacheMutex.RLock()
	defer s.cacheMutex.RUnlock()

	return map[string]interface{}{
		"metadata_cache_size": len(s.metadataCache),
		"quota_cache_size":    len(s.quotaCache),
		"cost_cache_size":     len(s.costCache),
		"last_cache_update":   s.lastCacheUpdate,
		"cache_expiry":        s.cacheExpiry.String(),
	}
}

func (s *UtilsService) Close() error {
	var errors []error

	if s.bigQueryClient != nil {
		if err := s.bigQueryClient.Close(); err != nil {
			errors = append(errors, fmt.Errorf("failed to close BigQuery client: %w", err))
		}
	}

	if s.loggingClient != nil {
		if err := s.loggingClient.Close(); err != nil {
			errors = append(errors, fmt.Errorf("failed to close logging client: %w", err))
		}
	}

	if len(errors) > 0 {
		return fmt.Errorf("errors closing utils service: %v", errors)
	}

	return nil
}