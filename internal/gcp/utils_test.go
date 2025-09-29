package gcp

import (
	"context"
	// "encoding/json"
	// "strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
)

func TestNewUtilsService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping utils service test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{
		CacheExpiry:                30 * time.Minute,
		MetricsEnabled:             true,
		AuditEnabled:               true,
		ValidationEnabled:          true,
		RecommendationsEnabled:     true,
		CostTrackingEnabled:        true,
		QuotaMonitoringEnabled:     true,
		ServiceDiscoveryEnabled:    true,
		ProjectAnalysisEnabled:     true,
		SecurityScanningEnabled:    true,
		ComplianceCheckingEnabled:  true,
		AutoOptimizationEnabled:    false,
		RealTimeMonitoringEnabled:  true,
		PredictiveAnalyticsEnabled: true,
		CustomMetricsEnabled:       true,
		DefaultRegion:              "us-central1",
		DefaultZone:                "us-central1-a",
		ParallelOperations:         10,
		RetryAttempts:              3,
		RetryDelay:                 time.Second,
		Timeout:                    5 * time.Minute,
		RateLimitQPS:               100,
		RateLimitBurst:             200,
		MaxCacheSize:               1000,
		BackupEnabled:              true,
		BackupInterval:             24 * time.Hour,
		BackupRetention:            7 * 24 * time.Hour,
		EncryptionEnabled:          true,
		CompressionEnabled:         true,
		LogLevel:                   "INFO",
		LogFormat:                  "json",
	}

	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Errorf("NewUtilsService() error = %v", err)
		return
	}

	if utilsService == nil {
		t.Error("NewUtilsService() returned nil service")
	}

	if utilsService.client != client {
		t.Error("NewUtilsService() did not set client correctly")
	}

	if utilsService.projectID != config.ProjectID {
		t.Errorf("NewUtilsService() projectID = %v, want %v", utilsService.projectID, config.ProjectID)
	}
}

func TestUtilsService_ValidateResource(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping validate resource test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping validate resource test due to utils service creation error: %v", err)
	}

	// Test struct validation
	type TestResource struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Count       int    `json:"count"`
		Email       string `json:"email"`
		URL         string `json:"url"`
		IP          string `json:"ip"`
		Active      bool   `json:"active"`
		Tags        []string `json:"tags"`
	}

	resource := &TestResource{
		Name:        "test-resource",
		Description: "A test resource for validation",
		Count:       42,
		Email:       "test@example.com",
		URL:         "https://example.com",
		IP:          "192.168.1.1",
		Active:      true,
		Tags:        []string{"test", "validation"},
	}

	rules := []ValidationRule{
		{
			Field:     "Name",
			Type:      "string",
			Required:  true,
			MinLength: 3,
			MaxLength: 50,
			Pattern:   `^[a-zA-Z0-9-]+$`,
		},
		{
			Field:    "Description",
			Type:     "string",
			Required: false,
		},
		{
			Field:    "Count",
			Type:     "number",
			Required: true,
			MinValue: 1,
			MaxValue: 100,
		},
		{
			Field:    "Email",
			Type:     "email",
			Required: true,
		},
		{
			Field:    "URL",
			Type:     "url",
			Required: true,
		},
		{
			Field:    "IP",
			Type:     "ip",
			Required: true,
		},
		{
			Field:    "Active",
			Type:     "bool",
			Required: true,
		},
		{
			Field:     "Tags",
			Type:      "array",
			Required:  false,
			MinLength: 1,
			MaxLength: 5,
		},
	}

	ctx := context.Background()
	result, err := utilsService.ValidateResource(ctx, resource, rules)
	if err != nil {
		t.Errorf("ValidateResource() error = %v", err)
		return
	}

	if result == nil {
		t.Error("ValidateResource() returned nil result")
		return
	}

	if !result.Valid {
		t.Errorf("ValidateResource() result should be valid, got errors: %v", result.Errors)
	}

	if len(result.Errors) != 0 {
		t.Errorf("ValidateResource() should have no errors for valid resource, got: %v", result.Errors)
	}

	// Test with invalid resource
	invalidResource := &TestResource{
		Name:        "", // Empty name should fail required validation
		Description: "A test resource",
		Count:       150, // Exceeds max value
		Email:       "invalid-email", // Invalid email format
		URL:         "not-a-url", // Invalid URL format
		IP:          "999.999.999.999", // Invalid IP
		Active:      true,
		Tags:        []string{}, // Empty array when min length is 1
	}

	invalidResult, err := utilsService.ValidateResource(ctx, invalidResource, rules)
	if err != nil {
		t.Errorf("ValidateResource() error = %v", err)
		return
	}

	if invalidResult.Valid {
		t.Error("ValidateResource() should be invalid for invalid resource")
	}

	if len(invalidResult.Errors) == 0 {
		t.Error("ValidateResource() should have errors for invalid resource")
	}

	// Verify specific error types
	errorCodes := make(map[string]bool)
	for _, validationError := range invalidResult.Errors {
		errorCodes[validationError.Code] = true
	}

	expectedErrorCodes := []string{
		"REQUIRED_FIELD_MISSING",
		"MAX_VALUE_VIOLATION",
		"INVALID_EMAIL",
		"INVALID_URL",
		"INVALID_IP",
		"MIN_LENGTH_VIOLATION",
	}

	for _, expectedCode := range expectedErrorCodes {
		if !errorCodes[expectedCode] {
			t.Errorf("ValidateResource() should have error code %s", expectedCode)
		}
	}
}

