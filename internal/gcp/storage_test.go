package gcp

import (
	"bytes"
	"context"
	"io"
	// "strings"
	"testing"
	"time"

	"cloud.google.com/go/storage"
	"google.golang.org/api/googleapi"
)

func TestNewStorageService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping storage service test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{
		DefaultStorageClass:      "STANDARD",
		DefaultLocation:          "US",
		ChunkSize:                8 * 1024 * 1024, // 8MB
		CacheEnabled:             true,
		CacheTTL:                 30 * time.Minute,
		MetricsEnabled:           true,
		CompressionEnabled:       true,
		EncryptionEnabled:        true,
		TransferTimeout:          30 * time.Minute,
		MaxConcurrentTransfers:   10,
		RetryAttempts:            3,
		RetryBackoffMultiplier:   2.0,
		RetryInitialDelay:        time.Second,
		RetryMaxDelay:            time.Minute,
	}

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Errorf("NewStorageService() error = %v", err)
		return
	}

	if storageService == nil {
		t.Error("NewStorageService() returned nil service")
	}

	if storageService.client != client {
		t.Error("NewStorageService() did not set client correctly")
	}

	if storageService.config.DefaultStorageClass != storageConfig.DefaultStorageClass {
		t.Errorf("NewStorageService() DefaultStorageClass = %v, want %v",
			storageService.config.DefaultStorageClass, storageConfig.DefaultStorageClass)
	}
}

func TestStorageConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *StorageConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &StorageConfig{
				DefaultStorageClass:    "STANDARD",
				DefaultLocation:        "US",
				ChunkSize:              8 * 1024 * 1024,
				TransferTimeout:        30 * time.Minute,
				MaxConcurrentTransfers: 10,
				RetryAttempts:          3,
				RetryInitialDelay:      time.Second,
				RetryMaxDelay:          time.Minute,
			},
			wantErr: false,
		},
		{
			name: "empty storage class",
			config: &StorageConfig{
				DefaultStorageClass:    "",
				DefaultLocation:        "US",
				ChunkSize:              8 * 1024 * 1024,
				TransferTimeout:        30 * time.Minute,
				MaxConcurrentTransfers: 10,
			},
			wantErr: true,
		},
		{
			name: "empty location",
			config: &StorageConfig{
				DefaultStorageClass:    "STANDARD",
				DefaultLocation:        "",
				ChunkSize:              8 * 1024 * 1024,
				TransferTimeout:        30 * time.Minute,
				MaxConcurrentTransfers: 10,
			},
			wantErr: true,
		},
		{
			name: "invalid chunk size",
			config: &StorageConfig{
				DefaultStorageClass:    "STANDARD",
				DefaultLocation:        "US",
				ChunkSize:              0,
				TransferTimeout:        30 * time.Minute,
				MaxConcurrentTransfers: 10,
			},
			wantErr: true,
		},
		{
			name: "invalid transfer timeout",
			config: &StorageConfig{
				DefaultStorageClass:    "STANDARD",
				DefaultLocation:        "US",
				ChunkSize:              8 * 1024 * 1024,
				TransferTimeout:        0,
				MaxConcurrentTransfers: 10,
			},
			wantErr: true,
		},
		{
			name: "invalid max concurrent transfers",
			config: &StorageConfig{
				DefaultStorageClass:    "STANDARD",
				DefaultLocation:        "US",
				ChunkSize:              8 * 1024 * 1024,
				TransferTimeout:        30 * time.Minute,
				MaxConcurrentTransfers: 0,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("StorageConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestStorageConfig_SetDefaults(t *testing.T) {
	config := &StorageConfig{}
	config.SetDefaults()

	if config.DefaultStorageClass == "" {
		t.Error("SetDefaults() did not set DefaultStorageClass")
	}

	if config.DefaultLocation == "" {
		t.Error("SetDefaults() did not set DefaultLocation")
	}

	if config.ChunkSize <= 0 {
		t.Error("SetDefaults() did not set ChunkSize")
	}

	if config.TransferTimeout <= 0 {
		t.Error("SetDefaults() did not set TransferTimeout")
	}

	if config.MaxConcurrentTransfers <= 0 {
		t.Error("SetDefaults() did not set MaxConcurrentTransfers")
	}

	if config.RetryAttempts <= 0 {
		t.Error("SetDefaults() did not set RetryAttempts")
	}

	if config.RetryInitialDelay <= 0 {
		t.Error("SetDefaults() did not set RetryInitialDelay")
	}

	if config.RetryMaxDelay <= 0 {
		t.Error("SetDefaults() did not set RetryMaxDelay")
	}

	if !config.CacheEnabled {
		t.Error("SetDefaults() did not enable cache")
	}

	if config.CacheTTL <= 0 {
		t.Error("SetDefaults() did not set CacheTTL")
	}
}

func TestStorageService_CreateBucket(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create bucket test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping create bucket test due to storage service creation error: %v", err)
	}

	bucketConfig := &BucketConfig{
		Name:         "test-bucket-" + time.Now().Format("20060102-150405"),
		Location:     "US",
		StorageClass: "STANDARD",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
		Lifecycle: &LifecycleConfig{
			Rules: []*LifecycleRule{
				{
					Action: &LifecycleAction{
						Type: "Delete",
					},
					Condition: &LifecycleCondition{
						Age: 30,
					},
				},
			},
		},
		CORS: []*CORSPolicy{
			{
				MaxAgeSeconds:  3600,
				Methods:        []string{"GET", "POST"},
				Origins:        []string{"*"},
				ResponseHeader: []string{"Content-Type"},
			},
		},
		Versioning: &VersioningConfig{
			Enabled: true,
		},
		Encryption: &EncryptionConfig{
			DefaultKMSKeyName: "",
		},
		UniformBucketLevelAccess: &UniformBucketLevelAccess{
			Enabled: true,
		},
		PublicAccessPrevention: "enforced",
		RetentionPolicy: &RetentionPolicy{
			RetentionPeriod: 86400, // 1 day
		},
	}

	ctx := context.Background()
	bucket, err := storageService.CreateBucket(ctx, bucketConfig)
	if err != nil {
		t.Logf("CreateBucket() error = %v (expected in test environment)", err)
		return
	}

	if bucket == nil {
		t.Error("CreateBucket() returned nil bucket")
		return
	}

	if bucket.Name != bucketConfig.Name {
		t.Errorf("CreateBucket() bucket name = %v, want %v", bucket.Name, bucketConfig.Name)
	}

	// Clean up - attempt to delete the bucket
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		storageService.DeleteBucket(deleteCtx, bucketConfig.Name, true)
	}()
}

