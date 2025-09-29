package gcp

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
	"time"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"go.uber.org/zap"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/durationpb"
	"google.golang.org/protobuf/types/known/fieldmaskpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// SecretsService provides comprehensive secret management operations
type SecretsService struct {
	client             *secretmanager.Client
	secretCache        *SecretCache
	versionCache       *VersionCache
	accessManager      *AccessManager
	rotationManager    *RotationManager
	auditManager       *AuditManager
	encryptionManager  *EncryptionManager
	backupManager      *BackupManager
	complianceManager  *ComplianceManager
	alertManager       *SecretsAlertManager
	logger             *zap.Logger
	metrics            *SecretsMetrics
	rateLimiter        *SecretsRateLimiter
	mu                 sync.RWMutex
}

// SecretCache caches secret metadata
type SecretCache struct {
	secrets      map[string]*secretmanagerpb.Secret
	lastUpdate   map[string]time.Time
	accessCounts map[string]int64
	mu           sync.RWMutex
	ttl          time.Duration
	maxEntries   int
}

// VersionCache caches secret versions and values
type VersionCache struct {
	versions     map[string]*secretmanagerpb.SecretVersion
	values       map[string]*SecretValue
	checksums    map[string]string
	lastUpdate   map[string]time.Time
	mu           sync.RWMutex
	ttl          time.Duration
	maxEntries   int
	encryptValues bool
}

// SecretValue represents cached secret value
type SecretValue struct {
	Data          []byte
	EncryptedData []byte
	Checksum      string
	AccessTime    time.Time
	AccessCount   int64
	TTL           time.Duration
}

// AccessManager manages secret access controls
type AccessManager struct {
	client            *secretmanager.Client
	logger            *zap.Logger
	accessPolicies    map[string]*AccessPolicy
	accessLogs        []AccessLogEntry
	permissionCache   map[string]*PermissionSet
	rateLimits        map[string]*RateLimit
	mu                sync.RWMutex
}

// AccessPolicy represents secret access policy
type AccessPolicy struct {
	SecretName        string
	AllowedPrincipals []string
	DeniedPrincipals  []string
	Conditions        []*AccessCondition
	TimeRestrictions  *TimeRestriction
	LocationRestrictions []string
	RequiredMFA       bool
	MaxAccessCount    int64
	AccessTTL         time.Duration
	ApprovalRequired  bool
	ApprovalUsers     []string
}

// AccessCondition represents access condition
type AccessCondition struct {
	Type        string
	Expression  string
	Title       string
	Description string
}

// TimeRestriction represents time-based access restrictions
type TimeRestriction struct {
	AllowedHours    []int
	AllowedDays     []int
	TimeZone        string
	EmergencyAccess bool
}

// PermissionSet represents user permissions
type PermissionSet struct {
	Principal     string
	Permissions   []string
	Roles         []string
	LastValidated time.Time
	ExpiresAt     time.Time
}

// RateLimit represents access rate limiting
type RateLimit struct {
	Principal     string
	RequestCount  int64
	WindowStart   time.Time
	WindowSize    time.Duration
	MaxRequests   int64
	Violations    int64
}

// AccessLogEntry represents access log entry
type AccessLogEntry struct {
	Timestamp     time.Time
	SecretName    string
	VersionName   string
	Principal     string
	Action        string
	Result        string
	SourceIP      string
	UserAgent     string
	RequestID     string
	SessionID     string
	Details       map[string]interface{}
}

// RotationManager manages secret rotation
type RotationManager struct {
	client            *secretmanager.Client
	logger            *zap.Logger
	rotationPolicies  map[string]*RotationPolicy
	rotationHistory   map[string][]*RotationEvent
	pendingRotations  []*PendingRotation
	rotationJobs      map[string]*RotationJob
	mu                sync.RWMutex
}

// RotationPolicy represents secret rotation policy
type RotationPolicy struct {
	SecretName        string
	RotationPeriod    time.Duration
	NextRotationTime  time.Time
	RotationType      string
	RotationFunction  string
	NotificationChannels []string
	PreRotationHook   string
	PostRotationHook  string
	RollbackPolicy    *RollbackPolicy
	TestConnectivity  bool
	VerificationTimeout time.Duration
}

// RotationEvent represents rotation event
type RotationEvent struct {
	Timestamp        time.Time
	SecretName       string
	OldVersionName   string
	NewVersionName   string
	RotationType     string
	Status           string
	Duration         time.Duration
	Error            error
	TriggeredBy      string
	RotationJobID    string
}

// PendingRotation represents pending rotation
type PendingRotation struct {
	SecretName       string
	ScheduledTime    time.Time
	RotationType     string
	Priority         int
	Retry            int
	MaxRetries       int
	LastAttempt      time.Time
	Error            error
}

// RotationJob represents rotation job
type RotationJob struct {
	JobID           string
	SecretName      string
	Status          string
	StartTime       time.Time
	EndTime         time.Time
	Progress        int
	Steps           []*RotationStep
	CurrentStep     int
	Error           error
}

// RotationStep represents rotation step
type RotationStep struct {
	Name        string
	Description string
	Status      string
	StartTime   time.Time
	EndTime     time.Time
	Error       error
	Retry       int
	MaxRetries  int
}

// RollbackPolicy represents rollback policy
type RollbackPolicy struct {
	Enabled         bool
	AutoRollback    bool
	RollbackTimeout time.Duration
	HealthChecks    []string
}

// AuditManager manages audit logging
type AuditManager struct {
	logger         *zap.Logger
	auditLogs      []AuditLogEntry
	logSinks       []*LogSink
	retentionPeriod time.Duration
	encryptLogs    bool
	mu             sync.RWMutex
}

// AuditLogEntry represents audit log entry
type AuditLogEntry struct {
	Timestamp      time.Time
	EventType      string
	SecretName     string
	VersionName    string
	Principal      string
	SourceIP       string
	UserAgent      string
	RequestID      string
	SessionID      string
	Action         string
	Result         string
	ResourceBefore interface{}
	ResourceAfter  interface{}
	Changes        map[string]interface{}
	Risk           string
	Compliance     map[string]bool
	Details        map[string]interface{}
}

