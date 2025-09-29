package gcp

import (
	"context"
	"fmt"
	// "strings"
	"sync"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/compute/metadata"
	// "github.com/googleapis/gax-go/v2"
	"go.uber.org/zap"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
	"google.golang.org/protobuf/proto"
)

// ComputeService provides comprehensive GCP Compute Engine operations
type ComputeService struct {
	client              *Client
	instancesClient     *compute.InstancesClient
	instanceGroupsClient *compute.InstanceGroupsClient
	instanceTemplatesClient *compute.InstanceTemplatesClient
	disksClient         *compute.DisksClient
	snapshotsClient     *compute.SnapshotsClient
	imagesClient        *compute.ImagesClient
	networksClient      *compute.NetworksClient
	firewallsClient     *compute.FirewallsClient
	healthChecksClient  *compute.HealthChecksClient
	backendServicesClient *compute.BackendServicesClient
	loadBalancersClient *compute.ForwardingRulesClient
	urlMapsClient       *compute.UrlMapsClient
	sslCertificatesClient *compute.SslCertificatesClient
	targetPoolsClient   *compute.TargetPoolsClient
	vpnGatewaysClient   *compute.VpnGatewaysClient
	vpnTunnelsClient    *compute.VpnTunnelsClient
	routersClient       *compute.RoutersClient
	routesClient        *compute.RoutesClient
	addressesClient     *compute.AddressesClient
	globalAddressesClient *compute.GlobalAddressesClient
	machineTypesClient  *compute.MachineTypesClient
	zonesClient         *compute.ZonesClient
	regionsClient       *compute.RegionsClient
	projectsClient      *compute.ProjectsClient
	logger              *zap.Logger
	cache               *ComputeCache
	mu                  sync.RWMutex
	metrics             *ComputeMetrics
	rateLimiter         *RateLimiter
	operationPoller     *OperationPoller
}

// ComputeCache caches frequently accessed compute resources
type ComputeCache struct {
	instances         map[string]*computepb.Instance
	instanceTemplates map[string]*computepb.InstanceTemplate
	machineTypes      map[string]*computepb.MachineType
	zones             map[string]*computepb.Zone
	regions           map[string]*computepb.Region
	networks          map[string]*computepb.Network
	subnetworks       map[string]*computepb.Subnetwork
	mu                sync.RWMutex
	ttl               time.Duration
	lastUpdate        map[string]time.Time
}

// ComputeMetrics tracks compute service metrics
type ComputeMetrics struct {
	InstanceOperations    int64
	DiskOperations        int64
	NetworkOperations     int64
	SnapshotOperations    int64
	LoadBalancerOperations int64
	OperationLatencies    []time.Duration
	ErrorCounts           map[string]int64
	mu                    sync.RWMutex
}

// InstanceConfig represents comprehensive instance configuration
type InstanceConfig struct {
	Name                   string
	Zone                   string
	MachineType            string
	Description            string
	Tags                   []string
	Labels                 map[string]string
	Metadata               map[string]string
	MetadataStartupScript  string
	MetadataShutdownScript string
	ServiceAccounts        []ServiceAccountConfig
	NetworkInterfaces      []NetworkInterfaceConfig
	Disks                  []DiskConfig
	Scheduling             *SchedulingConfig
	ShieldedInstanceConfig *ShieldedConfig
	ConfidentialCompute    bool
	ReservationAffinity    *ReservationAffinityConfig
	ResourcePolicies       []string
	MinCpuPlatform         string
	GuestAccelerators      []AcceleratorConfig
	DeletionProtection     bool
	Hostname               string
	EnableDisplay          bool
	AdvancedMachineFeatures *AdvancedMachineConfig
	NetworkPerformanceConfig *NetworkPerformanceConfig
	PrivateIpv6GoogleAccess string
	Fingerprint            string
	SourceInstanceTemplate string
	SourceMachineImage     string
	KeyRevocationAction    string
	PostKeyRevocationAction string
	EnableSecureBoot       bool
	EnableVtpm             bool
	EnableIntegrityMonitoring bool
}

// ServiceAccountConfig represents service account configuration
type ServiceAccountConfig struct {
	Email  string
	Scopes []string
}

// NetworkInterfaceConfig represents network interface configuration
type NetworkInterfaceConfig struct {
	Network            string
	Subnetwork         string
	NetworkIP          string
	Name               string
	AccessConfigs      []AccessConfig
	AliasIPRanges      []AliasIPRange
	Ipv6AccessConfigs  []Ipv6AccessConfig
	NicType            string
	QueueCount         int32
	StackType          string
	NetworkAttachment  string
}

// AccessConfig represents external IP configuration
type AccessConfig struct {
	Type                string
	Name                string
	NatIP               string
	NetworkTier         string
	PublicPtrDomainName string
	SetPublicPtr        bool
	SecurityPolicy      string
}

// AliasIPRange represents alias IP range configuration
type AliasIPRange struct {
	IPCIDRRange         string
	SubnetworkRangeName string
}

// Ipv6AccessConfig represents IPv6 access configuration
type Ipv6AccessConfig struct {
	Type                        string
	Name                        string
	ExternalIpv6                string
	ExternalIpv6PrefixLength    int32
	PublicPtrDomainName         string
	NetworkTier                 string
}

// DiskConfig represents disk configuration
type DiskConfig struct {
	AutoDelete            bool
	Boot                  bool
	DeviceName            string
	DiskName              string
	DiskSizeGb            int64
	DiskType              string
	DiskEncryptionKey     *CustomerEncryptionKey
	GuestOsFeatures       []string
	Interface             string
	Mode                  string
	Source                string
	InitializeParams      *DiskInitializeParams
	Labels                map[string]string
	Licenses              []string
	ResourcePolicies      []string
	ProvisionedIops       int64
	ProvisionedThroughput int64
	Architecture          string
}

