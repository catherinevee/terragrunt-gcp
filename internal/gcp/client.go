package gcp

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	"cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/container/apiv1"
	"cloud.google.com/go/container/apiv1/containerpb"
	"cloud.google.com/go/iam"
	"cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/kms/apiv1/kmspb"
	"cloud.google.com/go/logging/apiv2"
	"cloud.google.com/go/logging/apiv2/loggingpb"
	"cloud.google.com/go/monitoring/apiv3/v2"
	"cloud.google.com/go/monitoring/apiv3/v2/monitoringpb"
	"cloud.google.com/go/resourcemanager/apiv3"
	"cloud.google.com/go/resourcemanager/apiv3/resourcemanagerpb"
	"cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"cloud.google.com/go/storage"
	"github.com/googleapis/gax-go/v2"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"golang.org/x/time/rate"
	"google.golang.org/api/bigquery/v2"
	"google.golang.org/api/cloudresourcemanager/v3"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/serviceusage/v1"
	"google.golang.org/api/sqladmin/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/status"
)

// Client provides a unified interface to GCP services with connection pooling and retry logic
type Client struct {
	mu sync.RWMutex

	// Core configuration
	projectID        string
	region           string
	zone             string
	credentials      *google.Credentials
	httpClient       *http.Client
	grpcConnPool     *GRPCConnectionPool
	options          []option.ClientOption

	// Rate limiting
	rateLimiter      *rate.Limiter
	quotaManager     *QuotaManager

	// Service clients (lazy initialized)
	computeClient    *compute.InstancesClient
	storageClient    *storage.Client
	containerClient  *container.ClusterManagerClient
	iamClient        *iam.IamClient
	kmsClient        *kms.KeyManagementClient
	loggingClient    *logging.ConfigClient
	monitoringClient *monitoring.MetricClient
	secretClient     *secretmanager.Client
	resourceClient   *resourcemanager.ProjectsClient
	dnsClient        *dns.Service
	sqlClient        *sqladmin.Service
	bigqueryClient   *bigquery.Service
	serviceUsageClient *serviceusage.Service

	// Client configuration
	config           *ClientConfig
	retryConfig      *RetryConfig
	metricsCollector *MetricsCollector
	logger           Logger

	// Connection management
	activeRequests   int64
	totalRequests    int64
	errorCount       int64
	lastError        error
	healthChecker    *HealthChecker
	circuitBreaker   *CircuitBreaker
}

// ClientConfig represents configuration for the GCP client
type ClientConfig struct {
	ProjectID              string
	Region                 string
	Zone                   string
	CredentialsPath        string
	CredentialsJSON        []byte
	ServiceAccountEmail    string
	ImpersonateServiceAccount string
	AccessToken            string
	Scopes                 []string
	UserAgent              string
	Endpoint               string
	DisableRetries         bool
	DisableAuth            bool
	MaxRetries             int
	RetryTimeout           time.Duration
	ConnectionTimeout      time.Duration
	RequestTimeout         time.Duration
	KeepAliveTime          time.Duration
	KeepAliveTimeout       time.Duration
	MaxConnectionIdleTime  time.Duration
	MaxConnectionAge       time.Duration
	MaxConnectionAgeGrace  time.Duration
	MaxConcurrentRequests  int
	MaxRequestsPerSecond   int
	BurstSize              int
	EnableMetrics          bool
	EnableTracing          bool
	EnableDebug            bool
	EnableCache            bool
	CacheTTL               time.Duration
	CacheSize              int64
	CustomHeaders          map[string]string
	CustomLabels           map[string]string
	ProxyURL               string
	CABundle               []byte
	TLSInsecureSkipVerify  bool
}

// GRPCConnectionPool manages a pool of gRPC connections
type GRPCConnectionPool struct {
	mu          sync.RWMutex
	connections map[string]*grpc.ClientConn
	maxConns    int
	maxIdle     int
	idleTimeout time.Duration
	lastUsed    map[string]time.Time
	config      *grpc.ConnectParams
}

// QuotaManager tracks API quota usage
type QuotaManager struct {
	mu         sync.RWMutex
	quotas     map[string]*APIQuota
	limits     map[string]int64
	usage      map[string]int64
	resetTimes map[string]time.Time
}