// LogSink represents audit log sink
type LogSink struct {
	Name        string
	Type        string
	Destination string
	Filter      string
	Enabled     bool
	Format      string
}

// EncryptionManager manages secret encryption
type EncryptionManager struct {
	kmsKeyName       string
	localKeys        map[string][]byte
	keyRotationPeriod time.Duration
	encryptionAlgorithm string
	compressionEnabled bool
	mu               sync.RWMutex
}

// BackupManager manages secret backups
type BackupManager struct {
	logger           *zap.Logger
	backupPolicies   map[string]*BackupPolicy
	backupHistory    map[string][]*BackupEvent
	backupStorage    *BackupStorage
	encryptionKey    []byte
	mu               sync.RWMutex
}

// BackupPolicy represents backup policy
type BackupPolicy struct {
	SecretName       string
	BackupFrequency  time.Duration
	RetentionPeriod  time.Duration
	BackupLocation   string
	EncryptBackups   bool
	CompressBackups  bool
	VerifyBackups    bool
	CrossRegionBackup bool
	BackupMetadata   bool
}

// BackupEvent represents backup event
type BackupEvent struct {
	Timestamp      time.Time
	SecretName     string
	BackupID       string
	BackupLocation string
	Size           int64
	Status         string
	Error          error
	Duration       time.Duration
	Checksum       string
}

// BackupStorage represents backup storage
type BackupStorage struct {
	Type           string
	Location       string
	Bucket         string
	EncryptionKey  string
	Credentials    string
}

// ComplianceManager manages compliance checks
type ComplianceManager struct {
	logger           *zap.Logger
	policies         map[string]*CompliancePolicy
	violations       []ComplianceViolation
	reports          map[string]*ComplianceReport
	mu               sync.RWMutex
}

// CompliancePolicy represents compliance policy
type CompliancePolicy struct {
	Name             string
	Framework        string
	Rules            []*ComplianceRule
	Severity         string
	AutoRemediate    bool
	NotificationChannels []string
	ReportingFrequency time.Duration
}

// ComplianceRule represents compliance rule
type ComplianceRule struct {
	ID           string
	Name         string
	Description  string
	Type         string
	Expression   string
	Severity     string
	AutoFix      bool
	FixAction    string
}

// ComplianceViolation represents compliance violation
type ComplianceViolation struct {
	Timestamp     time.Time
	SecretName    string
	PolicyName    string
	RuleID        string
	Severity      string
	Description   string
	Remediation   string
	Status        string
	FixedAt       time.Time
	FixedBy       string
}

// ComplianceReport represents compliance report
type ComplianceReport struct {
	Timestamp        time.Time
	Framework        string
	TotalSecrets     int64
	CompliantSecrets int64
	Violations       []ComplianceViolation
	Score            float64
	Recommendations  []string
}

// SecretsAlertManager manages secret-related alerts
type SecretsAlertManager struct {
	logger         *zap.Logger
	alertPolicies  map[string]*AlertPolicy
	activeAlerts   []SecretAlert
	notifications  []*NotificationChannel
	escalations    map[string]*EscalationPolicy
	mu             sync.RWMutex
}

// SecretAlert represents secret alert
type SecretAlert struct {
	AlertID      string
	SecretName   string
	AlertType    string
	Severity     string
	Timestamp    time.Time
	Description  string
	Details      map[string]interface{}
	Status       string
	Acknowledged bool
	AcknowledgedBy string
	AcknowledgedAt time.Time
	ResolvedAt   time.Time
	EscalatedAt  time.Time
}

// NotificationChannel represents notification channel
type NotificationChannel struct {
	Name    string
	Type    string
	Config  map[string]string
	Enabled bool
}

// SecretsMetrics tracks secrets service metrics
type SecretsMetrics struct {
	SecretOperations    int64
	VersionOperations   int64
	AccessOperations    int64
	RotationOperations  int64
	BackupOperations    int64
	ComplianceChecks    int64
	ErrorCounts         map[string]int64
	OperationLatencies  []time.Duration
	SecretsCount        int64
	VersionsCount       int64
	AccessCount         int64
	RotationsCount      int64
	ViolationsCount     int64
	mu                  sync.RWMutex
}

// SecretsRateLimiter implements rate limiting
type SecretsRateLimiter struct {
	readLimiter    *time.Ticker
	writeLimiter   *time.Ticker
	accessLimiter  *time.Ticker
	adminLimiter   *time.Ticker
	mu             sync.Mutex
}

// SecretConfig represents comprehensive secret configuration
type SecretConfig struct {
	SecretID         string
	Labels           map[string]string
	Annotations      map[string]string
	Replication      *ReplicationConfig
	Expiration       *ExpirationConfig
	Rotation         *RotationConfig
	VersionAliases   map[string]string
	Etag             string
	Topics           []*TopicConfig
}

// ReplicationConfig represents replication configuration
type ReplicationConfig struct {
	Automatic    bool
	UserManaged  *UserManagedReplication
}

// UserManagedReplication represents user-managed replication
type UserManagedReplication struct {
	Replicas []*ReplicaConfig
}

// ReplicaConfig represents replica configuration
type ReplicaConfig struct {
	Location                 string
	CustomerManagedEncryption *CustomerManagedEncryption
}

// CustomerManagedEncryption represents CMEK configuration
type CustomerManagedEncryption struct {
	KmsKeyName string
}

// ExpirationConfig represents expiration configuration
type ExpirationConfig struct {
	ExpireTime *time.Time
	TTL        *time.Duration
}

// RotationConfig represents rotation configuration
type RotationConfig struct {
	NextRotationTime *time.Time
	RotationPeriod   *time.Duration
}

// TopicConfig represents Pub/Sub topic configuration
type TopicConfig struct {
	Name string
}

