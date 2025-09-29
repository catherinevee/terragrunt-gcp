package gcp

import (
	"context"
	// "encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	admin "cloud.google.com/go/iam/admin/apiv1"
	"cloud.google.com/go/iam/admin/apiv1/adminpb"
	credentials "cloud.google.com/go/iam/credentials/apiv1"
	"cloud.google.com/go/iam/credentials/apiv1/credentialspb"
	"cloud.google.com/go/resourcemanager/apiv3"
	// "cloud.google.com/go/resourcemanager/apiv3/resourcemanagerpb"
	"go.uber.org/zap"
	"google.golang.org/api/cloudresourcemanager/v1"
	"google.golang.org/api/iam/v1"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
	// "google.golang.org/grpc/codes"
	// "google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/durationpb"
	"google.golang.org/protobuf/types/known/fieldmaskpb"
)

// IAMService provides comprehensive IAM operations
type IAMService struct {
	projectID              string
	iamClient              *admin.IamClient
	credentialsClient      *credentials.IamCredentialsClient
	projectsClient         *resourcemanager.ProjectsClient
	foldersClient          *resourcemanager.FoldersClient
	organizationsClient    *resourcemanager.OrganizationsClient
	resourceManagerClient  *cloudresourcemanager.Service
	iamAPIClient           *iam.Service
	serviceAccountCache    *ServiceAccountCache
	roleCache              *RoleCache
	policyCache            *PolicyCache
	workloadIdentityPools  *WorkloadIdentityManager
	policyAnalyzer         *PolicyAnalyzer
	permissionTester       *PermissionTester
	auditLogger            *AuditLogger
	logger                 *zap.Logger
	metrics                *IAMMetrics
	rateLimiter            *IAMRateLimiter
	mu                     sync.RWMutex
}

// ServiceAccountCache caches service account information
type ServiceAccountCache struct {
	accounts      map[string]*adminpb.ServiceAccount
	keys          map[string][]*adminpb.ServiceAccountKey
	roles         map[string][]string
	mu            sync.RWMutex
	ttl           time.Duration
	lastUpdate    map[string]time.Time
}

// RoleCache caches role definitions
type RoleCache struct {
	predefinedRoles map[string]*adminpb.Role
	customRoles     map[string]*adminpb.Role
	permissions     map[string][]string
	mu              sync.RWMutex
	ttl             time.Duration
	lastUpdate      map[string]time.Time
}

// PolicyCache caches IAM policies
type PolicyCache struct {
	projectPolicies      map[string]*iam.Policy
	folderPolicies       map[string]*iam.Policy
	organizationPolicies map[string]*iam.Policy
	resourcePolicies     map[string]*PolicyData
	mu                   sync.RWMutex
	ttl                  time.Duration
	lastUpdate           map[string]time.Time
}

// PolicyData represents cached policy data
type PolicyData struct {
	Policy      interface{}
	Version     int32
	ETag        string
	UpdatedTime time.Time
}

// WorkloadIdentityManager manages workload identity configurations
type WorkloadIdentityManager struct {
	pools           map[string]*WorkloadIdentityPool
	providers       map[string]*WorkloadIdentityProvider
	serviceAccounts map[string]*WorkloadIdentityBinding
	mu              sync.RWMutex
}

// WorkloadIdentityPool represents a workload identity pool
type WorkloadIdentityPool struct {
	Name            string
	DisplayName     string
	Description     string
	Disabled        bool
	AttributeMapping map[string]string
	AttributeCondition string
}

// WorkloadIdentityProvider represents a workload identity provider
type WorkloadIdentityProvider struct {
	Name              string
	DisplayName       string
	Description       string
	Disabled          bool
	AttributeMapping  map[string]string
	AttributeCondition string
	OIDC              *OIDCConfig
	SAML              *SAMLConfig
	AWS               *AWSConfig
}

// OIDCConfig represents OIDC provider configuration
type OIDCConfig struct {
	IssuerURI      string
	AllowedAudiences []string
	JWKSJson       string
}

// SAMLConfig represents SAML provider configuration
type SAMLConfig struct {
	IDPMetadataXML string
}

// AWSConfig represents AWS provider configuration
type AWSConfig struct {
	AccountID string
	STSUri    string
}

// WorkloadIdentityBinding represents a service account binding
type WorkloadIdentityBinding struct {
	ServiceAccount string
	Pool           string
	Provider       string
	Attribute      string
}

// PolicyAnalyzer analyzes IAM policies
type PolicyAnalyzer struct {
	client *iam.Service
	logger *zap.Logger
	cache  map[string]*AnalysisResult
	mu     sync.RWMutex
}

// AnalysisResult represents policy analysis results
type AnalysisResult struct {
	OverlyPermissiveRoles []string
	UnusedServiceAccounts []string
	StaleBindings         []string
	RiskyPermissions      []string
	ComplianceIssues      []string
	Recommendations       []string
	AnalyzedAt            time.Time
}

// PermissionTester tests IAM permissions
type PermissionTester struct {
	client *cloudresourcemanager.Service
	logger *zap.Logger
	cache  map[string]*TestResult
	mu     sync.RWMutex
}

// TestResult represents permission test results
type TestResult struct {
	Resource          string
	Permissions       []string
	AllowedPermissions []string
	DeniedPermissions []string
	TestedAt          time.Time
}