// APIQuota represents quota information for a specific API
type APIQuota struct {
	API           string
	Limit         int64
	Used          int64
	Remaining     int64
	ResetTime     time.Time
	BurstLimit    int64
	SustainedRate float64
}

// MetricsCollector collects client metrics
type MetricsCollector struct {
	mu              sync.RWMutex
	requestCounts   map[string]int64
	errorCounts     map[string]int64
	latencies       map[string][]time.Duration
	lastCollection  time.Time
	collectionInterval time.Duration
}

// HealthChecker performs health checks on GCP services
type HealthChecker struct {
	mu            sync.RWMutex
	services      map[string]*ServiceHealth
	checkInterval time.Duration
	lastCheck     time.Time
	healthy       bool
}

// ServiceHealth represents health status of a GCP service
type ServiceHealth struct {
	Service       string
	Healthy       bool
	LastCheck     time.Time
	ResponseTime  time.Duration
	ErrorCount    int
	ConsecutiveFailures int
}

// CircuitBreaker implements circuit breaker pattern
type CircuitBreaker struct {
	mu              sync.RWMutex
	state           CircuitState
	failures        int
	successCount    int
	lastFailureTime time.Time
	threshold       int
	timeout         time.Duration
	halfOpenMax     int
}

// CircuitState represents circuit breaker state
type CircuitState int

const (
	CircuitClosed CircuitState = iota
	CircuitOpen
	CircuitHalfOpen
)