// CustomerEncryptionKey represents customer-managed encryption key
type CustomerEncryptionKey struct {
	RawKey               string
	RsaEncryptedKey      string
	KmsKeyName           string
	KmsKeyServiceAccount string
	Sha256               string
}

// DiskInitializeParams represents disk initialization parameters
type DiskInitializeParams struct {
	DiskName                        string
	DiskSizeGb                      int64
	DiskType                        string
	SourceImage                     string
	SourceImageEncryptionKey        *CustomerEncryptionKey
	SourceSnapshot                  string
	SourceSnapshotEncryptionKey     *CustomerEncryptionKey
	Description                     string
	Labels                          map[string]string
	OnUpdateAction                  string
	ProvisionedIops                 int64
	ProvisionedThroughput           int64
	ResourceManagerTags             map[string]string
	ResourcePolicies                []string
	Architecture                    string
	ReplicaZones                    []string
	StoragePool                     string
	EnableConfidentialCompute       bool
}

// SchedulingConfig represents instance scheduling configuration
type SchedulingConfig struct {
	AutomaticRestart          bool
	InstanceTerminationAction string
	LocalSsdRecoveryTimeout   *LocalSsdRecoveryTimeout
	MinNodeCpus               int32
	NodeAffinities            []NodeAffinity
	OnHostMaintenance         string
	Preemptible               bool
	ProvisioningModel         string
	TerminationTime           time.Time
	MaxRunDuration            *Duration
	HostErrorTimeoutSeconds   int32
}

// LocalSsdRecoveryTimeout represents local SSD recovery timeout
type LocalSsdRecoveryTimeout struct {
	Nanos   int32
	Seconds int64
}

// NodeAffinity represents node affinity configuration
type NodeAffinity struct {
	Key      string
	Operator string
	Values   []string
}

// Duration represents a duration
type Duration struct {
	Nanos   int32
	Seconds int64
}

// ShieldedConfig represents shielded instance configuration
type ShieldedConfig struct {
	EnableSecureBoot          bool
	EnableVtpm                bool
	EnableIntegrityMonitoring bool
}

// ReservationAffinityConfig represents reservation affinity configuration
type ReservationAffinityConfig struct {
	ConsumeReservationType string
	Key                     string
	Values                  []string
}

// AcceleratorConfig represents GPU accelerator configuration
type AcceleratorConfig struct {
	AcceleratorType  string
	AcceleratorCount int32
}

// AdvancedMachineConfig represents advanced machine features
type AdvancedMachineConfig struct {
	EnableNestedVirtualization bool
	ThreadsPerCore             int32
	VisibleCoreCount           int32
	EnableUefiNetworking       bool
	TurboMode                  string
	Numa                       string
}

// NetworkPerformanceConfig represents network performance configuration
type NetworkPerformanceConfig struct {
	TotalEgressBandwidthTier string
}

// OperationPoller polls for operation completion
type OperationPoller struct {
	client          *compute.GlobalOperationsClient
	zoneOpsClient   *compute.ZoneOperationsClient
	regionOpsClient *compute.RegionOperationsClient
	logger          *zap.Logger
	pollInterval    time.Duration
	maxPollDuration time.Duration
}

// RateLimiter implements rate limiting for compute operations
type RateLimiter struct {
	readLimiter  *time.Ticker
	writeLimiter *time.Ticker
	deleteLimiter *time.Ticker
	mu           sync.Mutex
	readQuota    int
	writeQuota   int
	deleteQuota  int
}

