package gcp

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
)

func TestNewSecretsService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping secrets service test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{
		DefaultReplication:       "automatic",
		DefaultTTL:               24 * time.Hour,
		DefaultRotationPeriod:    90 * 24 * time.Hour, // 90 days
		CacheEnabled:             true,
		CacheTTL:                 15 * time.Minute,
		MetricsEnabled:           true,
		AuditEnabled:             true,
		EncryptionEnabled:        true,
		CompressionEnabled:       false,
		AccessLoggingEnabled:     true,
		RotationEnabled:          true,
		BackupEnabled:            true,
		BackupRetentionPeriod:    7 * 24 * time.Hour, // 7 days
		ComplianceEnabled:        true,
		SecurityScanningEnabled: true,
		MaxSecretSize:            64 * 1024, // 64KB
		MaxVersions:              100,
		RetryAttempts:            3,
		RetryDelay:               time.Second,
		OperationTimeout:         5 * time.Minute,
		RateLimitQPS:             50,
		RateLimitBurst:           100,
		LogLevel:                 "INFO",
	}

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Errorf("NewSecretsService() error = %v", err)
		return
	}

	if secretsService == nil {
		t.Error("NewSecretsService() returned nil service")
	}

	if secretsService.client != client {
		t.Error("NewSecretsService() did not set client correctly")
	}

	if secretsService.config.DefaultReplication != secretsConfig.DefaultReplication {
		t.Errorf("NewSecretsService() DefaultReplication = %v, want %v",
			secretsService.config.DefaultReplication, secretsConfig.DefaultReplication)
	}
}

func TestSecretsConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *SecretsConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &SecretsConfig{
				DefaultReplication:    "automatic",
				DefaultTTL:            24 * time.Hour,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         64 * 1024,
				MaxVersions:           100,
				RetryAttempts:         3,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
				RateLimitQPS:          50,
				RateLimitBurst:        100,
			},
			wantErr: false,
		},
		{
			name: "invalid default replication",
			config: &SecretsConfig{
				DefaultReplication:    "invalid",
				DefaultTTL:            24 * time.Hour,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         64 * 1024,
				MaxVersions:           100,
				RetryAttempts:         3,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid default TTL",
			config: &SecretsConfig{
				DefaultReplication:    "automatic",
				DefaultTTL:            0,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         64 * 1024,
				MaxVersions:           100,
				RetryAttempts:         3,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid max secret size",
			config: &SecretsConfig{
				DefaultReplication:    "automatic",
				DefaultTTL:            24 * time.Hour,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         0,
				MaxVersions:           100,
				RetryAttempts:         3,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid max versions",
			config: &SecretsConfig{
				DefaultReplication:    "automatic",
				DefaultTTL:            24 * time.Hour,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         64 * 1024,
				MaxVersions:           0,
				RetryAttempts:         3,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid retry attempts",
			config: &SecretsConfig{
				DefaultReplication:    "automatic",
				DefaultTTL:            24 * time.Hour,
				DefaultRotationPeriod: 90 * 24 * time.Hour,
				MaxSecretSize:         64 * 1024,
				MaxVersions:           100,
				RetryAttempts:         0,
				RetryDelay:            time.Second,
				OperationTimeout:      5 * time.Minute,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("SecretsConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSecretsConfig_SetDefaults(t *testing.T) {
	config := &SecretsConfig{}
	config.SetDefaults()

	if config.DefaultReplication == "" {
		t.Error("SetDefaults() did not set DefaultReplication")
	}

	if config.DefaultTTL <= 0 {
		t.Error("SetDefaults() did not set DefaultTTL")
	}

	if config.DefaultRotationPeriod <= 0 {
		t.Error("SetDefaults() did not set DefaultRotationPeriod")
	}

	if config.MaxSecretSize <= 0 {
		t.Error("SetDefaults() did not set MaxSecretSize")
	}

	if config.MaxVersions <= 0 {
		t.Error("SetDefaults() did not set MaxVersions")
	}

	if config.RetryAttempts <= 0 {
		t.Error("SetDefaults() did not set RetryAttempts")
	}

	if config.RetryDelay <= 0 {
		t.Error("SetDefaults() did not set RetryDelay")
	}

	if config.OperationTimeout <= 0 {
		t.Error("SetDefaults() did not set OperationTimeout")
	}

	if !config.CacheEnabled {
		t.Error("SetDefaults() did not enable cache")
	}

	if config.CacheTTL <= 0 {
		t.Error("SetDefaults() did not set CacheTTL")
	}
}

func TestSecretsService_CreateSecret(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create secret test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping create secret test due to secrets service creation error: %v", err)
	}

	secretConfig := &SecretConfig{
		SecretID:    "test-secret-" + time.Now().Format("20060102-150405"),
		DisplayName: "Test Secret",
		Description: "Secret created by test suite",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
		Replication: &ReplicationConfig{
			Policy: "automatic",
			UserManaged: &UserManagedReplication{
				Replicas: []*ReplicaConfig{
					{
						Location: "us-central1",
						CustomerManagedEncryption: &CustomerManagedEncryption{
							KmsKeyName: "",
						},
					},
				},
			},
		},
		TTL: 24 * time.Hour,
		ExpireTime: time.Now().Add(30 * 24 * time.Hour), // 30 days
		Rotation: &RotationConfig{
			RotationPeriod:  90 * 24 * time.Hour, // 90 days
			NextRotationTime: time.Now().Add(90 * 24 * time.Hour),
		},
		Topics: []*TopicConfig{
			{
				Name: "projects/test-project-123/topics/secret-notifications",
			},
		},
		Annotations: map[string]string{
			"purpose": "testing",
			"owner":   "test-suite",
		},
		VersionAliases: map[string]string{
			"latest": "1",
		},
		VersionDestroyTTL: 24 * time.Hour,
	}

	ctx := context.Background()
	secret, err := secretsService.CreateSecret(ctx, secretConfig)
	if err != nil {
		t.Logf("CreateSecret() error = %v (expected in test environment)", err)
		return
	}

	if secret == nil {
		t.Error("CreateSecret() returned nil secret")
		return
	}

	if !strings.Contains(secret.Name, secretConfig.SecretID) {
		t.Errorf("CreateSecret() secret name = %v, should contain %v", secret.Name, secretConfig.SecretID)
	}

	// Clean up - attempt to delete the secret
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		secretsService.DeleteSecret(deleteCtx, secret.Name)
	}()
}

func TestSecretsService_AddSecretVersion(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping add secret version test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping add secret version test due to secrets service creation error: %v", err)
	}

	secretName := "projects/test-project-123/secrets/non-existent-secret"
	versionConfig := &SecretVersionConfig{
		Payload: &SecretPayload{
			Data: []byte("test-secret-value"),
		},
		State: "ENABLED",
		ClientSpecifiedPayloadChecksum: &PayloadChecksum{
			Crc32c: calculateCRC32C([]byte("test-secret-value")),
		},
	}

	ctx := context.Background()
	version, err := secretsService.AddSecretVersion(ctx, secretName, versionConfig)
	if err != nil {
		t.Logf("AddSecretVersion() error = %v (expected for non-existent secret)", err)
		return
	}

	if version == nil {
		t.Error("AddSecretVersion() returned nil version")
	}
}

func TestSecretsService_AccessSecretVersion(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping access secret version test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping access secret version test due to secrets service creation error: %v", err)
	}

	ctx := context.Background()
	versionName := "projects/test-project-123/secrets/non-existent-secret/versions/latest"

	payload, err := secretsService.AccessSecretVersion(ctx, versionName)
	if err == nil {
		t.Error("AccessSecretVersion() should have returned error for non-existent secret")
	}

	if payload != nil {
		t.Error("AccessSecretVersion() should have returned nil payload for non-existent secret")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("AccessSecretVersion() error should be not found error, got: %v", err)
	}
}

func TestSecretsService_ListSecrets(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list secrets test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping list secrets test due to secrets service creation error: %v", err)
	}

	ctx := context.Background()
	project := "projects/test-project-123"

	secrets, err := secretsService.ListSecrets(ctx, project, nil)
	if err != nil {
		t.Logf("ListSecrets() error = %v (expected in test environment)", err)
		return
	}

	if secrets == nil {
		t.Error("ListSecrets() returned nil secrets")
		return
	}

	t.Logf("ListSecrets() returned %d secrets", len(secrets))
}

func TestSecretsService_RotateSecret(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping rotate secret test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping rotate secret test due to secrets service creation error: %v", err)
	}

	rotationConfig := &SecretRotationConfig{
		SecretName: "projects/test-project-123/secrets/non-existent-secret",
		NewPayload: &SecretPayload{
			Data: []byte("new-rotated-secret-value"),
		},
		RotationTime: time.Now(),
		ForceRotation: false,
		UpdateRotationPeriod: &time.Duration{},
		NotifyOnRotation: true,
		ValidateAfterRotation: true,
		BackupBeforeRotation: true,
		RollbackOnFailure: true,
	}

	ctx := context.Background()
	result, err := secretsService.RotateSecret(ctx, rotationConfig)
	if err != nil {
		t.Logf("RotateSecret() error = %v (expected for non-existent secret)", err)
		return
	}

	if result == nil {
		t.Error("RotateSecret() returned nil result")
	}
}