// Logger interface for logging
type Logger interface {
	Debug(msg string, fields ...interface{})
	Info(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
}

// ClientOption is a function that configures a Client
type ClientOption func(*Client) error

// NewClient creates a new GCP client with the specified configuration
func NewClient(ctx context.Context, config *ClientConfig, opts ...ClientOption) (*Client, error) {
	client := &Client{
		projectID:    config.ProjectID,
		region:       config.Region,
		zone:         config.Zone,
		config:       config,
		rateLimiter:  rate.NewLimiter(rate.Limit(config.MaxRequestsPerSecond), config.BurstSize),
		quotaManager: NewQuotaManager(),
		grpcConnPool: NewGRPCConnectionPool(config),
		metricsCollector: NewMetricsCollector(config.EnableMetrics),
		healthChecker: NewHealthChecker(),
		circuitBreaker: NewCircuitBreaker(config),
		retryConfig: &RetryConfig{
			MaxRetries:     config.MaxRetries,
			InitialBackoff: 1 * time.Second,
			MaxBackoff:     30 * time.Second,
			BackoffFactor:  2.0,
			RetryTimeout:   config.RetryTimeout,
			RetryableErrors: DefaultRetryableErrors(),
		},
	}

	// Apply options
	for _, opt := range opts {
		if err := opt(client); err != nil {
			return nil, fmt.Errorf("applying client option: %w", err)
		}
	}

	// Initialize authentication
	if !config.DisableAuth {
		if err := client.initializeAuth(ctx); err != nil {
			return nil, fmt.Errorf("initializing authentication: %w", err)
		}
	}

	// Set up HTTP client with custom transport
	client.httpClient = client.createHTTPClient()

	// Set up client options
	client.options = client.buildClientOptions()

	// Initialize health checker
	if config.EnableMetrics {
		go client.startHealthChecker(ctx)
	}

	// Initialize metrics collector
	if config.EnableMetrics {
		go client.startMetricsCollector(ctx)
	}

	return client, nil
}

// initializeAuth sets up authentication credentials
func (c *Client) initializeAuth(ctx context.Context) error {
	var creds *google.Credentials
	var err error

	// Priority: Access Token > Credentials JSON > Credentials Path > Application Default
	if c.config.AccessToken != "" {
		// Use access token
		creds = &google.Credentials{
			TokenSource: oauth2.StaticTokenSource(&oauth2.Token{
				AccessToken: c.config.AccessToken,
			}),
		}
	} else if len(c.config.CredentialsJSON) > 0 {
		// Use credentials JSON
		creds, err = google.CredentialsFromJSON(ctx, c.config.CredentialsJSON, c.config.Scopes...)
		if err != nil {
			return fmt.Errorf("creating credentials from JSON: %w", err)
		}
	} else if c.config.CredentialsPath != "" {
		// Use credentials file
		data, err := os.ReadFile(c.config.CredentialsPath)
		if err != nil {
			return fmt.Errorf("reading credentials file: %w", err)
		}
		creds, err = google.CredentialsFromJSON(ctx, data, c.config.Scopes...)
		if err != nil {
			return fmt.Errorf("creating credentials from file: %w", err)
		}
	} else {
		// Use application default credentials
		creds, err = google.FindDefaultCredentials(ctx, c.config.Scopes...)
		if err != nil {
			return fmt.Errorf("finding default credentials: %w", err)
		}
	}

	// Handle impersonation if configured
	if c.config.ImpersonateServiceAccount != "" {
		creds, err = c.impersonateServiceAccount(ctx, creds, c.config.ImpersonateServiceAccount)
		if err != nil {
			return fmt.Errorf("impersonating service account: %w", err)
		}
	}

	c.credentials = creds
	return nil
}

// impersonateServiceAccount creates impersonated credentials
func (c *Client) impersonateServiceAccount(ctx context.Context, baseCreds *google.Credentials, targetEmail string) (*google.Credentials, error) {
	// Implementation would use IAM Service Account Credentials API
	// This is a placeholder for the actual implementation
	return baseCreds, nil
}

// createHTTPClient creates an HTTP client with custom configuration
func (c *Client) createHTTPClient() *http.Client {
	transport := &http.Transport{
		MaxIdleConns:          100,
		MaxIdleConnsPerHost:   10,
		MaxConnsPerHost:       20,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		DisableCompression:    false,
		DisableKeepAlives:     false,
		ForceAttemptHTTP2:     true,
	}

	if c.config.TLSInsecureSkipVerify {
		transport.TLSClientConfig = &tls.Config{
			InsecureSkipVerify: true,
		}
	}

	if c.config.CABundle != nil {
		caCertPool := x509.NewCertPool()
		caCertPool.AppendCertsFromPEM(c.config.CABundle)
		transport.TLSClientConfig = &tls.Config{
			RootCAs: caCertPool,
		}
	}

	if c.config.ProxyURL != "" {
		proxyURL, _ := url.Parse(c.config.ProxyURL)
		transport.Proxy = http.ProxyURL(proxyURL)
	}

	return &http.Client{
		Transport: transport,
		Timeout:   c.config.RequestTimeout,
	}
}

// buildClientOptions builds common client options
func (c *Client) buildClientOptions() []option.ClientOption {
	opts := []option.ClientOption{
		option.WithHTTPClient(c.httpClient),
	}

	if c.credentials != nil {
		opts = append(opts, option.WithCredentials(c.credentials))
	}

	if c.config.UserAgent != "" {
		opts = append(opts, option.WithUserAgent(c.config.UserAgent))
	}

	if c.config.Endpoint != "" {
		opts = append(opts, option.WithEndpoint(c.config.Endpoint))
	}

	// Add gRPC options
	grpcOpts := []grpc.DialOption{
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                c.config.KeepAliveTime,
			Timeout:             c.config.KeepAliveTimeout,
			PermitWithoutStream: true,
		}),
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(100 * 1024 * 1024), // 100MB
			grpc.MaxCallSendMsgSize(100 * 1024 * 1024), // 100MB
		),
	}

	opts = append(opts, option.WithGRPCDialOption(grpcOpts...))

	return opts
}

// GetComputeClient returns the Compute Engine client, initializing if needed
func (c *Client) GetComputeClient(ctx context.Context) (*compute.InstancesClient, error) {
	c.mu.RLock()
	if c.computeClient != nil {
		c.mu.RUnlock()
		return c.computeClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	// Double-check after acquiring write lock
	if c.computeClient != nil {
		return c.computeClient, nil
	}

	client, err := compute.NewInstancesRESTClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating compute client: %w", err)
	}

	c.computeClient = client
	return client, nil
}

