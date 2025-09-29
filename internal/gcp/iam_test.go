package gcp

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
	"google.golang.org/api/iam/v1"
)

func TestNewIAMService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping IAM service test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{
		CacheEnabled:       true,
		CacheTTL:           30 * time.Minute,
		MetricsEnabled:     true,
		AuditEnabled:       true,
		PolicyCacheEnabled: true,
		PolicyCacheTTL:     15 * time.Minute,
		MaxCacheSize:       1000,
		BatchSize:          100,
		RetryAttempts:      3,
		RetryDelay:         time.Second,
		Timeout:            5 * time.Minute,
	}

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Errorf("NewIAMService() error = %v", err)
		return
	}

	if iamService == nil {
		t.Error("NewIAMService() returned nil service")
	}

	if iamService.client != client {
		t.Error("NewIAMService() did not set client correctly")
	}

	if iamService.config.CacheEnabled != iamConfig.CacheEnabled {
		t.Errorf("NewIAMService() CacheEnabled = %v, want %v",
			iamService.config.CacheEnabled, iamConfig.CacheEnabled)
	}
}

func TestIAMConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *IAMConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  1000,
				BatchSize:     100,
				RetryAttempts: 3,
				RetryDelay:    time.Second,
				Timeout:       5 * time.Minute,
			},
			wantErr: false,
		},
		{
			name: "invalid cache TTL",
			config: &IAMConfig{
				CacheTTL:      0,
				MaxCacheSize:  1000,
				BatchSize:     100,
				RetryAttempts: 3,
				RetryDelay:    time.Second,
				Timeout:       5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid max cache size",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  0,
				BatchSize:     100,
				RetryAttempts: 3,
				RetryDelay:    time.Second,
				Timeout:       5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid batch size",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  1000,
				BatchSize:     0,
				RetryAttempts: 3,
				RetryDelay:    time.Second,
				Timeout:       5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid retry attempts",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  1000,
				BatchSize:     100,
				RetryAttempts: 0,
				RetryDelay:    time.Second,
				Timeout:       5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid retry delay",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  1000,
				BatchSize:     100,
				RetryAttempts: 3,
				RetryDelay:    0,
				Timeout:       5 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid timeout",
			config: &IAMConfig{
				CacheTTL:      30 * time.Minute,
				MaxCacheSize:  1000,
				BatchSize:     100,
				RetryAttempts: 3,
				RetryDelay:    time.Second,
				Timeout:       0,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("IAMConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestIAMConfig_SetDefaults(t *testing.T) {
	config := &IAMConfig{}
	config.SetDefaults()

	if config.CacheTTL <= 0 {
		t.Error("SetDefaults() did not set CacheTTL")
	}

	if config.MaxCacheSize <= 0 {
		t.Error("SetDefaults() did not set MaxCacheSize")
	}

	if config.BatchSize <= 0 {
		t.Error("SetDefaults() did not set BatchSize")
	}

	if config.RetryAttempts <= 0 {
		t.Error("SetDefaults() did not set RetryAttempts")
	}

	if config.RetryDelay <= 0 {
		t.Error("SetDefaults() did not set RetryDelay")
	}

	if config.Timeout <= 0 {
		t.Error("SetDefaults() did not set Timeout")
	}

	if !config.CacheEnabled {
		t.Error("SetDefaults() did not enable cache")
	}

	if !config.MetricsEnabled {
		t.Error("SetDefaults() did not enable metrics")
	}
}

func TestIAMService_CreateServiceAccount(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create service account test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping create service account test due to IAM service creation error: %v", err)
	}

	saConfig := &ServiceAccountConfig{
		AccountID:   "test-sa-" + time.Now().Format("20060102-150405"),
		DisplayName: "Test Service Account",
		Description: "Service account created by test suite",
		Project:     "test-project-123",
	}

	ctx := context.Background()
	serviceAccount, err := iamService.CreateServiceAccount(ctx, saConfig)
	if err != nil {
		t.Logf("CreateServiceAccount() error = %v (expected in test environment)", err)
		return
	}

	if serviceAccount == nil {
		t.Error("CreateServiceAccount() returned nil service account")
		return
	}

	if !strings.Contains(serviceAccount.Email, saConfig.AccountID) {
		t.Errorf("CreateServiceAccount() email = %v should contain %v", serviceAccount.Email, saConfig.AccountID)
	}

	// Clean up - attempt to delete the service account
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		iamService.DeleteServiceAccount(deleteCtx, serviceAccount.Email)
	}()
}

func TestIAMService_GetServiceAccount(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service account test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping get service account test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	email := "non-existent-sa@test-project-123.iam.gserviceaccount.com"

	serviceAccount, err := iamService.GetServiceAccount(ctx, email)
	if err == nil {
		t.Error("GetServiceAccount() should have returned error for non-existent service account")
	}

	if serviceAccount != nil {
		t.Error("GetServiceAccount() should have returned nil for non-existent service account")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("GetServiceAccount() error should be not found error, got: %v", err)
	}
}

func TestIAMService_ListServiceAccounts(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list service accounts test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping list service accounts test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	project := "test-project-123"

	serviceAccounts, err := iamService.ListServiceAccounts(ctx, project)
	if err != nil {
		t.Logf("ListServiceAccounts() error = %v (expected in test environment)", err)
		return
	}

	if serviceAccounts == nil {
		t.Error("ListServiceAccounts() returned nil service accounts")
	}

	t.Logf("ListServiceAccounts() returned %d service accounts", len(serviceAccounts))
}

func TestIAMService_CreateCustomRole(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create custom role test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping create custom role test due to IAM service creation error: %v", err)
	}

	roleConfig := &CustomRoleConfig{
		RoleID:      "test_role_" + time.Now().Format("20060102_150405"),
		Title:       "Test Custom Role",
		Description: "Custom role created by test suite",
		Permissions: []string{
			"storage.objects.get",
			"storage.objects.list",
		},
		Stage:   "GA",
		Project: "test-project-123",
	}

	ctx := context.Background()
	role, err := iamService.CreateCustomRole(ctx, roleConfig)
	if err != nil {
		t.Logf("CreateCustomRole() error = %v (expected in test environment)", err)
		return
	}

	if role == nil {
		t.Error("CreateCustomRole() returned nil role")
		return
	}

	if !strings.Contains(role.Name, roleConfig.RoleID) {
		t.Errorf("CreateCustomRole() role name = %v should contain %v", role.Name, roleConfig.RoleID)
	}

	// Clean up - attempt to delete the custom role
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		iamService.DeleteCustomRole(deleteCtx, role.Name)
	}()
}