// NewComputeService creates a new comprehensive compute service
func NewComputeService(ctx context.Context, client *Client, opts ...option.ClientOption) (*ComputeService, error) {
	// Initialize all compute clients
	instancesClient, err := compute.NewInstancesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create instances client: %w", err)
	}

	instanceGroupsClient, err := compute.NewInstanceGroupsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create instance groups client: %w", err)
	}

	instanceTemplatesClient, err := compute.NewInstanceTemplatesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create instance templates client: %w", err)
	}

	disksClient, err := compute.NewDisksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create disks client: %w", err)
	}

	snapshotsClient, err := compute.NewSnapshotsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create snapshots client: %w", err)
	}

	imagesClient, err := compute.NewImagesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create images client: %w", err)
	}

	networksClient, err := compute.NewNetworksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create networks client: %w", err)
	}

	firewallsClient, err := compute.NewFirewallsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create firewalls client: %w", err)
	}

	healthChecksClient, err := compute.NewHealthChecksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create health checks client: %w", err)
	}

	backendServicesClient, err := compute.NewBackendServicesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create backend services client: %w", err)
	}

	loadBalancersClient, err := compute.NewForwardingRulesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create load balancers client: %w", err)
	}

	urlMapsClient, err := compute.NewUrlMapsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create URL maps client: %w", err)
	}

	sslCertificatesClient, err := compute.NewSslCertificatesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create SSL certificates client: %w", err)
	}

	targetPoolsClient, err := compute.NewTargetPoolsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create target pools client: %w", err)
	}

	vpnGatewaysClient, err := compute.NewVpnGatewaysRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create VPN gateways client: %w", err)
	}

	vpnTunnelsClient, err := compute.NewVpnTunnelsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create VPN tunnels client: %w", err)
	}

	routersClient, err := compute.NewRoutersRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create routers client: %w", err)
	}

	routesClient, err := compute.NewRoutesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create routes client: %w", err)
	}

	addressesClient, err := compute.NewAddressesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create addresses client: %w", err)
	}

	globalAddressesClient, err := compute.NewGlobalAddressesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create global addresses client: %w", err)
	}

	machineTypesClient, err := compute.NewMachineTypesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create machine types client: %w", err)
	}

	zonesClient, err := compute.NewZonesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create zones client: %w", err)
	}

	regionsClient, err := compute.NewRegionsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create regions client: %w", err)
	}

	projectsClient, err := compute.NewProjectsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create projects client: %w", err)
	}

	// Initialize operation poller
	globalOpsClient, err := compute.NewGlobalOperationsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create global operations client: %w", err)
	}

	zoneOpsClient, err := compute.NewZoneOperationsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create zone operations client: %w", err)
	}

	regionOpsClient, err := compute.NewRegionOperationsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create region operations client: %w", err)
	}

	operationPoller := &OperationPoller{
		client:          globalOpsClient,
		zoneOpsClient:   zoneOpsClient,
		regionOpsClient: regionOpsClient,
		logger:          zap.L().Named("operations"),
		pollInterval:    2 * time.Second,
		maxPollDuration: 10 * time.Minute,
	}

	// Initialize cache
	cache := &ComputeCache{
		instances:         make(map[string]*computepb.Instance),
		instanceTemplates: make(map[string]*computepb.InstanceTemplate),
		machineTypes:      make(map[string]*computepb.MachineType),
		zones:             make(map[string]*computepb.Zone),
		regions:           make(map[string]*computepb.Region),
		networks:          make(map[string]*computepb.Network),
		subnetworks:       make(map[string]*computepb.Subnetwork),
		lastUpdate:        make(map[string]time.Time),
		ttl:               5 * time.Minute,
	}

	// Initialize metrics
	metrics := &ComputeMetrics{
		ErrorCounts:        make(map[string]int64),
		OperationLatencies: make([]time.Duration, 0),
	}

	// Initialize rate limiter
	rateLimiter := &RateLimiter{
		readLimiter:   time.NewTicker(10 * time.Millisecond),
		writeLimiter:  time.NewTicker(100 * time.Millisecond),
		deleteLimiter: time.NewTicker(100 * time.Millisecond),
		readQuota:     2000,
		writeQuota:    200,
		deleteQuota:   100,
	}

	return &ComputeService{
		client:                  client,
		instancesClient:         instancesClient,
		instanceGroupsClient:    instanceGroupsClient,
		instanceTemplatesClient: instanceTemplatesClient,
		disksClient:             disksClient,
		snapshotsClient:         snapshotsClient,
		imagesClient:            imagesClient,
		networksClient:          networksClient,
		firewallsClient:         firewallsClient,
		healthChecksClient:      healthChecksClient,
		backendServicesClient:   backendServicesClient,
		loadBalancersClient:     loadBalancersClient,
		urlMapsClient:           urlMapsClient,
		sslCertificatesClient:   sslCertificatesClient,
		targetPoolsClient:       targetPoolsClient,
		vpnGatewaysClient:       vpnGatewaysClient,
		vpnTunnelsClient:        vpnTunnelsClient,
		routersClient:           routersClient,
		routesClient:            routesClient,
		addressesClient:         addressesClient,
		globalAddressesClient:   globalAddressesClient,
		machineTypesClient:      machineTypesClient,
		zonesClient:             zonesClient,
		regionsClient:           regionsClient,
		projectsClient:          projectsClient,
		logger:                  zap.L(),
		cache:                   cache,
		metrics:                 metrics,
		rateLimiter:             rateLimiter,
		operationPoller:         operationPoller,
	}, nil
}