// GetStorageClient returns the Cloud Storage client, initializing if needed
func (c *Client) GetStorageClient(ctx context.Context) (*storage.Client, error) {
	c.mu.RLock()
	if c.storageClient != nil {
		c.mu.RUnlock()
		return c.storageClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.storageClient != nil {
		return c.storageClient, nil
	}

	client, err := storage.NewClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating storage client: %w", err)
	}

	c.storageClient = client
	return client, nil
}

// GetContainerClient returns the Container Engine client, initializing if needed
func (c *Client) GetContainerClient(ctx context.Context) (*container.ClusterManagerClient, error) {
	c.mu.RLock()
	if c.containerClient != nil {
		c.mu.RUnlock()
		return c.containerClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.containerClient != nil {
		return c.containerClient, nil
	}

	client, err := container.NewClusterManagerClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating container client: %w", err)
	}

	c.containerClient = client
	return client, nil
}

// GetKMSClient returns the KMS client, initializing if needed
func (c *Client) GetKMSClient(ctx context.Context) (*kms.KeyManagementClient, error) {
	c.mu.RLock()
	if c.kmsClient != nil {
		c.mu.RUnlock()
		return c.kmsClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.kmsClient != nil {
		return c.kmsClient, nil
	}

	client, err := kms.NewKeyManagementClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating KMS client: %w", err)
	}

	c.kmsClient = client
	return client, nil
}

// GetSecretManagerClient returns the Secret Manager client, initializing if needed
func (c *Client) GetSecretManagerClient(ctx context.Context) (*secretmanager.Client, error) {
	c.mu.RLock()
	if c.secretClient != nil {
		c.mu.RUnlock()
		return c.secretClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.secretClient != nil {
		return c.secretClient, nil
	}

	client, err := secretmanager.NewClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating secret manager client: %w", err)
	}

	c.secretClient = client
	return client, nil
}

// GetMonitoringClient returns the Monitoring client, initializing if needed
func (c *Client) GetMonitoringClient(ctx context.Context) (*monitoring.MetricClient, error) {
	c.mu.RLock()
	if c.monitoringClient != nil {
		c.mu.RUnlock()
		return c.monitoringClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.monitoringClient != nil {
		return c.monitoringClient, nil
	}

	client, err := monitoring.NewMetricClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating monitoring client: %w", err)
	}

	c.monitoringClient = client
	return client, nil
}

// GetLoggingClient returns the Logging client, initializing if needed
func (c *Client) GetLoggingClient(ctx context.Context) (*logging.ConfigClient, error) {
	c.mu.RLock()
	if c.loggingClient != nil {
		c.mu.RUnlock()
		return c.loggingClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.loggingClient != nil {
		return c.loggingClient, nil
	}

	client, err := logging.NewConfigClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating logging client: %w", err)
	}

	c.loggingClient = client
	return client, nil
}

