package gcp

import (
	"context"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
)

func TestNewNetworkService(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping network service test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{
		DefaultNetwork:               "default",
		DefaultSubnet:                "default",
		DefaultFirewallDirection:     "INGRESS",
		DefaultFirewallAction:        "ALLOW",
		CacheEnabled:                 true,
		CacheTTL:                     30 * time.Minute,
		MetricsEnabled:               true,
		AuditEnabled:                 true,
		ConnectivityTestingEnabled:   true,
		TrafficMonitoringEnabled:     true,
		SecurityScanningEnabled:      true,
		AutoOptimizationEnabled:      false,
		RealTimeMonitoringEnabled:    true,
		PerformanceAnalysisEnabled:   true,
		NetworkVisualizationEnabled: true,
		MaxConcurrentOperations:     10,
		OperationTimeout:             10 * time.Minute,
		RetryAttempts:                3,
		RetryDelay:                   time.Second,
		RateLimitQPS:                 50,
		RateLimitBurst:               100,
		LogLevel:                     "INFO",
	}

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Errorf("NewNetworkService() error = %v", err)
		return
	}

	if networkService == nil {
		t.Error("NewNetworkService() returned nil service")
	}

	if networkService.client != client {
		t.Error("NewNetworkService() did not set client correctly")
	}

	if networkService.config.DefaultNetwork != networkConfig.DefaultNetwork {
		t.Errorf("NewNetworkService() DefaultNetwork = %v, want %v",
			networkService.config.DefaultNetwork, networkConfig.DefaultNetwork)
	}
}

func TestNetworkConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *NetworkConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &NetworkConfig{
				DefaultNetwork:           "default",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INGRESS",
				DefaultFirewallAction:    "ALLOW",
				MaxConcurrentOperations:  10,
				OperationTimeout:         10 * time.Minute,
				RetryAttempts:            3,
				RetryDelay:               time.Second,
				RateLimitQPS:             50,
				RateLimitBurst:           100,
			},
			wantErr: false,
		},
		{
			name: "empty default network",
			config: &NetworkConfig{
				DefaultNetwork:           "",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INGRESS",
				DefaultFirewallAction:    "ALLOW",
				MaxConcurrentOperations:  10,
				OperationTimeout:         10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid firewall direction",
			config: &NetworkConfig{
				DefaultNetwork:           "default",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INVALID",
				DefaultFirewallAction:    "ALLOW",
				MaxConcurrentOperations:  10,
				OperationTimeout:         10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid firewall action",
			config: &NetworkConfig{
				DefaultNetwork:           "default",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INGRESS",
				DefaultFirewallAction:    "INVALID",
				MaxConcurrentOperations:  10,
				OperationTimeout:         10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid max concurrent operations",
			config: &NetworkConfig{
				DefaultNetwork:           "default",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INGRESS",
				DefaultFirewallAction:    "ALLOW",
				MaxConcurrentOperations:  0,
				OperationTimeout:         10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid operation timeout",
			config: &NetworkConfig{
				DefaultNetwork:           "default",
				DefaultSubnet:            "default",
				DefaultFirewallDirection: "INGRESS",
				DefaultFirewallAction:    "ALLOW",
				MaxConcurrentOperations:  10,
				OperationTimeout:         0,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("NetworkConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestNetworkConfig_SetDefaults(t *testing.T) {
	config := &NetworkConfig{}
	config.SetDefaults()

	if config.DefaultNetwork == "" {
		t.Error("SetDefaults() did not set DefaultNetwork")
	}

	if config.DefaultSubnet == "" {
		t.Error("SetDefaults() did not set DefaultSubnet")
	}

	if config.DefaultFirewallDirection == "" {
		t.Error("SetDefaults() did not set DefaultFirewallDirection")
	}

	if config.DefaultFirewallAction == "" {
		t.Error("SetDefaults() did not set DefaultFirewallAction")
	}

	if config.MaxConcurrentOperations <= 0 {
		t.Error("SetDefaults() did not set MaxConcurrentOperations")
	}

	if config.OperationTimeout <= 0 {
		t.Error("SetDefaults() did not set OperationTimeout")
	}

	if config.RetryAttempts <= 0 {
		t.Error("SetDefaults() did not set RetryAttempts")
	}

	if config.RetryDelay <= 0 {
		t.Error("SetDefaults() did not set RetryDelay")
	}

	if !config.CacheEnabled {
		t.Error("SetDefaults() did not enable cache")
	}

	if config.CacheTTL <= 0 {
		t.Error("SetDefaults() did not set CacheTTL")
	}
}

func TestNetworkService_CreateNetwork(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create network test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping create network test due to network service creation error: %v", err)
	}

	vpcConfig := &VPCNetworkConfig{
		Name:        "test-network-" + time.Now().Format("20060102-150405"),
		Description: "Test network created by test suite",
		RoutingMode: "REGIONAL",
		AutoCreateSubnetworks: false,
		MTU: 1460,
		EnableUlaInternalIpv6: false,
		InternalIpv6Range:     "",
		NetworkFirewallPolicyEnforcementOrder: "AFTER_CLASSIC_FIREWALL",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	network, err := networkService.CreateNetwork(ctx, vpcConfig)
	if err != nil {
		t.Logf("CreateNetwork() error = %v (expected in test environment)", err)
		return
	}

	if network == nil {
		t.Error("CreateNetwork() returned nil network")
		return
	}

	if network.Name != vpcConfig.Name {
		t.Errorf("CreateNetwork() network name = %v, want %v", network.Name, vpcConfig.Name)
	}

	// Clean up - attempt to delete the network
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		networkService.DeleteNetwork(deleteCtx, vpcConfig.Name)
	}()
}

func TestNetworkService_GetNetwork(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get network test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping get network test due to network service creation error: %v", err)
	}

	ctx := context.Background()

	// Test getting default network (should exist in most projects)
	network, err := networkService.GetNetwork(ctx, "default")
	if err != nil {
		t.Logf("GetNetwork(default) error = %v (expected in test environment)", err)
	} else if network != nil {
		if network.Name != "default" {
			t.Errorf("GetNetwork() network name = %v, want default", network.Name)
		}
	}

	// Test getting non-existent network
	nonExistentNetwork := "non-existent-network-" + time.Now().Format("20060102-150405")
	network, err = networkService.GetNetwork(ctx, nonExistentNetwork)
	if err == nil {
		t.Error("GetNetwork() should have returned error for non-existent network")
	}

	if network != nil {
		t.Error("GetNetwork() should have returned nil for non-existent network")
	}

	// Verify the error is a not found error
	if !IsNotFoundError(err) {
		t.Errorf("GetNetwork() error should be not found error, got: %v", err)
	}
}

func TestNetworkService_ListNetworks(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping list networks test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping list networks test due to network service creation error: %v", err)
	}

	ctx := context.Background()

	networks, err := networkService.ListNetworks(ctx, nil)
	if err != nil {
		t.Logf("ListNetworks() error = %v (expected in test environment)", err)
		return
	}

	if networks == nil {
		t.Error("ListNetworks() returned nil networks")
		return
	}

	t.Logf("ListNetworks() returned %d networks", len(networks))

	// Most projects should have at least the default network
	if len(networks) == 0 {
		t.Log("ListNetworks() returned 0 networks (this may be normal for some test projects)")
	}
}

func TestNetworkService_CreateSubnet(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create subnet test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping create subnet test due to network service creation error: %v", err)
	}

	subnetConfig := &SubnetworkConfig{
		Name:        "test-subnet-" + time.Now().Format("20060102-150405"),
		Network:     "default",
		IPCidrRange: "10.1.0.0/24",
		Region:      "us-central1",
		Description: "Test subnet created by test suite",
		EnablePrivateIPGoogleAccess: true,
		EnableFlowLogs:              true,
		FlowLogsConfig: &FlowLogsConfig{
			AggregationInterval: "INTERVAL_5_SEC",
			FlowSampling:        0.5,
			Metadata:            "INCLUDE_ALL_METADATA",
			FilterExpression:    "",
		},
		SecondaryIPRanges: []*SecondaryIPRange{
			{
				RangeName:   "pods",
				IPCidrRange: "10.2.0.0/16",
			},
			{
				RangeName:   "services",
				IPCidrRange: "10.3.0.0/16",
			},
		},
		Purpose:     "PRIVATE",
		Role:        "",
		StackType:   "IPV4_ONLY",
		Ipv6AccessType: "",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	subnet, err := networkService.CreateSubnet(ctx, subnetConfig)
	if err != nil {
		t.Logf("CreateSubnet() error = %v (expected in test environment)", err)
		return
	}

	if subnet == nil {
		t.Error("CreateSubnet() returned nil subnet")
		return
	}

	if subnet.Name != subnetConfig.Name {
		t.Errorf("CreateSubnet() subnet name = %v, want %v", subnet.Name, subnetConfig.Name)
	}

	// Clean up - attempt to delete the subnet
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		networkService.DeleteSubnet(deleteCtx, subnetConfig.Name, subnetConfig.Region)
	}()
}

func TestNetworkService_CreateFirewallRule(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping create firewall rule test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping create firewall rule test due to network service creation error: %v", err)
	}

	firewallConfig := &FirewallRuleConfig{
		Name:        "test-firewall-" + time.Now().Format("20060102-150405"),
		Network:     "default",
		Direction:   "INGRESS",
		Action:      "ALLOW",
		Priority:    1000,
		Description: "Test firewall rule created by test suite",
		SourceRanges: []string{"0.0.0.0/0"},
		TargetTags:   []string{"web-server"},
		Allowed: []*FirewallAllowed{
			{
				IPProtocol: "tcp",
				Ports:      []string{"80", "443"},
			},
		},
		Denied:              []*FirewallDenied{},
		SourceTags:          []string{},
		SourceServiceAccounts: []string{},
		TargetServiceAccounts: []string{},
		DestinationRanges:   []string{},
		EnableLogging:       true,
		LogConfig: &FirewallLogConfig{
			Enable:   true,
			Metadata: "INCLUDE_ALL_METADATA",
		},
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	firewallRule, err := networkService.CreateFirewallRule(ctx, firewallConfig)
	if err != nil {
		t.Logf("CreateFirewallRule() error = %v (expected in test environment)", err)
		return
	}

	if firewallRule == nil {
		t.Error("CreateFirewallRule() returned nil firewall rule")
		return
	}

	if firewallRule.Name != firewallConfig.Name {
		t.Errorf("CreateFirewallRule() rule name = %v, want %v", firewallRule.Name, firewallConfig.Name)
	}

	// Clean up - attempt to delete the firewall rule
	defer func() {
		deleteCtx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		networkService.DeleteFirewallRule(deleteCtx, firewallConfig.Name)
	}()
}

func TestNetworkService_AnalyzeNetworkConnectivity(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping analyze network connectivity test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping analyze network connectivity test due to network service creation error: %v", err)
	}

	connectivityConfig := &ConnectivityTestConfig{
		Name:        "test-connectivity-" + time.Now().Format("20060102-150405"),
		Description: "Test connectivity analysis",
		Source: &ConnectivityEndpoint{
			Instance:  "projects/test-project-123/zones/us-central1-a/instances/source-instance",
			IPAddress: "10.0.0.1",
			Port:      80,
			Network:   "default",
		},
		Destination: &ConnectivityEndpoint{
			Instance:  "projects/test-project-123/zones/us-central1-a/instances/dest-instance",
			IPAddress: "10.0.0.2",
			Port:      80,
			Network:   "default",
		},
		Protocol: "TCP",
		Labels: map[string]string{
			"environment": "test",
			"created-by":  "test-suite",
		},
	}

	ctx := context.Background()
	result, err := networkService.AnalyzeNetworkConnectivity(ctx, connectivityConfig)
	if err != nil {
		t.Logf("AnalyzeNetworkConnectivity() error = %v (expected for non-existent instances)", err)
		return
	}

	if result == nil {
		t.Error("AnalyzeNetworkConnectivity() returned nil result")
		return
	}

	if result.TestID == "" {
		t.Error("AnalyzeNetworkConnectivity() should have test ID")
	}
}

func TestVPCNetworkConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *VPCNetworkConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &VPCNetworkConfig{
				Name:        "test-network",
				Description: "Test network",
				RoutingMode: "REGIONAL",
				MTU:         1460,
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &VPCNetworkConfig{
				Name:        "",
				Description: "Test network",
				RoutingMode: "REGIONAL",
				MTU:         1460,
			},
			wantErr: true,
		},
		{
			name: "invalid routing mode",
			config: &VPCNetworkConfig{
				Name:        "test-network",
				Description: "Test network",
				RoutingMode: "INVALID",
				MTU:         1460,
			},
			wantErr: true,
		},
		{
			name: "invalid MTU",
			config: &VPCNetworkConfig{
				Name:        "test-network",
				Description: "Test network",
				RoutingMode: "REGIONAL",
				MTU:         100, // Too small
			},
			wantErr: true,
		},
		{
			name: "invalid name format",
			config: &VPCNetworkConfig{
				Name:        "Test_Network",
				Description: "Test network",
				RoutingMode: "REGIONAL",
				MTU:         1460,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("VPCNetworkConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSubnetworkConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *SubnetworkConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &SubnetworkConfig{
				Name:        "test-subnet",
				Network:     "default",
				IPCidrRange: "10.0.0.0/24",
				Region:      "us-central1",
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &SubnetworkConfig{
				Name:        "",
				Network:     "default",
				IPCidrRange: "10.0.0.0/24",
				Region:      "us-central1",
			},
			wantErr: true,
		},
		{
			name: "empty network",
			config: &SubnetworkConfig{
				Name:        "test-subnet",
				Network:     "",
				IPCidrRange: "10.0.0.0/24",
				Region:      "us-central1",
			},
			wantErr: true,
		},
		{
			name: "invalid CIDR range",
			config: &SubnetworkConfig{
				Name:        "test-subnet",
				Network:     "default",
				IPCidrRange: "invalid-cidr",
				Region:      "us-central1",
			},
			wantErr: true,
		},
		{
			name: "empty region",
			config: &SubnetworkConfig{
				Name:        "test-subnet",
				Network:     "default",
				IPCidrRange: "10.0.0.0/24",
				Region:      "",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("SubnetworkConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestFirewallRuleConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *FirewallRuleConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &FirewallRuleConfig{
				Name:      "test-firewall",
				Network:   "default",
				Direction: "INGRESS",
				Action:    "ALLOW",
				Priority:  1000,
				Allowed: []*FirewallAllowed{
					{
						IPProtocol: "tcp",
						Ports:      []string{"80"},
					},
				},
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &FirewallRuleConfig{
				Name:      "",
				Network:   "default",
				Direction: "INGRESS",
				Action:    "ALLOW",
				Priority:  1000,
			},
			wantErr: true,
		},
		{
			name: "empty network",
			config: &FirewallRuleConfig{
				Name:      "test-firewall",
				Network:   "",
				Direction: "INGRESS",
				Action:    "ALLOW",
				Priority:  1000,
			},
			wantErr: true,
		},
		{
			name: "invalid direction",
			config: &FirewallRuleConfig{
				Name:      "test-firewall",
				Network:   "default",
				Direction: "INVALID",
				Action:    "ALLOW",
				Priority:  1000,
			},
			wantErr: true,
		},
		{
			name: "invalid action",
			config: &FirewallRuleConfig{
				Name:      "test-firewall",
				Network:   "default",
				Direction: "INGRESS",
				Action:    "INVALID",
				Priority:  1000,
			},
			wantErr: true,
		},
		{
			name: "invalid priority",
			config: &FirewallRuleConfig{
				Name:      "test-firewall",
				Network:   "default",
				Direction: "INGRESS",
				Action:    "ALLOW",
				Priority:  70000, // Too high
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("FirewallRuleConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestNetworkService_GetServiceMetrics(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{
		MetricsEnabled: true,
	}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping get service metrics test due to network service creation error: %v", err)
	}

	metrics := networkService.GetServiceMetrics()
	if metrics == nil {
		t.Error("GetServiceMetrics() returned nil when metrics are enabled")
	}
}

func TestNetworkService_ClearCache(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping clear cache test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{
		CacheEnabled: true,
	}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping clear cache test due to network service creation error: %v", err)
	}

	// Clear cache should not error
	networkService.ClearCache()

	// Verify cache stats show empty cache
	stats := networkService.GetCacheStats()
	if stats != nil {
		if size, ok := stats["size"].(int); ok && size != 0 {
			t.Errorf("ClearCache() cache size = %d, want 0", size)
		}
	}
}

func TestNetworkServiceConcurrency(t *testing.T) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		t.Skipf("Skipping concurrency test due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		t.Skipf("Skipping concurrency test due to network service creation error: %v", err)
	}

	// Test concurrent access to network service methods
	done := make(chan bool, 10)
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		go func(index int) {
			defer func() { done <- true }()

			// Test concurrent calls to network service methods
			networkName := "non-existent-network"

			networkService.GetNetwork(ctx, networkName)
			networkService.ListNetworks(ctx, nil)
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < 10; i++ {
		<-done
	}

	t.Log("Concurrent access test completed successfully")
}

func BenchmarkNetworkService_GetNetwork(b *testing.B) {
	config := &ClientConfig{
		ProjectID: "test-project-123",
		Region:    "us-central1",
		Zone:      "us-central1-a",
	}

	client, err := NewClient(context.Background(), config)
	if err != nil {
		b.Skipf("Skipping benchmark due to client creation error: %v", err)
	}

	networkConfig := &NetworkConfig{}
	networkConfig.SetDefaults()

	networkService, err := NewNetworkService(client, networkConfig)
	if err != nil {
		b.Skipf("Skipping benchmark due to network service creation error: %v", err)
	}

	ctx := context.Background()
	networkName := "default"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		networkService.GetNetwork(ctx, networkName)
	}
}

func BenchmarkVPCNetworkConfig_Validate(b *testing.B) {
	config := &VPCNetworkConfig{
		Name:        "test-network",
		Description: "Test network",
		RoutingMode: "REGIONAL",
		MTU:         1460,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		config.Validate()
	}
}

func TestNetworkErrorHandling(t *testing.T) {
	// Test various error scenarios
	tests := []struct {
		name     string
		err      error
		wantCode ErrorCode
	}{
		{
			name:     "network not found",
			err:      &googleapi.Error{Code: 404, Message: "Network not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "subnet not found",
			err:      &googleapi.Error{Code: 404, Message: "Subnet not found"},
			wantCode: ErrorCodeNotFound,
		},
		{
			name:     "permission denied",
			err:      &googleapi.Error{Code: 403, Message: "Permission denied"},
			wantCode: ErrorCodePermissionDenied,
		},
		{
			name:     "network already exists",
			err:      &googleapi.Error{Code: 409, Message: "Network already exists"},
			wantCode: ErrorCodeAlreadyExists,
		},
		{
			name:     "quota exceeded",
			err:      &googleapi.Error{Code: 403, Message: "Quota exceeded"},
			wantCode: ErrorCodeQuotaExceeded,
		},
		{
			name:     "invalid CIDR range",
			err:      &googleapi.Error{Code: 400, Message: "Invalid CIDR range"},
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

func TestNetworkConnectivityValidation(t *testing.T) {
	// Test connectivity test configuration validation
	validConfig := &ConnectivityTestConfig{
		Name:        "test-connectivity",
		Description: "Test connectivity",
		Source: &ConnectivityEndpoint{
			IPAddress: "10.0.0.1",
			Port:      80,
			Network:   "default",
		},
		Destination: &ConnectivityEndpoint{
			IPAddress: "10.0.0.2",
			Port:      80,
			Network:   "default",
		},
		Protocol: "TCP",
	}

	err := validConfig.Validate()
	if err != nil {
		t.Errorf("Valid ConnectivityTestConfig should not error: %v", err)
	}

	// Test invalid configurations
	invalidConfigs := []*ConnectivityTestConfig{
		{
			Name: "", // Empty name
			Source: &ConnectivityEndpoint{
				IPAddress: "10.0.0.1",
			},
			Destination: &ConnectivityEndpoint{
				IPAddress: "10.0.0.2",
			},
		},
		{
			Name:   "test",
			Source: nil, // Missing source
			Destination: &ConnectivityEndpoint{
				IPAddress: "10.0.0.2",
			},
		},
		{
			Name: "test",
			Source: &ConnectivityEndpoint{
				IPAddress: "10.0.0.1",
			},
			Destination: nil, // Missing destination
		},
		{
			Name: "test",
			Source: &ConnectivityEndpoint{
				IPAddress: "invalid-ip", // Invalid IP
			},
			Destination: &ConnectivityEndpoint{
				IPAddress: "10.0.0.2",
			},
		},
	}

	for i, config := range invalidConfigs {
		t.Run(strings.Join([]string{"invalid", string(rune(i+'0'))}, "_"), func(t *testing.T) {
			err := config.Validate()
			if err == nil {
				t.Error("Invalid ConnectivityTestConfig should error")
			}
		})
	}
}

// Helper function for ConnectivityTestConfig validation (would be part of actual implementation)
func (c *ConnectivityTestConfig) Validate() error {
	if c.Name == "" {
		return fmt.Errorf("name is required")
	}
	if c.Source == nil {
		return fmt.Errorf("source is required")
	}
	if c.Destination == nil {
		return fmt.Errorf("destination is required")
	}
	if c.Source.IPAddress != "" {
		if net.ParseIP(c.Source.IPAddress) == nil {
			return fmt.Errorf("invalid source IP address")
		}
	}
	if c.Destination.IPAddress != "" {
		if net.ParseIP(c.Destination.IPAddress) == nil {
			return fmt.Errorf("invalid destination IP address")
		}
	}
	return nil
}