// CreateInstance creates a new compute instance with comprehensive configuration
func (cs *ComputeService) CreateInstance(ctx context.Context, config *InstanceConfig) (*computepb.Instance, error) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	startTime := time.Now()
	cs.logger.Info("Creating instance",
		zap.String("name", config.Name),
		zap.String("zone", config.Zone),
		zap.String("machineType", config.MachineType))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	// Build instance resource
	instance := &computepb.Instance{
		Name:                    proto.String(config.Name),
		Zone:                    proto.String(fmt.Sprintf("zones/%s", config.Zone)),
		MachineType:             proto.String(fmt.Sprintf("zones/%s/machineTypes/%s", config.Zone, config.MachineType)),
		Description:             proto.String(config.Description),
		Tags:                    &computepb.Tags{Items: config.Tags},
		Labels:                  config.Labels,
		MinCpuPlatform:          proto.String(config.MinCpuPlatform),
		DeletionProtection:      proto.Bool(config.DeletionProtection),
		Hostname:                proto.String(config.Hostname),
		// EnableDisplay field not available in current computepb.Instance
		// EnableDisplay:           proto.Bool(config.EnableDisplay),
		PrivateIpv6GoogleAccess: proto.String(config.PrivateIpv6GoogleAccess),
		Fingerprint:             proto.String(config.Fingerprint),
	}

	// Configure metadata
	if len(config.Metadata) > 0 || config.MetadataStartupScript != "" || config.MetadataShutdownScript != "" {
		items := make([]*computepb.Items, 0)
		for key, value := range config.Metadata {
			items = append(items, &computepb.Items{
				Key:   proto.String(key),
				Value: proto.String(value),
			})
		}
		if config.MetadataStartupScript != "" {
			items = append(items, &computepb.Items{
				Key:   proto.String("startup-script"),
				Value: proto.String(config.MetadataStartupScript),
			})
		}
		if config.MetadataShutdownScript != "" {
			items = append(items, &computepb.Items{
				Key:   proto.String("shutdown-script"),
				Value: proto.String(config.MetadataShutdownScript),
			})
		}
		instance.Metadata = &computepb.Metadata{Items: items}
	}

	// Configure service accounts
	if len(config.ServiceAccounts) > 0 {
		serviceAccounts := make([]*computepb.ServiceAccount, len(config.ServiceAccounts))
		for i, sa := range config.ServiceAccounts {
			serviceAccounts[i] = &computepb.ServiceAccount{
				Email:  proto.String(sa.Email),
				Scopes: sa.Scopes,
			}
		}
		instance.ServiceAccounts = serviceAccounts
	}

	// Configure network interfaces
	if len(config.NetworkInterfaces) > 0 {
		networkInterfaces := make([]*computepb.NetworkInterface, len(config.NetworkInterfaces))
		for i, ni := range config.NetworkInterfaces {
			networkInterface := &computepb.NetworkInterface{
				Network:           proto.String(ni.Network),
				Subnetwork:        proto.String(ni.Subnetwork),
				NetworkIP:         proto.String(ni.NetworkIP),
				Name:              proto.String(ni.Name),
				NicType:           proto.String(ni.NicType),
				QueueCount:        proto.Int32(ni.QueueCount),
				StackType:         proto.String(ni.StackType),
				NetworkAttachment: proto.String(ni.NetworkAttachment),
			}

			// Configure access configs
			if len(ni.AccessConfigs) > 0 {
				accessConfigs := make([]*computepb.AccessConfig, len(ni.AccessConfigs))
				for j, ac := range ni.AccessConfigs {
					accessConfigs[j] = &computepb.AccessConfig{
						Type:                proto.String(ac.Type),
						Name:                proto.String(ac.Name),
						NatIP:               proto.String(ac.NatIP),
						NetworkTier:         proto.String(ac.NetworkTier),
						PublicPtrDomainName: proto.String(ac.PublicPtrDomainName),
						SetPublicPtr:        proto.Bool(ac.SetPublicPtr),
						SecurityPolicy:      proto.String(ac.SecurityPolicy),
					}
				}
				networkInterface.AccessConfigs = accessConfigs
			}

			// Configure alias IP ranges
			if len(ni.AliasIPRanges) > 0 {
				aliasIpRanges := make([]*computepb.AliasIpRange, len(ni.AliasIPRanges))
				for j, air := range ni.AliasIPRanges {
					aliasIpRanges[j] = &computepb.AliasIpRange{
						IpCidrRange:         proto.String(air.IPCIDRRange),
						SubnetworkRangeName: proto.String(air.SubnetworkRangeName),
					}
				}
				networkInterface.AliasIpRanges = aliasIpRanges
			}

			networkInterfaces[i] = networkInterface
		}
		instance.NetworkInterfaces = networkInterfaces
	}

	// Configure disks
	if len(config.Disks) > 0 {
		disks := make([]*computepb.AttachedDisk, len(config.Disks))
		for i, disk := range config.Disks {
			attachedDisk := &computepb.AttachedDisk{
				AutoDelete:      proto.Bool(disk.AutoDelete),
				Boot:            proto.Bool(disk.Boot),
				DeviceName:      proto.String(disk.DeviceName),
				DiskSizeGb:      proto.Int64(disk.DiskSizeGb),
				Interface:       proto.String(disk.Interface),
				Mode:            proto.String(disk.Mode),
				Source:          proto.String(disk.Source),
				Type:            proto.String(disk.DiskType),
				Architecture:    proto.String(disk.Architecture),
			}

			// Configure disk encryption
			if disk.DiskEncryptionKey != nil {
				attachedDisk.DiskEncryptionKey = &computepb.CustomerEncryptionKey{
					RawKey:               proto.String(disk.DiskEncryptionKey.RawKey),
					RsaEncryptedKey:      proto.String(disk.DiskEncryptionKey.RsaEncryptedKey),
					KmsKeyName:           proto.String(disk.DiskEncryptionKey.KmsKeyName),
					KmsKeyServiceAccount: proto.String(disk.DiskEncryptionKey.KmsKeyServiceAccount),
					Sha256:               proto.String(disk.DiskEncryptionKey.Sha256),
				}
			}

			// Configure initialization parameters
			if disk.InitializeParams != nil {
				initParams := &computepb.AttachedDiskInitializeParams{
					DiskName:              proto.String(disk.InitializeParams.DiskName),
					DiskSizeGb:            proto.Int64(disk.InitializeParams.DiskSizeGb),
					DiskType:              proto.String(disk.InitializeParams.DiskType),
					SourceImage:           proto.String(disk.InitializeParams.SourceImage),
					SourceSnapshot:        proto.String(disk.InitializeParams.SourceSnapshot),
					Description:           proto.String(disk.InitializeParams.Description),
					Labels:                disk.InitializeParams.Labels,
					OnUpdateAction:        proto.String(disk.InitializeParams.OnUpdateAction),
					ProvisionedIops:       proto.Int64(disk.InitializeParams.ProvisionedIops),
					ProvisionedThroughput: proto.Int64(disk.InitializeParams.ProvisionedThroughput),
					ResourcePolicies:      disk.InitializeParams.ResourcePolicies,
					Architecture:          proto.String(disk.InitializeParams.Architecture),
					ReplicaZones:          disk.InitializeParams.ReplicaZones,
					StoragePool:           proto.String(disk.InitializeParams.StoragePool),
					EnableConfidentialCompute: proto.Bool(disk.InitializeParams.EnableConfidentialCompute),
				}

				if disk.InitializeParams.SourceImageEncryptionKey != nil {
					initParams.SourceImageEncryptionKey = &computepb.CustomerEncryptionKey{
						RawKey:          proto.String(disk.InitializeParams.SourceImageEncryptionKey.RawKey),
						RsaEncryptedKey: proto.String(disk.InitializeParams.SourceImageEncryptionKey.RsaEncryptedKey),
						KmsKeyName:      proto.String(disk.InitializeParams.SourceImageEncryptionKey.KmsKeyName),
						Sha256:          proto.String(disk.InitializeParams.SourceImageEncryptionKey.Sha256),
					}
				}

				attachedDisk.InitializeParams = initParams
			}

			disks[i] = attachedDisk
		}
		instance.Disks = disks
	}

	// Configure scheduling
	if config.Scheduling != nil {
		scheduling := &computepb.Scheduling{
			AutomaticRestart:          proto.Bool(config.Scheduling.AutomaticRestart),
			InstanceTerminationAction: proto.String(config.Scheduling.InstanceTerminationAction),
			MinNodeCpus:               proto.Int32(config.Scheduling.MinNodeCpus),
			OnHostMaintenance:         proto.String(config.Scheduling.OnHostMaintenance),
			Preemptible:               proto.Bool(config.Scheduling.Preemptible),
			ProvisioningModel:         proto.String(config.Scheduling.ProvisioningModel),
			// HostErrorTimeoutSeconds field not available in current computepb.Scheduling
			// HostErrorTimeoutSeconds:   proto.Int32(config.Scheduling.HostErrorTimeoutSeconds),
		}

		if len(config.Scheduling.NodeAffinities) > 0 {
			nodeAffinities := make([]*computepb.SchedulingNodeAffinity, len(config.Scheduling.NodeAffinities))
			for i, na := range config.Scheduling.NodeAffinities {
				nodeAffinities[i] = &computepb.SchedulingNodeAffinity{
					Key:      proto.String(na.Key),
					Operator: proto.String(na.Operator),
					Values:   na.Values,
				}
			}
			scheduling.NodeAffinities = nodeAffinities
		}

		instance.Scheduling = scheduling
	}

	// Configure shielded instance
	if config.ShieldedInstanceConfig != nil {
		instance.ShieldedInstanceConfig = &computepb.ShieldedInstanceConfig{
			EnableSecureBoot:          proto.Bool(config.ShieldedInstanceConfig.EnableSecureBoot),
			EnableVtpm:                proto.Bool(config.ShieldedInstanceConfig.EnableVtpm),
			EnableIntegrityMonitoring: proto.Bool(config.ShieldedInstanceConfig.EnableIntegrityMonitoring),
		}
	}

	// Configure reservation affinity
	if config.ReservationAffinity != nil {
		instance.ReservationAffinity = &computepb.ReservationAffinity{
			ConsumeReservationType: proto.String(config.ReservationAffinity.ConsumeReservationType),
			Key:                    proto.String(config.ReservationAffinity.Key),
			Values:                 config.ReservationAffinity.Values,
		}
	}

	// Configure guest accelerators
	if len(config.GuestAccelerators) > 0 {
		accelerators := make([]*computepb.AcceleratorConfig, len(config.GuestAccelerators))
		for i, ga := range config.GuestAccelerators {
			accelerators[i] = &computepb.AcceleratorConfig{
				AcceleratorType:  proto.String(ga.AcceleratorType),
				AcceleratorCount: proto.Int32(ga.AcceleratorCount),
			}
		}
		instance.GuestAccelerators = accelerators
	}

	// Configure advanced machine features
	if config.AdvancedMachineFeatures != nil {
		instance.AdvancedMachineFeatures = &computepb.AdvancedMachineFeatures{
			EnableNestedVirtualization: proto.Bool(config.AdvancedMachineFeatures.EnableNestedVirtualization),
			ThreadsPerCore:             proto.Int32(config.AdvancedMachineFeatures.ThreadsPerCore),
			VisibleCoreCount:           proto.Int32(config.AdvancedMachineFeatures.VisibleCoreCount),
			EnableUefiNetworking:       proto.Bool(config.AdvancedMachineFeatures.EnableUefiNetworking),
			TurboMode:                  proto.String(config.AdvancedMachineFeatures.TurboMode),
		}
	}

	// Configure network performance
	if config.NetworkPerformanceConfig != nil {
		instance.NetworkPerformanceConfig = &computepb.NetworkPerformanceConfig{
			TotalEgressBandwidthTier: proto.String(config.NetworkPerformanceConfig.TotalEgressBandwidthTier),
		}
	}

	// Add resource policies
	instance.ResourcePolicies = config.ResourcePolicies

	// Create the instance
	req := &computepb.InsertInstanceRequest{
		Project:          cs.client.projectID,
		Zone:             config.Zone,
		InstanceResource: instance,
	}

	op, err := cs.instancesClient.Insert(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_create"]++
		cs.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create instance: %w", err)
	}

	// Wait for operation to complete
	// op.Name is a pointer to string
	if op.Name != nil {
		if err := cs.waitForZoneOperation(ctx, config.Zone, op.Name()); err != nil {
			return nil, fmt.Errorf("instance creation operation failed: %w", err)
		}
	} else {
		return nil, fmt.Errorf("operation name is nil")
	}

	// Get the created instance
	getReq := &computepb.GetInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     config.Zone,
		Instance: config.Name,
	}

	createdInstance, err := cs.instancesClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created instance: %w", err)
	}

	// Update cache
	cs.cache.mu.Lock()
	cacheKey := fmt.Sprintf("%s/%s/%s", cs.client.projectID, config.Zone, config.Name)
	cs.cache.instances[cacheKey] = createdInstance
	cs.cache.lastUpdate[cacheKey] = time.Now()
	cs.cache.mu.Unlock()

	// Update metrics
	cs.metrics.mu.Lock()
	cs.metrics.InstanceOperations++
	cs.metrics.OperationLatencies = append(cs.metrics.OperationLatencies, time.Since(startTime))
	cs.metrics.mu.Unlock()

	cs.logger.Info("Instance created successfully",
		zap.String("name", config.Name),
		zap.String("zone", config.Zone),
		zap.Duration("duration", time.Since(startTime)))

	return createdInstance, nil
}