// GetResourceManagerClient returns the Resource Manager client, initializing if needed
func (c *Client) GetResourceManagerClient(ctx context.Context) (*resourcemanager.ProjectsClient, error) {
	c.mu.RLock()
	if c.resourceClient != nil {
		c.mu.RUnlock()
		return c.resourceClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.resourceClient != nil {
		return c.resourceClient, nil
	}

	client, err := resourcemanager.NewProjectsClient(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating resource manager client: %w", err)
	}

	c.resourceClient = client
	return client, nil
}

// GetDNSClient returns the DNS client, initializing if needed
func (c *Client) GetDNSClient(ctx context.Context) (*dns.Service, error) {
	c.mu.RLock()
	if c.dnsClient != nil {
		c.mu.RUnlock()
		return c.dnsClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.dnsClient != nil {
		return c.dnsClient, nil
	}

	client, err := dns.NewService(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating DNS client: %w", err)
	}

	c.dnsClient = client
	return client, nil
}

// GetSQLAdminClient returns the SQL Admin client, initializing if needed
func (c *Client) GetSQLAdminClient(ctx context.Context) (*sqladmin.Service, error) {
	c.mu.RLock()
	if c.sqlClient != nil {
		c.mu.RUnlock()
		return c.sqlClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.sqlClient != nil {
		return c.sqlClient, nil
	}

	client, err := sqladmin.NewService(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating SQL admin client: %w", err)
	}

	c.sqlClient = client
	return client, nil
}

// GetBigQueryClient returns the BigQuery client, initializing if needed
func (c *Client) GetBigQueryClient(ctx context.Context) (*bigquery.Service, error) {
	c.mu.RLock()
	if c.bigqueryClient != nil {
		c.mu.RUnlock()
		return c.bigqueryClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.bigqueryClient != nil {
		return c.bigqueryClient, nil
	}

	client, err := bigquery.NewService(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating BigQuery client: %w", err)
	}

	c.bigqueryClient = client
	return client, nil
}

// GetServiceUsageClient returns the Service Usage client, initializing if needed
func (c *Client) GetServiceUsageClient(ctx context.Context) (*serviceusage.Service, error) {
	c.mu.RLock()
	if c.serviceUsageClient != nil {
		c.mu.RUnlock()
		return c.serviceUsageClient, nil
	}
	c.mu.RUnlock()

	c.mu.Lock()
	defer c.mu.Unlock()

	if c.serviceUsageClient != nil {
		return c.serviceUsageClient, nil
	}

	client, err := serviceusage.NewService(ctx, c.options...)
	if err != nil {
		return nil, fmt.Errorf("creating service usage client: %w", err)
	}

	c.serviceUsageClient = client
	return client, nil
}

// ExecuteWithRetry executes a function with retry logic
func (c *Client) ExecuteWithRetry(ctx context.Context, fn func() error) error {
	if c.config.DisableRetries {
		return fn()
	}

	return c.retryConfig.Execute(ctx, fn)
}

// WaitForOperation waits for a long-running operation to complete
func (c *Client) WaitForOperation(ctx context.Context, op interface{}, pollInterval time.Duration) error {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	timeout := time.After(c.config.RequestTimeout)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-timeout:
			return fmt.Errorf("operation timeout exceeded")
		case <-ticker.C:
			// Check operation status based on type
			// This would need type assertion and specific handling
			// for different operation types
			return nil
		}
	}
}

// CheckQuota checks if an API call is within quota limits
func (c *Client) CheckQuota(api string) error {
	return c.quotaManager.CheckQuota(api)
}

// RecordMetric records a metric for the specified operation
func (c *Client) RecordMetric(operation string, duration time.Duration, err error) {
	if c.metricsCollector != nil {
		c.metricsCollector.Record(operation, duration, err)
	}
}

// GetProjectID returns the configured project ID
func (c *Client) GetProjectID() string {
	return c.projectID
}

// GetRegion returns the configured region
func (c *Client) GetRegion() string {
	return c.region
}

// GetZone returns the configured zone
func (c *Client) GetZone() string {
	return c.zone
}

// Close closes all client connections
func (c *Client) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	var errs []error

	if c.computeClient != nil {
		if err := c.computeClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing compute client: %w", err))
		}
	}

	if c.storageClient != nil {
		if err := c.storageClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing storage client: %w", err))
		}
	}

	if c.containerClient != nil {
		if err := c.containerClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing container client: %w", err))
		}
	}

	if c.kmsClient != nil {
		if err := c.kmsClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing KMS client: %w", err))
		}
	}

	if c.secretClient != nil {
		if err := c.secretClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing secret manager client: %w", err))
		}
	}

	if c.monitoringClient != nil {
		if err := c.monitoringClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing monitoring client: %w", err))
		}
	}

	if c.loggingClient != nil {
		if err := c.loggingClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing logging client: %w", err))
		}
	}

	if c.resourceClient != nil {
		if err := c.resourceClient.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing resource manager client: %w", err))
		}
	}

	if c.grpcConnPool != nil {
		if err := c.grpcConnPool.Close(); err != nil {
			errs = append(errs, fmt.Errorf("closing gRPC connection pool: %w", err))
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors closing clients: %v", errs)
	}

	return nil
}

