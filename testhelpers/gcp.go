package testhelpers

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/storage"
	"github.com/gruntwork-io/terratest/modules/random"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
)

// TestConfig represents the configuration for test execution
type TestConfig struct {
	ProjectID   string
	Region      string
	Zone        string
	Environment string
	RandomID    string
	Timeout     time.Duration
}

// GetTestConfig retrieves test configuration from environment variables
func GetTestConfig(t *testing.T) *TestConfig {
	projectID := os.Getenv("GCP_PROJECT_ID")
	if projectID == "" {
		t.Fatal("GCP_PROJECT_ID environment variable is required")
	}

	region := os.Getenv("GCP_REGION")
	if region == "" {
		region = "europe-west1"
	}

	zone := os.Getenv("GCP_ZONE")
	if zone == "" {
		zone = "europe-west1-a"
	}

	environment := os.Getenv("TEST_ENVIRONMENT")
	if environment == "" {
		environment = "test"
	}

	timeoutStr := os.Getenv("TEST_TIMEOUT")
	timeout := 30 * time.Minute
	if timeoutStr != "" {
		if parsedTimeout, err := time.ParseDuration(timeoutStr); err == nil {
			timeout = parsedTimeout
		}
	}

	return &TestConfig{
		ProjectID:   projectID,
		Region:      region,
		Zone:        zone,
		Environment: environment,
		RandomID:    random.UniqueId(),
		Timeout:     timeout,
	}
}

// ResourceType represents different types of GCP resources
type ResourceType string

const (
	ResourceTypeComputeInstance   ResourceType = "compute_instance"
	ResourceTypeStorageBucket     ResourceType = "storage_bucket"
	ResourceTypeNetwork           ResourceType = "network"
	ResourceTypeSubnetwork        ResourceType = "subnetwork"
	ResourceTypeFirewall          ResourceType = "firewall"
	ResourceTypeInstanceGroup     ResourceType = "instance_group"
	ResourceTypeInstanceTemplate  ResourceType = "instance_template"
	ResourceTypeHealthCheck       ResourceType = "health_check"
	ResourceTypeLoadBalancer      ResourceType = "load_balancer"
	ResourceTypeBackendService    ResourceType = "backend_service"
	ResourceTypeUrlMap            ResourceType = "url_map"
	ResourceTypeTargetHttpProxy   ResourceType = "target_http_proxy"
	ResourceTypeTargetHttpsProxy  ResourceType = "target_https_proxy"
	ResourceTypeForwardingRule    ResourceType = "forwarding_rule"
	ResourceTypeStaticIP          ResourceType = "static_ip"
	ResourceTypeSSLCertificate    ResourceType = "ssl_certificate"
)

// ResourceIdentifier represents a resource to be cleaned up
type ResourceIdentifier struct {
	Type     ResourceType
	Name     string
	Zone     string
	Region   string
	Project  string
	Metadata map[string]string
}

// ParseResourceString parses a resource string in format "type:name:zone/region"
func ParseResourceString(resourceStr string) (*ResourceIdentifier, error) {
	parts := strings.Split(resourceStr, ":")
	if len(parts) < 2 {
		return nil, fmt.Errorf("invalid resource format: %s (expected type:name or type:name:zone)", resourceStr)
	}

	resource := &ResourceIdentifier{
		Type:     ResourceType(parts[0]),
		Name:     parts[1],
		Metadata: make(map[string]string),
	}

	if len(parts) >= 3 {
		if strings.Contains(parts[2], "/") {
			resource.Region = parts[2]
		} else {
			resource.Zone = parts[2]
		}
	}

	if len(parts) >= 4 {
		resource.Project = parts[3]
	}

	return resource, nil
}

// CleanupTestResources cleans up test resources
func CleanupTestResources(t *testing.T, projectID string, resources []string) {
	t.Logf("Cleaning up test resources in project: %s", projectID)

	ctx := context.Background()

	for _, resourceStr := range resources {
		t.Logf("Cleaning up resource: %s", resourceStr)

		resource, err := ParseResourceString(resourceStr)
		if err != nil {
			t.Logf("Error parsing resource string %s: %v", resourceStr, err)
			continue
		}

		if resource.Project == "" {
			resource.Project = projectID
		}

		if err := CleanupResource(ctx, t, resource); err != nil {
			t.Logf("Error cleaning up resource %s: %v", resourceStr, err)
		} else {
			t.Logf("Successfully cleaned up resource: %s", resourceStr)
		}
	}
}