// GetInstance retrieves an instance by name and zone
func (cs *ComputeService) GetInstance(ctx context.Context, zone, name string) (*computepb.Instance, error) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	// Check cache first
	cacheKey := fmt.Sprintf("%s/%s/%s", cs.client.projectID, zone, name)
	cs.cache.mu.RLock()
	if instance, ok := cs.cache.instances[cacheKey]; ok {
		if time.Since(cs.cache.lastUpdate[cacheKey]) < cs.cache.ttl {
			cs.cache.mu.RUnlock()
			cs.logger.Debug("Returning instance from cache", zap.String("name", name))
			return instance, nil
		}
	}
	cs.cache.mu.RUnlock()

	// Apply rate limiting
	<-cs.rateLimiter.readLimiter.C

	req := &computepb.GetInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
	}

	instance, err := cs.instancesClient.Get(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_get"]++
		cs.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to get instance: %w", err)
	}

	// Update cache
	cs.cache.mu.Lock()
	cs.cache.instances[cacheKey] = instance
	cs.cache.lastUpdate[cacheKey] = time.Now()
	cs.cache.mu.Unlock()

	return instance, nil
}

// ListInstances lists all instances in a zone or all zones
func (cs *ComputeService) ListInstances(ctx context.Context, zone string, filter string) ([]*computepb.Instance, error) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()

	instances := make([]*computepb.Instance, 0)

	// Apply rate limiting
	<-cs.rateLimiter.readLimiter.C

	if zone != "" {
		// List instances in specific zone
		req := &computepb.ListInstancesRequest{
			Project: cs.client.projectID,
			Zone:    zone,
			Filter:  proto.String(filter),
		}

		it := cs.instancesClient.List(ctx, req)
		for {
			instance, err := it.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				cs.metrics.mu.Lock()
				cs.metrics.ErrorCounts["instance_list"]++
				cs.metrics.mu.Unlock()
				return nil, fmt.Errorf("failed to list instances: %w", err)
			}
			instances = append(instances, instance)
		}
	} else {
		// List instances in all zones
		req := &computepb.AggregatedListInstancesRequest{
			Project: cs.client.projectID,
			Filter:  proto.String(filter),
		}

		it := cs.instancesClient.AggregatedList(ctx, req)
		for {
			pair, err := it.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				cs.metrics.mu.Lock()
				cs.metrics.ErrorCounts["instance_list"]++
				cs.metrics.mu.Unlock()
				return nil, fmt.Errorf("failed to list instances: %w", err)
			}
			if pair.Value.Instances != nil {
				instances = append(instances, pair.Value.Instances...)
			}
		}
	}

	cs.logger.Info("Listed instances",
		zap.String("zone", zone),
		zap.Int("count", len(instances)))

	return instances, nil
}