// VersionConfig represents version configuration
type VersionConfig struct {
	SecretData    []byte
	State         string
	DestroyTime   *time.Time
	Etag          string
}

// NewSecretsService creates a new comprehensive secrets service
func NewSecretsService(ctx context.Context, projectID string, opts ...option.ClientOption) (*SecretsService, error) {
	logger := zap.L().Named("secrets")

	// Initialize secret manager client
	client, err := secretmanager.NewClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create secret manager client: %w", err)
	}

	// Initialize caches
	secretCache := &SecretCache{
		secrets:      make(map[string]*secretmanagerpb.Secret),
		lastUpdate:   make(map[string]time.Time),
		accessCounts: make(map[string]int64),
		ttl:          5 * time.Minute,
		maxEntries:   10000,
	}

	versionCache := &VersionCache{
		versions:      make(map[string]*secretmanagerpb.SecretVersion),
		values:        make(map[string]*SecretValue),
		checksums:     make(map[string]string),
		lastUpdate:    make(map[string]time.Time),
		ttl:           2 * time.Minute,
		maxEntries:    50000,
		encryptValues: true,
	}

	// Initialize managers
	accessManager := &AccessManager{
		client:          client,
		logger:          logger.Named("access"),
		accessPolicies:  make(map[string]*AccessPolicy),
		accessLogs:      make([]AccessLogEntry, 0),
		permissionCache: make(map[string]*PermissionSet),
		rateLimits:      make(map[string]*RateLimit),
	}

	rotationManager := &RotationManager{
		client:           client,
		logger:           logger.Named("rotation"),
		rotationPolicies: make(map[string]*RotationPolicy),
		rotationHistory:  make(map[string][]*RotationEvent),
		pendingRotations: make([]*PendingRotation, 0),
		rotationJobs:     make(map[string]*RotationJob),
	}

	auditManager := &AuditManager{
		logger:          logger.Named("audit"),
		auditLogs:       make([]AuditLogEntry, 0),
		logSinks:        make([]*LogSink, 0),
		retentionPeriod: 90 * 24 * time.Hour, // 90 days
		encryptLogs:     true,
	}

	encryptionManager := &EncryptionManager{
		localKeys:           make(map[string][]byte),
		keyRotationPeriod:   90 * 24 * time.Hour, // 90 days
		encryptionAlgorithm: "AES-256-GCM",
		compressionEnabled:  true,
	}

	backupManager := &BackupManager{
		logger:         logger.Named("backup"),
		backupPolicies: make(map[string]*BackupPolicy),
		backupHistory:  make(map[string][]*BackupEvent),
		encryptionKey:  make([]byte, 32),
	}

	// Generate backup encryption key
	if _, err := rand.Read(backupManager.encryptionKey); err != nil {
		return nil, fmt.Errorf("failed to generate backup encryption key: %w", err)
	}

	complianceManager := &ComplianceManager{
		logger:    logger.Named("compliance"),
		policies:  make(map[string]*CompliancePolicy),
		violations: make([]ComplianceViolation, 0),
		reports:   make(map[string]*ComplianceReport),
	}

	alertManager := &SecretsAlertManager{
		logger:        logger.Named("alerts"),
		alertPolicies: make(map[string]*AlertPolicy),
		activeAlerts:  make([]SecretAlert, 0),
		notifications: make([]*NotificationChannel, 0),
		escalations:   make(map[string]*EscalationPolicy),
	}

	// Initialize metrics
	metrics := &SecretsMetrics{
		ErrorCounts:        make(map[string]int64),
		OperationLatencies: make([]time.Duration, 0),
	}

	// Initialize rate limiter
	rateLimiter := &SecretsRateLimiter{
		readLimiter:   time.NewTicker(10 * time.Millisecond),
		writeLimiter:  time.NewTicker(50 * time.Millisecond),
		accessLimiter: time.NewTicker(5 * time.Millisecond),
		adminLimiter:  time.NewTicker(100 * time.Millisecond),
	}

	// Start background tasks
	service := &SecretsService{
		client:            client,
		secretCache:       secretCache,
		versionCache:      versionCache,
		accessManager:     accessManager,
		rotationManager:   rotationManager,
		auditManager:      auditManager,
		encryptionManager: encryptionManager,
		backupManager:     backupManager,
		complianceManager: complianceManager,
		alertManager:      alertManager,
		logger:            logger,
		metrics:           metrics,
		rateLimiter:       rateLimiter,
	}

	// Start rotation scheduler
	go service.rotationScheduler()

	// Start compliance checker
	go service.complianceChecker()

	// Start audit log processor
	go service.auditLogProcessor()

	return service, nil
}