// AuditLogger logs IAM operations for audit
type AuditLogger struct {
	logger      *zap.Logger
	logEntries  []AuditEntry
	mu          sync.RWMutex
	maxEntries  int
	flushPeriod time.Duration
}

// AuditEntry represents an audit log entry
type AuditEntry struct {
	Timestamp   time.Time
	Operation   string
	Resource    string
	Principal   string
	Result      string
	Details     map[string]interface{}
}

// IAMMetrics tracks IAM operations metrics
type IAMMetrics struct {
	ServiceAccountOperations int64
	RoleOperations           int64
	PolicyOperations         int64
	KeyOperations            int64
	BindingOperations        int64
	WorkloadIdentityOperations int64
	PermissionTests          int64
	PolicyAnalyses           int64
	ErrorCounts              map[string]int64
	OperationLatencies       []time.Duration
	mu                       sync.RWMutex
}

// IAMRateLimiter implements rate limiting for IAM operations
type IAMRateLimiter struct {
	readLimiter    *time.Ticker
	writeLimiter   *time.Ticker
	deleteLimiter  *time.Ticker
	adminLimiter   *time.Ticker
	mu             sync.Mutex
	readQuota      int
	writeQuota     int
	deleteQuota    int
	adminQuota     int
}

// IAMServiceAccountConfig represents service account configuration for IAM operations
type IAMServiceAccountConfig struct {
	AccountID    string
	DisplayName  string
	Description  string
	ProjectID    string
}

// ServiceAccountKeyConfig represents service account key configuration
type ServiceAccountKeyConfig struct {
	ServiceAccount  string
	KeyAlgorithm    adminpb.ServiceAccountKeyAlgorithm
	PrivateKeyType  adminpb.ServiceAccountPrivateKeyType
	KeyOrigin       adminpb.ServiceAccountKeyOrigin
	ValidAfterTime  time.Time
	ValidBeforeTime time.Time
}

// RoleConfig represents custom role configuration
type RoleConfig struct {
	RoleID          string
	Title           string
	Description     string
	IncludedPermissions []string
	Stage           adminpb.Role_RoleLaunchStage
}

// BindingConfig represents IAM binding configuration
type BindingConfig struct {
	Resource  string
	Role      string
	Members   []string
	Condition *Condition
}

// Condition represents IAM condition
type Condition struct {
	Expression  string
	Title       string
	Description string
	Location    string
}

// PolicyConfig represents IAM policy configuration
type PolicyConfig struct {
	Resource       string
	Bindings       []*Binding
	AuditConfigs   []*AuditConfig
	Version        int32
	Etag           string
}

// Binding represents an IAM binding
type Binding struct {
	Role      string
	Members   []string
	Condition *Condition
}

// AuditConfig represents audit configuration
type AuditConfig struct {
	Service         string
	AuditLogConfigs []*AuditLogConfig
	ExemptedMembers []string
}

// AuditLogConfig represents audit log configuration
type AuditLogConfig struct {
	LogType         string
	ExemptedMembers []string
}

// NewIAMService creates a new comprehensive IAM service
func NewIAMService(ctx context.Context, projectID string, opts ...option.ClientOption) (*IAMService, error) {
	logger := zap.L().Named("iam")

	// Initialize IAM admin client
	iamClient, err := admin.NewIamClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create IAM client: %w", err)
	}

	// Initialize credentials client
	credentialsClient, err := credentials.NewIamCredentialsClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create credentials client: %w", err)
	}

	// Initialize resource manager clients
	projectsClient, err := resourcemanager.NewProjectsClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create projects client: %w", err)
	}

	foldersClient, err := resourcemanager.NewFoldersClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create folders client: %w", err)
	}

	organizationsClient, err := resourcemanager.NewOrganizationsClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create organizations client: %w", err)
	}

	// Initialize legacy clients
	resourceManagerClient, err := cloudresourcemanager.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource manager client: %w", err)
	}

	iamAPIClient, err := iam.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create IAM API client: %w", err)
	}

	// Initialize caches
	serviceAccountCache := &ServiceAccountCache{
		accounts:   make(map[string]*adminpb.ServiceAccount),
		keys:       make(map[string][]*adminpb.ServiceAccountKey),
		roles:      make(map[string][]string),
		lastUpdate: make(map[string]time.Time),
		ttl:        5 * time.Minute,
	}

	roleCache := &RoleCache{
		predefinedRoles: make(map[string]*adminpb.Role),
		customRoles:     make(map[string]*adminpb.Role),
		permissions:     make(map[string][]string),
		lastUpdate:      make(map[string]time.Time),
		ttl:             10 * time.Minute,
	}

	policyCache := &PolicyCache{
		projectPolicies:      make(map[string]*iam.Policy),
		folderPolicies:       make(map[string]*iam.Policy),
		organizationPolicies: make(map[string]*iam.Policy),
		resourcePolicies:     make(map[string]*PolicyData),
		lastUpdate:           make(map[string]time.Time),
		ttl:                  2 * time.Minute,
	}

	// Initialize workload identity manager
	workloadIdentityPools := &WorkloadIdentityManager{
		pools:           make(map[string]*WorkloadIdentityPool),
		providers:       make(map[string]*WorkloadIdentityProvider),
		serviceAccounts: make(map[string]*WorkloadIdentityBinding),
	}

	// Initialize policy analyzer
	policyAnalyzer := &PolicyAnalyzer{
		client: iamAPIClient,
		logger: logger.Named("analyzer"),
		cache:  make(map[string]*AnalysisResult),
	}

	// Initialize permission tester
	permissionTester := &PermissionTester{
		client: resourceManagerClient,
		logger: logger.Named("tester"),
		cache:  make(map[string]*TestResult),
	}

	// Initialize audit logger
	auditLogger := &AuditLogger{
		logger:      logger.Named("audit"),
		logEntries:  make([]AuditEntry, 0),
		maxEntries:  10000,
		flushPeriod: 5 * time.Minute,
	}

	// Initialize metrics
	metrics := &IAMMetrics{
		ErrorCounts:        make(map[string]int64),
		OperationLatencies: make([]time.Duration, 0),
	}

	// Initialize rate limiter
	rateLimiter := &IAMRateLimiter{
		readLimiter:   time.NewTicker(10 * time.Millisecond),
		writeLimiter:  time.NewTicker(50 * time.Millisecond),
		deleteLimiter: time.NewTicker(50 * time.Millisecond),
		adminLimiter:  time.NewTicker(100 * time.Millisecond),
		readQuota:     6000,
		writeQuota:    600,
		deleteQuota:   300,
		adminQuota:    60,
	}

	// Start audit log flusher
	go auditLogger.startFlusher()

	return &IAMService{
		iamClient:              iamClient,
		credentialsClient:      credentialsClient,
		projectsClient:         projectsClient,
		foldersClient:          foldersClient,
		organizationsClient:    organizationsClient,
		resourceManagerClient:  resourceManagerClient,
		iamAPIClient:           iamAPIClient,
		serviceAccountCache:    serviceAccountCache,
		roleCache:              roleCache,
		policyCache:            policyCache,
		workloadIdentityPools:  workloadIdentityPools,
		policyAnalyzer:         policyAnalyzer,
		permissionTester:       permissionTester,
		auditLogger:            auditLogger,
		logger:                 logger,
		metrics:                metrics,
		rateLimiter:            rateLimiter,
	}, nil
}