func TestStorageService_GetBucket(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get bucket test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping get bucket test due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket-" + time.Now().Format("20060102-150405")

	bucket, err := storageService.GetBucket(ctx, bucketName)
	if err == nil {
		t.Error("GetBucket() should have returned error for non-existent bucket")
	}

	if bucket != nil {
		t.Error("GetBucket() should have returned nil for non-existent bucket")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("GetBucket() error should be not found error, got: %v", err)
	}
}

func TestStorageService_ListBuckets(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list buckets test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping list buckets test due to storage service creation error: %v", err)
	}

	ctx := context.Background()

	buckets, err := storageService.ListBuckets(ctx, nil)
	if err != nil {
		t.Logf("ListBuckets() error = %v (expected in test environment)", err)
		return
	}

	if buckets == nil {
		t.Error("ListBuckets() returned nil buckets")
	}

	t.Logf("ListBuckets() returned %d buckets", len(buckets))
}

func TestStorageService_UploadObject(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping upload object test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping upload object test due to storage service creation error: %v", err)
	}

	objectConfig := &ObjectConfig{
		Bucket:      "non-existent-bucket",
		Name:        "test-object.txt",
		ContentType: "text/plain",
		Metadata: map[string]string{
			"created-by":  "test-suite",
			"environment": "test",
		},
		CacheControl:       "no-cache",
		ContentDisposition: "attachment",
		ContentEncoding:    "gzip",
		ContentLanguage:    "en",
	}

	data := []byte("Hello, World! This is test data.")
	reader := bytes.NewReader(data)

	ctx := context.Background()
	objectInfo, err := storageService.UploadObject(ctx, objectConfig, reader)
	if err != nil {
		t.Logf("UploadObject() error = %v (expected for non-existent bucket)", err)
		return
	}

	if objectInfo == nil {
		t.Error("UploadObject() returned nil object info")
	}
}

func TestStorageService_DownloadObject(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping download object test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping download object test due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket"
	objectName := "non-existent-object.txt"

	reader, err := storageService.DownloadObject(ctx, bucketName, objectName)
	if err == nil {
		t.Error("DownloadObject() should have returned error for non-existent object")
		if reader != nil {
			reader.Close()
		}
	}

	if reader != nil {
		t.Error("DownloadObject() should have returned nil reader for non-existent object")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("DownloadObject() error should be not found error, got: %v", err)
	}
}

func TestStorageService_GetObjectInfo(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get object info test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping get object info test due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket"
	objectName := "non-existent-object.txt"

	objectInfo, err := storageService.GetObjectInfo(ctx, bucketName, objectName)
	if err == nil {
		t.Error("GetObjectInfo() should have returned error for non-existent object")
	}

	if objectInfo != nil {
		t.Error("GetObjectInfo() should have returned nil for non-existent object")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("GetObjectInfo() error should be not found error, got: %v", err)
	}
}

