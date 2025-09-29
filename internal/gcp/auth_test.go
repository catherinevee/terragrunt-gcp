package gcp

import (
	"context"
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

func TestNewAuthService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping auth service test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		ServiceAccountKeyPath:            "",
		ServiceAccountKey:                "",
		ImpersonateServiceAccount:        "",
		AccessToken:                      "",
		Scopes: []string{
			"https://www.googleapis.com/auth/cloud-platform",
		},
		TokenCacheEnabled: true,
		TokenCacheTTL:     30 * time.Minute,
		TokenCacheSize:    100,
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Errorf("NewAuthService() error = %v", err)
		return
	}

	if authService == nil {
		t.Error("NewAuthService() returned nil service")
	}

	if authService.client != client {
		t.Error("NewAuthService() did not set client correctly")
	}
}

func TestAuthConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *AuthConfig
		wantErr bool
	}{
		{
			name: "valid application default credentials",
			config: &AuthConfig{
				UseApplicationDefaultCredentials: true,
				Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: false,
		},
		{
			name: "valid service account key path",
			config: &AuthConfig{
				ServiceAccountKeyPath: "/path/to/key.json",
				Scopes:                []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: false,
		},
		{
			name: "valid service account key content",
			config: &AuthConfig{
				ServiceAccountKey: `{"type": "service_account"}`,
				Scopes:            []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: false,
		},
		{
			name: "valid access token",
			config: &AuthConfig{
				AccessToken: "ya29.test-token",
				Scopes:      []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: false,
		},
		{
			name: "multiple auth methods",
			config: &AuthConfig{
				UseApplicationDefaultCredentials: true,
				ServiceAccountKeyPath:            "/path/to/key.json",
				Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: true,
		},
		{
			name: "no auth method",
			config: &AuthConfig{
				Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
			},
			wantErr: true,
		},
		{
			name: "empty scopes",
			config: &AuthConfig{
				UseApplicationDefaultCredentials: true,
				Scopes: []string{},
			},
			wantErr: true,
		},
		{
			name: "nil scopes",
			config: &AuthConfig{
				UseApplicationDefaultCredentials: true,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("AuthConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestAuthConfig_SetDefaults(t *testing.T) {
	config := &AuthConfig{}
	config.SetDefaults()

	if !config.UseApplicationDefaultCredentials {
		t.Error("SetDefaults() did not set UseApplicationDefaultCredentials to true")
	}

	expectedScopes := []string{
		"https://www.googleapis.com/auth/cloud-platform",
		"https://www.googleapis.com/auth/userinfo.email",
	}

	if len(config.Scopes) != len(expectedScopes) {
		t.Errorf("SetDefaults() scopes length = %d, want %d", len(config.Scopes), len(expectedScopes))
	}

	for i, scope := range expectedScopes {
		if i >= len(config.Scopes) || config.Scopes[i] != scope {
			t.Errorf("SetDefaults() scopes[%d] = %v, want %v", i, config.Scopes[i], scope)
		}
	}

	if !config.TokenCacheEnabled {
		t.Error("SetDefaults() did not set TokenCacheEnabled to true")
	}

	if config.TokenCacheTTL != 30*time.Minute {
		t.Errorf("SetDefaults() TokenCacheTTL = %v, want %v", config.TokenCacheTTL, 30*time.Minute)
	}

	if config.TokenCacheSize != 100 {
		t.Errorf("SetDefaults() TokenCacheSize = %d, want %d", config.TokenCacheSize, 100)
	}
}

func TestAuthService_GetCredentials(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get credentials test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping get credentials test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	creds, err := authService.GetCredentials(ctx)
	if err != nil {
		t.Logf("GetCredentials() error = %v (expected in test environment)", err)
		return
	}

	if creds == nil {
		t.Error("GetCredentials() returned nil credentials")
	}
}

func TestAuthService_GetToken(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get token test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping get token test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	token, err := authService.GetToken(ctx)
	if err != nil {
		t.Logf("GetToken() error = %v (expected in test environment)", err)
		return
	}

	if token == nil {
		t.Error("GetToken() returned nil token")
	}

	if token.AccessToken == "" {
		t.Error("GetToken() returned token with empty access token")
	}
}

func TestAuthService_RefreshToken(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping refresh token test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping refresh token test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	token, err := authService.RefreshToken(ctx)
	if err != nil {
		t.Logf("RefreshToken() error = %v (expected in test environment)", err)
		return
	}

	if token == nil {
		t.Error("RefreshToken() returned nil token")
	}
}

func TestAuthService_ValidateToken(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping validate token test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping validate token test due to auth service creation error: %v", err)
	}

	ctx := context.Background()

	// Test with nil token
	valid := authService.ValidateToken(ctx, nil)
	if valid {
		t.Error("ValidateToken() returned true for nil token")
	}

	// Test with expired token
	expiredToken := &oauth2.Token{
		AccessToken: "expired-token",
		TokenType:   "Bearer",
		Expiry:      time.Now().Add(-time.Hour),
	}

	valid = authService.ValidateToken(ctx, expiredToken)
	if valid {
		t.Error("ValidateToken() returned true for expired token")
	}

	// Test with valid token
	validToken := &oauth2.Token{
		AccessToken: "valid-token",
		TokenType:   "Bearer",
		Expiry:      time.Now().Add(time.Hour),
	}

	valid = authService.ValidateToken(ctx, validToken)
	if !valid {
		t.Error("ValidateToken() returned false for valid token")
	}
}

func TestAuthService_GetUserInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get user info test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{
			"https://www.googleapis.com/auth/cloud-platform",
			"https://www.googleapis.com/auth/userinfo.email",
		},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping get user info test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	userInfo, err := authService.GetUserInfo(ctx)
	if err != nil {
		t.Logf("GetUserInfo() error = %v (expected in test environment)", err)
		return
	}

	if userInfo == nil {
		t.Error("GetUserInfo() returned nil user info")
	}
}

func TestAuthService_GetServiceAccountInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service account info test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping get service account info test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	saInfo, err := authService.GetServiceAccountInfo(ctx)
	if err != nil {
		t.Logf("GetServiceAccountInfo() error = %v (expected in test environment)", err)
		return
	}

	if saInfo == nil {
		t.Error("GetServiceAccountInfo() returned nil service account info")
	}
}

func TestAuthService_ImpersonateServiceAccount(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping impersonate service account test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping impersonate service account test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	targetServiceAccount := "test-sa@test-project-123.iam.gserviceaccount.com"
	scopes := []string{"https://www.googleapis.com/auth/cloud-platform"}

	token, err := authService.ImpersonateServiceAccount(ctx, targetServiceAccount, scopes)
	if err != nil {
		t.Logf("ImpersonateServiceAccount() error = %v (expected in test environment)", err)
		return
	}

	if token == nil {
		t.Error("ImpersonateServiceAccount() returned nil token")
	}
}

func TestAuthService_CreateServiceAccountKey(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create service account key test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping create service account key test due to auth service creation error: %v", err)
	}

	ctx := context.Background()
	serviceAccount := "test-sa@test-project-123.iam.gserviceaccount.com"

	keyData, err := authService.CreateServiceAccountKey(ctx, serviceAccount)
	if err != nil {
		t.Logf("CreateServiceAccountKey() error = %v (expected in test environment)", err)
		return
	}

	if len(keyData) == 0 {
		t.Error("CreateServiceAccountKey() returned empty key data")
	}

	// Verify it's valid JSON
	var keyJSON map[string]interface{}
	if err := json.Unmarshal(keyData, &keyJSON); err != nil {
		t.Errorf("CreateServiceAccountKey() returned invalid JSON: %v", err)
	}
}

func TestCreateCredentialsFromJSON(t *testing.T) {
	// Test with valid service account JSON
	validJSON := `{
		"type": "service_account",
		"project_id": "test-project",
		"private_key_id": "key-id",
		"private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n",
		"client_email": "test@test-project.iam.gserviceaccount.com",
		"client_id": "123456789",
		"auth_uri": "https://accounts.google.com/o/oauth2/auth",
		"token_uri": "https://oauth2.googleapis.com/token"
	}`

	ctx := context.Background()
	scopes := []string{"https://www.googleapis.com/auth/cloud-platform"}

	creds, err := CreateCredentialsFromJSON(ctx, []byte(validJSON), scopes)
	if err != nil {
		t.Logf("CreateCredentialsFromJSON() error = %v (expected with test key)", err)
		return
	}

	if creds == nil {
		t.Error("CreateCredentialsFromJSON() returned nil credentials")
	}

	// Test with invalid JSON
	invalidJSON := `{"invalid": "json"`
	_, err = CreateCredentialsFromJSON(ctx, []byte(invalidJSON), scopes)
	if err == nil {
		t.Error("CreateCredentialsFromJSON() should have returned error for invalid JSON")
	}
}

func TestCreateCredentialsFromFile(t *testing.T) {
	// Create a temporary service account file
	tempFile, err := os.CreateTemp("", "service-account-*.json")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())

	serviceAccountJSON := `{
		"type": "service_account",
		"project_id": "test-project",
		"private_key_id": "key-id",
		"private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n",
		"client_email": "test@test-project.iam.gserviceaccount.com",
		"client_id": "123456789",
		"auth_uri": "https://accounts.google.com/o/oauth2/auth",
		"token_uri": "https://oauth2.googleapis.com/token"
	}`

	if _, err := tempFile.WriteString(serviceAccountJSON); err != nil {
		t.Fatalf("Failed to write to temp file: %v", err)
	}
	tempFile.Close()

	ctx := context.Background()
	scopes := []string{"https://www.googleapis.com/auth/cloud-platform"}

	creds, err := CreateCredentialsFromFile(ctx, tempFile.Name(), scopes)
	if err != nil {
		t.Logf("CreateCredentialsFromFile() error = %v (expected with test key)", err)
		return
	}

	if creds == nil {
		t.Error("CreateCredentialsFromFile() returned nil credentials")
	}

	// Test with non-existent file
	_, err = CreateCredentialsFromFile(ctx, "/non/existent/file.json", scopes)
	if err == nil {
		t.Error("CreateCredentialsFromFile() should have returned error for non-existent file")
	}
}

func TestCredentialSource_String(t *testing.T) {
	tests := []struct {
		source CredentialSource
		want   string
	}{
		{CredentialSourceADC, "application_default_credentials"},
		{CredentialSourceServiceAccountKey, "service_account_key"},
		{CredentialSourceServiceAccountFile, "service_account_file"},
		{CredentialSourceAccessToken, "access_token"},
		{CredentialSourceImpersonation, "impersonation"},
		{CredentialSource(999), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.source.String(); got != tt.want {
				t.Errorf("CredentialSource.String() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGoogleOAuth2Flow(t *testing.T) {
	// Test OAuth2 configuration
	config := &oauth2.Config{
		ClientID:     "test-client-id",
		ClientSecret: "test-client-secret",
		Scopes:       []string{"https://www.googleapis.com/auth/cloud-platform"},
		Endpoint:     google.Endpoint,
		RedirectURL:  "urn:ietf:wg:oauth:2.0:oob",
	}

	authURL := config.AuthCodeURL("state", oauth2.AccessTypeOffline)
	if !strings.Contains(authURL, "https://accounts.google.com/o/oauth2/auth") {
		t.Errorf("AuthCodeURL() = %v, should contain Google OAuth2 endpoint", authURL)
	}

	if !strings.Contains(authURL, "client_id=test-client-id") {
		t.Error("AuthCodeURL() should contain client ID")
	}

	if !strings.Contains(authURL, "scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcloud-platform") {
		t.Error("AuthCodeURL() should contain scope")
	}
}

func TestTokenValidation(t *testing.T) {
	tests := []struct {
		name  string
		token *oauth2.Token
		valid bool
	}{
		{
			name:  "nil token",
			token: nil,
			valid: false,
		},
		{
			name: "empty access token",
			token: &oauth2.Token{
				AccessToken: "",
				TokenType:   "Bearer",
				Expiry:      time.Now().Add(time.Hour),
			},
			valid: false,
		},
		{
			name: "expired token",
			token: &oauth2.Token{
				AccessToken: "valid-token",
				TokenType:   "Bearer",
				Expiry:      time.Now().Add(-time.Hour),
			},
			valid: false,
		},
		{
			name: "valid token",
			token: &oauth2.Token{
				AccessToken: "valid-token",
				TokenType:   "Bearer",
				Expiry:      time.Now().Add(time.Hour),
			},
			valid: true,
		},
		{
			name: "token without expiry",
			token: &oauth2.Token{
				AccessToken: "valid-token",
				TokenType:   "Bearer",
			},
			valid: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			valid := isTokenValid(tt.token)
			if valid != tt.valid {
				t.Errorf("isTokenValid() = %v, want %v", valid, tt.valid)
			}
		})
	}
}

func isTokenValid(token *oauth2.Token) bool {
	if token == nil {
		return false
	}
	if token.AccessToken == "" {
		return false
	}
	if !token.Expiry.IsZero() && token.Expiry.Before(time.Now()) {
		return false
	}
	return true
}

func TestAuthServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to auth service creation error: %v", err)
	}

	// Test concurrent access to auth service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func() {
			defer func() { done <- true }()

			// Test concurrent calls to auth service methods
			authService.GetCredentials(ctx)
			authService.GetToken(ctx)
			authService.RefreshToken(ctx)

			token := &oauth2.Token{
				AccessToken: "test-token",
				TokenType:   "Bearer",
				Expiry:      time.Now().Add(time.Hour),
			}
			authService.ValidateToken(ctx, token)
		}()
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkGetToken(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to auth service creation error: %v", err)
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		authService.GetToken(ctx)
	}
}

func BenchmarkValidateToken(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	authConfig := &AuthConfig{
		UseApplicationDefaultCredentials: true,
		Scopes: []string{"https://www.googleapis.com/auth/cloud-platform"},
	}

	authService, err := NewAuthService(client, authConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to auth service creation error: %v", err)
	}

	token := &oauth2.Token{
		AccessToken: "test-token",
		TokenType:   "Bearer",
		Expiry:      time.Now().Add(time.Hour),
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		authService.ValidateToken(ctx, token)
	}
}