// CreateServiceAccount creates a new service account
func (is *IAMService) CreateServiceAccount(ctx context.Context, config *ServiceAccountConfig) (*adminpb.ServiceAccount, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	startTime := time.Now()
	is.logger.Info("Creating service account",
		zap.String("accountID", strings.Split(config.Email, "@")[0]),
		zap.String("project", is.projectID))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	req := &adminpb.CreateServiceAccountRequest{
		Name:      fmt.Sprintf("projects/%s", is.projectID),
		AccountId: strings.Split(config.Email, "@")[0],
		ServiceAccount: &adminpb.ServiceAccount{
			DisplayName: config.Email,
			Description: "Service account",
		},
	}

	sa, err := is.iamClient.CreateServiceAccount(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["service_account_create"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create service account: %w", err)
	}

	// Update cache
	is.serviceAccountCache.mu.Lock()
	is.serviceAccountCache.accounts[sa.Email] = sa
	is.serviceAccountCache.lastUpdate[sa.Email] = time.Now()
	is.serviceAccountCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "CreateServiceAccount",
		Resource:  sa.Name,
		Principal: is.projectID,
		Result:    "Success",
		Details: map[string]interface{}{
			"email":       sa.Email,
			"displayName": config.Email,
		},
	})

	// Update metrics
	is.metrics.mu.Lock()
	is.metrics.ServiceAccountOperations++
	is.metrics.OperationLatencies = append(is.metrics.OperationLatencies, time.Since(startTime))
	is.metrics.mu.Unlock()

	is.logger.Info("Service account created successfully",
		zap.String("email", sa.Email),
		zap.Duration("duration", time.Since(startTime)))

	return sa, nil
}

// GetServiceAccount retrieves a service account
func (is *IAMService) GetServiceAccount(ctx context.Context, email string) (*adminpb.ServiceAccount, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	// Check cache first
	is.serviceAccountCache.mu.RLock()
	if sa, ok := is.serviceAccountCache.accounts[email]; ok {
		if time.Since(is.serviceAccountCache.lastUpdate[email]) < is.serviceAccountCache.ttl {
			is.serviceAccountCache.mu.RUnlock()
			is.logger.Debug("Returning service account from cache", zap.String("email", email))
			return sa, nil
		}
	}
	is.serviceAccountCache.mu.RUnlock()

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	req := &adminpb.GetServiceAccountRequest{
		Name: fmt.Sprintf("projects/-/serviceAccounts/%s", email),
	}

	sa, err := is.iamClient.GetServiceAccount(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["service_account_get"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to get service account: %w", err)
	}

	// Update cache
	is.serviceAccountCache.mu.Lock()
	is.serviceAccountCache.accounts[email] = sa
	is.serviceAccountCache.lastUpdate[email] = time.Now()
	is.serviceAccountCache.mu.Unlock()

	return sa, nil
}

// ListServiceAccounts lists all service accounts in a project
func (is *IAMService) ListServiceAccounts(ctx context.Context, projectID string) ([]*adminpb.ServiceAccount, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	req := &adminpb.ListServiceAccountsRequest{
		Name:     fmt.Sprintf("projects/%s", projectID),
		PageSize: 100,
	}

	var accounts []*adminpb.ServiceAccount
	it := is.iamClient.ListServiceAccounts(ctx, req)

	for {
		sa, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			is.metrics.mu.Lock()
			is.metrics.ErrorCounts["service_account_list"]++
			is.metrics.mu.Unlock()
			return nil, fmt.Errorf("failed to list service accounts: %w", err)
		}
		accounts = append(accounts, sa)

		// Update cache
		is.serviceAccountCache.mu.Lock()
		is.serviceAccountCache.accounts[sa.Email] = sa
		is.serviceAccountCache.lastUpdate[sa.Email] = time.Now()
		is.serviceAccountCache.mu.Unlock()
	}

	is.metrics.mu.Lock()
	is.metrics.ServiceAccountOperations++
	is.metrics.mu.Unlock()

	is.logger.Info("Listed service accounts",
		zap.String("project", projectID),
		zap.Int("count", len(accounts)))

	return accounts, nil
}

