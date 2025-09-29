package providers

import (
	"context"
	"time"

	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
)

type Provider interface {
	// Basic provider information
	Name() string
	Project() string
	Region() string
	Initialize(ctx context.Context) error
	Validate(ctx context.Context) error
	Close() error

	// Resource discovery and management
	ListResources(ctx context.Context, resourceType string, filters map[string]interface{}) ([]core.Resource, error)
	GetResource(ctx context.Context, resourceID string) (*core.Resource, error)
	CreateResource(ctx context.Context, resource *core.Resource) error
	UpdateResource(ctx context.Context, resource *core.Resource) error
	DeleteResource(ctx context.Context, resourceID string) error

	// Resource metadata and configuration
	GetResourceTags(ctx context.Context, resourceID string, resourceType string) (map[string]string, error)
	SetResourceTags(ctx context.Context, resourceID string, resourceType string, tags map[string]string) error
	GetResourceMetrics(ctx context.Context, resourceID string, resourceType string) (map[string]interface{}, error)
	GetResourceConfiguration(ctx context.Context, resourceID string, resourceType string) (map[string]interface{}, error)

	// Cost and billing
	GetResourceCost(ctx context.Context, resourceID string, resourceType string) (*core.ResourceCost, error)
	GetBillingData(ctx context.Context, startDate, endDate time.Time) ([]BillingData, error)
	GetCostForecast(ctx context.Context, days int) (*CostForecast, error)

	// Security and compliance
	CheckResourceCompliance(ctx context.Context, resourceID string, resourceType string) ([]map[string]interface{}, error)
	ScanResourceVulnerabilities(ctx context.Context, resourceID string, resourceType string) ([]map[string]interface{}, error)
	GetResourceRecommendations(ctx context.Context, resourceID string, resourceType string) ([]string, error)
	GetSecurityFindings(ctx context.Context, resourceID string) ([]SecurityFinding, error)

	// Dependencies and relationships
	GetResourceDependencies(ctx context.Context, resourceID string, resourceType string) ([]string, error)
	GetResourceRelationships(ctx context.Context, resourceID string) ([]ResourceRelationship, error)

	// Account and project management
	DiscoverAccounts(ctx context.Context) ([]core.Account, error)
	DiscoverResources(ctx context.Context, account core.Account) ([]core.Resource, error)

	// Monitoring and metrics
	GetMetrics(ctx context.Context, query MetricQuery) ([]MetricResult, error)
	GetLogs(ctx context.Context, query LogQuery) ([]LogEntry, error)
	GetAlerts(ctx context.Context) ([]Alert, error)

	// Backup and recovery
	CreateBackup(ctx context.Context, resourceID string) (*Backup, error)
	ListBackups(ctx context.Context, resourceID string) ([]Backup, error)
	RestoreBackup(ctx context.Context, backupID string) error

	// Network operations
	GetNetworkTopology(ctx context.Context) (*NetworkTopology, error)
	GetFirewallRules(ctx context.Context) ([]FirewallRule, error)
	GetLoadBalancers(ctx context.Context) ([]LoadBalancer, error)

	// IAM operations
	GetIAMPolicy(ctx context.Context, resourceID string) (*IAMPolicy, error)
	SetIAMPolicy(ctx context.Context, resourceID string, policy *IAMPolicy) error
	GetServiceAccounts(ctx context.Context) ([]ServiceAccount, error)

	// Storage operations
	ListBuckets(ctx context.Context) ([]StorageBucket, error)
	GetBucketPolicy(ctx context.Context, bucketName string) (*BucketPolicy, error)
	SetBucketPolicy(ctx context.Context, bucketName string, policy *BucketPolicy) error

	// Database operations
	ListDatabases(ctx context.Context) ([]Database, error)
	GetDatabaseMetrics(ctx context.Context, dbID string) (*DatabaseMetrics, error)
	CreateDatabaseBackup(ctx context.Context, dbID string) (*DatabaseBackup, error)

	// Compute operations
	ListInstances(ctx context.Context) ([]ComputeInstance, error)
	GetInstanceMetrics(ctx context.Context, instanceID string) (*InstanceMetrics, error)
	StartInstance(ctx context.Context, instanceID string) error
	StopInstance(ctx context.Context, instanceID string) error
	ResizeInstance(ctx context.Context, instanceID string, newSize string) error
}