// CleanupResource cleans up a single resource based on its type
func CleanupResource(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	switch resource.Type {
	case ResourceTypeComputeInstance:
		return cleanupComputeInstance(ctx, t, resource)
	case ResourceTypeStorageBucket:
		return cleanupStorageBucket(ctx, t, resource)
	case ResourceTypeNetwork:
		return cleanupNetwork(ctx, t, resource)
	case ResourceTypeSubnetwork:
		return cleanupSubnetwork(ctx, t, resource)
	case ResourceTypeFirewall:
		return cleanupFirewall(ctx, t, resource)
	case ResourceTypeInstanceGroup:
		return cleanupInstanceGroup(ctx, t, resource)
	case ResourceTypeInstanceTemplate:
		return cleanupInstanceTemplate(ctx, t, resource)
	case ResourceTypeHealthCheck:
		return cleanupHealthCheck(ctx, t, resource)
	case ResourceTypeLoadBalancer:
		return cleanupLoadBalancer(ctx, t, resource)
	case ResourceTypeBackendService:
		return cleanupBackendService(ctx, t, resource)
	case ResourceTypeUrlMap:
		return cleanupUrlMap(ctx, t, resource)
	case ResourceTypeTargetHttpProxy:
		return cleanupTargetHttpProxy(ctx, t, resource)
	case ResourceTypeTargetHttpsProxy:
		return cleanupTargetHttpsProxy(ctx, t, resource)
	case ResourceTypeForwardingRule:
		return cleanupForwardingRule(ctx, t, resource)
	case ResourceTypeStaticIP:
		return cleanupStaticIP(ctx, t, resource)
	case ResourceTypeSSLCertificate:
		return cleanupSSLCertificate(ctx, t, resource)
	default:
		return fmt.Errorf("unknown resource type: %s", resource.Type)
	}
}

func cleanupComputeInstance(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create compute client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteInstanceRequest{
		Project:  resource.Project,
		Zone:     resource.Zone,
		Instance: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete instance: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, resource.Zone, ""); err != nil {
		return fmt.Errorf("failed to wait for instance deletion: %w", err)
	}

	t.Logf("Deleted compute instance: %s", resource.Name)
	return nil
}

func cleanupStorageBucket(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	bucket := client.Bucket(resource.Name)

	it := bucket.Objects(ctx, nil)
	for {
		objAttrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to list objects: %w", err)
		}

		if err := bucket.Object(objAttrs.Name).Delete(ctx); err != nil {
			t.Logf("Failed to delete object %s: %v", objAttrs.Name, err)
		}
	}

	if err := bucket.Delete(ctx); err != nil {
		return fmt.Errorf("failed to delete bucket: %w", err)
	}

	t.Logf("Deleted storage bucket: %s", resource.Name)
	return nil
}

func cleanupNetwork(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewNetworksRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create networks client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteNetworkRequest{
		Project: resource.Project,
		Network: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete network: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for network deletion: %w", err)
	}

	t.Logf("Deleted network: %s", resource.Name)
	return nil
}

func cleanupSubnetwork(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewSubnetworksRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create subnetworks client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteSubnetworkRequest{
		Project:    resource.Project,
		Region:     resource.Region,
		Subnetwork: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete subnetwork: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", resource.Region); err != nil {
		return fmt.Errorf("failed to wait for subnetwork deletion: %w", err)
	}

	t.Logf("Deleted subnetwork: %s", resource.Name)
	return nil
}

func cleanupFirewall(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewFirewallsRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create firewalls client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteFirewallRequest{
		Project:  resource.Project,
		Firewall: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete firewall: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for firewall deletion: %w", err)
	}

	t.Logf("Deleted firewall: %s", resource.Name)
	return nil
}