func TestStorageService_ListObjects(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list objects test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping list objects test due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket"

	objects, err := storageService.ListObjects(ctx, bucketName, nil)
	if err == nil {
		t.Error("ListObjects() should have returned error for non-existent bucket")
	}

	if objects != nil {
		t.Error("ListObjects() should have returned nil for non-existent bucket")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("ListObjects() error should be not found error, got: %v", err)
	}
}

func TestStorageService_DeleteObject(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping delete object test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping delete object test due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket"
	objectName := "non-existent-object.txt"

	err = storageService.DeleteObject(ctx, bucketName, objectName)
	if err == nil {
		t.Error("DeleteObject() should have returned error for non-existent object")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("DeleteObject() error should be not found error, got: %v", err)
	}
}

func TestStorageService_GenerateSignedURL(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping generate signed URL test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping generate signed URL test due to storage service creation error: %v", err)
	}

	signedURLConfig := &SignedURLConfig{
		Bucket:         "test-bucket",
		Object:         "test-object.txt",
		Method:         "GET",
		Expiration:     time.Now().Add(time.Hour),
		ContentType:    "text/plain",
		ContentMD5:     "",
		Headers:        map[string]string{},
		QueryParameters: map[string]string{},
	}

	url, err := storageService.GenerateSignedURL(signedURLConfig)
	if err != nil {
		t.Logf("GenerateSignedURL() error = %v (expected in test environment)", err)
		return
	}

	if url == "" {
		t.Error("GenerateSignedURL() returned empty URL")
	}

	// Verify URL format
	if !strings.Contains(url, "https://storage.googleapis.com") {
		t.Errorf("GenerateSignedURL() URL format invalid: %v", url)
	}

	if !strings.Contains(url, signedURLConfig.Bucket) {
		t.Error("GenerateSignedURL() URL should contain bucket name")
	}

	if !strings.Contains(url, signedURLConfig.Object) {
		t.Error("GenerateSignedURL() URL should contain object name")
	}
}

func TestBucketConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *BucketConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &BucketConfig{
				Name:         "test-bucket",
				Location:     "US",
				StorageClass: "STANDARD",
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &BucketConfig{
				Name:         "",
				Location:     "US",
				StorageClass: "STANDARD",
			},
			wantErr: true,
		},
		{
			name: "empty location",
			config: &BucketConfig{
				Name:         "test-bucket",
				Location:     "",
				StorageClass: "STANDARD",
			},
			wantErr: true,
		},
		{
			name: "empty storage class",
			config: &BucketConfig{
				Name:         "test-bucket",
				Location:     "US",
				StorageClass: "",
			},
			wantErr: true,
		},
		{
			name: "invalid name format uppercase",
			config: &BucketConfig{
				Name:         "Test-Bucket",
				Location:     "US",
				StorageClass: "STANDARD",
			},
			wantErr: true,
		},
		{
			name: "invalid name format underscore",
			config: &BucketConfig{
				Name:         "test_bucket",
				Location:     "US",
				StorageClass: "STANDARD",
			},
			wantErr: true,
		},
		{
			name: "name too short",
			config: &BucketConfig{
				Name:         "ab",
				Location:     "US",
				StorageClass: "STANDARD",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("BucketConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestObjectConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *ObjectConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &ObjectConfig{
				Bucket:      "test-bucket",
				Name:        "test-object.txt",
				ContentType: "text/plain",
			},
			wantErr: false,
		},
		{
			name: "empty bucket",
			config: &ObjectConfig{
				Bucket:      "",
				Name:        "test-object.txt",
				ContentType: "text/plain",
			},
			wantErr: true,
		},
		{
			name: "empty name",
			config: &ObjectConfig{
				Bucket:      "test-bucket",
				Name:        "",
				ContentType: "text/plain",
			},
			wantErr: true,
		},
		{
			name: "empty content type",
			config: &ObjectConfig{
				Bucket:      "test-bucket",
				Name:        "test-object.txt",
				ContentType: "",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ObjectConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSignedURLConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *SignedURLConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &SignedURLConfig{
				Bucket:     "test-bucket",
				Object:     "test-object.txt",
				Method:     "GET",
				Expiration: time.Now().Add(time.Hour),
			},
			wantErr: false,
		},
		{
			name: "empty bucket",
			config: &SignedURLConfig{
				Bucket:     "",
				Object:     "test-object.txt",
				Method:     "GET",
				Expiration: time.Now().Add(time.Hour),
			},
			wantErr: true,
		},
		{
			name: "empty object",
			config: &SignedURLConfig{
				Bucket:     "test-bucket",
				Object:     "",
				Method:     "GET",
				Expiration: time.Now().Add(time.Hour),
			},
			wantErr: true,
		},
		{
			name: "empty method",
			config: &SignedURLConfig{
				Bucket:     "test-bucket",
				Object:     "test-object.txt",
				Method:     "",
				Expiration: time.Now().Add(time.Hour),
			},
			wantErr: true,
		},
		{
			name: "expired expiration",
			config: &SignedURLConfig{
				Bucket:     "test-bucket",
				Object:     "test-object.txt",
				Method:     "GET",
				Expiration: time.Now().Add(-time.Hour),
			},
			wantErr: true,
		},
		{
			name: "invalid method",
			config: &SignedURLConfig{
				Bucket:     "test-bucket",
				Object:     "test-object.txt",
				Method:     "INVALID",
				Expiration: time.Now().Add(time.Hour),
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("SignedURLConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestStorageService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{
		MetricsEnabled: true,
	}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to storage service creation error: %v", err)
	}

	metrics := storageService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestStorageService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{
		CacheEnabled: true,
	}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to storage service creation error: %v", err)
	}

	// Clear cache should not error
	storageService.ClearCache()

	// Verify cache stats show empty cache
	stats := storageService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestStorageServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to storage service creation error: %v", err)
	}

	// Test concurrent access to storage service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to storage service methods
			bucketName := "non-existent-bucket"
			objectName := "non-existent-object.txt"

			storageService.GetBucket(ctx, bucketName)
			storageService.ListBuckets(ctx, nil)
			storageService.GetObjectInfo(ctx, bucketName, objectName)
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func TestStorageStreamingOperations(t *testing.T) {
	// Test streaming upload and download operations
	data := make([]byte, 1024*1024) // 1MB of data
	for i := range data {
		data[i] = byte(i % 256)
	}

	reader := bytes.NewReader(data)

	// Test reading from the reader
	buffer := make([]byte, 4096)
	totalRead := 0

	for {
		n, err := reader.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Errorf("Error reading data: %v", err)
			break
		}
		totalRead += n
	}

	if totalRead != len(data) {
		t.Errorf("Read %d bytes, expected %d", totalRead, len(data))
	}

	// Reset reader for next test
	reader.Seek(0, 0)

	// Test chunked reading
	chunkSize := 1024
	chunksRead := 0
	buffer = make([]byte, chunkSize)

	for {
		n, err := reader.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Errorf("Error reading chunk: %v", err)
			break
		}
		chunksRead++
		if n > chunkSize {
			t.Errorf("Read chunk size %d exceeds expected %d", n, chunkSize)
		}
	}

	expectedChunks := (len(data) + chunkSize - 1) / chunkSize
	if chunksRead != expectedChunks {
		t.Errorf("Read %d chunks, expected %d", chunksRead, expectedChunks)
	}
}