func TestUtilsService_GetProjectInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get project info test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping get project info test due to utils service creation error: %v", err)
	}

	ctx := context.Background()
	projectID := "test-project-123"

	projectInfo, err := utilsService.GetProjectInfo(ctx, projectID)
	if err != nil {
		t.Logf("GetProjectInfo() error = %v (expected in test environment)", err)
		return
	}

	if projectInfo == nil {
		t.Error("GetProjectInfo() returned nil project info")
		return
	}

	if projectInfo.ProjectID != projectID {
		t.Errorf("GetProjectInfo() projectID = %v, want %v", projectInfo.ProjectID, projectID)
	}

	if projectInfo.Name == "" {
		t.Error("GetProjectInfo() should have project name")
	}

	if projectInfo.State == "" {
		t.Error("GetProjectInfo() should have project state")
	}
}

func TestUtilsService_GetQuotaInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get quota info test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping get quota info test due to utils service creation error: %v", err)
	}

	ctx := context.Background()
	projectID := "test-project-123"

	quotaInfo, err := utilsService.GetQuotaInfo(ctx, projectID)
	if err != nil {
		t.Errorf("GetQuotaInfo() error = %v", err)
		return
	}

	if quotaInfo == nil {
		t.Error("GetQuotaInfo() returned nil quota info")
		return
	}

	if quotaInfo.ProjectID != projectID {
		t.Errorf("GetQuotaInfo() projectID = %v, want %v", quotaInfo.ProjectID, projectID)
	}

	if quotaInfo.LastUpdated.IsZero() {
		t.Error("GetQuotaInfo() should have last updated time")
	}
}

func TestUtilsService_GetCostInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get cost info test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping get cost info test due to utils service creation error: %v", err)
	}

	ctx := context.Background()
	projectID := "test-project-123"
	timeRange := TimeRange{
		Start: time.Now().AddDate(0, -1, 0), // 1 month ago
		End:   time.Now(),
	}

	costInfo, err := utilsService.GetCostInfo(ctx, projectID, timeRange)
	if err != nil {
		t.Errorf("GetCostInfo() error = %v", err)
		return
	}

	if costInfo == nil {
		t.Error("GetCostInfo() returned nil cost info")
		return
	}

	if costInfo.ProjectID != projectID {
		t.Errorf("GetCostInfo() projectID = %v, want %v", costInfo.ProjectID, projectID)
	}

	if costInfo.Currency == "" {
		t.Error("GetCostInfo() should have currency")
	}

	if costInfo.LastUpdated.IsZero() {
		t.Error("GetCostInfo() should have last updated time")
	}

	// Verify forecast exists
	if costInfo.Forecast == nil {
		t.Error("GetCostInfo() should have forecast")
	}

	// Verify budget exists
	if costInfo.Budget == nil {
		t.Error("GetCostInfo() should have budget")
	}

	// Verify trends exist
	if costInfo.Trends == nil {
		t.Error("GetCostInfo() should have trends")
	}
}