func cleanupInstanceGroup(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create instance groups client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteInstanceGroupRequest{
		Project:       resource.Project,
		Zone:          resource.Zone,
		InstanceGroup: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete instance group: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, resource.Zone, ""); err != nil {
		return fmt.Errorf("failed to wait for instance group deletion: %w", err)
	}

	t.Logf("Deleted instance group: %s", resource.Name)
	return nil
}

func cleanupInstanceTemplate(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewInstanceTemplatesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create instance templates client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteInstanceTemplateRequest{
		Project:          resource.Project,
		InstanceTemplate: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete instance template: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for instance template deletion: %w", err)
	}

	t.Logf("Deleted instance template: %s", resource.Name)
	return nil
}

func cleanupHealthCheck(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewHealthChecksRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create health checks client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteHealthCheckRequest{
		Project:     resource.Project,
		HealthCheck: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete health check: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for health check deletion: %w", err)
	}

	t.Logf("Deleted health check: %s", resource.Name)
	return nil
}

func cleanupLoadBalancer(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	return fmt.Errorf("load balancer cleanup requires specific component cleanup (forwarding rules, backend services, etc.)")
}

func cleanupBackendService(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewBackendServicesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create backend services client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteBackendServiceRequest{
		Project:        resource.Project,
		BackendService: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete backend service: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for backend service deletion: %w", err)
	}

	t.Logf("Deleted backend service: %s", resource.Name)
	return nil
}

func cleanupUrlMap(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewUrlMapsRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create URL maps client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteUrlMapRequest{
		Project: resource.Project,
		UrlMap:  resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete URL map: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for URL map deletion: %w", err)
	}

	t.Logf("Deleted URL map: %s", resource.Name)
	return nil
}

func cleanupTargetHttpProxy(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewTargetHttpProxiesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create target HTTP proxies client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteTargetHttpProxyRequest{
		Project:         resource.Project,
		TargetHttpProxy: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete target HTTP proxy: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for target HTTP proxy deletion: %w", err)
	}

	t.Logf("Deleted target HTTP proxy: %s", resource.Name)
	return nil
}

func cleanupTargetHttpsProxy(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewTargetHttpsProxiesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create target HTTPS proxies client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteTargetHttpsProxyRequest{
		Project:          resource.Project,
		TargetHttpsProxy: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete target HTTPS proxy: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for target HTTPS proxy deletion: %w", err)
	}

	t.Logf("Deleted target HTTPS proxy: %s", resource.Name)
	return nil
}

func cleanupForwardingRule(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	if resource.Region != "" {
		return cleanupRegionalForwardingRule(ctx, t, resource)
	}
	return cleanupGlobalForwardingRule(ctx, t, resource)
}

func cleanupGlobalForwardingRule(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewGlobalForwardingRulesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create global forwarding rules client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteGlobalForwardingRuleRequest{
		Project:        resource.Project,
		ForwardingRule: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete global forwarding rule: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for global forwarding rule deletion: %w", err)
	}

	t.Logf("Deleted global forwarding rule: %s", resource.Name)
	return nil
}

func cleanupRegionalForwardingRule(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewForwardingRulesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create forwarding rules client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteForwardingRuleRequest{
		Project:        resource.Project,
		Region:         resource.Region,
		ForwardingRule: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete forwarding rule: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", resource.Region); err != nil {
		return fmt.Errorf("failed to wait for forwarding rule deletion: %w", err)
	}

	t.Logf("Deleted forwarding rule: %s", resource.Name)
	return nil
}

func cleanupStaticIP(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	if resource.Region != "" {
		return cleanupRegionalStaticIP(ctx, t, resource)
	}
	return cleanupGlobalStaticIP(ctx, t, resource)
}

func cleanupGlobalStaticIP(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewGlobalAddressesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create global addresses client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteGlobalAddressRequest{
		Project: resource.Project,
		Address: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete global address: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for global address deletion: %w", err)
	}

	t.Logf("Deleted global static IP: %s", resource.Name)
	return nil
}

func cleanupRegionalStaticIP(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewAddressesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create addresses client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteAddressRequest{
		Project: resource.Project,
		Region:  resource.Region,
		Address: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete address: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", resource.Region); err != nil {
		return fmt.Errorf("failed to wait for address deletion: %w", err)
	}

	t.Logf("Deleted static IP: %s", resource.Name)
	return nil
}