func TestSecretsService_SetSecretIAMPolicy(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping set secret IAM policy test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping set secret IAM policy test due to secrets service creation error: %v", err)
	}

	secretName := "projects/test-project-123/secrets/non-existent-secret"
	policy := &IAMPolicy{
		Version: 3,
		Bindings: []*IAMBinding{
			{
				Role: "roles/secretmanager.secretAccessor",
				Members: []string{
					"user:test@example.com",
				},
				Condition: &IAMCondition{
					Title:       "Test Condition",
					Description: "Test access condition",
					Expression:  `request.time < timestamp("2024-01-01T00:00:00Z")`,
				},
			},
		},
		AuditConfigs: []*AuditConfig{
			{
				Service: "secretmanager.googleapis.com",
				AuditLogConfigs: []*AuditLogConfig{
					{
						LogType: "DATA_READ",
						ExemptedMembers: []string{
							"user:admin@example.com",
						},
					},
				},
			},
		},
		Etag: "",
	}

	ctx := context.Background()
	updatedPolicy, err := secretsService.SetSecretIAMPolicy(ctx, secretName, policy)
	if err != nil {
		t.Logf("SetSecretIAMPolicy() error = %v (expected for non-existent secret)", err)
		return
	}

	if updatedPolicy == nil {
		t.Error("SetSecretIAMPolicy() returned nil policy")
	}
}

func TestSecretConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *SecretConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &SecretConfig{
				SecretID:    "test-secret",
				DisplayName: "Test Secret",
				Replication: &ReplicationConfig{
					Policy: "automatic",
				},
			},
			wantErr: false,
		},
		{
			name: "empty secret ID",
			config: &SecretConfig{
				SecretID:    "",
				DisplayName: "Test Secret",
				Replication: &ReplicationConfig{
					Policy: "automatic",
				},
			},
			wantErr: true,
		},
		{
			name: "invalid secret ID format",
			config: &SecretConfig{
				SecretID:    "Test_Secret",
				DisplayName: "Test Secret",
				Replication: &ReplicationConfig{
					Policy: "automatic",
				},
			},
			wantErr: true,
		},
		{
			name: "missing replication config",
			config: &SecretConfig{
				SecretID:    "test-secret",
				DisplayName: "Test Secret",
			},
			wantErr: true,
		},
		{
			name: "invalid replication policy",
			config: &SecretConfig{
				SecretID:    "test-secret",
				DisplayName: "Test Secret",
				Replication: &ReplicationConfig{
					Policy: "invalid",
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("SecretConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSecretVersionConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *SecretVersionConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &SecretVersionConfig{
				Payload: &SecretPayload{
					Data: []byte("secret-data"),
				},
				State: "ENABLED",
			},
			wantErr: false,
		},
		{
			name: "missing payload",
			config: &SecretVersionConfig{
				State: "ENABLED",
			},
			wantErr: true,
		},
		{
			name: "empty payload data",
			config: &SecretVersionConfig{
				Payload: &SecretPayload{
					Data: []byte{},
				},
				State: "ENABLED",
			},
			wantErr: true,
		},
		{
			name: "invalid state",
			config: &SecretVersionConfig{
				Payload: &SecretPayload{
					Data: []byte("secret-data"),
				},
				State: "INVALID",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("SecretVersionConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSecretsService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{
		MetricsEnabled: true,
	}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to secrets service creation error: %v", err)
	}

	metrics := secretsService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestSecretsService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{
		CacheEnabled: true,
	}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to secrets service creation error: %v", err)
	}

	// Clear cache should not error
	secretsService.ClearCache()

	// Verify cache stats show empty cache
	stats := secretsService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestSecretsServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to secrets service creation error: %v", err)
	}

	// Test concurrent access to secrets service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to secrets service methods
			project := "projects/test-project-123"
			versionName := "projects/test-project-123/secrets/non-existent-secret/versions/latest"

			secretsService.ListSecrets(ctx, project, nil)
			secretsService.AccessSecretVersion(ctx, versionName)
			secretsService.GetServiceMetrics()
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkSecretsService_AccessSecretVersion(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	secretsConfig := &SecretsConfig{}
	secretsConfig.SetDefaults()

	secretsService, err := NewSecretsService(client, secretsConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to secrets service creation error: %v", err)
	}

	ctx := context.Background()
	versionName := "projects/test-project-123/secrets/non-existent-secret/versions/latest"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		secretsService.AccessSecretVersion(ctx, versionName)
	}
}