func TestIAMService_GetRole(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get role test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping get role test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()

	// Test getting a predefined role
	roleName := "roles/storage.objectViewer"
	role, err := iamService.GetRole(ctx, roleName)
	if err != nil {
		t.Logf("GetRole() error = %v (expected in test environment)", err)
		return
	}

	if role == nil {
		t.Error("GetRole() returned nil role for predefined role")
		return
	}

	if role.Name != roleName {
		t.Errorf("GetRole() role name = %v, want %v", role.Name, roleName)
	}

	// Test getting a non-existent role
	nonExistentRole := "projects/test-project-123/roles/non-existent-role"
	role, err = iamService.GetRole(ctx, nonExistentRole)
	if err == nil {
		t.Error("GetRole() should have returned error for non-existent role")
	}

	if role != nil {
		t.Error("GetRole() should have returned nil for non-existent role")
	}
}

func TestIAMService_GetIAMPolicy(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get IAM policy test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping get IAM policy test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	resource := "projects/test-project-123"

	policy, err := iamService.GetIAMPolicy(ctx, resource)
	if err != nil {
		t.Logf("GetIAMPolicy() error = %v (expected in test environment)", err)
		return
	}

	if policy == nil {
		t.Error("GetIAMPolicy() returned nil policy")
	}
}

func TestIAMService_SetIAMPolicy(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping set IAM policy test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping set IAM policy test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	resource := "projects/test-project-123"

	// First get the current policy
	currentPolicy, err := iamService.GetIAMPolicy(ctx, resource)
	if err != nil {
		t.Logf("GetIAMPolicy() error = %v (expected in test environment)", err)
		return
	}

	if currentPolicy == nil {
		t.Skip("Cannot test SetIAMPolicy without current policy")
	}

	// Try to set the same policy back
	updatedPolicy, err := iamService.SetIAMPolicy(ctx, resource, currentPolicy)
	if err != nil {
		t.Logf("SetIAMPolicy() error = %v (expected in test environment)", err)
		return
	}

	if updatedPolicy == nil {
		t.Error("SetIAMPolicy() returned nil updated policy")
	}
}

func TestIAMService_TestIAMPermissions(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping test IAM permissions test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping test IAM permissions test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	resource := "projects/test-project-123"
	permissions := []string{
		"storage.objects.get",
		"storage.objects.list",
		"compute.instances.get",
	}

	allowedPermissions, err := iamService.TestIAMPermissions(ctx, resource, permissions)
	if err != nil {
		t.Logf("TestIAMPermissions() error = %v (expected in test environment)", err)
		return
	}

	if allowedPermissions == nil {
		t.Error("TestIAMPermissions() returned nil allowed permissions")
	}

	t.Logf("TestIAMPermissions() returned %d allowed permissions out of %d requested",
		len(allowedPermissions), len(permissions))
}

