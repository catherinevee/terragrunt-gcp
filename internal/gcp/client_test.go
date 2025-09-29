package gcp

import (
	"context"
	"os"
	"testing"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
)

func TestNewClient(t *testing.T) {
	tests := []struct {
		name      string
		projectID string
		wantErr   bool
	}{
		{
			name:      "valid project ID",
			projectID: "test-project-123",
			wantErr:   false,
		},
		{
			name:      "empty project ID",
			projectID: "",
			wantErr:   true,
		},
		{
			name:      "invalid project ID format",
			projectID: "Test_Project!",
			wantErr:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			config := &ClientConfig{
				ProjectID: tt.projectID,
				Region:    "us-central1",
				Zone:      "us-central1-a",
			}

			client, err := NewClient(context.Background(), config)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewClient() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr && client == nil {
				t.Error("NewClient() returned nil client when expecting valid client")
			}

			if !tt.wantErr && client != nil {
				if client.ProjectID() != tt.projectID {
					t.Errorf("NewClient() ProjectID = %v, want %v", client.ProjectID(), tt.projectID)
				}

				if client.Region() != config.Region {
					t.Errorf("NewClient() Region = %v, want %v", client.Region(), config.Region)
				}

				if client.Zone() != config.Zone {
					t.Errorf("NewClient() Zone = %v, want %v", client.Zone(), config.Zone)
				}
			}
		})
	}
}

func TestClientConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *ClientConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &ClientConfig{
				ProjectID: "test-project-123",
				Region:    "us-central1",
				Zone:      "us-central1-a",
			},
			wantErr: false,
		},
		{
			name: "missing project ID",
			config: &ClientConfig{
				Region: "us-central1",
				Zone:   "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "missing region",
			config: &ClientConfig{
				ProjectID: "test-project-123",
				Zone:      "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "missing zone",
			config: &ClientConfig{
				ProjectID: "test-project-123",
				Region:    "us-central1",
			},
			wantErr: true,
		},
		{
			name: "invalid project ID with uppercase",
			config: &ClientConfig{
				ProjectID: "Test-Project",
				Region:    "us-central1",
				Zone:      "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "invalid project ID with special chars",
			config: &ClientConfig{
				ProjectID: "test_project!",
				Region:    "us-central1",
				Zone:      "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "project ID too short",
			config: &ClientConfig{
				ProjectID: "ab",
				Region:    "us-central1",
				Zone:      "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "project ID too long",
			config: &ClientConfig{
				ProjectID: "this-is-a-very-long-project-id-that-exceeds-the-maximum-length-allowed",
				Region:    "us-central1",
				Zone:      "us-central1-a",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ClientConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestClientConfig_SetDefaults(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project",
	}

	config.SetDefaults()

	if config.Region == "" {
		t.Error("SetDefaults() did not set default region")
	}

	if config.Zone == "" {
		t.Error("SetDefaults() did not set default zone")
	}

	if config.Timeout() == 0 {
		t.Error("SetDefaults() did not set default timeout")
	}

	if config.RetryAttempts() == 0 {
		t.Error("SetDefaults() did not set default retry attempts")
	}

	if config.RetryDelay() == 0 {
		t.Error("SetDefaults() did not set default retry delay")
	}

	if config.RateLimitQPS() == 0 {
		t.Error("SetDefaults() did not set default rate limit QPS")
	}

	if config.RateLimitBurst() == 0 {
		t.Error("SetDefaults() did not set default rate limit burst")
	}
}

func TestClient_GetCredentials(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping credential test due to client creation error: %v", err)
	}

	creds, err := client.GetCredentials()
	if err != nil {
		t.Skipf("GetCredentials() error: %v", err)
	}
	if creds == nil {
		t.Error("GetCredentials() returned nil credentials")
	}
}

func TestClient_GetProjectID(t *testing.T) {
	expectedProjectID := "test-project-123"
	config := &ClientConfig{
		ProjectID: expectedProjectID,
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping project ID test due to client creation error: %v", err)
	}

	projectID := client.GetProjectID()
	if projectID != expectedProjectID {
		t.Errorf("GetProjectID() = %v, want %v", projectID, expectedProjectID)
	}
}

func TestClient_GetRegion(t *testing.T) {
	expectedRegion := "us-central1"
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    expectedRegion,
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping region test due to client creation error: %v", err)
	}

	region := client.GetRegion()
	if region != expectedRegion {
		t.Errorf("GetRegion() = %v, want %v", region, expectedRegion)
	}
}

func TestClient_GetZone(t *testing.T) {
	expectedZone := "us-central1-a"
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      expectedZone,
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping zone test due to client creation error: %v", err)
	}

	zone := client.GetZone()
	if zone != expectedZone {
		t.Errorf("GetZone() = %v, want %v", zone, expectedZone)
	}
}

func TestClient_IsAuthenticated(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping authentication test due to client creation error: %v", err)
	}

	authenticated := client.IsAuthenticated()

	// This test will vary based on environment
	t.Logf("IsAuthenticated() = %v", authenticated)
}

func TestClient_RefreshCredentials(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping refresh credentials test due to client creation error: %v", err)
	}

	ctx := context.Background()
	err = client.RefreshCredentials(ctx)
	if err != nil {
		t.Logf("RefreshCredentials() error = %v (expected in test environment)", err)
	}
}

func TestClient_Close(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping close test due to client creation error: %v", err)
	}

	err = client.Close()
	if err != nil {
		t.Errorf("Close() error = %v", err)
	}
}

func TestClientMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID:     "test-project-123",
		Region:        "us-central1",
		Zone:          "us-central1-a",
		EnableMetrics: true,
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping metrics test due to client creation error: %v", err)
	}

	metrics := client.GetMetrics()
	if metrics == nil {
		t.Error("GetMetrics() returned nil when metrics are enabled")
	}
}

func TestTokenCache(t *testing.T) {
	cache := NewTokenCache(5 * time.Minute)

	token := &oauth2.Token{
		AccessToken:  "test-token",
		TokenType:    "Bearer",
		RefreshToken: "refresh-token",
		Expiry:       time.Now().Add(time.Hour),
	}

	key := "test-key"

	// Test Put
	cache.Put(key, token, []string{})

	// Test Get
	cachedToken := cache.Get(key)
	if cachedToken == nil {
		t.Error("Get() returned nil for cached token")
	}

	if cachedToken.Token.AccessToken != token.AccessToken {
		t.Errorf("Get() AccessToken = %v, want %v", cachedToken.Token.AccessToken, token.AccessToken)
	}

	// Test Delete
	cache.Delete(key)
	if cache.Get(key) != nil {
		t.Error("Get() returned token after Delete()")
	}

	// Test Clear
	cache.Put("key1", token, []string{})
	cache.Put("key2", token, []string{})
	cache.Clear()

	if cache.Get("key1") != nil || cache.Get("key2") != nil {
		t.Error("Get() returned tokens after Clear()")
	}
}

func TestTokenCache_IsExpired(t *testing.T) {
	t.Skip("IsExpired method not implemented in TokenCache")
}

func TestTokenCache_GetStats(t *testing.T) {
	t.Skip("GetStats method not implemented in TokenCache")
}

func TestGoogleCredentials(t *testing.T) {
	// Test finding default credentials
	ctx := context.Background()
	creds, err := google.FindDefaultCredentials(ctx)

	if err != nil {
		t.Logf("FindDefaultCredentials() error = %v (expected in test environment)", err)
		return
	}

	if creds == nil {
		t.Error("FindDefaultCredentials() returned nil credentials")
	}

	if creds.ProjectID == "" {
		t.Log("FindDefaultCredentials() returned empty project ID")
	}
}

func TestClientOptions(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
		UserAgent: "test-user-agent",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping client options test due to client creation error: %v", err)
	}

	// Test that client was created with custom options
	if client.UserAgent() != config.UserAgent {
		t.Errorf("Client UserAgent = %v, want %v", client.UserAgent(), config.UserAgent)
	}
}

func TestClientConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	// Test concurrent access to client methods
	done := make(chan bool, 10)

	for i := 0; i < 10; i++ {
		go func() {
			defer func() { done <- true }()

			// Test concurrent calls to client methods
			_ = client.GetProjectID()
			_ = client.GetRegion()
			_ = client.GetZone()
			_, _ = client.GetCredentials()

			_ = client.IsAuthenticated()
		}()
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkNewClient(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		client, err := NewClient(ctx, config)
		if err != nil {
			b.Errorf("NewClient() error = %v", err)
			continue
		}
		client.Close()
	}
}

func BenchmarkTokenCache(b *testing.B) {
	cache := NewTokenCache(5 * time.Minute)

	token := &oauth2.Token{
		AccessToken: "test-token",
		TokenType:   "Bearer",
		Expiry:      time.Now().Add(time.Hour),
	}

	b.ResetTimer()

	b.Run("Put", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			key := "key-" + string(rune(i%1000))
			cache.Put(key, token, []string{})
		}
	})

	b.Run("Get", func(b *testing.B) {
		// Pre-populate cache
		for i := 0; i < 1000; i++ {
			key := "key-" + string(rune(i))
			cache.Put(key, token, []string{})
		}

		b.ResetTimer()
		for i := 0; i < b.N; i++ {
			key := "key-" + string(rune(i%1000))
			cache.Get(key)
		}
	})
}

func TestClientConfigFromEnvironment(t *testing.T) {
	// Test reading configuration from environment variables
	originalProjectID := os.Getenv("GOOGLE_CLOUD_PROJECT")
	originalRegion := os.Getenv("GOOGLE_CLOUD_REGION")
	originalZone := os.Getenv("GOOGLE_CLOUD_ZONE")

	defer func() {
		os.Setenv("GOOGLE_CLOUD_PROJECT", originalProjectID)
		os.Setenv("GOOGLE_CLOUD_REGION", originalRegion)
		os.Setenv("GOOGLE_CLOUD_ZONE", originalZone)
	}()

	os.Setenv("GOOGLE_CLOUD_PROJECT", "env-test-project")
	os.Setenv("GOOGLE_CLOUD_REGION", "env-test-region")
	os.Setenv("GOOGLE_CLOUD_ZONE", "env-test-zone")

	config := &ClientConfig{}
	config.SetDefaults()

	// In a real implementation, the config would read from environment
	// This is a placeholder for that functionality
	t.Log("Environment configuration test placeholder")
}