// CreateSecret creates a new secret with comprehensive configuration
func (ss *SecretsService) CreateSecret(ctx context.Context, projectID string, config *SecretConfig) (*secretmanagerpb.Secret, error) {
	ss.mu.Lock()
	defer ss.mu.Unlock()

	startTime := time.Now()
	ss.logger.Info("Creating secret",
		zap.String("secretID", config.SecretID),
		zap.String("project", projectID))

	// Apply rate limiting
	<-ss.rateLimiter.writeLimiter.C

	secret := &secretmanagerpb.Secret{
		Labels:         config.Labels,
		Annotations:    config.Annotations,
		VersionAliases: config.VersionAliases,
		Etag:           config.Etag,
	}

	// Configure replication
	if config.Replication != nil {
		if config.Replication.Automatic {
			secret.Replication = &secretmanagerpb.Replication{
				Replication: &secretmanagerpb.Replication_Automatic_{
					Automatic: &secretmanagerpb.Replication_Automatic{
						CustomerManagedEncryption: nil, // Can be set if needed
					},
				},
			}
		} else if config.Replication.UserManaged != nil {
			replicas := make([]*secretmanagerpb.Replication_UserManaged_Replica, len(config.Replication.UserManaged.Replicas))
			for i, replica := range config.Replication.UserManaged.Replicas {
				replicas[i] = &secretmanagerpb.Replication_UserManaged_Replica{
					Location: replica.Location,
				}
				if replica.CustomerManagedEncryption != nil {
					replicas[i].CustomerManagedEncryption = &secretmanagerpb.CustomerManagedEncryption{
						KmsKeyName: replica.CustomerManagedEncryption.KmsKeyName,
					}
				}
			}

			secret.Replication = &secretmanagerpb.Replication{
				Replication: &secretmanagerpb.Replication_UserManaged_{
					UserManaged: &secretmanagerpb.Replication_UserManaged{
						Replicas: replicas,
					},
				},
			}
		}
	}

	// Configure expiration
	if config.Expiration != nil {
		if config.Expiration.ExpireTime != nil {
			secret.Expiration = &secretmanagerpb.Secret_ExpireTime{
				ExpireTime: timestamppb.New(*config.Expiration.ExpireTime),
			}
		} else if config.Expiration.TTL != nil {
			secret.Expiration = &secretmanagerpb.Secret_Ttl{
				Ttl: durationpb.New(*config.Expiration.TTL),
			}
		}
	}

	// Configure rotation
	if config.Rotation != nil {
		secret.Rotation = &secretmanagerpb.Rotation{}
		if config.Rotation.NextRotationTime != nil {
			secret.Rotation.NextRotationTime = timestamppb.New(*config.Rotation.NextRotationTime)
		}
		if config.Rotation.RotationPeriod != nil {
			secret.Rotation.RotationPeriod = durationpb.New(*config.Rotation.RotationPeriod)
		}
	}

	// Configure topics
	if len(config.Topics) > 0 {
		topics := make([]*secretmanagerpb.Topic, len(config.Topics))
		for i, topic := range config.Topics {
			topics[i] = &secretmanagerpb.Topic{
				Name: topic.Name,
			}
		}
		secret.Topics = topics
	}

	req := &secretmanagerpb.CreateSecretRequest{
		Parent:   fmt.Sprintf("projects/%s", projectID),
		SecretId: config.SecretID,
		Secret:   secret,
	}

	createdSecret, err := ss.client.CreateSecret(ctx, req)
	if err != nil {
		ss.metrics.mu.Lock()
		ss.metrics.ErrorCounts["secret_create"]++
		ss.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create secret: %w", err)
	}

	// Update cache
	ss.secretCache.mu.Lock()
	ss.secretCache.secrets[createdSecret.Name] = createdSecret
	ss.secretCache.lastUpdate[createdSecret.Name] = time.Now()
	ss.secretCache.accessCounts[createdSecret.Name] = 0
	ss.secretCache.mu.Unlock()

	// Log audit entry
	ss.auditManager.mu.Lock()
	ss.auditManager.auditLogs = append(ss.auditManager.auditLogs, AuditLogEntry{
		Timestamp:  time.Now(),
		EventType:  "SECRET_CREATE",
		SecretName: createdSecret.Name,
		Action:     "CREATE",
		Result:     "SUCCESS",
		Details: map[string]interface{}{
			"labels":      config.Labels,
			"replication": config.Replication != nil,
			"rotation":    config.Rotation != nil,
		},
	})
	ss.auditManager.mu.Unlock()

	// Update metrics
	ss.metrics.mu.Lock()
	ss.metrics.SecretOperations++
	ss.metrics.SecretsCount++
	ss.metrics.OperationLatencies = append(ss.metrics.OperationLatencies, time.Since(startTime))
	ss.metrics.mu.Unlock()

	ss.logger.Info("Secret created successfully",
		zap.String("name", createdSecret.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdSecret, nil
}

// AddSecretVersion adds a new version to an existing secret
func (ss *SecretsService) AddSecretVersion(ctx context.Context, secretName string, config *VersionConfig) (*secretmanagerpb.SecretVersion, error) {
	ss.mu.Lock()
	defer ss.mu.Unlock()

	startTime := time.Now()
	ss.logger.Info("Adding secret version",
		zap.String("secretName", secretName))

	// Apply rate limiting
	<-ss.rateLimiter.writeLimiter.C

	// Validate secret exists
	if err := ss.validateSecretExists(ctx, secretName); err != nil {
		return nil, fmt.Errorf("secret validation failed: %w", err)
	}

	// Check compliance before adding version
	if violation := ss.checkSecretCompliance(secretName, config.SecretData); violation != nil {
		ss.complianceManager.mu.Lock()
		ss.complianceManager.violations = append(ss.complianceManager.violations, *violation)
		ss.complianceManager.mu.Unlock()
		return nil, fmt.Errorf("compliance violation: %s", violation.Description)
	}

	// Encrypt secret data if configured
	secretData := config.SecretData
	if ss.encryptionManager.kmsKeyName != "" {
		encryptedData, err := ss.encryptSecretData(secretData)
		if err != nil {
			return nil, fmt.Errorf("failed to encrypt secret data: %w", err)
		}
		secretData = encryptedData
	}

	// Calculate checksum
	checksum := ss.calculateChecksum(secretData)

	payload := &secretmanagerpb.SecretPayload{
		Data:        secretData,
		DataCrc32C:  ss.calculateCRC32C(secretData),
	}

	req := &secretmanagerpb.AddSecretVersionRequest{
		Parent:  secretName,
		Payload: payload,
	}

	createdVersion, err := ss.client.AddSecretVersion(ctx, req)
	if err != nil {
		ss.metrics.mu.Lock()
		ss.metrics.ErrorCounts["version_add"]++
		ss.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to add secret version: %w", err)
	}

	// Update version cache
	ss.versionCache.mu.Lock()
	ss.versionCache.versions[createdVersion.Name] = createdVersion
	ss.versionCache.checksums[createdVersion.Name] = checksum
	ss.versionCache.lastUpdate[createdVersion.Name] = time.Now()

	// Cache the decrypted value
	ss.versionCache.values[createdVersion.Name] = &SecretValue{
		Data:        config.SecretData,
		EncryptedData: secretData,
		Checksum:    checksum,
		AccessTime:  time.Now(),
		AccessCount: 0,
		TTL:         ss.versionCache.ttl,
	}
	ss.versionCache.mu.Unlock()

	// Log audit entry
	ss.auditManager.mu.Lock()
	ss.auditManager.auditLogs = append(ss.auditManager.auditLogs, AuditLogEntry{
		Timestamp:   time.Now(),
		EventType:   "SECRET_VERSION_ADD",
		SecretName:  secretName,
		VersionName: createdVersion.Name,
		Action:      "ADD_VERSION",
		Result:      "SUCCESS",
		Details: map[string]interface{}{
			"checksum": checksum,
			"size":     len(config.SecretData),
		},
	})
	ss.auditManager.mu.Unlock()

	// Update metrics
	ss.metrics.mu.Lock()
	ss.metrics.VersionOperations++
	ss.metrics.VersionsCount++
	ss.metrics.OperationLatencies = append(ss.metrics.OperationLatencies, time.Since(startTime))
	ss.metrics.mu.Unlock()

	// Trigger backup if policy exists
	ss.triggerBackupIfNeeded(secretName)

	ss.logger.Info("Secret version added successfully",
		zap.String("versionName", createdVersion.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdVersion, nil
}

// AccessSecretVersion accesses a secret version with comprehensive controls
func (ss *SecretsService) AccessSecretVersion(ctx context.Context, versionName string, principal string) (*secretmanagerpb.AccessSecretVersionResponse, error) {
	ss.mu.RLock()
	defer ss.mu.RUnlock()

	startTime := time.Now()
	ss.logger.Info("Accessing secret version",
		zap.String("versionName", versionName),
		zap.String("principal", principal))

	// Apply rate limiting
	<-ss.rateLimiter.accessLimiter.C

	// Check access permissions
	if err := ss.checkAccessPermissions(ctx, versionName, principal); err != nil {
		ss.metrics.mu.Lock()
		ss.metrics.ErrorCounts["access_denied"]++
		ss.metrics.mu.Unlock()
		return nil, fmt.Errorf("access denied: %w", err)
	}

	// Check cache first
	ss.versionCache.mu.RLock()
	if cachedValue, ok := ss.versionCache.values[versionName]; ok {
		if time.Since(cachedValue.AccessTime) < cachedValue.TTL {
			ss.versionCache.mu.RUnlock()

			// Update cache access stats
			ss.versionCache.mu.Lock()
			cachedValue.AccessTime = time.Now()
			cachedValue.AccessCount++
			ss.versionCache.mu.Unlock()

			// Log access
			ss.logSecretAccess(versionName, principal, "CACHE_HIT", nil)

			response := &secretmanagerpb.AccessSecretVersionResponse{
				Name: versionName,
				Payload: &secretmanagerpb.SecretPayload{
					Data:       cachedValue.Data,
					DataCrc32C: ss.calculateCRC32C(cachedValue.Data),
				},
			}

			ss.logger.Debug("Returning secret from cache")
			return response, nil
		}
	}
	ss.versionCache.mu.RUnlock()

	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: versionName,
	}

	response, err := ss.client.AccessSecretVersion(ctx, req)
	if err != nil {
		ss.metrics.mu.Lock()
		ss.metrics.ErrorCounts["access_error"]++
		ss.metrics.mu.Unlock()

		// Log failed access
		ss.logSecretAccess(versionName, principal, "ERROR", err)
		return nil, fmt.Errorf("failed to access secret version: %w", err)
	}

	// Decrypt data if encrypted
	secretData := response.Payload.Data
	if ss.encryptionManager.kmsKeyName != "" {
		decryptedData, err := ss.decryptSecretData(secretData)
		if err != nil {
			return nil, fmt.Errorf("failed to decrypt secret data: %w", err)
		}
		response.Payload.Data = decryptedData
		response.Payload.DataCrc32C = ss.calculateCRC32C(decryptedData)
	}

	// Update cache
	checksum := ss.calculateChecksum(response.Payload.Data)
	ss.versionCache.mu.Lock()
	ss.versionCache.values[versionName] = &SecretValue{
		Data:          response.Payload.Data,
		EncryptedData: secretData,
		Checksum:      checksum,
		AccessTime:    time.Now(),
		AccessCount:   1,
		TTL:           ss.versionCache.ttl,
	}
	ss.versionCache.checksums[versionName] = checksum
	ss.versionCache.lastUpdate[versionName] = time.Now()
	ss.versionCache.mu.Unlock()

	// Log successful access
	ss.logSecretAccess(versionName, principal, "SUCCESS", nil)

	// Update metrics
	ss.metrics.mu.Lock()
	ss.metrics.AccessOperations++
	ss.metrics.AccessCount++
	ss.metrics.OperationLatencies = append(ss.metrics.OperationLatencies, time.Since(startTime))
	ss.metrics.mu.Unlock()

	ss.logger.Info("Secret version accessed successfully",
		zap.String("versionName", versionName),
		zap.Duration("duration", time.Since(startTime)))

	return response, nil
}

// RotateSecret rotates a secret according to its rotation policy
func (ss *SecretsService) RotateSecret(ctx context.Context, secretName string, newSecretData []byte) error {
	ss.mu.Lock()
	defer ss.mu.Unlock()

	startTime := time.Now()
	ss.logger.Info("Rotating secret",
		zap.String("secretName", secretName))

	// Get rotation policy
	ss.rotationManager.mu.RLock()
	policy, exists := ss.rotationManager.rotationPolicies[secretName]
	ss.rotationManager.mu.RUnlock()

	if !exists {
		return fmt.Errorf("no rotation policy found for secret: %s", secretName)
	}

	// Create rotation job
	jobID := fmt.Sprintf("rotation-%s-%d", secretName, time.Now().Unix())
	job := &RotationJob{
		JobID:      jobID,
		SecretName: secretName,
		Status:     "RUNNING",
		StartTime:  time.Now(),
		Steps: []*RotationStep{
			{Name: "validate", Description: "Validate rotation requirements"},
			{Name: "backup", Description: "Backup current version"},
			{Name: "test", Description: "Test new secret data"},
			{Name: "rotate", Description: "Add new secret version"},
			{Name: "verify", Description: "Verify rotation success"},
		},
		CurrentStep: 0,
	}

	ss.rotationManager.mu.Lock()
	ss.rotationManager.rotationJobs[jobID] = job
	ss.rotationManager.mu.Unlock()

	var rotationError error
	var oldVersionName string
	var newVersionName string

	// Execute rotation steps
	for i, step := range job.Steps {
		step.Status = "RUNNING"
		step.StartTime = time.Now()
		job.CurrentStep = i

		switch step.Name {
		case "validate":
			// Validate rotation requirements
			if err := ss.validateRotationRequirements(secretName, newSecretData); err != nil {
				rotationError = err
				step.Status = "FAILED"
				step.Error = err
				break
			}

		case "backup":
			// Backup current version
			if err := ss.backupCurrentVersion(ctx, secretName); err != nil {
				rotationError = err
				step.Status = "FAILED"
				step.Error = err
				break
			}

		case "test":
			// Test connectivity with new secret
			if policy.TestConnectivity {
				if err := ss.testSecretConnectivity(newSecretData); err != nil {
					rotationError = err
					step.Status = "FAILED"
					step.Error = err
					break
				}
			}

		case "rotate":
			// Add new version
			config := &VersionConfig{
				SecretData: newSecretData,
				State:      "ENABLED",
			}

			newVersion, err := ss.AddSecretVersion(ctx, secretName, config)
			if err != nil {
				rotationError = err
				step.Status = "FAILED"
				step.Error = err
				break
			}
			newVersionName = newVersion.Name

		case "verify":
			// Verify rotation success
			if err := ss.verifyRotation(ctx, secretName, newVersionName); err != nil {
				rotationError = err
				step.Status = "FAILED"
				step.Error = err
				break
			}
		}

		step.EndTime = time.Now()
		if rotationError != nil {
			step.Status = "FAILED"
			break
		}
		step.Status = "COMPLETED"
	}

	// Update job status
	job.EndTime = time.Now()
	if rotationError != nil {
		job.Status = "FAILED"
		job.Error = rotationError

		// Trigger rollback if configured
		if policy.RollbackPolicy != nil && policy.RollbackPolicy.Enabled {
			ss.rollbackRotation(ctx, secretName, oldVersionName)
		}
	} else {
		job.Status = "COMPLETED"
	}

	// Record rotation event
	event := &RotationEvent{
		Timestamp:      time.Now(),
		SecretName:     secretName,
		OldVersionName: oldVersionName,
		NewVersionName: newVersionName,
		RotationType:   policy.RotationType,
		Status:         job.Status,
		Duration:       time.Since(startTime),
		Error:          rotationError,
		RotationJobID:  jobID,
	}

	ss.rotationManager.mu.Lock()
	if ss.rotationManager.rotationHistory[secretName] == nil {
		ss.rotationManager.rotationHistory[secretName] = make([]*RotationEvent, 0)
	}
	ss.rotationManager.rotationHistory[secretName] = append(ss.rotationManager.rotationHistory[secretName], event)

	// Update next rotation time
	if rotationError == nil && policy.RotationPeriod > 0 {
		policy.NextRotationTime = time.Now().Add(policy.RotationPeriod)
	}
	ss.rotationManager.mu.Unlock()

	// Log audit entry
	ss.auditManager.mu.Lock()
	ss.auditManager.auditLogs = append(ss.auditManager.auditLogs, AuditLogEntry{
		Timestamp:   time.Now(),
		EventType:   "SECRET_ROTATION",
		SecretName:  secretName,
		VersionName: newVersionName,
		Action:      "ROTATE",
		Result:      job.Status,
		Details: map[string]interface{}{
			"jobID":           jobID,
			"rotationType":    policy.RotationType,
			"duration":        time.Since(startTime).String(),
			"stepsCompleted":  job.CurrentStep + 1,
		},
	})
	ss.auditManager.mu.Unlock()

	// Update metrics
	ss.metrics.mu.Lock()
	ss.metrics.RotationOperations++
	if rotationError == nil {
		ss.metrics.RotationsCount++
	} else {
		ss.metrics.ErrorCounts["rotation_failed"]++
	}
	ss.metrics.OperationLatencies = append(ss.metrics.OperationLatencies, time.Since(startTime))
	ss.metrics.mu.Unlock()

	if rotationError != nil {
		ss.logger.Error("Secret rotation failed",
			zap.String("secretName", secretName),
			zap.String("jobID", jobID),
			zap.Error(rotationError))
		return rotationError
	}

	ss.logger.Info("Secret rotation completed successfully",
		zap.String("secretName", secretName),
		zap.String("jobID", jobID),
		zap.Duration("duration", time.Since(startTime)))

	return nil
}

// Helper methods

// validateSecretExists validates that a secret exists
func (ss *SecretsService) validateSecretExists(ctx context.Context, secretName string) error {
	req := &secretmanagerpb.GetSecretRequest{
		Name: secretName,
	}

	_, err := ss.client.GetSecret(ctx, req)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return fmt.Errorf("secret not found: %s", secretName)
		}
		return err
	}
	return nil
}

// checkSecretCompliance checks secret compliance
func (ss *SecretsService) checkSecretCompliance(secretName string, data []byte) *ComplianceViolation {
	// Check for common violations
	dataStr := string(data)

	// Check for passwords
	if strings.Contains(strings.ToLower(dataStr), "password") {
		return &ComplianceViolation{
			Timestamp:   time.Now(),
			SecretName:  secretName,
			Severity:    "HIGH",
			Description: "Secret contains plaintext password",
			Remediation: "Use hashed passwords or secure credential storage",
			Status:      "ACTIVE",
		}
	}

	// Check for API keys pattern
	if len(data) < 32 {
		return &ComplianceViolation{
			Timestamp:   time.Now(),
			SecretName:  secretName,
			Severity:    "MEDIUM",
			Description: "Secret data appears to be too short for secure key",
			Remediation: "Use minimum 32 characters for secure keys",
			Status:      "ACTIVE",
		}
	}

	return nil
}

// encryptSecretData encrypts secret data
func (ss *SecretsService) encryptSecretData(data []byte) ([]byte, error) {
	// Placeholder for encryption logic
	// In real implementation, this would use KMS or local encryption
	return data, nil
}

// decryptSecretData decrypts secret data
func (ss *SecretsService) decryptSecretData(encryptedData []byte) ([]byte, error) {
	// Placeholder for decryption logic
	// In real implementation, this would use KMS or local decryption
	return encryptedData, nil
}

// calculateChecksum calculates SHA256 checksum
func (ss *SecretsService) calculateChecksum(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

// calculateCRC32C calculates CRC32C checksum
func (ss *SecretsService) calculateCRC32C(data []byte) *int64 {
	// Placeholder for CRC32C calculation
	crc := int64(len(data)) // Simplified
	return &crc
}

// checkAccessPermissions checks access permissions
func (ss *SecretsService) checkAccessPermissions(ctx context.Context, versionName string, principal string) error {
	// Extract secret name from version name
	parts := strings.Split(versionName, "/versions/")
	if len(parts) != 2 {
		return fmt.Errorf("invalid version name format")
	}
	secretName := parts[0]

	// Check access policy
	ss.accessManager.mu.RLock()
	policy, exists := ss.accessManager.accessPolicies[secretName]
	ss.accessManager.mu.RUnlock()

	if !exists {
		// Default allow if no policy
		return nil
	}

	// Check denied principals
	for _, denied := range policy.DeniedPrincipals {
		if denied == principal {
			return fmt.Errorf("principal explicitly denied")
		}
	}

	// Check allowed principals
	allowed := false
	for _, allowedPrincipal := range policy.AllowedPrincipals {
		if allowedPrincipal == principal || allowedPrincipal == "*" {
			allowed = true
			break
		}
	}

	if !allowed {
		return fmt.Errorf("principal not in allowed list")
	}

	// Check time restrictions
	if policy.TimeRestrictions != nil {
		now := time.Now()
		if !ss.isTimeAllowed(now, policy.TimeRestrictions) {
			return fmt.Errorf("access not allowed at current time")
		}
	}

	// Check rate limits
	if err := ss.checkRateLimit(principal, secretName); err != nil {
		return err
	}

	return nil
}

// isTimeAllowed checks if current time is allowed
func (ss *SecretsService) isTimeAllowed(now time.Time, restrictions *TimeRestriction) bool {
	// Check allowed hours
	hour := now.Hour()
	hourAllowed := len(restrictions.AllowedHours) == 0
	for _, allowedHour := range restrictions.AllowedHours {
		if hour == allowedHour {
			hourAllowed = true
			break
		}
	}

	// Check allowed days
	weekday := int(now.Weekday())
	dayAllowed := len(restrictions.AllowedDays) == 0
	for _, allowedDay := range restrictions.AllowedDays {
		if weekday == allowedDay {
			dayAllowed = true
			break
		}
	}

	return hourAllowed && dayAllowed
}

// checkRateLimit checks rate limiting
func (ss *SecretsService) checkRateLimit(principal string, secretName string) error {
	key := fmt.Sprintf("%s:%s", principal, secretName)

	ss.accessManager.mu.Lock()
	defer ss.accessManager.mu.Unlock()

	rateLimit, exists := ss.accessManager.rateLimits[key]
	if !exists {
		// Create new rate limit
		rateLimit = &RateLimit{
			Principal:    principal,
			RequestCount: 1,
			WindowStart:  time.Now(),
			WindowSize:   time.Hour,
			MaxRequests:  100,
			Violations:   0,
		}
		ss.accessManager.rateLimits[key] = rateLimit
		return nil
	}

	// Check if window has expired
	if time.Since(rateLimit.WindowStart) > rateLimit.WindowSize {
		rateLimit.RequestCount = 1
		rateLimit.WindowStart = time.Now()
		return nil
	}

	// Check rate limit
	rateLimit.RequestCount++
	if rateLimit.RequestCount > rateLimit.MaxRequests {
		rateLimit.Violations++
		return fmt.Errorf("rate limit exceeded: %d requests in %s",
			rateLimit.RequestCount, rateLimit.WindowSize)
	}

	return nil
}

// logSecretAccess logs secret access
func (ss *SecretsService) logSecretAccess(versionName string, principal string, result string, err error) {
	entry := AccessLogEntry{
		Timestamp:   time.Now(),
		VersionName: versionName,
		Principal:   principal,
		Action:      "ACCESS",
		Result:      result,
	}

	if err != nil {
		entry.Details = map[string]interface{}{
			"error": err.Error(),
		}
	}

	ss.accessManager.mu.Lock()
	ss.accessManager.accessLogs = append(ss.accessManager.accessLogs, entry)

	// Keep only recent logs
	if len(ss.accessManager.accessLogs) > 100000 {
		ss.accessManager.accessLogs = ss.accessManager.accessLogs[len(ss.accessManager.accessLogs)-100000:]
	}
	ss.accessManager.mu.Unlock()
}

// triggerBackupIfNeeded triggers backup if policy exists
func (ss *SecretsService) triggerBackupIfNeeded(secretName string) {
	ss.backupManager.mu.RLock()
	policy, exists := ss.backupManager.backupPolicies[secretName]
	ss.backupManager.mu.RUnlock()

	if exists {
		go ss.performBackup(secretName, policy)
	}
}

// performBackup performs secret backup
func (ss *SecretsService) performBackup(secretName string, policy *BackupPolicy) {
	startTime := time.Now()
	backupID := fmt.Sprintf("backup-%s-%d", secretName, time.Now().Unix())

	event := &BackupEvent{
		Timestamp:      startTime,
		SecretName:     secretName,
		BackupID:       backupID,
		BackupLocation: policy.BackupLocation,
		Status:         "IN_PROGRESS",
	}

	// Placeholder for actual backup implementation
	// This would backup secret metadata and versions

	event.Status = "COMPLETED"
	event.Duration = time.Since(startTime)
	event.Size = 1024 // Placeholder

	ss.backupManager.mu.Lock()
	if ss.backupManager.backupHistory[secretName] == nil {
		ss.backupManager.backupHistory[secretName] = make([]*BackupEvent, 0)
	}
	ss.backupManager.backupHistory[secretName] = append(ss.backupManager.backupHistory[secretName], event)
	ss.backupManager.mu.Unlock()

	ss.metrics.mu.Lock()
	ss.metrics.BackupOperations++
	ss.metrics.mu.Unlock()
}

// Background tasks

// rotationScheduler runs rotation scheduler
func (ss *SecretsService) rotationScheduler() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		ss.checkPendingRotations()
	}
}