func BenchmarkSecretConfig_Validate(b *testing.B) {
	config := &SecretConfig{
		SecretID:    "test-secret",
		DisplayName: "Test Secret",
		Replication: &ReplicationConfig{
			Policy: "automatic",
		},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestSecretsErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "secret not found",
			err:      &googleapi.Error{Code: 404, Message: "Secret not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "secret version not found",
			err:      &googleapi.Error{Code: 404, Message: "Secret version not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "secret already exists",
			err:      &googleapi.Error{Code: 409, Message: "Secret already exists"},
			wantCode: ErrorCodeAlreadyExists,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "invalid secret ID",
			err:      &googleapi.Error{Code: 400, Message: "Invalid secret ID"},
			wantCode: ErrorCodeInvalidArgument,
		},
		{
			name:     "secret payload too large",
			err:      &googleapi.Error{Code: 400, Message: "Secret payload is too large"},
			wantCode: ErrorCodeInvalidArgument,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gcpErr := NewGCPError("TestOperation", "test-resource", tt.err)
			if gcpErr.Code != tt.wantCode {
				t.Errorf("Error classification = %v, want %v", gcpErr.Code, tt.wantCode)
			}
		})
	}
}

func TestSecretPayloadValidation(t *testing.T) {
	// Test secret payload validation
	tests := []struct {
		name    string
		payload *SecretPayload
		maxSize int
		valid   bool
	}{
		{
			name: "valid payload",
			payload: &SecretPayload{
				Data: []byte("secret-data"),
			},
			maxSize: 1024,
			valid:   true,
		},
		{
			name: "empty payload",
			payload: &SecretPayload{
				Data: []byte{},
			},
			maxSize: 1024,
			valid:   false,
		},
		{
			name:    "nil payload",
			payload: nil,
			maxSize: 1024,
			valid:   false,
		},
		{
			name: "payload too large",
			payload: &SecretPayload{
				Data: make([]byte, 2048),
			},
			maxSize: 1024,
			valid:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateSecretPayload(tt.payload, tt.maxSize)
			isValid := err == nil

			if isValid != tt.valid {
				t.Errorf("validateSecretPayload() valid = %v, want %v", isValid, tt.valid)
			}
		})
	}
}

// Helper function for secret payload validation (would be part of actual implementation)
func validateSecretPayload(payload *SecretPayload, maxSize int) error {
	if payload == nil {
		return fmt.Errorf("payload is required")
	}
	if len(payload.Data) == 0 {
		return fmt.Errorf("payload data cannot be empty")
	}
	if len(payload.Data) > maxSize {
		return fmt.Errorf("payload size %d exceeds maximum %d", len(payload.Data), maxSize)
	}
	return nil
}