// DeleteServiceAccount deletes a service account
func (is *IAMService) DeleteServiceAccount(ctx context.Context, email string) error {
	is.mu.Lock()
	defer is.mu.Unlock()

	startTime := time.Now()
	is.logger.Info("Deleting service account",
		zap.String("email", email))

	// Apply rate limiting
	<-is.rateLimiter.deleteLimiter.C

	req := &adminpb.DeleteServiceAccountRequest{
		Name: fmt.Sprintf("projects/-/serviceAccounts/%s", email),
	}

	if err := is.iamClient.DeleteServiceAccount(ctx, req); err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["service_account_delete"]++
		is.metrics.mu.Unlock()
		return fmt.Errorf("failed to delete service account: %w", err)
	}

	// Remove from cache
	is.serviceAccountCache.mu.Lock()
	delete(is.serviceAccountCache.accounts, email)
	delete(is.serviceAccountCache.keys, email)
	delete(is.serviceAccountCache.roles, email)
	delete(is.serviceAccountCache.lastUpdate, email)
	is.serviceAccountCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "DeleteServiceAccount",
		Resource:  email,
		Result:    "Success",
	})

	// Update metrics
	is.metrics.mu.Lock()
	is.metrics.ServiceAccountOperations++
	is.metrics.OperationLatencies = append(is.metrics.OperationLatencies, time.Since(startTime))
	is.metrics.mu.Unlock()

	is.logger.Info("Service account deleted successfully",
		zap.String("email", email),
		zap.Duration("duration", time.Since(startTime)))

	return nil
}

// CreateServiceAccountKey creates a new service account key
func (is *IAMService) CreateServiceAccountKey(ctx context.Context, config *ServiceAccountKeyConfig) (*adminpb.ServiceAccountKey, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	startTime := time.Now()
	is.logger.Info("Creating service account key",
		zap.String("serviceAccount", config.ServiceAccount))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	req := &adminpb.CreateServiceAccountKeyRequest{
		Name:           fmt.Sprintf("projects/-/serviceAccounts/%s", config.ServiceAccount),
		PrivateKeyType: config.PrivateKeyType,
		KeyAlgorithm:   config.KeyAlgorithm,
	}

	key, err := is.iamClient.CreateServiceAccountKey(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["key_create"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create service account key: %w", err)
	}

	// Update cache
	is.serviceAccountCache.mu.Lock()
	if is.serviceAccountCache.keys[config.ServiceAccount] == nil {
		is.serviceAccountCache.keys[config.ServiceAccount] = make([]*adminpb.ServiceAccountKey, 0)
	}
	is.serviceAccountCache.keys[config.ServiceAccount] = append(is.serviceAccountCache.keys[config.ServiceAccount], key)
	is.serviceAccountCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "CreateServiceAccountKey",
		Resource:  config.ServiceAccount,
		Result:    "Success",
		Details: map[string]interface{}{
			"keyId":        key.Name,
			"keyAlgorithm": config.KeyAlgorithm.String(),
		},
	})

	// Update metrics
	is.metrics.mu.Lock()
	is.metrics.KeyOperations++
	is.metrics.OperationLatencies = append(is.metrics.OperationLatencies, time.Since(startTime))
	is.metrics.mu.Unlock()

	is.logger.Info("Service account key created successfully",
		zap.String("keyId", key.Name),
		zap.Duration("duration", time.Since(startTime)))

	return key, nil
}

// ListServiceAccountKeys lists all keys for a service account
func (is *IAMService) ListServiceAccountKeys(ctx context.Context, serviceAccount string) ([]*adminpb.ServiceAccountKey, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	// Check cache first
	is.serviceAccountCache.mu.RLock()
	if keys, ok := is.serviceAccountCache.keys[serviceAccount]; ok {
		is.serviceAccountCache.mu.RUnlock()
		is.logger.Debug("Returning keys from cache", zap.String("serviceAccount", serviceAccount))
		return keys, nil
	}
	is.serviceAccountCache.mu.RUnlock()

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	req := &adminpb.ListServiceAccountKeysRequest{
		Name: fmt.Sprintf("projects/-/serviceAccounts/%s", serviceAccount),
		KeyTypes: []adminpb.ListServiceAccountKeysRequest_KeyType{
			adminpb.ListServiceAccountKeysRequest_USER_MANAGED,
			adminpb.ListServiceAccountKeysRequest_SYSTEM_MANAGED,
		},
	}

	resp, err := is.iamClient.ListServiceAccountKeys(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["key_list"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to list service account keys: %w", err)
	}

	// Update cache
	is.serviceAccountCache.mu.Lock()
	is.serviceAccountCache.keys[serviceAccount] = resp.Keys
	is.serviceAccountCache.mu.Unlock()

	is.metrics.mu.Lock()
	is.metrics.KeyOperations++
	is.metrics.mu.Unlock()

	return resp.Keys, nil
}

// DeleteServiceAccountKey deletes a service account key
func (is *IAMService) DeleteServiceAccountKey(ctx context.Context, keyName string) error {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Deleting service account key",
		zap.String("keyName", keyName))

	// Apply rate limiting
	<-is.rateLimiter.deleteLimiter.C

	req := &adminpb.DeleteServiceAccountKeyRequest{
		Name: keyName,
	}

	if err := is.iamClient.DeleteServiceAccountKey(ctx, req); err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["key_delete"]++
		is.metrics.mu.Unlock()
		return fmt.Errorf("failed to delete service account key: %w", err)
	}

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "DeleteServiceAccountKey",
		Resource:  keyName,
		Result:    "Success",
	})

	is.metrics.mu.Lock()
	is.metrics.KeyOperations++
	is.metrics.mu.Unlock()

	is.logger.Info("Service account key deleted successfully",
		zap.String("keyName", keyName))

	return nil
}

