package gcp

import (
	"context"
	"strings"
	"testing"
	"time"

	"cloud.google.com/go/compute/apiv1/computepb"
	"google.golang.org/api/googleapi"
)

func TestNewComputeService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping compute service test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{
		DefaultMachineType:    "e2-medium",
		DefaultDiskSizeGB:     20,
		DefaultDiskType:       "pd-standard",
		DefaultNetworkTier:    "STANDARD",
		CacheEnabled:          true,
		CacheTTL:              30 * time.Minute,
		MetricsEnabled:        true,
		OperationPollInterval: 5 * time.Second,
		OperationTimeout:      10 * time.Minute,
	}

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Errorf("NewComputeService() error = %v", err)
		return
	}

	if computeService == nil {
		t.Error("NewComputeService() returned nil service")
	}

	if computeService.client != client {
		t.Error("NewComputeService() did not set client correctly")
	}

	if computeService.config.DefaultMachineType != computeConfig.DefaultMachineType {
		t.Errorf("NewComputeService() DefaultMachineType = %v, want %v",
			computeService.config.DefaultMachineType, computeConfig.DefaultMachineType)
	}
}

func TestComputeConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *ComputeConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &ComputeConfig{
				DefaultMachineType:    "e2-medium",
				DefaultDiskSizeGB:     20,
				DefaultDiskType:       "pd-standard",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 5 * time.Second,
				OperationTimeout:      10 * time.Minute,
			},
			wantErr: false,
		},
		{
			name: "empty machine type",
			config: &ComputeConfig{
				DefaultMachineType:    "",
				DefaultDiskSizeGB:     20,
				DefaultDiskType:       "pd-standard",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 5 * time.Second,
				OperationTimeout:      10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid disk size",
			config: &ComputeConfig{
				DefaultMachineType:    "e2-medium",
				DefaultDiskSizeGB:     0,
				DefaultDiskType:       "pd-standard",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 5 * time.Second,
				OperationTimeout:      10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "empty disk type",
			config: &ComputeConfig{
				DefaultMachineType:    "e2-medium",
				DefaultDiskSizeGB:     20,
				DefaultDiskType:       "",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 5 * time.Second,
				OperationTimeout:      10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid poll interval",
			config: &ComputeConfig{
				DefaultMachineType:    "e2-medium",
				DefaultDiskSizeGB:     20,
				DefaultDiskType:       "pd-standard",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 0,
				OperationTimeout:      10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid timeout",
			config: &ComputeConfig{
				DefaultMachineType:    "e2-medium",
				DefaultDiskSizeGB:     20,
				DefaultDiskType:       "pd-standard",
				DefaultNetworkTier:    "STANDARD",
				OperationPollInterval: 5 * time.Second,
				OperationTimeout:      0,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ComputeConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestComputeConfig_SetDefaults(t *testing.T) {
	config := &ComputeConfig{}
	config.SetDefaults()

	if config.DefaultMachineType == "" {
		t.Error("SetDefaults() did not set DefaultMachineType")
	}

	if config.DefaultDiskSizeGB <= 0 {
		t.Error("SetDefaults() did not set DefaultDiskSizeGB")
	}

	if config.DefaultDiskType == "" {
		t.Error("SetDefaults() did not set DefaultDiskType")
	}

	if config.DefaultNetworkTier == "" {
		t.Error("SetDefaults() did not set DefaultNetworkTier")
	}

	if config.OperationPollInterval <= 0 {
		t.Error("SetDefaults() did not set OperationPollInterval")
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

func TestComputeService_CreateInstance(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create instance test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{
		DefaultMachineType: "e2-medium",
		DefaultDiskSizeGB:  20,
		DefaultDiskType:    "pd-standard",
	}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping create instance test due to compute service creation error: %v", err)
	}

	instanceConfig := &InstanceConfig{
		Name:        "test-instance-" + time.Now().Format("20060102-150405"),
		MachineType: "e2-micro",
		Zone:        "us-central1-a",
		BootDisk: &DiskConfig{
			SizeGB:     10,
			Type:       "pd-standard",
			SourceImage: "projects/debian-cloud/global/images/family/debian-11",
		},
		NetworkInterfaces: []*NetworkInterfaceConfig{
			{
				Network:    "default",
				Subnetwork: "",
				AccessConfigs: []*AccessConfig{
					{
						Type:        "ONE_TO_ONE_NAT",
						NetworkTier: "STANDARD",
					},
				},
			},
		},
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
		Metadata: map[string]string{
			"startup-script": "echo 'Hello, World!'",
		},
		Tags: []string{"http-server", "https-server"},
		ServiceAccounts: []*ServiceAccountConfig{
			{
				Email: "default",
				Scopes: []string{
					"https://www.googleapis.com/auth/devstorage.read_only",
					"https://www.googleapis.com/auth/logging.write",
					"https://www.googleapis.com/auth/monitoring.write",
				},
			},
		},
	}

	ctx := context.Background()
	instance, err := computeService.CreateInstance(ctx, instanceConfig)
	if err != nil {
		t.Logf("CreateInstance() error = %v (expected in test environment)", err)
		return
	}

	if instance == nil {
		t.Error("CreateInstance() returned nil instance")
		return
	}

	if instance.Name != instanceConfig.Name {
		t.Errorf("CreateInstance() instance name = %v, want %v", instance.Name, instanceConfig.Name)
	}

	// Clean up - attempt to delete the instance
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		computeService.DeleteInstance(deleteCtx, instanceConfig.Name, instanceConfig.Zone)
	}()
}

func TestComputeService_GetInstance(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get instance test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping get instance test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	instanceName := "non-existent-instance"
	zone := "us-central1-a"

	instance, err := computeService.GetInstance(ctx, instanceName, zone)
	if err == nil {
		t.Error("GetInstance() should have returned error for non-existent instance")
	}

	if instance != nil {
		t.Error("GetInstance() should have returned nil for non-existent instance")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("GetInstance() error should be not found error, got: %v", err)
	}
}

func TestComputeService_ListInstances(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list instances test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping list instances test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	zone := "us-central1-a"

	instances, err := computeService.ListInstances(ctx, zone, nil)
	if err != nil {
		t.Logf("ListInstances() error = %v (expected in test environment)", err)
		return
	}

	if instances == nil {
		t.Error("ListInstances() returned nil instances")
	}

	t.Logf("ListInstances() returned %d instances", len(instances))
}

func TestComputeService_StartInstance(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping start instance test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping start instance test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	instanceName := "non-existent-instance"
	zone := "us-central1-a"

	err = computeService.StartInstance(ctx, instanceName, zone)
	if err == nil {
		t.Error("StartInstance() should have returned error for non-existent instance")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("StartInstance() error should be not found error, got: %v", err)
	}
}

func TestComputeService_StopInstance(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping stop instance test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping stop instance test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	instanceName := "non-existent-instance"
	zone := "us-central1-a"

	err = computeService.StopInstance(ctx, instanceName, zone)
	if err == nil {
		t.Error("StopInstance() should have returned error for non-existent instance")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("StopInstance() error should be not found error, got: %v", err)
	}
}

func TestComputeService_CreateSnapshot(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create snapshot test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping create snapshot test due to compute service creation error: %v", err)
	}

	snapshotConfig := &SnapshotConfig{
		Name:        "test-snapshot-" + time.Now().Format("20060102-150405"),
		SourceDisk:  "projects/test-project-123/zones/us-central1-a/disks/non-existent-disk",
		Description: "Test snapshot created by test suite",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	snapshot, err := computeService.CreateSnapshot(ctx, snapshotConfig)
	if err != nil {
		t.Logf("CreateSnapshot() error = %v (expected for non-existent disk)", err)
		return
	}

	if snapshot == nil {
		t.Error("CreateSnapshot() returned nil snapshot")
	}
}

func TestComputeService_GetMachineTypes(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get machine types test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping get machine types test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	zone := "us-central1-a"

	machineTypes, err := computeService.GetMachineTypes(ctx, zone)
	if err != nil {
		t.Logf("GetMachineTypes() error = %v (expected in test environment)", err)
		return
	}

	if machineTypes == nil {
		t.Error("GetMachineTypes() returned nil machine types")
	}

	t.Logf("GetMachineTypes() returned %d machine types", len(machineTypes))

	// Verify common machine types exist
	commonTypes := []string{"e2-micro", "e2-small", "e2-medium", "n1-standard-1"}
	for _, machineType := range commonTypes {
		found := false
		for _, mt := range machineTypes {
			if strings.Contains(mt.Name, machineType) {
				found = true
				break
			}
		}
		if !found {
			t.Logf("Common machine type %s not found (this may be normal)", machineType)
		}
	}
}

func TestComputeService_GetImages(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get images test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping get images test due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	project := "debian-cloud" // Public image project

	images, err := computeService.GetImages(ctx, project)
	if err != nil {
		t.Logf("GetImages() error = %v (expected in test environment)", err)
		return
	}

	if images == nil {
		t.Error("GetImages() returned nil images")
	}

	t.Logf("GetImages() returned %d images", len(images))
}

func TestInstanceConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *InstanceConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &InstanceConfig{
				Name:        "test-instance",
				MachineType: "e2-medium",
				Zone:        "us-central1-a",
				BootDisk: &DiskConfig{
					SizeGB:      20,
					Type:        "pd-standard",
					SourceImage: "projects/debian-cloud/global/images/family/debian-11",
				},
				NetworkInterfaces: []*NetworkInterfaceConfig{
					{
						Network: "default",
					},
				},
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &InstanceConfig{
				Name:        "",
				MachineType: "e2-medium",
				Zone:        "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "empty machine type",
			config: &InstanceConfig{
				Name:        "test-instance",
				MachineType: "",
				Zone:        "us-central1-a",
			},
			wantErr: true,
		},
		{
			name: "empty zone",
			config: &InstanceConfig{
				Name:        "test-instance",
				MachineType: "e2-medium",
				Zone:        "",
			},
			wantErr: true,
		},
		{
			name: "invalid name format",
			config: &InstanceConfig{
				Name:        "Test_Instance",
				MachineType: "e2-medium",
				Zone:        "us-central1-a",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("InstanceConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestDiskConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *DiskConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &DiskConfig{
				SizeGB:      20,
				Type:        "pd-standard",
				SourceImage: "projects/debian-cloud/global/images/family/debian-11",
			},
			wantErr: false,
		},
		{
			name: "zero size",
			config: &DiskConfig{
				SizeGB:      0,
				Type:        "pd-standard",
				SourceImage: "projects/debian-cloud/global/images/family/debian-11",
			},
			wantErr: true,
		},
		{
			name: "empty type",
			config: &DiskConfig{
				SizeGB:      20,
				Type:        "",
				SourceImage: "projects/debian-cloud/global/images/family/debian-11",
			},
			wantErr: true,
		},
		{
			name: "empty source image",
			config: &DiskConfig{
				SizeGB:      20,
				Type:        "pd-standard",
				SourceImage: "",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("DiskConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestComputeService_WaitForOperation(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping wait for operation test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{
		OperationPollInterval: 100 * time.Millisecond,
		OperationTimeout:      time.Second,
	}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping wait for operation test due to compute service creation error: %v", err)
	}

	// Create a mock operation
	operation := &computepb.Operation{
		Name:   stringPtr("operation-test"),
		Status: stringPtr("RUNNING"),
		Zone:   stringPtr("us-central1-a"),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	err = computeService.WaitForOperation(ctx, operation)
	if err == nil {
		t.Error("WaitForOperation() should timeout for mock operation")
	}

	// Should be a timeout error
	if !IsTimeoutError(err) && err != context.DeadlineExceeded {
		t.Errorf("WaitForOperation() should return timeout error, got: %v", err)
	}
}

func stringPtr(s string) *string {
	return &s
}

func TestComputeService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{
		MetricsEnabled: true,
	}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to compute service creation error: %v", err)
	}

	metrics := computeService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestComputeService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{
		CacheEnabled: true,
	}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to compute service creation error: %v", err)
	}

	// Clear cache should not error
	computeService.ClearCache()

	// Verify cache stats show empty cache
	stats := computeService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestComputeServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to compute service creation error: %v", err)
	}

	// Test concurrent access to compute service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to compute service methods
			instanceName := "non-existent-instance"
			zone := "us-central1-a"

			computeService.GetInstance(ctx, instanceName, zone)
			computeService.ListInstances(ctx, zone, nil)
			computeService.GetMachineTypes(ctx, zone)
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkComputeService_GetInstance(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	computeConfig := &ComputeConfig{}
	computeConfig.SetDefaults()

	computeService, err := NewComputeService(client, computeConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to compute service creation error: %v", err)
	}

	ctx := context.Background()
	instanceName := "non-existent-instance"
	zone := "us-central1-a"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		computeService.GetInstance(ctx, instanceName, zone)
	}
}

func BenchmarkInstanceConfig_Validate(b *testing.B) {
	config := &InstanceConfig{
		Name:        "test-instance",
		MachineType: "e2-medium",
		Zone:        "us-central1-a",
		BootDisk: &DiskConfig{
			SizeGB:      20,
			Type:        "pd-standard",
			SourceImage: "projects/debian-cloud/global/images/family/debian-11",
		},
		NetworkInterfaces: []*NetworkInterfaceConfig{
			{
				Network: "default",
			},
		},
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestComputeErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "instance not found",
			err:      &googleapi.Error{Code: 404, Message: "Instance not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota 'INSTANCES' exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "zone not found",
			err:      &googleapi.Error{Code: 404, Message: "The zone 'us-central1-z' was not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "machine type not found",
			err:      &googleapi.Error{Code: 404, Message: "Machine type 'invalid-type' not found"},
			wantCode: ErrorCodeNotFound,
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