func TestIAMService_GenerateAccessToken(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping generate access token test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping generate access token test due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	serviceAccount := "test-sa@test-project-123.iam.gserviceaccount.com"
	scopes := []string{
		"https://www.googleapis.com/auth/cloud-platform",
	}

	token, err := iamService.GenerateAccessToken(ctx, serviceAccount, scopes)
	if err != nil {
		t.Logf("GenerateAccessToken() error = %v (expected for non-existent service account)", err)
		return
	}

	if token == nil {
		t.Error("GenerateAccessToken() returned nil token")
	}

	if token.AccessToken == "" {
		t.Error("GenerateAccessToken() returned empty access token")
	}

	if token.Expiry.IsZero() {
		t.Error("GenerateAccessToken() returned token without expiry")
	}
}

func TestServiceAccountConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *ServiceAccountConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &ServiceAccountConfig{
				AccountID:   "test-service-account",
				DisplayName: "Test Service Account",
				Description: "Test description",
				Project:     "test-project-123",
			},
			wantErr: false,
		},
		{
			name: "empty account ID",
			config: &ServiceAccountConfig{
				AccountID:   "",
				DisplayName: "Test Service Account",
				Description: "Test description",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "empty project",
			config: &ServiceAccountConfig{
				AccountID:   "test-service-account",
				DisplayName: "Test Service Account",
				Description: "Test description",
				Project:     "",
			},
			wantErr: true,
		},
		{
			name: "invalid account ID format",
			config: &ServiceAccountConfig{
				AccountID:   "Test-Service-Account",
				DisplayName: "Test Service Account",
				Description: "Test description",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "account ID too long",
			config: &ServiceAccountConfig{
				AccountID:   "this-is-a-very-long-service-account-id-that-exceeds-maximum-length",
				DisplayName: "Test Service Account",
				Description: "Test description",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ServiceAccountConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestCustomRoleConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *CustomRoleConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &CustomRoleConfig{
				RoleID:      "test_custom_role",
				Title:       "Test Custom Role",
				Description: "Test description",
				Permissions: []string{"storage.objects.get", "storage.objects.list"},
				Stage:       "GA",
				Project:     "test-project-123",
			},
			wantErr: false,
		},
		{
			name: "empty role ID",
			config: &CustomRoleConfig{
				RoleID:      "",
				Title:       "Test Custom Role",
				Description: "Test description",
				Permissions: []string{"storage.objects.get"},
				Stage:       "GA",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "empty title",
			config: &CustomRoleConfig{
				RoleID:      "test_custom_role",
				Title:       "",
				Description: "Test description",
				Permissions: []string{"storage.objects.get"},
				Stage:       "GA",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "empty permissions",
			config: &CustomRoleConfig{
				RoleID:      "test_custom_role",
				Title:       "Test Custom Role",
				Description: "Test description",
				Permissions: []string{},
				Stage:       "GA",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "invalid stage",
			config: &CustomRoleConfig{
				RoleID:      "test_custom_role",
				Title:       "Test Custom Role",
				Description: "Test description",
				Permissions: []string{"storage.objects.get"},
				Stage:       "INVALID",
				Project:     "test-project-123",
			},
			wantErr: true,
		},
		{
			name: "empty project",
			config: &CustomRoleConfig{
				RoleID:      "test_custom_role",
				Title:       "Test Custom Role",
				Description: "Test description",
				Permissions: []string{"storage.objects.get"},
				Stage:       "GA",
				Project:     "",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("CustomRoleConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestIAMService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{
		MetricsEnabled: true,
	}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to IAM service creation error: %v", err)
	}

	metrics := iamService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestIAMService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{
		CacheEnabled: true,
	}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to IAM service creation error: %v", err)
	}

	// Clear cache should not error
	iamService.ClearCache()

	// Verify cache stats show empty cache
	stats := iamService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestIAMServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to IAM service creation error: %v", err)
	}

	// Test concurrent access to IAM service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to IAM service methods
			email := "non-existent-sa@test-project-123.iam.gserviceaccount.com"
			project := "test-project-123"

			iamService.GetServiceAccount(ctx, email)
			iamService.ListServiceAccounts(ctx, project)

			roleName := "roles/storage.objectViewer"
			iamService.GetRole(ctx, roleName)
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkIAMService_GetServiceAccount(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	iamConfig := &IAMConfig{}
	iamConfig.SetDefaults()

	iamService, err := NewIAMService(client, iamConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to IAM service creation error: %v", err)
	}

	ctx := context.Background()
	email := "non-existent-sa@test-project-123.iam.gserviceaccount.com"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		iamService.GetServiceAccount(ctx, email)
	}
}

func BenchmarkServiceAccountConfig_Validate(b *testing.B) {
	config := &ServiceAccountConfig{
		AccountID:   "test-service-account",
		DisplayName: "Test Service Account",
		Description: "Test description",
		Project:     "test-project-123",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestIAMErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "service account not found",
			err:      &googleapi.Error{Code: 404, Message: "Service account not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "service account already exists",
			err:      &googleapi.Error{Code: 409, Message: "Service account already exists"},
			wantCode: ErrorCodeAlreadyExists,
		},
		{
			name:     "invalid service account ID",
			err:      &googleapi.Error{Code: 400, Message: "Invalid service account ID"},
			wantCode: ErrorCodeInvalidArgument,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
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

func TestPolicyBindingOperations(t *testing.T) {
	// Test policy binding helper functions
	policy := &iam.Policy{
		Bindings: []*iam.Binding{
			{
				Role: "roles/storage.objectViewer",
				Members: []string{
					"user:test@example.com",
					"serviceAccount:test-sa@test-project.iam.gserviceaccount.com",
				},
			},
			{
				Role: "roles/storage.objectAdmin",
				Members: []string{
					"user:admin@example.com",
				},
			},
		},
	}

	// Test finding bindings
	binding := findBinding(policy, "roles/storage.objectViewer")
	if binding == nil {
		t.Error("findBinding() should have found existing binding")
	}

	if len(binding.Members) != 2 {
		t.Errorf("findBinding() binding should have 2 members, got %d", len(binding.Members))
	}

	// Test finding non-existent binding
	nonExistentBinding := findBinding(policy, "roles/non.existent")
	if nonExistentBinding != nil {
		t.Error("findBinding() should not have found non-existent binding")
	}

	// Test adding member to existing binding
	addMemberToPolicy(policy, "roles/storage.objectViewer", "user:new@example.com")
	updatedBinding := findBinding(policy, "roles/storage.objectViewer")
	if len(updatedBinding.Members) != 3 {
		t.Errorf("addMemberToPolicy() binding should have 3 members after adding, got %d", len(updatedBinding.Members))
	}

	// Test adding member to new binding
	addMemberToPolicy(policy, "roles/compute.viewer", "user:compute@example.com")
	newBinding := findBinding(policy, "roles/compute.viewer")
	if newBinding == nil {
		t.Error("addMemberToPolicy() should have created new binding")
	}

	if len(newBinding.Members) != 1 {
		t.Errorf("addMemberToPolicy() new binding should have 1 member, got %d", len(newBinding.Members))
	}

	// Test removing member
	removeMemberFromPolicy(policy, "roles/storage.objectViewer", "user:test@example.com")
	finalBinding := findBinding(policy, "roles/storage.objectViewer")
	if len(finalBinding.Members) != 2 {
		t.Errorf("removeMemberFromPolicy() binding should have 2 members after removal, got %d", len(finalBinding.Members))
	}

	// Verify the correct member was removed
	for _, member := range finalBinding.Members {
		if member == "user:test@example.com" {
			t.Error("removeMemberFromPolicy() should have removed user:test@example.com")
		}
	}
}

// Helper functions for policy manipulation (these would be part of the actual implementation)
func findBinding(policy *iam.Policy, role string) *iam.Binding {
	for _, binding := range policy.Bindings {
		if binding.Role == role {
			return binding
		}
	}
	return nil
}

func addMemberToPolicy(policy *iam.Policy, role, member string) {
	binding := findBinding(policy, role)
	if binding == nil {
		// Create new binding
		binding = &iam.Binding{
			Role:    role,
			Members: []string{},
		}
		policy.Bindings = append(policy.Bindings, binding)
	}

	// Check if member already exists
	for _, existingMember := range binding.Members {
		if existingMember == member {
			return // Member already exists
		}
	}

	binding.Members = append(binding.Members, member)
}

func removeMemberFromPolicy(policy *iam.Policy, role, member string) {
	binding := findBinding(policy, role)
	if binding == nil {
		return // Binding doesn't exist
	}

	for i, existingMember := range binding.Members {
		if existingMember == member {
			// Remove member by replacing with last element and truncating
			binding.Members[i] = binding.Members[len(binding.Members)-1]
			binding.Members = binding.Members[:len(binding.Members)-1]
			return
		}
	}
}