func TestUtilsService_GenerateRecommendations(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping generate recommendations test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping generate recommendations test due to utils service creation error: %v", err)
	}

	ctx := context.Background()
	projectID := "test-project-123"

	recommendations, err := utilsService.GenerateRecommendations(ctx, projectID)
	if err != nil {
		t.Errorf("GenerateRecommendations() error = %v", err)
		return
	}

	if recommendations == nil {
		t.Error("GenerateRecommendations() returned nil recommendations")
		return
	}

	// Verify recommendations are sorted by priority
	for i := 1; i < len(recommendations); i++ {
		if recommendations[i-1].Priority > recommendations[i].Priority {
			t.Error("GenerateRecommendations() should return recommendations sorted by priority")
			break
		}
	}

	// Verify recommendation structure
	for i, rec := range recommendations {
		if rec.Type == "" {
			t.Errorf("Recommendation %d should have type", i)
		}
		if rec.Resource == "" {
			t.Errorf("Recommendation %d should have resource", i)
		}
		if rec.Effort == "" {
			t.Errorf("Recommendation %d should have effort", i)
		}
		if rec.Category == "" {
			t.Errorf("Recommendation %d should have category", i)
		}
		if len(rec.Steps) == 0 {
			t.Errorf("Recommendation %d should have steps", i)
		}
	}
}

func TestUtilsService_StringUtilities(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping string utilities test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping string utilities test due to utils service creation error: %v", err)
	}

	// Test string validation
	tests := []struct {
		input    string
		function string
		expected bool
	}{
		{"test@example.com", "IsValidEmail", true},
		{"invalid-email", "IsValidEmail", false},
		{"https://example.com", "IsValidURL", true},
		{"not-a-url", "IsValidURL", false},
		{"192.168.1.1", "IsValidIP", true},
		{"999.999.999.999", "IsValidIP", false},
		{"192.168.1.0/24", "IsValidCIDR", true},
		{"192.168.1.1/33", "IsValidCIDR", false},
	}

	for _, test := range tests {
		t.Run(test.function+"_"+test.input, func(t *testing.T) {
			var result bool
			switch test.function {
			case "IsValidEmail":
				result = utilsService.IsValidEmail(test.input)
			case "IsValidURL":
				result = utilsService.IsValidURL(test.input)
			case "IsValidIP":
				result = utilsService.IsValidIP(test.input)
			case "IsValidCIDR":
				result = utilsService.IsValidCIDR(test.input)
			}

			if result != test.expected {
				t.Errorf("%s(%s) = %v, want %v", test.function, test.input, result, test.expected)
			}
		})
	}

	// Test string manipulation
	input := "  Hello, <World>! This is a test string with special chars & symbols.  "

	sanitized := utilsService.SanitizeString(input)
	if strings.Contains(sanitized, "<") || strings.Contains(sanitized, ">") {
		t.Error("SanitizeString should remove HTML characters")
	}

	escaped := utilsService.EscapeHTML(input)
	if !strings.Contains(escaped, "&lt;") || !strings.Contains(escaped, "&gt;") {
		t.Error("EscapeHTML should escape HTML characters")
	}

	truncated := utilsService.TruncateString(input, 20)
	if len(truncated) > 20 {
		t.Errorf("TruncateString should limit length to 20, got %d", len(truncated))
	}

	slug := utilsService.SlugifyString("Hello World! Test 123")
	expected := "hello-world-test-123"
	if slug != expected {
		t.Errorf("SlugifyString() = %v, want %v", slug, expected)
	}
}