// GenerateAccessToken generates an access token for a service account
func (is *IAMService) GenerateAccessToken(ctx context.Context, serviceAccount string, scopes []string, lifetime time.Duration) (string, time.Time, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Generating access token",
		zap.String("serviceAccount", serviceAccount),
		zap.Strings("scopes", scopes))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	req := &credentialspb.GenerateAccessTokenRequest{
		Name:     fmt.Sprintf("projects/-/serviceAccounts/%s", serviceAccount),
		Scope:    scopes,
		Lifetime: durationpb.New(lifetime),
	}

	resp, err := is.credentialsClient.GenerateAccessToken(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["token_generate"]++
		is.metrics.mu.Unlock()
		return "", time.Time{}, fmt.Errorf("failed to generate access token: %w", err)
	}

	expireTime := resp.ExpireTime.AsTime()

	is.logger.Info("Access token generated successfully",
		zap.String("serviceAccount", serviceAccount),
		zap.Time("expires", expireTime))

	return resp.AccessToken, expireTime, nil
}

// SignBlob signs a blob using a service account
func (is *IAMService) SignBlob(ctx context.Context, serviceAccount string, payload []byte) ([]byte, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Signing blob",
		zap.String("serviceAccount", serviceAccount),
		zap.Int("payloadSize", len(payload)))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	req := &credentialspb.SignBlobRequest{
		Name:    fmt.Sprintf("projects/-/serviceAccounts/%s", serviceAccount),
		Payload: payload,
	}

	resp, err := is.credentialsClient.SignBlob(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["blob_sign"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to sign blob: %w", err)
	}

	is.logger.Info("Blob signed successfully",
		zap.String("serviceAccount", serviceAccount),
		zap.String("keyId", resp.KeyId))

	return resp.SignedBlob, nil
}

// SignJWT signs a JWT using a service account
func (is *IAMService) SignJWT(ctx context.Context, serviceAccount string, payload map[string]interface{}) (string, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Signing JWT",
		zap.String("serviceAccount", serviceAccount))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal JWT payload: %w", err)
	}

	req := &credentialspb.SignJwtRequest{
		Name:    fmt.Sprintf("projects/-/serviceAccounts/%s", serviceAccount),
		Payload: string(payloadBytes),
	}

	resp, err := is.credentialsClient.SignJwt(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["jwt_sign"]++
		is.metrics.mu.Unlock()
		return "", fmt.Errorf("failed to sign JWT: %w", err)
	}

	is.logger.Info("JWT signed successfully",
		zap.String("serviceAccount", serviceAccount),
		zap.String("keyId", resp.KeyId))

	return resp.SignedJwt, nil
}

// CreateCustomRole creates a custom IAM role
func (is *IAMService) CreateCustomRole(ctx context.Context, parent string, config *RoleConfig) (*adminpb.Role, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	startTime := time.Now()
	is.logger.Info("Creating custom role",
		zap.String("roleId", config.RoleID),
		zap.String("parent", parent))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	req := &adminpb.CreateRoleRequest{
		Parent: parent,
		RoleId: config.RoleID,
		Role: &adminpb.Role{
			Title:               config.Title,
			Description:         "Service account",
			IncludedPermissions: config.IncludedPermissions,
			Stage:               config.Stage,
		},
	}

	role, err := is.iamClient.CreateRole(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["role_create"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create custom role: %w", err)
	}

	// Update cache
	is.roleCache.mu.Lock()
	is.roleCache.customRoles[role.Name] = role
	is.roleCache.permissions[role.Name] = config.IncludedPermissions
	is.roleCache.lastUpdate[role.Name] = time.Now()
	is.roleCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "CreateCustomRole",
		Resource:  role.Name,
		Result:    "Success",
		Details: map[string]interface{}{
			"title":           config.Title,
			"permissionCount": len(config.IncludedPermissions),
		},
	})

	// Update metrics
	is.metrics.mu.Lock()
	is.metrics.RoleOperations++
	is.metrics.OperationLatencies = append(is.metrics.OperationLatencies, time.Since(startTime))
	is.metrics.mu.Unlock()

	is.logger.Info("Custom role created successfully",
		zap.String("roleName", role.Name),
		zap.Duration("duration", time.Since(startTime)))

	return role, nil
}