// startHealthChecker starts the health checking routine
func (c *Client) startHealthChecker(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			c.healthChecker.CheckAll(ctx, c)
		}
	}
}

// startMetricsCollector starts the metrics collection routine
func (c *Client) startMetricsCollector(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			c.metricsCollector.Collect()
		}
	}
}

// Helper functions for connection pool, quota manager, etc.

// NewGRPCConnectionPool creates a new gRPC connection pool
func NewGRPCConnectionPool(config *ClientConfig) *GRPCConnectionPool {
	return &GRPCConnectionPool{
		connections: make(map[string]*grpc.ClientConn),
		maxConns:    100,
		maxIdle:     10,
		idleTimeout: 5 * time.Minute,
		lastUsed:    make(map[string]time.Time),
	}
}

// Get retrieves a connection from the pool
func (p *GRPCConnectionPool) Get(endpoint string) (*grpc.ClientConn, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if conn, exists := p.connections[endpoint]; exists {
		p.lastUsed[endpoint] = time.Now()
		return conn, nil
	}

	// Create new connection
	conn, err := grpc.Dial(endpoint,
		grpc.WithInsecure(),
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                30 * time.Second,
			Timeout:             10 * time.Second,
			PermitWithoutStream: true,
		}),
	)
	if err != nil {
		return nil, err
	}

	p.connections[endpoint] = conn
	p.lastUsed[endpoint] = time.Now()

	// Clean up old connections if needed
	if len(p.connections) > p.maxConns {
		p.cleanup()
	}

	return conn, nil
}

// cleanup removes idle connections
func (p *GRPCConnectionPool) cleanup() {
	now := time.Now()
	for endpoint, lastUsed := range p.lastUsed {
		if now.Sub(lastUsed) > p.idleTimeout {
			if conn, exists := p.connections[endpoint]; exists {
				conn.Close()
				delete(p.connections, endpoint)
				delete(p.lastUsed, endpoint)
			}
		}
	}
}

// Close closes all connections in the pool
func (p *GRPCConnectionPool) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	for _, conn := range p.connections {
		if err := conn.Close(); err != nil {
			return err
		}
	}

	p.connections = make(map[string]*grpc.ClientConn)
	p.lastUsed = make(map[string]time.Time)

	return nil
}

// NewQuotaManager creates a new quota manager
func NewQuotaManager() *QuotaManager {
	return &QuotaManager{
		quotas:     make(map[string]*APIQuota),
		limits:     make(map[string]int64),
		usage:      make(map[string]int64),
		resetTimes: make(map[string]time.Time),
	}
}

// CheckQuota checks if an API call is within quota
func (q *QuotaManager) CheckQuota(api string) error {
	q.mu.RLock()
	defer q.mu.RUnlock()

	if quota, exists := q.quotas[api]; exists {
		if quota.Remaining <= 0 && time.Now().Before(quota.ResetTime) {
			return fmt.Errorf("API quota exceeded for %s, resets at %v", api, quota.ResetTime)
		}
	}

	return nil
}

// UpdateQuota updates quota usage for an API
func (q *QuotaManager) UpdateQuota(api string, used int64) {
	q.mu.Lock()
	defer q.mu.Unlock()

	if quota, exists := q.quotas[api]; exists {
		quota.Used += used
		quota.Remaining = quota.Limit - quota.Used
		if quota.Remaining < 0 {
			quota.Remaining = 0
		}
	}
}

// NewMetricsCollector creates a new metrics collector
func NewMetricsCollector(enabled bool) *MetricsCollector {
	if !enabled {
		return nil
	}

	return &MetricsCollector{
		requestCounts:      make(map[string]int64),
		errorCounts:        make(map[string]int64),
		latencies:          make(map[string][]time.Duration),
		collectionInterval: 30 * time.Second,
	}
}

// Record records a metric
func (m *MetricsCollector) Record(operation string, duration time.Duration, err error) {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	m.requestCounts[operation]++

	if err != nil {
		m.errorCounts[operation]++
	}

	if m.latencies[operation] == nil {
		m.latencies[operation] = make([]time.Duration, 0)
	}
	m.latencies[operation] = append(m.latencies[operation], duration)

	// Keep only last 1000 samples
	if len(m.latencies[operation]) > 1000 {
		m.latencies[operation] = m.latencies[operation][len(m.latencies[operation])-1000:]
	}
}