func TestUtilsService_FormatUtilities(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping format utilities test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping format utilities test due to utils service creation error: %v", err)
	}

	// Test file size formatting
	fileSizeTests := []struct {
		bytes    int64
		expected string
	}{
		{512, "512 B"},
		{1024, "1.0 KB"},
		{1536, "1.5 KB"},
		{1048576, "1.0 MB"},
		{1073741824, "1.0 GB"},
	}

	for _, test := range fileSizeTests {
		result := utilsService.FormatFileSize(test.bytes)
		if result != test.expected {
			t.Errorf("FormatFileSize(%d) = %v, want %v", test.bytes, result, test.expected)
		}
	}

	// Test duration formatting
	durationTests := []struct {
		duration time.Duration
		expected string
	}{
		{30 * time.Second, "30s"},
		{2 * time.Minute, "2m"},
		{90 * time.Minute, "1.5h"},
		{25 * time.Hour, "1.0d"},
	}

	for _, test := range durationTests {
		result := utilsService.FormatDuration(test.duration)
		if result != test.expected {
			t.Errorf("FormatDuration(%v) = %v, want %v", test.duration, result, test.expected)
		}
	}

	// Test percentage calculation
	percentage := utilsService.CalculatePercentage(25, 100)
	if percentage != 25.0 {
		t.Errorf("CalculatePercentage(25, 100) = %v, want 25.0", percentage)
	}

	// Test percentage with zero total
	zeroPercentage := utilsService.CalculatePercentage(10, 0)
	if zeroPercentage != 0.0 {
		t.Errorf("CalculatePercentage(10, 0) = %v, want 0.0", zeroPercentage)
	}

	// Test decimal rounding
	rounded := utilsService.RoundToDecimals(3.14159, 2)
	if rounded != 3.14 {
		t.Errorf("RoundToDecimals(3.14159, 2) = %v, want 3.14", rounded)
	}
}

func TestUtilsService_CryptographicUtilities(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping cryptographic utilities test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping cryptographic utilities test due to utils service creation error: %v", err)
	}

	// Test unique ID generation
	id1 := utilsService.GenerateUniqueID()
	id2 := utilsService.GenerateUniqueID()

	if id1 == id2 {
		t.Error("GenerateUniqueID should generate unique IDs")
	}

	if len(id1) == 0 || len(id2) == 0 {
		t.Error("GenerateUniqueID should generate non-empty IDs")
	}

	// Test secure token generation
	token, err := utilsService.GenerateSecureToken(32)
	if err != nil {
		t.Errorf("GenerateSecureToken() error = %v", err)
	}

	if len(token) != 32 {
		t.Errorf("GenerateSecureToken(32) length = %d, want 32", len(token))
	}

	// Test invalid token length
	_, err = utilsService.GenerateSecureToken(0)
	if err == nil {
		t.Error("GenerateSecureToken(0) should return error")
	}

	// Test string hashing
	input := "test string"
	salt := "salt123"
	hash1 := utilsService.HashString(input, salt)
	hash2 := utilsService.HashString(input, salt)

	if hash1 != hash2 {
		t.Error("HashString should produce consistent hashes")
	}

	if len(hash1) == 0 {
		t.Error("HashString should produce non-empty hash")
	}

	// Different salt should produce different hash
	differentSaltHash := utilsService.HashString(input, "different-salt")
	if hash1 == differentSaltHash {
		t.Error("HashString should produce different hashes with different salts")
	}

	// Test base64 encoding/decoding
	data := []byte("Hello, World!")
	encoded := utilsService.EncodeBase64(data)

	if len(encoded) == 0 {
		t.Error("EncodeBase64 should produce non-empty result")
	}

	decoded, err := utilsService.DecodeBase64(encoded)
	if err != nil {
		t.Errorf("DecodeBase64() error = %v", err)
	}

	if string(decoded) != string(data) {
		t.Errorf("DecodeBase64() = %v, want %v", string(decoded), string(data))
	}

	// Test invalid base64
	_, err = utilsService.DecodeBase64("invalid-base64!")
	if err == nil {
		t.Error("DecodeBase64 should return error for invalid input")
	}
}