// Common data structures used by providers

type BillingData struct {
	Date        time.Time              `json:"date"`
	Service     string                 `json:"service"`
	Resource    string                 `json:"resource"`
	Cost        float64                `json:"cost"`
	Usage       float64                `json:"usage"`
	Unit        string                 `json:"unit"`
	Currency    string                 `json:"currency"`
	Tags        map[string]string      `json:"tags"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type CostForecast struct {
	Period          string                 `json:"period"`
	PredictedCost   float64                `json:"predicted_cost"`
	UpperBound      float64                `json:"upper_bound"`
	LowerBound      float64                `json:"lower_bound"`
	Confidence      float64                `json:"confidence"`
	Breakdown       map[string]float64     `json:"breakdown"`
	Recommendations []string               `json:"recommendations"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type SecurityFinding struct {
	ID              string                 `json:"id"`
	Type            string                 `json:"type"`
	Severity        string                 `json:"severity"`
	Title           string                 `json:"title"`
	Description     string                 `json:"description"`
	ResourceID      string                 `json:"resource_id"`
	Category        string                 `json:"category"`
	Risk            string                 `json:"risk"`
	Remediation     string                 `json:"remediation"`
	ComplianceStatus string                `json:"compliance_status"`
	FirstDetected   time.Time              `json:"first_detected"`
	LastSeen        time.Time              `json:"last_seen"`
	Status          string                 `json:"status"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type ResourceRelationship struct {
	Type        string                 `json:"type"`
	Direction   string                 `json:"direction"`
	TargetID    string                 `json:"target_id"`
	TargetType  string                 `json:"target_type"`
	Strength    string                 `json:"strength"`
	Description string                 `json:"description"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type MetricQuery struct {
	MetricType  string                 `json:"metric_type"`
	ResourceID  string                 `json:"resource_id"`
	StartTime   time.Time              `json:"start_time"`
	EndTime     time.Time              `json:"end_time"`
	Interval    time.Duration          `json:"interval"`
	Aggregation string                 `json:"aggregation"`
	Filters     map[string]interface{} `json:"filters"`
	GroupBy     []string               `json:"group_by"`
}

type MetricResult struct {
	Timestamp   time.Time              `json:"timestamp"`
	Value       float64                `json:"value"`
	Unit        string                 `json:"unit"`
	Labels      map[string]string      `json:"labels"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type LogQuery struct {
	ResourceID  string                 `json:"resource_id"`
	StartTime   time.Time              `json:"start_time"`
	EndTime     time.Time              `json:"end_time"`
	Severity    []string               `json:"severity"`
	Filter      string                 `json:"filter"`
	Limit       int                    `json:"limit"`
	OrderBy     string                 `json:"order_by"`
}

type LogEntry struct {
	Timestamp   time.Time              `json:"timestamp"`
	Severity    string                 `json:"severity"`
	Message     string                 `json:"message"`
	ResourceID  string                 `json:"resource_id"`
	Labels      map[string]string      `json:"labels"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type Alert struct {
	ID          string                 `json:"id"`
	Name        string                 `json:"name"`
	Type        string                 `json:"type"`
	Severity    string                 `json:"severity"`
	Status      string                 `json:"status"`
	Description string                 `json:"description"`
	Condition   string                 `json:"condition"`
	Actions     []string               `json:"actions"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
	LastFired   time.Time              `json:"last_fired"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type Backup struct {
	ID          string                 `json:"id"`
	ResourceID  string                 `json:"resource_id"`
	Type        string                 `json:"type"`
	Status      string                 `json:"status"`
	Size        int64                  `json:"size"`
	CreatedAt   time.Time              `json:"created_at"`
	ExpiresAt   time.Time              `json:"expires_at"`
	Location    string                 `json:"location"`
	Encrypted   bool                   `json:"encrypted"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type NetworkTopology struct {
	VPCs            []VPC                  `json:"vpcs"`
	Subnets         []Subnet               `json:"subnets"`
	Routes          []Route                `json:"routes"`
	Peerings        []Peering              `json:"peerings"`
	Gateways        []Gateway              `json:"gateways"`
	LoadBalancers   []LoadBalancer         `json:"load_balancers"`
	Endpoints       []Endpoint             `json:"endpoints"`
	SecurityGroups  []SecurityGroup        `json:"security_groups"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type VPC struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	CIDR            string                 `json:"cidr"`
	Region          string                 `json:"region"`
	State           string                 `json:"state"`
	Subnets         []string               `json:"subnets"`
	RouteTables     []string               `json:"route_tables"`
	SecurityGroups  []string               `json:"security_groups"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Subnet struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	VPC             string                 `json:"vpc"`
	CIDR            string                 `json:"cidr"`
	AvailabilityZone string                `json:"availability_zone"`
	State           string                 `json:"state"`
	Public          bool                   `json:"public"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Route struct {
	ID              string                 `json:"id"`
	RouteTable      string                 `json:"route_table"`
	Destination     string                 `json:"destination"`
	Target          string                 `json:"target"`
	State           string                 `json:"state"`
	Priority        int                    `json:"priority"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Peering struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	LocalVPC        string                 `json:"local_vpc"`
	RemoteVPC       string                 `json:"remote_vpc"`
	State           string                 `json:"state"`
	CreatedAt       time.Time              `json:"created_at"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Gateway struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Type            string                 `json:"type"`
	VPC             string                 `json:"vpc"`
	State           string                 `json:"state"`
	PublicIP        string                 `json:"public_ip"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type LoadBalancer struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Type            string                 `json:"type"`
	State           string                 `json:"state"`
	DNS             string                 `json:"dns"`
	IP              string                 `json:"ip"`
	Port            int                    `json:"port"`
	Protocol        string                 `json:"protocol"`
	TargetGroups    []string               `json:"target_groups"`
	HealthCheck     HealthCheck            `json:"health_check"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type HealthCheck struct {
	Protocol            string                 `json:"protocol"`
	Port                int                    `json:"port"`
	Path                string                 `json:"path"`
	Interval            int                    `json:"interval"`
	Timeout             int                    `json:"timeout"`
	HealthyThreshold    int                    `json:"healthy_threshold"`
	UnhealthyThreshold  int                    `json:"unhealthy_threshold"`
}

type Endpoint struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Service         string                 `json:"service"`
	VPC             string                 `json:"vpc"`
	Subnet          string                 `json:"subnet"`
	State           string                 `json:"state"`
	DNS             string                 `json:"dns"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type SecurityGroup struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Description     string                 `json:"description"`
	VPC             string                 `json:"vpc"`
	InboundRules    []SecurityRule         `json:"inbound_rules"`
	OutboundRules   []SecurityRule         `json:"outbound_rules"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type SecurityRule struct {
	Protocol    string                 `json:"protocol"`
	FromPort    int                    `json:"from_port"`
	ToPort      int                    `json:"to_port"`
	Source      string                 `json:"source"`
	Description string                 `json:"description"`
}

type FirewallRule struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Direction       string                 `json:"direction"`
	Priority        int                    `json:"priority"`
	SourceRanges    []string               `json:"source_ranges"`
	DestRanges      []string               `json:"dest_ranges"`
	Allowed         []FirewallProtocol     `json:"allowed"`
	Denied          []FirewallProtocol     `json:"denied"`
	TargetTags      []string               `json:"target_tags"`
	Disabled        bool                   `json:"disabled"`
	LogConfig       FirewallLogConfig      `json:"log_config"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type FirewallProtocol struct {
	Protocol    string   `json:"protocol"`
	Ports       []string `json:"ports"`
}

type FirewallLogConfig struct {
	Enable      bool     `json:"enable"`
	Include     []string `json:"include"`
	Exclude     []string `json:"exclude"`
}

type IAMPolicy struct {
	Version     int                    `json:"version"`
	Bindings    []IAMBinding           `json:"bindings"`
	AuditConfigs []AuditConfig         `json:"audit_configs"`
	Etag        string                 `json:"etag"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type IAMBinding struct {
	Role        string                 `json:"role"`
	Members     []string               `json:"members"`
	Condition   *IAMCondition          `json:"condition,omitempty"`
}

type IAMCondition struct {
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	Expression  string                 `json:"expression"`
}

type AuditConfig struct {
	Service     string                 `json:"service"`
	AuditLogs   []AuditLog             `json:"audit_logs"`
}

type AuditLog struct {
	LogType         string                 `json:"log_type"`
	ExemptedMembers []string               `json:"exempted_members"`
}

type ServiceAccount struct {
	ID              string                 `json:"id"`
	Email           string                 `json:"email"`
	DisplayName     string                 `json:"display_name"`
	Description     string                 `json:"description"`
	Enabled         bool                   `json:"enabled"`
	Keys            []ServiceAccountKey    `json:"keys"`
	Roles           []string               `json:"roles"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type ServiceAccountKey struct {
	ID              string                 `json:"id"`
	Type            string                 `json:"type"`
	Algorithm       string                 `json:"algorithm"`
	CreatedAt       time.Time              `json:"created_at"`
	ExpiresAt       time.Time              `json:"expires_at"`
	Status          string                 `json:"status"`
}

type StorageBucket struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Location        string                 `json:"location"`
	StorageClass    string                 `json:"storage_class"`
	Size            int64                  `json:"size"`
	ObjectCount     int64                  `json:"object_count"`
	Versioning      bool                   `json:"versioning"`
	Encryption      BucketEncryption       `json:"encryption"`
	Lifecycle       []LifecycleRule        `json:"lifecycle"`
	CORS            []CORSConfig           `json:"cors"`
	Public          bool                   `json:"public"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type BucketPolicy struct {
	Version     string                 `json:"version"`
	Statements  []PolicyStatement      `json:"statements"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type PolicyStatement struct {
	Sid         string                 `json:"sid"`
	Effect      string                 `json:"effect"`
	Principal   interface{}            `json:"principal"`
	Action      interface{}            `json:"action"`
	Resource    interface{}            `json:"resource"`
	Condition   map[string]interface{} `json:"condition"`
}

type BucketEncryption struct {
	Type        string                 `json:"type"`
	Algorithm   string                 `json:"algorithm"`
	KeyID       string                 `json:"key_id"`
}

type LifecycleRule struct {
	ID          string                 `json:"id"`
	Status      string                 `json:"status"`
	Prefix      string                 `json:"prefix"`
	Tags        map[string]string      `json:"tags"`
	Transitions []LifecycleTransition  `json:"transitions"`
	Expiration  *LifecycleExpiration   `json:"expiration"`
}

type LifecycleTransition struct {
	Days         int                    `json:"days"`
	StorageClass string                 `json:"storage_class"`
}

type LifecycleExpiration struct {
	Days int                    `json:"days"`
}

type CORSConfig struct {
	Origins         []string               `json:"origins"`
	Methods         []string               `json:"methods"`
	Headers         []string               `json:"headers"`
	ExposeHeaders   []string               `json:"expose_headers"`
	MaxAge          int                    `json:"max_age"`
}

type Database struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Engine          string                 `json:"engine"`
	Version         string                 `json:"version"`
	State           string                 `json:"state"`
	Size            string                 `json:"size"`
	StorageGB       int                    `json:"storage_gb"`
	IOPS            int                    `json:"iops"`
	Endpoint        string                 `json:"endpoint"`
	Port            int                    `json:"port"`
	MultiAZ         bool                   `json:"multi_az"`
	Encrypted       bool                   `json:"encrypted"`
	BackupRetention int                    `json:"backup_retention"`
	MaintenanceWindow string               `json:"maintenance_window"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type DatabaseMetrics struct {
	CPU             float64                `json:"cpu"`
	Memory          float64                `json:"memory"`
	Storage         float64                `json:"storage"`
	Connections     int                    `json:"connections"`
	IOPS            float64                `json:"iops"`
	Latency         float64                `json:"latency"`
	Throughput      float64                `json:"throughput"`
	QueriesPerSec   float64                `json:"queries_per_sec"`
	SlowQueries     int                    `json:"slow_queries"`
	Timestamp       time.Time              `json:"timestamp"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type DatabaseBackup struct {
	ID              string                 `json:"id"`
	DatabaseID      string                 `json:"database_id"`
	Type            string                 `json:"type"`
	Status          string                 `json:"status"`
	Size            int64                  `json:"size"`
	CreatedAt       time.Time              `json:"created_at"`
	CompletedAt     time.Time              `json:"completed_at"`
	ExpiresAt       time.Time              `json:"expires_at"`
	Location        string                 `json:"location"`
	Encrypted       bool                   `json:"encrypted"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type ComputeInstance struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Type            string                 `json:"type"`
	State           string                 `json:"state"`
	Zone            string                 `json:"zone"`
	MachineType     string                 `json:"machine_type"`
	CPU             int                    `json:"cpu"`
	MemoryGB        float64                `json:"memory_gb"`
	Disks           []Disk                 `json:"disks"`
	NetworkInterfaces []NetworkInterface   `json:"network_interfaces"`
	PublicIP        string                 `json:"public_ip"`
	PrivateIP       string                 `json:"private_ip"`
	ImageID         string                 `json:"image_id"`
	KeyPair         string                 `json:"key_pair"`
	SecurityGroups  []string               `json:"security_groups"`
	UserData        string                 `json:"user_data"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
	Tags            map[string]string      `json:"tags"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Disk struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Type            string                 `json:"type"`
	SizeGB          int                    `json:"size_gb"`
	IOPS            int                    `json:"iops"`
	Throughput      int                    `json:"throughput"`
	Encrypted       bool                   `json:"encrypted"`
	DeviceName      string                 `json:"device_name"`
	AttachedAt      time.Time              `json:"attached_at"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type NetworkInterface struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Subnet          string                 `json:"subnet"`
	PrivateIP       string                 `json:"private_ip"`
	PublicIP        string                 `json:"public_ip"`
	MAC             string                 `json:"mac"`
	SecurityGroups  []string               `json:"security_groups"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type InstanceMetrics struct {
	CPU             float64                `json:"cpu"`
	Memory          float64                `json:"memory"`
	DiskRead        float64                `json:"disk_read"`
	DiskWrite       float64                `json:"disk_write"`
	NetworkIn       float64                `json:"network_in"`
	NetworkOut      float64                `json:"network_out"`
	DiskIOPS        float64                `json:"disk_iops"`
	NetworkPacketsIn float64               `json:"network_packets_in"`
	NetworkPacketsOut float64              `json:"network_packets_out"`
	Timestamp       time.Time              `json:"timestamp"`
	Metadata        map[string]interface{} `json:"metadata"`
}

// ProviderConfig represents common configuration for providers
type ProviderConfig struct {
	Credentials     string                 `json:"credentials"`
	Region          string                 `json:"region"`
	Project         string                 `json:"project"`
	Timeout         time.Duration          `json:"timeout"`
	RetryAttempts   int                    `json:"retry_attempts"`
	RetryDelay      time.Duration          `json:"retry_delay"`
	MaxConcurrency  int                    `json:"max_concurrency"`
	RateLimit       int                    `json:"rate_limit"`
	CacheEnabled    bool                   `json:"cache_enabled"`
	CacheTTL        time.Duration          `json:"cache_ttl"`
	Debug           bool                   `json:"debug"`
	Metadata        map[string]interface{} `json:"metadata"`
}

// ProviderError represents errors from provider operations
type ProviderError struct {
	Code        string                 `json:"code"`
	Message     string                 `json:"message"`
	Provider    string                 `json:"provider"`
	Operation   string                 `json:"operation"`
	Resource    string                 `json:"resource"`
	Retryable   bool                   `json:"retryable"`
	Timestamp   time.Time              `json:"timestamp"`
	Details     map[string]interface{} `json:"details"`
}

func (e *ProviderError) Error() string {
	return fmt.Sprintf("[%s] %s: %s (resource: %s, operation: %s)",
		e.Provider, e.Code, e.Message, e.Resource, e.Operation)
}