// Collect collects and processes metrics
func (m *MetricsCollector) Collect() {
	if m == nil {
		return
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// Process metrics here
	// This could send to monitoring service, log, etc.
	m.lastCollection = time.Now()
}

// NewHealthChecker creates a new health checker
func NewHealthChecker() *HealthChecker {
	return &HealthChecker{
		services:      make(map[string]*ServiceHealth),
		checkInterval: 1 * time.Minute,
		healthy:       true,
	}
}

// CheckAll checks health of all services
func (h *HealthChecker) CheckAll(ctx context.Context, client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// Check each service health
	// This would implement actual health checks
	h.lastCheck = time.Now()
}

// IsHealthy returns overall health status
func (h *HealthChecker) IsHealthy() bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.healthy
}

// NewCircuitBreaker creates a new circuit breaker
func NewCircuitBreaker(config *ClientConfig) *CircuitBreaker {
	return &CircuitBreaker{
		state:       CircuitClosed,
		threshold:   5,
		timeout:     30 * time.Second,
		halfOpenMax: 3,
	}
}

// Call executes a function with circuit breaker protection
func (cb *CircuitBreaker) Call(fn func() error) error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case CircuitOpen:
		if time.Since(cb.lastFailureTime) > cb.timeout {
			cb.state = CircuitHalfOpen
			cb.successCount = 0
		} else {
			return fmt.Errorf("circuit breaker is open")
		}

	case CircuitHalfOpen:
		if cb.successCount >= cb.halfOpenMax {
			cb.state = CircuitClosed
			cb.failures = 0
		}
	}

	err := fn()

	if err != nil {
		cb.failures++
		cb.lastFailureTime = time.Now()

		if cb.failures >= cb.threshold {
			cb.state = CircuitOpen
		}

		return err
	}

	if cb.state == CircuitHalfOpen {
		cb.successCount++
	}

	return nil
}

// DefaultRetryableErrors returns default retryable error patterns
func DefaultRetryableErrors() []string {
	return []string{
		"rate limit exceeded",
		"quota exceeded",
		"service unavailable",
		"deadline exceeded",
		"resource exhausted",
		"temporary failure",
		"connection refused",
		"connection reset",
		"timeout",
		"too many requests",
		"throttled",
		"backoff",
	}
}

// IsRetryable checks if an error is retryable
func IsRetryable(err error) bool {
	if err == nil {
		return false
	}

	// Check gRPC errors
	if st, ok := status.FromError(err); ok {
		switch st.Code() {
		case codes.Unavailable,
			codes.ResourceExhausted,
			codes.DeadlineExceeded,
			codes.Aborted:
			return true
		}
	}

	// Check for specific error strings
	errStr := strings.ToLower(err.Error())
	for _, pattern := range DefaultRetryableErrors() {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}

	return false
}

// GetMetrics returns current metrics
func (c *Client) GetMetrics() map[string]interface{} {
	metrics := make(map[string]interface{})

	c.mu.RLock()
	defer c.mu.RUnlock()

	metrics["active_requests"] = c.activeRequests
	metrics["total_requests"] = c.totalRequests
	metrics["error_count"] = c.errorCount

	if c.metricsCollector != nil {
		c.metricsCollector.mu.RLock()
		defer c.metricsCollector.mu.RUnlock()

		metrics["request_counts"] = c.metricsCollector.requestCounts
		metrics["error_counts"] = c.metricsCollector.errorCounts
	}

	if c.healthChecker != nil {
		metrics["health_status"] = c.healthChecker.IsHealthy()
	}

	return metrics
}

// GetHealth returns health status of all services
func (c *Client) GetHealth() map[string]*ServiceHealth {
	if c.healthChecker == nil {
		return nil
	}

	c.healthChecker.mu.RLock()
	defer c.healthChecker.mu.RUnlock()

	health := make(map[string]*ServiceHealth)
	for k, v := range c.healthChecker.services {
		health[k] = v
	}

	return health
}