// checkPendingRotations checks for pending rotations
func (ss *SecretsService) checkPendingRotations() {
	now := time.Now()

	ss.rotationManager.mu.Lock()
	for secretName, policy := range ss.rotationManager.rotationPolicies {
		if now.After(policy.NextRotationTime) {
			pendingRotation := &PendingRotation{
				SecretName:    secretName,
				ScheduledTime: policy.NextRotationTime,
				RotationType:  policy.RotationType,
				Priority:      1,
				MaxRetries:    3,
			}
			ss.rotationManager.pendingRotations = append(ss.rotationManager.pendingRotations, pendingRotation)
		}
	}
	ss.rotationManager.mu.Unlock()
}

// complianceChecker runs compliance checks
func (ss *SecretsService) complianceChecker() {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		ss.performComplianceCheck()
	}
}

// performComplianceCheck performs compliance check
func (ss *SecretsService) performComplianceCheck() {
	ss.metrics.mu.Lock()
	ss.metrics.ComplianceChecks++
	ss.metrics.mu.Unlock()

	// Placeholder for compliance check implementation
}

// auditLogProcessor processes audit logs
func (ss *SecretsService) auditLogProcessor() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		ss.processAuditLogs()
	}
}

// processAuditLogs processes and flushes audit logs
func (ss *SecretsService) processAuditLogs() {
	ss.auditManager.mu.Lock()
	if len(ss.auditManager.auditLogs) == 0 {
		ss.auditManager.mu.Unlock()
		return
	}

	// Process logs (send to sinks, etc.)
	logsToProcess := make([]AuditLogEntry, len(ss.auditManager.auditLogs))
	copy(logsToProcess, ss.auditManager.auditLogs)

	// Clear processed logs
	ss.auditManager.auditLogs = ss.auditManager.auditLogs[:0]
	ss.auditManager.mu.Unlock()

	// Send to log sinks
	for _, sink := range ss.auditManager.logSinks {
		if sink.Enabled {
			go ss.sendToLogSink(logsToProcess, sink)
		}
	}
}