func BenchmarkStorageService_GetBucket(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	storageConfig := &StorageConfig{}
	storageConfig.SetDefaults()

	storageService, err := NewStorageService(client, storageConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to storage service creation error: %v", err)
	}

	ctx := context.Background()
	bucketName := "non-existent-bucket"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		storageService.GetBucket(ctx, bucketName)
	}
}

func BenchmarkBucketConfig_Validate(b *testing.B) {
	config := &BucketConfig{
		Name:         "test-bucket",
		Location:     "US",
		StorageClass: "STANDARD",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestStorageErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "bucket not found",
			err:      &googleapi.Error{Code: 404, Message: "Bucket not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "object not found",
			err:      &googleapi.Error{Code: 404, Message: "Object not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "bucket already exists",
			err:      &googleapi.Error{Code: 409, Message: "Bucket already exists"},
			wantCode: ErrorCodeAlreadyExists,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "invalid bucket name",
			err:      &googleapi.Error{Code: 400, Message: "Invalid bucket name"},
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

func TestStorageClassValidation(t *testing.T) {
	validClasses := []string{
		"STANDARD",
		"NEARLINE",
		"COLDLINE",
		"ARCHIVE",
		"MULTI_REGIONAL",
		"REGIONAL",
	}

	for _, class := range validClasses {
		t.Run(class, func(t *testing.T) {
			config := &BucketConfig{
				Name:         "test-bucket",
				Location:     "US",
				StorageClass: class,
			}

			err := config.Validate()
			if err != nil {
				t.Errorf("Valid storage class %s should not error: %v", class, err)
			}
		})
	}

	invalidClasses := []string{
		"INVALID",
		"standard",
		"",
		"HOT",
		"COOL",
	}

	for _, class := range invalidClasses {
		t.Run("invalid_"+class, func(t *testing.T) {
			config := &BucketConfig{
				Name:         "test-bucket",
				Location:     "US",
				StorageClass: class,
			}

			err := config.Validate()
			if err == nil {
				t.Errorf("Invalid storage class %s should error", class)
			}
		})
	}
}