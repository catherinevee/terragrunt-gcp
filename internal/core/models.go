package core

import (
	"encoding/json"
	"time"
)

type Account struct {
	ID       string            `json:"id"`
	Provider string            `json:"provider"`
	Name     string            `json:"name"`
	Type     string            `json:"type"`
	Tags     map[string]string `json:"tags"`
	Region   string            `json:"region,omitempty"`
	Status   string            `json:"status"`
	Metadata map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt time.Time        `json:"created_at"`
	UpdatedAt time.Time        `json:"updated_at"`
}

func (a *Account) IsActive() bool {
	return a.Status == "active" || a.Status == "enabled"
}

func (a *Account) GetTag(key string) (string, bool) {
	value, exists := a.Tags[key]
	return value, exists
}

func (a *Account) SetTag(key, value string) {
	if a.Tags == nil {
		a.Tags = make(map[string]string)
	}
	a.Tags[key] = value
}

type Resource struct {
	ID          string                 `json:"id"`
	Name        string                 `json:"name"`
	Type        string                 `json:"type"`
	Region      string                 `json:"region"`
	Zone        string                 `json:"zone,omitempty"`
	Tags        map[string]string      `json:"tags"`
	Account     Account                `json:"account"`
	Status      string                 `json:"status"`
	Properties  map[string]interface{} `json:"properties,omitempty"`
	Cost        *ResourceCost          `json:"cost,omitempty"`
	Dependencies []ResourceDependency  `json:"dependencies,omitempty"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
	DiscoveredAt time.Time             `json:"discovered_at"`
}

func (r *Resource) IsRunning() bool {
	return r.Status == "running" || r.Status == "active" || r.Status == "available"
}

func (r *Resource) GetTag(key string) (string, bool) {
	value, exists := r.Tags[key]
	return value, exists
}

func (r *Resource) SetTag(key, value string) {
	if r.Tags == nil {
		r.Tags = make(map[string]string)
	}
	r.Tags[key] = value
}

func (r *Resource) GetProperty(key string) (interface{}, bool) {
	if r.Properties == nil {
		return nil, false
	}
	value, exists := r.Properties[key]
	return value, exists
}

func (r *Resource) SetProperty(key string, value interface{}) {
	if r.Properties == nil {
		r.Properties = make(map[string]interface{})
	}
	r.Properties[key] = value
}

type ResourceCost struct {
	Currency     string  `json:"currency"`
	DailyCost    float64 `json:"daily_cost"`
	MonthlyCost  float64 `json:"monthly_cost"`
	EstimatedAnnualCost float64 `json:"estimated_annual_cost"`
	LastUpdated  time.Time `json:"last_updated"`
}

type ResourceDependency struct {
	ResourceID   string `json:"resource_id"`
	ResourceType string `json:"resource_type"`
	DependencyType string `json:"dependency_type"`
	Direction    string `json:"direction"` // "inbound" or "outbound"
}


type GCPConfig struct {
	ProjectIDs       []string      `json:"project_ids"`
	ServiceAccountKey string       `json:"service_account_key,omitempty"`
	Regions          []string      `json:"regions,omitempty"`
	Zones            []string      `json:"zones,omitempty"`
	MaxRetries       int           `json:"max_retries"`
	Timeout          time.Duration `json:"timeout"`
	RateLimit        int           `json:"rate_limit,omitempty"`
	UseDefaultCredentials bool     `json:"use_default_credentials"`
	DiscoveryConfig  DiscoveryConfig `json:"discovery_config,omitempty"`
}

func (c *GCPConfig) Validate() error {
	if len(c.ProjectIDs) == 0 {
		return &ConfigValidationError{
			Field:   "project_ids",
			Message: "at least one project ID must be specified",
		}
	}

	if !c.UseDefaultCredentials && c.ServiceAccountKey == "" {
		return &ConfigValidationError{
			Field:   "service_account_key",
			Message: "service_account_key is required when not using default credentials",
		}
	}

	if c.MaxRetries < 0 {
		return &ConfigValidationError{
			Field:   "max_retries",
			Message: "max_retries cannot be negative",
		}
	}

	if c.Timeout <= 0 {
		c.Timeout = 30 * time.Second
	}

	return nil
}

func (c *GCPConfig) SetDefaults() {
	if c.MaxRetries == 0 {
		c.MaxRetries = 3
	}
	if c.Timeout == 0 {
		c.Timeout = 30 * time.Second
	}
	if c.RateLimit == 0 {
		c.RateLimit = 100
	}
	if len(c.Regions) == 0 {
		c.Regions = []string{"us-central1", "us-east1", "us-west1"}
	}
}

type ConfigValidationError struct {
	Field   string
	Message string
}

func (e *ConfigValidationError) Error() string {
	return "config validation error for field '" + e.Field + "': " + e.Message
}

type DiscoveryResult struct {
	Accounts     []Account              `json:"accounts"`
	Resources    []Resource             `json:"resources"`
	Summary      DiscoverySummary       `json:"summary"`
	Errors       []DiscoveryError       `json:"errors,omitempty"`
	StartTime    time.Time              `json:"start_time"`
	EndTime      time.Time              `json:"end_time"`
	Duration     time.Duration          `json:"duration"`
}

type DiscoverySummary struct {
	TotalAccounts   int                    `json:"total_accounts"`
	TotalResources  int                    `json:"total_resources"`
	ResourcesByType map[string]int         `json:"resources_by_type"`
	ResourcesByRegion map[string]int       `json:"resources_by_region"`
	AccountsByProvider map[string]int      `json:"accounts_by_provider"`
	ErrorCount      int                    `json:"error_count"`
}

type DiscoveryError struct {
	Provider    string    `json:"provider"`
	Account     string    `json:"account,omitempty"`
	Resource    string    `json:"resource,omitempty"`
	Error       string    `json:"error"`
	Timestamp   time.Time `json:"timestamp"`
	Retryable   bool      `json:"retryable"`
}

func (dr *DiscoveryResult) AddAccount(account Account) {
	dr.Accounts = append(dr.Accounts, account)
	dr.Summary.TotalAccounts = len(dr.Accounts)

	if dr.Summary.AccountsByProvider == nil {
		dr.Summary.AccountsByProvider = make(map[string]int)
	}
	dr.Summary.AccountsByProvider[account.Provider]++
}

func (dr *DiscoveryResult) AddResource(resource Resource) {
	dr.Resources = append(dr.Resources, resource)
	dr.Summary.TotalResources = len(dr.Resources)

	if dr.Summary.ResourcesByType == nil {
		dr.Summary.ResourcesByType = make(map[string]int)
	}
	dr.Summary.ResourcesByType[resource.Type]++

	if dr.Summary.ResourcesByRegion == nil {
		dr.Summary.ResourcesByRegion = make(map[string]int)
	}
	dr.Summary.ResourcesByRegion[resource.Region]++
}

func (dr *DiscoveryResult) AddError(err DiscoveryError) {
	dr.Errors = append(dr.Errors, err)
	dr.Summary.ErrorCount = len(dr.Errors)
}

func (dr *DiscoveryResult) ToJSON() ([]byte, error) {
	return json.MarshalIndent(dr, "", "  ")
}

func (dr *DiscoveryResult) HasErrors() bool {
	return len(dr.Errors) > 0
}

func (dr *DiscoveryResult) GetRetryableErrors() []DiscoveryError {
	var retryable []DiscoveryError
	for _, err := range dr.Errors {
		if err.Retryable {
			retryable = append(retryable, err)
		}
	}
	return retryable
}