// DeleteInstance deletes an instance
func (cs *ComputeService) DeleteInstance(ctx context.Context, zone, name string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	startTime := time.Now()
	cs.logger.Info("Deleting instance",
		zap.String("name", name),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.deleteLimiter.C

	req := &computepb.DeleteInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
	}

	op, err := cs.instancesClient.Delete(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_delete"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to delete instance: %w", err)
	}

	// Wait for operation to complete
	// op.Name is a pointer to string
	if op.Name == nil {
		return fmt.Errorf("operation name is nil")
	}
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("instance deletion operation failed: %w", err)
	}

	// Remove from cache
	cacheKey := fmt.Sprintf("%s/%s/%s", cs.client.projectID, zone, name)
	cs.cache.mu.Lock()
	delete(cs.cache.instances, cacheKey)
	delete(cs.cache.lastUpdate, cacheKey)
	cs.cache.mu.Unlock()

	// Update metrics
	cs.metrics.mu.Lock()
	cs.metrics.InstanceOperations++
	cs.metrics.OperationLatencies = append(cs.metrics.OperationLatencies, time.Since(startTime))
	cs.metrics.mu.Unlock()

	cs.logger.Info("Instance deleted successfully",
		zap.String("name", name),
		zap.String("zone", zone),
		zap.Duration("duration", time.Since(startTime)))

	return nil
}

// StartInstance starts a stopped instance
func (cs *ComputeService) StartInstance(ctx context.Context, zone, name string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Starting instance",
		zap.String("name", name),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	req := &computepb.StartInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
	}

	op, err := cs.instancesClient.Start(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_start"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to start instance: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("instance start operation failed: %w", err)
	}

	cs.logger.Info("Instance started successfully",
		zap.String("name", name),
		zap.String("zone", zone))

	return nil
}

// StopInstance stops a running instance
func (cs *ComputeService) StopInstance(ctx context.Context, zone, name string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Stopping instance",
		zap.String("name", name),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	req := &computepb.StopInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
	}

	op, err := cs.instancesClient.Stop(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_stop"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to stop instance: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("instance stop operation failed: %w", err)
	}

	cs.logger.Info("Instance stopped successfully",
		zap.String("name", name),
		zap.String("zone", zone))

	return nil
}

// ResetInstance resets an instance
func (cs *ComputeService) ResetInstance(ctx context.Context, zone, name string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Resetting instance",
		zap.String("name", name),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	req := &computepb.ResetInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
	}

	op, err := cs.instancesClient.Reset(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_reset"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to reset instance: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("instance reset operation failed: %w", err)
	}

	cs.logger.Info("Instance reset successfully",
		zap.String("name", name),
		zap.String("zone", zone))

	return nil
}