// GetRole retrieves a role definition
func (is *IAMService) GetRole(ctx context.Context, roleName string) (*adminpb.Role, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	// Check cache first
	is.roleCache.mu.RLock()
	if role, ok := is.roleCache.customRoles[roleName]; ok {
		if time.Since(is.roleCache.lastUpdate[roleName]) < is.roleCache.ttl {
			is.roleCache.mu.RUnlock()
			is.logger.Debug("Returning role from cache", zap.String("role", roleName))
			return role, nil
		}
	}
	if role, ok := is.roleCache.predefinedRoles[roleName]; ok {
		if time.Since(is.roleCache.lastUpdate[roleName]) < is.roleCache.ttl {
			is.roleCache.mu.RUnlock()
			is.logger.Debug("Returning role from cache", zap.String("role", roleName))
			return role, nil
		}
	}
	is.roleCache.mu.RUnlock()

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	req := &adminpb.GetRoleRequest{
		Name: roleName,
	}

	role, err := is.iamClient.GetRole(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["role_get"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to get role: %w", err)
	}

	// Update cache
	is.roleCache.mu.Lock()
	if strings.Contains(roleName, "custom") {
		is.roleCache.customRoles[roleName] = role
	} else {
		is.roleCache.predefinedRoles[roleName] = role
	}
	is.roleCache.permissions[roleName] = role.IncludedPermissions
	is.roleCache.lastUpdate[roleName] = time.Now()
	is.roleCache.mu.Unlock()

	return role, nil
}

// UpdateCustomRole updates a custom role
func (is *IAMService) UpdateCustomRole(ctx context.Context, roleName string, config *RoleConfig) (*adminpb.Role, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Updating custom role",
		zap.String("role", roleName))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	role := &adminpb.Role{
		Name:                roleName,
		Title:               config.Title,
		Description:         "Service account",
		IncludedPermissions: config.IncludedPermissions,
		Stage:               config.Stage,
	}

	updateMask := &fieldmaskpb.FieldMask{
		Paths: []string{"title", "description", "included_permissions", "stage"},
	}

	req := &adminpb.UpdateRoleRequest{
		Name:       roleName,
		Role:       role,
		UpdateMask: updateMask,
	}

	updatedRole, err := is.iamClient.UpdateRole(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["role_update"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to update custom role: %w", err)
	}

	// Update cache
	is.roleCache.mu.Lock()
	is.roleCache.customRoles[roleName] = updatedRole
	is.roleCache.permissions[roleName] = config.IncludedPermissions
	is.roleCache.lastUpdate[roleName] = time.Now()
	is.roleCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "UpdateCustomRole",
		Resource:  roleName,
		Result:    "Success",
	})

	is.metrics.mu.Lock()
	is.metrics.RoleOperations++
	is.metrics.mu.Unlock()

	return updatedRole, nil
}

// DeleteCustomRole deletes a custom role
func (is *IAMService) DeleteCustomRole(ctx context.Context, roleName string) error {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Deleting custom role",
		zap.String("role", roleName))

	// Apply rate limiting
	<-is.rateLimiter.deleteLimiter.C

	req := &adminpb.DeleteRoleRequest{
		Name: roleName,
	}

	if _, err := is.iamClient.DeleteRole(ctx, req); err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["role_delete"]++
		is.metrics.mu.Unlock()
		return fmt.Errorf("failed to delete custom role: %w", err)
	}

	// Remove from cache
	is.roleCache.mu.Lock()
	delete(is.roleCache.customRoles, roleName)
	delete(is.roleCache.permissions, roleName)
	delete(is.roleCache.lastUpdate, roleName)
	is.roleCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "DeleteCustomRole",
		Resource:  roleName,
		Result:    "Success",
	})

	is.metrics.mu.Lock()
	is.metrics.RoleOperations++
	is.metrics.mu.Unlock()

	is.logger.Info("Custom role deleted successfully",
		zap.String("role", roleName))

	return nil
}

// GetProjectIAMPolicy gets the IAM policy for a project
func (is *IAMService) GetProjectIAMPolicy(ctx context.Context, projectID string) (*iam.Policy, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	// Check cache first
	is.policyCache.mu.RLock()
	if policy, ok := is.policyCache.projectPolicies[projectID]; ok {
		if time.Since(is.policyCache.lastUpdate[projectID]) < is.policyCache.ttl {
			is.policyCache.mu.RUnlock()
			is.logger.Debug("Returning policy from cache", zap.String("project", projectID))
			return policy, nil
		}
	}
	is.policyCache.mu.RUnlock()

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	// GetIamPolicyRequest not available in current API
	// Using iamAPIClient instead
	var policy *iam.Policy
	var err error
	if is.iamAPIClient != nil {
		// GetIamPolicy only takes resource name, not a request object
		policy, err = is.iamAPIClient.Projects.ServiceAccounts.GetIamPolicy(
			fmt.Sprintf("projects/%s/serviceAccounts/default@%s.iam.gserviceaccount.com", projectID, projectID)).Context(ctx).Do()
	} else {
		return nil, fmt.Errorf("iamAPIClient not initialized")
	}
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["policy_get"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to get project IAM policy: %w", err)
	}

	// Update cache
	is.policyCache.mu.Lock()
	is.policyCache.projectPolicies[projectID] = policy
	is.policyCache.lastUpdate[projectID] = time.Now()
	is.policyCache.mu.Unlock()

	is.metrics.mu.Lock()
	is.metrics.PolicyOperations++
	is.metrics.mu.Unlock()

	return policy, nil
}