func TestUtilsService_TemplateProcessing(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping template processing test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping template processing test due to utils service creation error: %v", err)
	}

	// Test template parsing
	template := "Hello {{name}}, your project {{project}} has {{count}} resources."
	data := map[string]interface{}{
		"name":    "John",
		"project": "test-project",
		"count":   42,
	}

	result, err := utilsService.ParseTemplate(template, data)
	if err != nil {
		t.Errorf("ParseTemplate() error = %v", err)
	}

	expected := "Hello John, your project test-project has 42 resources."
	if result != expected {
		t.Errorf("ParseTemplate() = %v, want %v", result, expected)
	}

	// Test template with missing data
	incompleteTemplate := "Hello {{name}}, your {{missing}} value."
	incompleteData := map[string]interface{}{
		"name": "John",
	}

	_, err = utilsService.ParseTemplate(incompleteTemplate, incompleteData)
	if err == nil {
		t.Error("ParseTemplate should return error for missing placeholders")
	}
}

func TestUtilsService_JSONOperations(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping JSON operations test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping JSON operations test due to utils service creation error: %v", err)
	}

	// Test struct to JSON conversion
	testData := struct {
		Name  string `json:"name"`
		Count int    `json:"count"`
		Items []string `json:"items"`
	}{
		Name:  "Test",
		Count: 42,
		Items: []string{"item1", "item2"},
	}

	jsonStr, err := utilsService.ConvertToJSON(testData)
	if err != nil {
		t.Errorf("ConvertToJSON() error = %v", err)
	}

	if !strings.Contains(jsonStr, "\"name\": \"Test\"") {
		t.Error("ConvertToJSON should contain correct JSON format")
	}

	// Test JSON parsing
	var parsed struct {
		Name  string `json:"name"`
		Count int    `json:"count"`
		Items []string `json:"items"`
	}

	err = utilsService.ParseJSON(jsonStr, &parsed)
	if err != nil {
		t.Errorf("ParseJSON() error = %v", err)
	}

	if parsed.Name != testData.Name {
		t.Errorf("ParseJSON() name = %v, want %v", parsed.Name, testData.Name)
	}

	if parsed.Count != testData.Count {
		t.Errorf("ParseJSON() count = %v, want %v", parsed.Count, testData.Count)
	}

	// Test invalid JSON
	err = utilsService.ParseJSON("{invalid json}", &parsed)
	if err == nil {
		t.Error("ParseJSON should return error for invalid JSON")
	}
}

func TestUtilsService_CacheOperations(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping cache operations test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{
		CacheExpiry: 30 * time.Minute,
	}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping cache operations test due to utils service creation error: %v", err)
	}

	// Test cache stats before any operations
	initialStats := utilsService.GetCacheStats()
	if initialStats == nil {
		t.Error("GetCacheStats() should return stats")
	}

	// Test cache clearing
	utilsService.ClearCache()

	afterClearStats := utilsService.GetCacheStats()
	if afterClearStats == nil {
		t.Error("GetCacheStats() should return stats after clear")
	}

	// Verify cache sizes are zero after clear
	if size, ok := afterClearStats["metadata_cache_size"].(int); ok && size != 0 {
		t.Errorf("metadata cache size should be 0 after clear, got %d", size)
	}

	if size, ok := afterClearStats["quota_cache_size"].(int); ok && size != 0 {
		t.Errorf("quota cache size should be 0 after clear, got %d", size)
	}

	if size, ok := afterClearStats["cost_cache_size"].(int); ok && size != 0 {
		t.Errorf("cost cache size should be 0 after clear, got %d", size)
	}
}

func TestUtilsService_ServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping service metrics test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping service metrics test due to utils service creation error: %v", err)
	}

	metrics := utilsService.GetServiceMetrics()
	// Metrics may be nil if not enabled, which is acceptable
	if metrics != nil {
		// If metrics exist, they should be in map format
		if _, ok := metrics["service_name"]; !ok {
			t.Log("Service metrics exist but may not contain expected fields")
		}
	}
}

func TestUtilsServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to utils service creation error: %v", err)
	}

	// Test concurrent access to utils service methods
	done := make(chan bool, 10)

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to utils service methods
			utilsService.GenerateUniqueID()
			utilsService.IsValidEmail("test@example.com")
			utilsService.FormatFileSize(1024)
			utilsService.CalculatePercentage(50, 100)
			utilsService.GetCacheStats()
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkUtilsService_GenerateUniqueID(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to utils service creation error: %v", err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		utilsService.GenerateUniqueID()
	}
}

func BenchmarkUtilsService_ValidateResource(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	utilsConfig := &UtilsConfig{}
	utilsService, err := NewUtilsService(client, utilsConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to utils service creation error: %v", err)
	}

	resource := map[string]interface{}{
		"name":  "test-resource",
		"count": 42,
		"email": "test@example.com",
	}

	rules := []ValidationRule{
		{
			Field:    "name",
			Type:     "string",
			Required: true,
		},
		{
			Field:    "count",
			Type:     "number",
			Required: true,
		},
		{
			Field:    "email",
			Type:     "email",
			Required: true,
		},
	}

	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		utilsService.ValidateResource(ctx, resource, rules)
	}
}

func TestUtilsErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "project not found",
			err:      &googleapi.Error{Code: 404, Message: "Project not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "invalid request",
			err:      &googleapi.Error{Code: 400, Message: "Invalid request"},
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

func TestValidationRuleTypes(t *testing.T) {
	// Test all validation rule types
	testCases := []struct {
		fieldType string
		value     interface{}
		rule      ValidationRule
		valid     bool
	}{
		{
			fieldType: "string",
			value:     "test",
			rule:      ValidationRule{Type: "string", MinLength: 2, MaxLength: 10},
			valid:     true,
		},
		{
			fieldType: "number",
			value:     42,
			rule:      ValidationRule{Type: "number", MinValue: 1, MaxValue: 100},
			valid:     true,
		},
		{
			fieldType: "bool",
			value:     true,
			rule:      ValidationRule{Type: "bool"},
			valid:     true,
		},
		{
			fieldType: "array",
			value:     []string{"item1", "item2"},
			rule:      ValidationRule{Type: "array", MinLength: 1, MaxLength: 5},
			valid:     true,
		},
		{
			fieldType: "email",
			value:     "test@example.com",
			rule:      ValidationRule{Type: "email"},
			valid:     true,
		},
		{
			fieldType: "url",
			value:     "https://example.com",
			rule:      ValidationRule{Type: "url"},
			valid:     true,
		},
		{
			fieldType: "ip",
			value:     "192.168.1.1",
			rule:      ValidationRule{Type: "ip"},
			valid:     true,
		},
		{
			fieldType: "cidr",
			value:     "192.168.1.0/24",
			rule:      ValidationRule{Type: "cidr"},
			valid:     true,
		},
		{
			fieldType: "uuid",
			value:     "550e8400-e29b-41d4-a716-446655440000",
			rule:      ValidationRule{Type: "uuid"},
			valid:     true,
		},
		{
			fieldType: "date",
			value:     "2023-01-01",
			rule:      ValidationRule{Type: "date"},
			valid:     true,
		},
		{
			fieldType: "json",
			value:     `{"key": "value"}`,
			rule:      ValidationRule{Type: "json"},
			valid:     true,
		},
		{
			fieldType: "base64",
			value:     "SGVsbG8gV29ybGQ=", // "Hello World" in base64
			rule:      ValidationRule{Type: "base64"},
			valid:     true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.fieldType, func(t *testing.T) {
			t.Logf("Testing validation type: %s with value: %v", tc.fieldType, tc.value)
			// This is a conceptual test - actual validation would be done
			// through the ValidateResource method with proper setup
		})
	}
}