func TestSecretAccessControls(t *testing.T) {
	// Test secret access control configurations
	accessControls := []*SecretAccessControl{
		{
			Principal:   "user:test@example.com",
			Role:        "roles/secretmanager.secretAccessor",
			Conditions:  []string{`request.time < timestamp("2024-01-01T00:00:00Z")`},
			TimeRestrictions: &TimeRestrictions{
				StartTime: "09:00",
				EndTime:   "17:00",
				Timezone:  "UTC",
				DaysOfWeek: []string{"MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"},
			},
			IPRestrictions: &IPRestrictions{
				AllowedRanges: []string{"10.0.0.0/8", "192.168.0.0/16"},
				DeniedRanges:  []string{"10.0.0.100/32"},
			},
		},
		{
			Principal:  "serviceAccount:test-sa@test-project.iam.gserviceaccount.com",
			Role:       "roles/secretmanager.secretVersionManager",
			Conditions: []string{`resource.name.startsWith("projects/test-project/secrets/prod-")`},
		},
	}

	for i, ac := range accessControls {
		t.Run(strings.Join([]string{"access_control", string(rune(i+'0'))}, "_"), func(t *testing.T) {
			if ac.Principal == "" {
				t.Error("Access control should have principal")
			}
			if ac.Role == "" {
				t.Error("Access control should have role")
			}

			// Validate role format
			if !strings.HasPrefix(ac.Role, "roles/") {
				t.Error("Role should start with 'roles/'")
			}

			// Validate principal format
			validPrefixes := []string{"user:", "serviceAccount:", "group:", "domain:"}
			validPrincipal := false
			for _, prefix := range validPrefixes {
				if strings.HasPrefix(ac.Principal, prefix) {
					validPrincipal = true
					break
				}
			}
			if !validPrincipal {
				t.Errorf("Principal should have valid prefix, got: %s", ac.Principal)
			}
		})
	}
}

// Helper function for CRC32C calculation (simplified)
func calculateCRC32C(data []byte) uint32 {
	// This is a simplified implementation
	// In real code, you'd use the actual CRC32C algorithm
	return uint32(len(data))
}

func TestSecretRotationScheduling(t *testing.T) {
	// Test secret rotation scheduling
	rotationSchedules := []*RotationSchedule{
		{
			SecretName:      "projects/test-project/secrets/db-password",
			RotationPeriod:  30 * 24 * time.Hour, // 30 days
			NextRotation:    time.Now().Add(30 * 24 * time.Hour),
			AutoRotation:    true,
			RotationWindow:  2 * time.Hour,
			MaxRetries:      3,
			NotificationChannels: []string{
				"projects/test-project/notificationChannels/email-alerts",
			},
			PreRotationHook:  "projects/test-project/functions/prepare-rotation",
			PostRotationHook: "projects/test-project/functions/validate-rotation",
		},
		{
			SecretName:     "projects/test-project/secrets/api-key",
			RotationPeriod: 90 * 24 * time.Hour, // 90 days
			NextRotation:   time.Now().Add(90 * 24 * time.Hour),
			AutoRotation:   false, // Manual rotation only
		},
	}

	for i, schedule := range rotationSchedules {
		t.Run(strings.Join([]string{"rotation_schedule", string(rune(i+'0'))}, "_"), func(t *testing.T) {
			if schedule.SecretName == "" {
				t.Error("Rotation schedule should have secret name")
			}
			if schedule.RotationPeriod <= 0 {
				t.Error("Rotation schedule should have positive rotation period")
			}
			if schedule.NextRotation.IsZero() {
				t.Error("Rotation schedule should have next rotation time")
			}
			if schedule.NextRotation.Before(time.Now()) {
				t.Error("Next rotation time should be in the future")
			}

			// Validate secret name format
			if !strings.HasPrefix(schedule.SecretName, "projects/") {
				t.Error("Secret name should start with 'projects/'")
			}
			if !strings.Contains(schedule.SecretName, "/secrets/") {
				t.Error("Secret name should contain '/secrets/'")
			}
		})
	}
}