func cleanupSSLCertificate(ctx context.Context, t *testing.T, resource *ResourceIdentifier) error {
	client, err := compute.NewSslCertificatesRESTClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create SSL certificates client: %w", err)
	}
	defer client.Close()

	req := &computepb.DeleteSslCertificateRequest{
		Project:        resource.Project,
		SslCertificate: resource.Name,
	}

	op, err := client.Delete(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to delete SSL certificate: %w", err)
	}

	if err := waitForOperation(ctx, op, resource.Project, "", ""); err != nil {
		return fmt.Errorf("failed to wait for SSL certificate deletion: %w", err)
	}

	t.Logf("Deleted SSL certificate: %s", resource.Name)
	return nil
}

func waitForOperation(ctx context.Context, op *compute.Operation, project, zone, region string) error {
	if op == nil {
		return nil
	}

	var client interface{}
	var err error

	if zone != "" {
		client, err = compute.NewZoneOperationsRESTClient(ctx)
	} else if region != "" {
		client, err = compute.NewRegionOperationsRESTClient(ctx)
	} else {
		client, err = compute.NewGlobalOperationsRESTClient(ctx)
	}

	if err != nil {
		return fmt.Errorf("failed to create operations client: %w", err)
	}

	for {
		var getReq interface{}
		var resp interface{}

		switch c := client.(type) {
		case *compute.ZoneOperationsClient:
			defer c.Close()
			getReq = &computepb.GetZoneOperationRequest{
				Project:   project,
				Zone:      zone,
				Operation: op.Name(),
			}
			resp, err = c.Get(ctx, getReq.(*computepb.GetZoneOperationRequest))
		case *compute.RegionOperationsClient:
			defer c.Close()
			getReq = &computepb.GetRegionOperationRequest{
				Project:   project,
				Region:    region,
				Operation: op.Name(),
			}
			resp, err = c.Get(ctx, getReq.(*computepb.GetRegionOperationRequest))
		case *compute.GlobalOperationsClient:
			defer c.Close()
			getReq = &computepb.GetGlobalOperationRequest{
				Project:   project,
				Operation: op.Name(),
			}
			resp, err = c.Get(ctx, getReq.(*computepb.GetGlobalOperationRequest))
		}

		if err != nil {
			return fmt.Errorf("failed to get operation status: %w", err)
		}

		operation := resp.(*computepb.Operation)
		if operation.GetStatus() == computepb.Operation_DONE {
			if operation.Error != nil {
				return fmt.Errorf("operation failed: %v", operation.Error)
			}
			return nil
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(5 * time.Second):
		}
	}
}

// CleanupResourcesByPattern cleans up resources matching a pattern
func CleanupResourcesByPattern(ctx context.Context, t *testing.T, projectID string, pattern string) error {
	t.Logf("Cleaning up resources matching pattern: %s", pattern)

	return fmt.Errorf("pattern-based cleanup not yet implemented")
}

// CleanupAllTestResources cleans up all test resources in a project
func CleanupAllTestResources(ctx context.Context, t *testing.T, projectID string, testPrefix string) error {
	t.Logf("Cleaning up all test resources with prefix: %s", testPrefix)

	return fmt.Errorf("bulk cleanup not yet implemented")
}

// CreateTestProject creates a test GCP project (if needed)
func CreateTestProject(t *testing.T, projectID string) string {
	// For now, return the provided project ID
	// In a real implementation, this would create a test project
	return projectID
}

// ValidateGCPCredentials validates that GCP credentials are properly configured
func ValidateGCPCredentials(t *testing.T) {
	// Simple credential validation by checking for service account key or default credentials
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") == "" && os.Getenv("GCLOUD_PROJECT") == "" {
		t.Skip("No GCP credentials found. Set GOOGLE_APPLICATION_CREDENTIALS or GCLOUD_PROJECT environment variable.")
	}
}


// WaitForResourceCreation waits for a resource to be created
func WaitForResourceCreation(t *testing.T, checkFunc func() bool, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if checkFunc() {
				return true
			}
		case <-time.After(time.Until(deadline)):
			return false
		}
	}
}