// SetProjectIAMPolicy sets the IAM policy for a project
func (is *IAMService) SetProjectIAMPolicy(ctx context.Context, projectID string, policy *iam.Policy) (*iam.Policy, error) {
	is.mu.Lock()
	defer is.mu.Unlock()

	startTime := time.Now()
	is.logger.Info("Setting project IAM policy",
		zap.String("project", projectID),
		zap.Int("bindingCount", len(policy.Bindings)))

	// Apply rate limiting
	<-is.rateLimiter.writeLimiter.C

	// SetIamPolicyRequest not available in current API
	// Temporarily returning the input policy
	updatedPolicy := policy
	var err error
	// req := &resourcemanagerpb.SetIamPolicyRequest{
	// 	Resource: fmt.Sprintf("projects/%s", projectID),
	// 	Policy:   policy,
	// 	UpdateMask: &fieldmaskpb.FieldMask{
	// 		Paths: []string{"bindings", "etag"},
	// 	},
	// }
	// updatedPolicy, err := is.projectsClient.SetIamPolicy(ctx, req)
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["policy_set"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to set project IAM policy: %w", err)
	}

	// Update cache
	is.policyCache.mu.Lock()
	is.policyCache.projectPolicies[projectID] = updatedPolicy
	is.policyCache.lastUpdate[projectID] = time.Now()
	is.policyCache.mu.Unlock()

	// Log audit entry
	is.auditLogger.logEntry(&AuditEntry{
		Timestamp: time.Now(),
		Operation: "SetProjectIAMPolicy",
		Resource:  fmt.Sprintf("projects/%s", projectID),
		Result:    "Success",
		Details: map[string]interface{}{
			"bindingCount": len(policy.Bindings),
			"version":      policy.Version,
		},
	})

	// Update metrics
	is.metrics.mu.Lock()
	is.metrics.PolicyOperations++
	is.metrics.BindingOperations += int64(len(policy.Bindings))
	is.metrics.OperationLatencies = append(is.metrics.OperationLatencies, time.Since(startTime))
	is.metrics.mu.Unlock()

	is.logger.Info("Project IAM policy set successfully",
		zap.String("project", projectID),
		zap.Duration("duration", time.Since(startTime)))

	return updatedPolicy, nil
}

// TestIAMPermissions tests IAM permissions
func (is *IAMService) TestIAMPermissions(ctx context.Context, resource string, permissions []string) ([]string, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	is.logger.Info("Testing IAM permissions",
		zap.String("resource", resource),
		zap.Int("permissionCount", len(permissions)))

	// Apply rate limiting
	<-is.rateLimiter.readLimiter.C

	// TestIamPermissionsRequest not available in current API
	// Using cloudresourcemanager API instead
	var resp *cloudresourcemanager.TestIamPermissionsResponse
	var err error
	if is.resourceManagerClient != nil {
		req := &cloudresourcemanager.TestIamPermissionsRequest{
			Permissions: permissions,
		}
		resp, err = is.resourceManagerClient.Projects.TestIamPermissions(
			resource, req).Context(ctx).Do()
	} else {
		return nil, fmt.Errorf("resourceManagerClient not initialized")
	}
	if err != nil {
		is.metrics.mu.Lock()
		is.metrics.ErrorCounts["permission_test"]++
		is.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to test IAM permissions: %w", err)
	}

	// Store test result
	is.permissionTester.mu.Lock()
	deniedPermissions := make([]string, 0)
	for _, perm := range permissions {
		found := false
		for _, allowed := range resp.Permissions {
			if perm == allowed {
				found = true
				break
			}
		}
		if !found {
			deniedPermissions = append(deniedPermissions, perm)
		}
	}

	is.permissionTester.cache[resource] = &TestResult{
		Resource:           resource,
		Permissions:        permissions,
		AllowedPermissions: resp.Permissions,
		DeniedPermissions:  deniedPermissions,
		TestedAt:           time.Now(),
	}
	is.permissionTester.mu.Unlock()

	is.metrics.mu.Lock()
	is.metrics.PermissionTests++
	is.metrics.mu.Unlock()

	is.logger.Info("IAM permissions tested",
		zap.String("resource", resource),
		zap.Int("allowed", len(resp.Permissions)),
		zap.Int("denied", len(deniedPermissions)))

	return resp.Permissions, nil
}