// ResizeInstance changes the machine type of an instance
func (cs *ComputeService) ResizeInstance(ctx context.Context, zone, name, newMachineType string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Resizing instance",
		zap.String("name", name),
		zap.String("zone", zone),
		zap.String("newMachineType", newMachineType))

	// Stop the instance first
	if err := cs.StopInstance(ctx, zone, name); err != nil {
		return fmt.Errorf("failed to stop instance before resize: %w", err)
	}

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	// Change machine type
	req := &computepb.SetMachineTypeInstanceRequest{
		Project:  cs.client.projectID,
		Zone:     zone,
		Instance: name,
		InstancesSetMachineTypeRequestResource: &computepb.InstancesSetMachineTypeRequest{
			MachineType: proto.String(fmt.Sprintf("zones/%s/machineTypes/%s", zone, newMachineType)),
		},
	}

	op, err := cs.instancesClient.SetMachineType(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["instance_resize"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to set machine type: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("machine type change operation failed: %w", err)
	}

	// Start the instance again
	if err := cs.StartInstance(ctx, zone, name); err != nil {
		return fmt.Errorf("failed to start instance after resize: %w", err)
	}

	cs.logger.Info("Instance resized successfully",
		zap.String("name", name),
		zap.String("zone", zone),
		zap.String("newMachineType", newMachineType))

	return nil
}

// AttachDisk attaches a disk to an instance
func (cs *ComputeService) AttachDisk(ctx context.Context, zone, instance, disk string, deviceName string, readOnly bool) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Attaching disk to instance",
		zap.String("instance", instance),
		zap.String("disk", disk),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	attachedDisk := &computepb.AttachedDisk{
		Source:     proto.String(fmt.Sprintf("zones/%s/disks/%s", zone, disk)),
		DeviceName: proto.String(deviceName),
		Mode:       proto.String("READ_WRITE"),
	}

	if readOnly {
		attachedDisk.Mode = proto.String("READ_ONLY")
	}

	req := &computepb.AttachDiskInstanceRequest{
		Project:                cs.client.projectID,
		Zone:                   zone,
		Instance:               instance,
		AttachedDiskResource:   attachedDisk,
		ForceAttach:            proto.Bool(false),
	}

	op, err := cs.instancesClient.AttachDisk(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["disk_attach"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to attach disk: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("disk attach operation failed: %w", err)
	}

	cs.logger.Info("Disk attached successfully",
		zap.String("instance", instance),
		zap.String("disk", disk),
		zap.String("zone", zone))

	return nil
}

// DetachDisk detaches a disk from an instance
func (cs *ComputeService) DetachDisk(ctx context.Context, zone, instance, deviceName string) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Detaching disk from instance",
		zap.String("instance", instance),
		zap.String("deviceName", deviceName),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	req := &computepb.DetachDiskInstanceRequest{
		Project:    cs.client.projectID,
		Zone:       zone,
		Instance:   instance,
		DeviceName: deviceName,
	}

	op, err := cs.instancesClient.DetachDisk(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["disk_detach"]++
		cs.metrics.mu.Unlock()
		return fmt.Errorf("failed to detach disk: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return fmt.Errorf("disk detach operation failed: %w", err)
	}

	cs.logger.Info("Disk detached successfully",
		zap.String("instance", instance),
		zap.String("deviceName", deviceName),
		zap.String("zone", zone))

	return nil
}

// CreateSnapshot creates a snapshot of a disk
func (cs *ComputeService) CreateSnapshot(ctx context.Context, zone, disk, snapshotName string, labels map[string]string) (*computepb.Snapshot, error) {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Creating snapshot",
		zap.String("disk", disk),
		zap.String("snapshotName", snapshotName),
		zap.String("zone", zone))

	// Apply rate limiting
	<-cs.rateLimiter.writeLimiter.C

	snapshot := &computepb.Snapshot{
		Name:        proto.String(snapshotName),
		Description: proto.String(fmt.Sprintf("Snapshot of disk %s", disk)),
		Labels:      labels,
		SourceDisk:  proto.String(fmt.Sprintf("zones/%s/disks/%s", zone, disk)),
	}

	req := &computepb.CreateSnapshotDiskRequest{
		Project:          cs.client.projectID,
		Zone:             zone,
		Disk:             disk,
		SnapshotResource: snapshot,
	}

	op, err := cs.disksClient.CreateSnapshot(ctx, req)
	if err != nil {
		cs.metrics.mu.Lock()
		cs.metrics.ErrorCounts["snapshot_create"]++
		cs.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create snapshot: %w", err)
	}

	// Wait for operation to complete
	if err := cs.waitForZoneOperation(ctx, zone, op.Name()); err != nil {
		return nil, fmt.Errorf("snapshot creation operation failed: %w", err)
	}

	// Get the created snapshot
	getReq := &computepb.GetSnapshotRequest{
		Project:  cs.client.projectID,
		Snapshot: snapshotName,
	}

	createdSnapshot, err := cs.snapshotsClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created snapshot: %w", err)
	}

	cs.metrics.mu.Lock()
	cs.metrics.SnapshotOperations++
	cs.metrics.mu.Unlock()

	cs.logger.Info("Snapshot created successfully",
		zap.String("disk", disk),
		zap.String("snapshotName", snapshotName),
		zap.String("zone", zone))

	return createdSnapshot, nil
}

// GetMetadata retrieves metadata from the metadata server
func (cs *ComputeService) GetMetadata(ctx context.Context, path string) (string, error) {
	if !metadata.OnGCE() {
		return "", fmt.Errorf("not running on Google Compute Engine")
	}

	value, err := metadata.GetWithContext(ctx, path)
	if err != nil {
		return "", fmt.Errorf("failed to get metadata for path %s: %w", path, err)
	}

	return value, nil
}

// waitForZoneOperation waits for a zone operation to complete
func (cs *ComputeService) waitForZoneOperation(ctx context.Context, zone, operationName string) error {
	return cs.operationPoller.WaitForZoneOperation(ctx, cs.client.projectID, zone, operationName)
}