// sendToLogSink sends logs to sink
func (ss *SecretsService) sendToLogSink(logs []AuditLogEntry, sink *LogSink) {
	// Placeholder for sending logs to various sinks
	ss.logger.Debug("Sending audit logs to sink",
		zap.String("sink", sink.Name),
		zap.Int("logCount", len(logs)))
}

// Placeholder helper methods for rotation

func (ss *SecretsService) validateRotationRequirements(secretName string, newSecretData []byte) error {
	// Placeholder for validation logic
	return nil
}

func (ss *SecretsService) backupCurrentVersion(ctx context.Context, secretName string) error {
	// Placeholder for backup logic
	return nil
}

func (ss *SecretsService) testSecretConnectivity(newSecretData []byte) error {
	// Placeholder for connectivity test
	return nil
}

func (ss *SecretsService) verifyRotation(ctx context.Context, secretName string, newVersionName string) error {
	// Placeholder for rotation verification
	return nil
}

func (ss *SecretsService) rollbackRotation(ctx context.Context, secretName string, oldVersionName string) error {
	// Placeholder for rollback logic
	return nil
}

// GetMetrics returns secrets service metrics
func (ss *SecretsService) GetMetrics() *SecretsMetrics {
	ss.metrics.mu.RLock()
	defer ss.metrics.mu.RUnlock()

	return &SecretsMetrics{
		SecretOperations:    ss.metrics.SecretOperations,
		VersionOperations:   ss.metrics.VersionOperations,
		AccessOperations:    ss.metrics.AccessOperations,
		RotationOperations:  ss.metrics.RotationOperations,
		BackupOperations:    ss.metrics.BackupOperations,
		ComplianceChecks:    ss.metrics.ComplianceChecks,
		ErrorCounts:         copyStringInt64Map(ss.metrics.ErrorCounts),
		OperationLatencies:  append([]time.Duration{}, ss.metrics.OperationLatencies...),
		SecretsCount:        ss.metrics.SecretsCount,
		VersionsCount:       ss.metrics.VersionsCount,
		AccessCount:         ss.metrics.AccessCount,
		RotationsCount:      ss.metrics.RotationsCount,
		ViolationsCount:     ss.metrics.ViolationsCount,
	}
}

// Close closes the secrets service
func (ss *SecretsService) Close() error {
	ss.mu.Lock()
	defer ss.mu.Unlock()

	ss.logger.Info("Closing secrets service")

	// Stop rate limiters
	ss.rateLimiter.readLimiter.Stop()
	ss.rateLimiter.writeLimiter.Stop()
	ss.rateLimiter.accessLimiter.Stop()
	ss.rateLimiter.adminLimiter.Stop()

	// Close client
	return ss.client.Close()
}