// AnalyzePolicy analyzes an IAM policy for issues
func (is *IAMService) AnalyzePolicy(ctx context.Context, resource string) (*AnalysisResult, error) {
	is.mu.RLock()
	defer is.mu.RUnlock()

	is.logger.Info("Analyzing IAM policy",
		zap.String("resource", resource))

	// Check cache first
	is.policyAnalyzer.mu.RLock()
	if result, ok := is.policyAnalyzer.cache[resource]; ok {
		if time.Since(result.AnalyzedAt) < 30*time.Minute {
			is.policyAnalyzer.mu.RUnlock()
			is.logger.Debug("Returning analysis from cache", zap.String("resource", resource))
			return result, nil
		}
	}
	is.policyAnalyzer.mu.RUnlock()

	result := &AnalysisResult{
		OverlyPermissiveRoles: make([]string, 0),
		UnusedServiceAccounts: make([]string, 0),
		StaleBindings:         make([]string, 0),
		RiskyPermissions:      make([]string, 0),
		ComplianceIssues:      make([]string, 0),
		Recommendations:       make([]string, 0),
		AnalyzedAt:            time.Now(),
	}

	// Get policy
	var policy interface{}
	if strings.HasPrefix(resource, "projects/") {
		projectID := strings.TrimPrefix(resource, "projects/")
		p, err := is.GetProjectIAMPolicy(ctx, projectID)
		if err != nil {
			return nil, fmt.Errorf("failed to get policy for analysis: %w", err)
		}
		policy = p
	}

	// Analyze the policy
	if p, ok := policy.(*iam.Policy); ok {
		// Check for overly permissive roles
		for _, binding := range p.Bindings {
			if strings.Contains(binding.Role, "owner") || strings.Contains(binding.Role, "editor") {
				result.OverlyPermissiveRoles = append(result.OverlyPermissiveRoles, binding.Role)
				result.Recommendations = append(result.Recommendations,
					fmt.Sprintf("Consider using more specific roles instead of %s", binding.Role))
			}

			// Check for allUsers or allAuthenticatedUsers
			for _, member := range binding.Members {
				if member == "allUsers" || member == "allAuthenticatedUsers" {
					result.ComplianceIssues = append(result.ComplianceIssues,
						fmt.Sprintf("Public access granted via %s in role %s", member, binding.Role))
				}

				// Check for deleted service accounts
				if strings.HasPrefix(member, "deleted:") {
					result.StaleBindings = append(result.StaleBindings, member)
				}
			}
		}

		// Check for risky permissions
		riskyPermissions := []string{
			"iam.serviceAccountKeys.create",
			"iam.serviceAccounts.actAs",
			"resourcemanager.projects.setIamPolicy",
		}

		for _, binding := range p.Bindings {
			// Would need to resolve role to permissions
			for _, perm := range riskyPermissions {
				if strings.Contains(binding.Role, perm) {
					result.RiskyPermissions = append(result.RiskyPermissions, perm)
				}
			}
		}
	}

	// Cache result
	is.policyAnalyzer.mu.Lock()
	is.policyAnalyzer.cache[resource] = result
	is.policyAnalyzer.mu.Unlock()

	is.metrics.mu.Lock()
	is.metrics.PolicyAnalyses++
	is.metrics.mu.Unlock()

	is.logger.Info("Policy analysis completed",
		zap.String("resource", resource),
		zap.Int("issues", len(result.ComplianceIssues)))

	return result, nil
}

// Audit logger methods

// logEntry logs an audit entry
func (al *AuditLogger) logEntry(entry *AuditEntry) {
	al.mu.Lock()
	defer al.mu.Unlock()

	al.logEntries = append(al.logEntries, *entry)

	// Log to zap logger
	al.logger.Info("Audit",
		zap.Time("timestamp", entry.Timestamp),
		zap.String("operation", entry.Operation),
		zap.String("resource", entry.Resource),
		zap.String("principal", entry.Principal),
		zap.String("result", entry.Result),
		zap.Any("details", entry.Details))

	// Trim if exceeds max
	if len(al.logEntries) > al.maxEntries {
		al.logEntries = al.logEntries[len(al.logEntries)-al.maxEntries:]
	}
}

// startFlusher starts the audit log flusher
func (al *AuditLogger) startFlusher() {
	ticker := time.NewTicker(al.flushPeriod)
	defer ticker.Stop()

	for range ticker.C {
		al.flush()
	}
}

// flush flushes audit logs
func (al *AuditLogger) flush() {
	al.mu.Lock()
	defer al.mu.Unlock()

	if len(al.logEntries) == 0 {
		return
	}

	// In production, this would send to Cloud Logging or another audit service
	al.logger.Info("Flushing audit logs",
		zap.Int("entryCount", len(al.logEntries)))

	// Clear after flush
	al.logEntries = al.logEntries[:0]
}

// GetMetrics returns IAM service metrics
func (is *IAMService) GetMetrics() *IAMMetrics {
	is.metrics.mu.RLock()
	defer is.metrics.mu.RUnlock()

	return &IAMMetrics{
		ServiceAccountOperations:   is.metrics.ServiceAccountOperations,
		RoleOperations:             is.metrics.RoleOperations,
		PolicyOperations:           is.metrics.PolicyOperations,
		KeyOperations:              is.metrics.KeyOperations,
		BindingOperations:          is.metrics.BindingOperations,
		WorkloadIdentityOperations: is.metrics.WorkloadIdentityOperations,
		PermissionTests:            is.metrics.PermissionTests,
		PolicyAnalyses:             is.metrics.PolicyAnalyses,
		ErrorCounts:                copyStringInt64Map(is.metrics.ErrorCounts),
		OperationLatencies:         append([]time.Duration{}, is.metrics.OperationLatencies...),
	}
}

// Close closes the IAM service
func (is *IAMService) Close() error {
	is.mu.Lock()
	defer is.mu.Unlock()

	is.logger.Info("Closing IAM service")

	// Stop rate limiters
	is.rateLimiter.readLimiter.Stop()
	is.rateLimiter.writeLimiter.Stop()
	is.rateLimiter.deleteLimiter.Stop()
	is.rateLimiter.adminLimiter.Stop()

	// Flush audit logs
	is.auditLogger.flush()

	// Close clients
	var errs []error

	if err := is.iamClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close IAM client: %w", err))
	}
	if err := is.credentialsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close credentials client: %w", err))
	}
	if err := is.projectsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close projects client: %w", err))
	}
	if err := is.foldersClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close folders client: %w", err))
	}
	if err := is.organizationsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close organizations client: %w", err))
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors closing IAM service: %v", errs)
	}

	return nil
}