// waitForRegionOperation waits for a region operation to complete
func (cs *ComputeService) waitForRegionOperation(ctx context.Context, region, operationName string) error {
	return cs.operationPoller.WaitForRegionOperation(ctx, cs.client.projectID, region, operationName)
}

// waitForGlobalOperation waits for a global operation to complete
func (cs *ComputeService) waitForGlobalOperation(ctx context.Context, operationName string) error {
	return cs.operationPoller.WaitForGlobalOperation(ctx, cs.client.projectID, operationName)
}

// WaitForZoneOperation waits for a zone operation to complete
func (op *OperationPoller) WaitForZoneOperation(ctx context.Context, project, zone, operationName string) error {
	ticker := time.NewTicker(op.pollInterval)
	defer ticker.Stop()

	deadline := time.Now().Add(op.maxPollDuration)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if time.Now().After(deadline) {
				return fmt.Errorf("operation timeout: %s", operationName)
			}

			req := &computepb.GetZoneOperationRequest{
				Project:   project,
				Zone:      zone,
				Operation: operationName,
			}

			operation, err := op.zoneOpsClient.Get(ctx, req)
			if err != nil {
				return fmt.Errorf("failed to get operation status: %w", err)
			}

			if operation.GetStatus() == computepb.Operation_DONE {
				if operation.GetError() != nil {
					return fmt.Errorf("operation failed: %v", operation.GetError())
				}
				return nil
			}

			op.logger.Debug("Waiting for operation",
				zap.String("operation", operationName),
				zap.String("status", operation.GetStatus().String()),
				zap.Int32("progress", operation.GetProgress()))
		}
	}
}

// WaitForRegionOperation waits for a region operation to complete
func (op *OperationPoller) WaitForRegionOperation(ctx context.Context, project, region, operationName string) error {
	ticker := time.NewTicker(op.pollInterval)
	defer ticker.Stop()

	deadline := time.Now().Add(op.maxPollDuration)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if time.Now().After(deadline) {
				return fmt.Errorf("operation timeout: %s", operationName)
			}

			req := &computepb.GetRegionOperationRequest{
				Project:   project,
				Region:    region,
				Operation: operationName,
			}

			operation, err := op.regionOpsClient.Get(ctx, req)
			if err != nil {
				return fmt.Errorf("failed to get operation status: %w", err)
			}

			if operation.GetStatus() == computepb.Operation_DONE {
				if operation.GetError() != nil {
					return fmt.Errorf("operation failed: %v", operation.GetError())
				}
				return nil
			}

			op.logger.Debug("Waiting for operation",
				zap.String("operation", operationName),
				zap.String("status", operation.GetStatus().String()),
				zap.Int32("progress", operation.GetProgress()))
		}
	}
}

// WaitForGlobalOperation waits for a global operation to complete
func (op *OperationPoller) WaitForGlobalOperation(ctx context.Context, project, operationName string) error {
	ticker := time.NewTicker(op.pollInterval)
	defer ticker.Stop()

	deadline := time.Now().Add(op.maxPollDuration)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if time.Now().After(deadline) {
				return fmt.Errorf("operation timeout: %s", operationName)
			}

			req := &computepb.GetGlobalOperationRequest{
				Project:   project,
				Operation: operationName,
			}

			operation, err := op.client.Get(ctx, req)
			if err != nil {
				return fmt.Errorf("failed to get operation status: %w", err)
			}

			if operation.GetStatus() == computepb.Operation_DONE {
				if operation.GetError() != nil {
					return fmt.Errorf("operation failed: %v", operation.GetError())
				}
				return nil
			}

			op.logger.Debug("Waiting for operation",
				zap.String("operation", operationName),
				zap.String("status", operation.GetStatus().String()),
				zap.Int32("progress", operation.GetProgress()))
		}
	}
}

// GetMetrics returns compute service metrics
func (cs *ComputeService) GetMetrics() *ComputeMetrics {
	cs.metrics.mu.RLock()
	defer cs.metrics.mu.RUnlock()

	return &ComputeMetrics{
		InstanceOperations:     cs.metrics.InstanceOperations,
		DiskOperations:         cs.metrics.DiskOperations,
		NetworkOperations:      cs.metrics.NetworkOperations,
		SnapshotOperations:     cs.metrics.SnapshotOperations,
		LoadBalancerOperations: cs.metrics.LoadBalancerOperations,
		OperationLatencies:     append([]time.Duration{}, cs.metrics.OperationLatencies...),
		ErrorCounts:            copyErrorCounts(cs.metrics.ErrorCounts),
	}
}

// copyErrorCounts creates a copy of error counts map
func copyErrorCounts(m map[string]int64) map[string]int64 {
	result := make(map[string]int64)
	for k, v := range m {
		result[k] = v
	}
	return result
}

// Close closes all compute service resources
func (cs *ComputeService) Close() error {
	cs.mu.Lock()
	defer cs.mu.Unlock()

	cs.logger.Info("Closing compute service")

	// Close all clients
	var errs []error

	if err := cs.instancesClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close instances client: %w", err))
	}
	if err := cs.instanceGroupsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close instance groups client: %w", err))
	}
	if err := cs.instanceTemplatesClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close instance templates client: %w", err))
	}
	if err := cs.disksClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close disks client: %w", err))
	}
	if err := cs.snapshotsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close snapshots client: %w", err))
	}
	if err := cs.imagesClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close images client: %w", err))
	}
	if err := cs.networksClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close networks client: %w", err))
	}
	if err := cs.firewallsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close firewalls client: %w", err))
	}

	// Stop rate limiters
	cs.rateLimiter.readLimiter.Stop()
	cs.rateLimiter.writeLimiter.Stop()
	cs.rateLimiter.deleteLimiter.Stop()

	if len(errs) > 0 {
		return fmt.Errorf("errors closing compute service: %v", errs)
	}

	return nil
}