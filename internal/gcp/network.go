package gcp

import (
	"context"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	networkconnectivity "cloud.google.com/go/networkconnectivity/apiv1"
	"cloud.google.com/go/networkconnectivity/apiv1/networkconnectivitypb"
	servicenetworking "cloud.google.com/go/servicenetworking/apiv1"
	vpcaccess "cloud.google.com/go/vpcaccess/apiv1"
	"cloud.google.com/go/vpcaccess/apiv1/vpcaccesspb"
	"go.uber.org/zap"
	"google.golang.org/api/dns/v1"
	"google.golang.org/api/iterator"
	"google.golang.org/api/networkmanagement/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/servicenetworking/v1"
	"google.golang.org/protobuf/proto"
)

// NetworkService provides comprehensive network operations
type NetworkService struct {
	networksClient             *compute.NetworksClient
	subnetworksClient          *compute.SubnetworksClient
	firewallsClient            *compute.FirewallsClient
	routesClient               *compute.RoutesClient
	routersClient              *compute.RoutersClient
	vpnGatewaysClient          *compute.VpnGatewaysClient
	vpnTunnelsClient           *compute.VpnTunnelsClient
	interconnectsClient        *compute.InterconnectsClient
	interconnectAttachmentsClient *compute.InterconnectAttachmentsClient
	addressesClient            *compute.AddressesClient
	globalAddressesClient      *compute.GlobalAddressesClient
	forwardingRulesClient      *compute.ForwardingRulesClient
	globalForwardingRulesClient *compute.GlobalForwardingRulesClient
	targetPoolsClient          *compute.TargetPoolsClient
	backendServicesClient      *compute.BackendServicesClient
	healthChecksClient         *compute.HealthChecksClient
	urlMapsClient              *compute.UrlMapsClient
	targetHttpProxiesClient    *compute.TargetHttpProxiesClient
	targetHttpsProxiesClient   *compute.TargetHttpsProxiesClient
	sslCertificatesClient      *compute.SslCertificatesClient
	networkEndpointGroupsClient *compute.NetworkEndpointGroupsClient
	packetMirroringsClient     *compute.PacketMirroringsClient
	securityPoliciesClient     *compute.SecurityPoliciesClient
	networkConnectivityClient  *networkconnectivity.HubClient
	serviceNetworkingClient    *servicenetworking.Service
	vpcAccessClient            *vpcaccess.Client
	dnsService                 *dns.Service
	networkManagementService   *networkmanagement.Service
	networkCache               *NetworkCache
	subnetCache                *SubnetCache
	firewallCache              *FirewallCache
	routeCache                 *RouteCache
	peeringManager             *PeeringManager
	privateServiceManager      *PrivateServiceManager
	loadBalancerManager        *LoadBalancerManager
	vpnManager                 *VPNManager
	interconnectManager        *InterconnectManager
	dnsManager                 *DNSManager
	networkAnalyzer            *NetworkAnalyzer
	trafficAnalyzer            *TrafficAnalyzer
	logger                     *zap.Logger
	metrics                    *NetworkMetrics
	rateLimiter                *NetworkRateLimiter
	mu                         sync.RWMutex
}

// NetworkCache caches network information
type NetworkCache struct {
	networks    map[string]*computepb.Network
	networkInfo map[string]*NetworkInfo
	mu          sync.RWMutex
	ttl         time.Duration
	lastUpdate  map[string]time.Time
}

// SubnetCache caches subnet information
type SubnetCache struct {
	subnets       map[string]*computepb.Subnetwork
	availableIPs  map[string][]string
	usedIPs       map[string][]string
	mu            sync.RWMutex
	ttl           time.Duration
	lastUpdate    map[string]time.Time
}

// FirewallCache caches firewall rules
type FirewallCache struct {
	rules         map[string]*computepb.Firewall
	rulesByTag    map[string][]*computepb.Firewall
	rulesByNetwork map[string][]*computepb.Firewall
	mu            sync.RWMutex
	ttl           time.Duration
	lastUpdate    map[string]time.Time
}

// RouteCache caches routes
type RouteCache struct {
	routes        map[string]*computepb.Route
	routesByNetwork map[string][]*computepb.Route
	routeTables   map[string]*RouteTable
	mu            sync.RWMutex
	ttl           time.Duration
	lastUpdate    map[string]time.Time
}

// NetworkInfo contains detailed network information
type NetworkInfo struct {
	Network          *computepb.Network
	Subnets          []*computepb.Subnetwork
	FirewallRules    []*computepb.Firewall
	Routes           []*computepb.Route
	Peerings         []*NetworkPeering
	ConnectedProjects []string
	IPRanges         []*IPRange
	UsedIPCount      int64
	AvailableIPCount int64
}

// NetworkPeering represents a VPC peering connection
type NetworkPeering struct {
	Name                     string
	Network                  string
	PeerNetwork              string
	State                    string
	StateDetails             string
	AutoCreateRoutes         bool
	ExportCustomRoutes       bool
	ImportCustomRoutes       bool
	ExportSubnetRoutesWithPublicIP bool
	ImportSubnetRoutesWithPublicIP bool
	StackType                string
}

// IPRange represents an IP address range
type IPRange struct {
	CIDR          string
	StartIP       net.IP
	EndIP         net.IP
	Gateway       net.IP
	Broadcast     net.IP
	UsableIPs     int64
	ReservedRanges []string
	Purpose       string
}

// RouteTable represents a routing table
type RouteTable struct {
	Network       string
	Routes        []*computepb.Route
	DefaultRoute  *computepb.Route
	CustomRoutes  []*computepb.Route
	PeeringRoutes []*computepb.Route
	NextHopMap    map[string]string
}

// PeeringManager manages VPC peering connections
type PeeringManager struct {
	client   *compute.NetworksClient
	logger   *zap.Logger
	peerings map[string]*NetworkPeering
	mu       sync.RWMutex
}

// PrivateServiceManager manages private service connections
type PrivateServiceManager struct {
	client              *servicenetworking.Service
	logger              *zap.Logger
	connections         map[string]*PrivateServiceConnection
	allocatedRanges     map[string]*AllocatedRange
	mu                  sync.RWMutex
}

// PrivateServiceConnection represents a private service connection
type PrivateServiceConnection struct {
	Network         string
	Service         string
	ReservedIPRange string
	IPPrefix        int
	ConnectionName  string
	Status          string
}

// AllocatedRange represents an allocated IP range
type AllocatedRange struct {
	Name         string
	Network      string
	IPRange      string
	PrefixLength int
	Purpose      string
	CreateTime   time.Time
}

// LoadBalancerManager manages load balancing resources
type LoadBalancerManager struct {
	backendServicesClient *compute.BackendServicesClient
	healthChecksClient    *compute.HealthChecksClient
	urlMapsClient         *compute.UrlMapsClient
	targetPoolsClient     *compute.TargetPoolsClient
	logger                *zap.Logger
	loadBalancers         map[string]*LoadBalancer
	healthChecks          map[string]*computepb.HealthCheck
	mu                    sync.RWMutex
}

// LoadBalancer represents a load balancer configuration
type LoadBalancer struct {
	Name            string
	Type            string // HTTP, HTTPS, TCP, UDP, Internal
	BackendServices []*computepb.BackendService
	HealthChecks    []*computepb.HealthCheck
	URLMap          *computepb.UrlMap
	ForwardingRules []*computepb.ForwardingRule
	TargetPools     []*computepb.TargetPool
	SSLCertificates []*computepb.SslCertificate
	IPAddress       string
	Port            []string
	Protocol        string
}

// VPNManager manages VPN connections
type VPNManager struct {
	vpnGatewaysClient *compute.VpnGatewaysClient
	vpnTunnelsClient  *compute.VpnTunnelsClient
	logger            *zap.Logger
	gateways          map[string]*computepb.VpnGateway
	tunnels           map[string]*computepb.VpnTunnel
	connections       map[string]*VPNConnection
	mu                sync.RWMutex
}

// VPNConnection represents a VPN connection
type VPNConnection struct {
	Gateway              *computepb.VpnGateway
	Tunnels              []*computepb.VpnTunnel
	PeerGateway          string
	PeerIP               string
	SharedSecret         string
	IKEVersion           int32
	LocalTrafficSelector []string
	RemoteTrafficSelector []string
	Status               string
	Throughput           int64
}

// InterconnectManager manages interconnect attachments
type InterconnectManager struct {
	interconnectsClient       *compute.InterconnectsClient
	attachmentsClient         *compute.InterconnectAttachmentsClient
	logger                    *zap.Logger
	interconnects             map[string]*computepb.Interconnect
	attachments               map[string]*computepb.InterconnectAttachment
	mu                        sync.RWMutex
}

// DNSManager manages DNS resources
type DNSManager struct {
	service      *dns.Service
	logger       *zap.Logger
	zones        map[string]*dns.ManagedZone
	records      map[string][]*dns.ResourceRecordSet
	policies     map[string]*dns.Policy
	mu           sync.RWMutex
}

// NetworkAnalyzer analyzes network configurations
type NetworkAnalyzer struct {
	service              *networkmanagement.Service
	logger               *zap.Logger
	connectivityTests    map[string]*networkmanagement.ConnectivityTest
	reachabilityDetails  map[string]*ReachabilityAnalysis
	mu                   sync.RWMutex
}

// ReachabilityAnalysis represents network reachability analysis
type ReachabilityAnalysis struct {
	Source           string
	Destination      string
	Protocol         string
	Port             int32
	Result           string
	Traces           []*networkmanagement.Trace
	VerifyTime       time.Time
	Latency          time.Duration
	PacketLoss       float64
	Hops             int32
	BlockingFirewall string
	BlockingRoute    string
}

// TrafficAnalyzer analyzes network traffic
type TrafficAnalyzer struct {
	logger          *zap.Logger
	flowLogs        map[string][]*FlowLog
	trafficPatterns map[string]*TrafficPattern
	anomalies       []TrafficAnomaly
	mu              sync.RWMutex
}

// FlowLog represents a VPC flow log entry
type FlowLog struct {
	Timestamp    time.Time
	SourceIP     string
	DestIP       string
	SourcePort   int32
	DestPort     int32
	Protocol     string
	Bytes        int64
	Packets      int64
	Action       string
	Direction    string
}

// TrafficPattern represents observed traffic patterns
type TrafficPattern struct {
	TopSources      []string
	TopDestinations []string
	TopProtocols    []string
	PeakHours       []int
	AverageBytes    int64
	AveragePackets  int64
	TotalBytes      int64
	TotalPackets    int64
}

// TrafficAnomaly represents a detected traffic anomaly
type TrafficAnomaly struct {
	Timestamp   time.Time
	Type        string
	Severity    string
	Description string
	SourceIP    string
	DestIP      string
	Details     map[string]interface{}
}

// NetworkMetrics tracks network operations metrics
type NetworkMetrics struct {
	NetworkOperations    int64
	SubnetOperations     int64
	FirewallOperations   int64
	RouteOperations      int64
	PeeringOperations    int64
	VPNOperations        int64
	LoadBalancerOperations int64
	DNSOperations        int64
	ErrorCounts          map[string]int64
	OperationLatencies   []time.Duration
	TrafficBytes         int64
	TrafficPackets       int64
	mu                   sync.RWMutex
}

// NetworkRateLimiter implements rate limiting
type NetworkRateLimiter struct {
	readLimiter   *time.Ticker
	writeLimiter  *time.Ticker
	deleteLimiter *time.Ticker
	adminLimiter  *time.Ticker
	mu            sync.Mutex
}

// NetworkConfig represents comprehensive network configuration
type NetworkConfig struct {
	Name                    string
	Description             string
	AutoCreateSubnetworks   bool
	RoutingMode             string
	MTU                     int32
	EnableUlaInternalIpv6   bool
	InternalIpv6Range       string
	NetworkFirewallPolicyEnforcement string
	Subnets                 []*SubnetConfig
	FirewallRules           []*FirewallConfig
	Routes                  []*RouteConfig
	Peerings                []*PeeringConfig
}

// SubnetConfig represents subnet configuration
type SubnetConfig struct {
	Name                     string
	Region                   string
	IPCIDRRange              string
	Purpose                  string
	Role                     string
	SecondaryIPRanges        []*SecondaryRange
	PrivateIPGoogleAccess    bool
	PrivateIpv6GoogleAccess  string
	FlowLogs                 *FlowLogConfig
	StackType                string
	Ipv6AccessType           string
	Ipv6CidrRange            string
	ExternalIpv6Prefix       string
	AggregationInterval      string
	EnableL7IlbSubnet        bool
}

// SecondaryRange represents a secondary IP range
type SecondaryRange struct {
	RangeName   string
	IPCIDRRange string
}

// FlowLogConfig represents flow log configuration
type FlowLogConfig struct {
	Enable              bool
	AggregationInterval string
	FlowSampling        float64
	Metadata            string
	MetadataFields      []string
	FilterExpression    string
}

// FirewallConfig represents firewall rule configuration
type FirewallConfig struct {
	Name               string
	Description        string
	Direction          string
	Priority           int32
	SourceRanges       []string
	DestinationRanges  []string
	SourceTags         []string
	TargetTags         []string
	SourceServiceAccounts []string
	TargetServiceAccounts []string
	Allowed            []*FirewallRule
	Denied             []*FirewallRule
	LogConfig          *FirewallLogConfig
	Disabled           bool
	EnableLogging      bool
}

// FirewallRule represents a firewall allow/deny rule
type FirewallRule struct {
	IPProtocol string
	Ports      []string
}

// FirewallLogConfig represents firewall logging configuration
type FirewallLogConfig struct {
	Enable   bool
	Metadata string
}

// RouteConfig represents route configuration
type RouteConfig struct {
	Name             string
	Description      string
	DestRange        string
	Priority         int32
	NextHopInstance  string
	NextHopIP        string
	NextHopNetwork   string
	NextHopGateway   string
	NextHopVpnTunnel string
	NextHopIlb       string
	NextHopHub       string
	Tags             []string
}

// PeeringConfig represents peering configuration
type PeeringConfig struct {
	Name                     string
	PeerNetwork              string
	AutoCreateRoutes         bool
	ExportCustomRoutes       bool
	ImportCustomRoutes       bool
	ExportSubnetRoutesWithPublicIP bool
	ImportSubnetRoutesWithPublicIP bool
	StackType                string
}

// NewNetworkService creates a new comprehensive network service
func NewNetworkService(ctx context.Context, projectID string, opts ...option.ClientOption) (*NetworkService, error) {
	logger := zap.L().Named("network")

	// Initialize all network-related clients
	networksClient, err := compute.NewNetworksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create networks client: %w", err)
	}

	subnetworksClient, err := compute.NewSubnetworksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create subnetworks client: %w", err)
	}

	firewallsClient, err := compute.NewFirewallsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create firewalls client: %w", err)
	}

	routesClient, err := compute.NewRoutesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create routes client: %w", err)
	}

	routersClient, err := compute.NewRoutersRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create routers client: %w", err)
	}

	vpnGatewaysClient, err := compute.NewVpnGatewaysRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create VPN gateways client: %w", err)
	}

	vpnTunnelsClient, err := compute.NewVpnTunnelsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create VPN tunnels client: %w", err)
	}

	interconnectsClient, err := compute.NewInterconnectsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create interconnects client: %w", err)
	}

	interconnectAttachmentsClient, err := compute.NewInterconnectAttachmentsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create interconnect attachments client: %w", err)
	}

	addressesClient, err := compute.NewAddressesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create addresses client: %w", err)
	}

	globalAddressesClient, err := compute.NewGlobalAddressesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create global addresses client: %w", err)
	}

	forwardingRulesClient, err := compute.NewForwardingRulesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create forwarding rules client: %w", err)
	}

	globalForwardingRulesClient, err := compute.NewGlobalForwardingRulesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create global forwarding rules client: %w", err)
	}

	targetPoolsClient, err := compute.NewTargetPoolsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create target pools client: %w", err)
	}

	backendServicesClient, err := compute.NewBackendServicesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create backend services client: %w", err)
	}

	healthChecksClient, err := compute.NewHealthChecksRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create health checks client: %w", err)
	}

	urlMapsClient, err := compute.NewUrlMapsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create URL maps client: %w", err)
	}

	targetHttpProxiesClient, err := compute.NewTargetHttpProxiesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create target HTTP proxies client: %w", err)
	}

	targetHttpsProxiesClient, err := compute.NewTargetHttpsProxiesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create target HTTPS proxies client: %w", err)
	}

	sslCertificatesClient, err := compute.NewSslCertificatesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create SSL certificates client: %w", err)
	}

	networkEndpointGroupsClient, err := compute.NewNetworkEndpointGroupsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create network endpoint groups client: %w", err)
	}

	packetMirroringsClient, err := compute.NewPacketMirroringsRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create packet mirrorings client: %w", err)
	}

	securityPoliciesClient, err := compute.NewSecurityPoliciesRESTClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create security policies client: %w", err)
	}

	networkConnectivityClient, err := networkconnectivity.NewHubClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create network connectivity client: %w", err)
	}

	serviceNetworkingClient, err := servicenetworking.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create service networking client: %w", err)
	}

	vpcAccessClient, err := vpcaccess.NewClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create VPC access client: %w", err)
	}

	dnsService, err := dns.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create DNS service: %w", err)
	}

	networkManagementService, err := networkmanagement.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create network management service: %w", err)
	}

	// Initialize caches
	networkCache := &NetworkCache{
		networks:    make(map[string]*computepb.Network),
		networkInfo: make(map[string]*NetworkInfo),
		lastUpdate:  make(map[string]time.Time),
		ttl:         5 * time.Minute,
	}

	subnetCache := &SubnetCache{
		subnets:      make(map[string]*computepb.Subnetwork),
		availableIPs: make(map[string][]string),
		usedIPs:      make(map[string][]string),
		lastUpdate:   make(map[string]time.Time),
		ttl:          5 * time.Minute,
	}

	firewallCache := &FirewallCache{
		rules:          make(map[string]*computepb.Firewall),
		rulesByTag:     make(map[string][]*computepb.Firewall),
		rulesByNetwork: make(map[string][]*computepb.Firewall),
		lastUpdate:     make(map[string]time.Time),
		ttl:            2 * time.Minute,
	}

	routeCache := &RouteCache{
		routes:          make(map[string]*computepb.Route),
		routesByNetwork: make(map[string][]*computepb.Route),
		routeTables:     make(map[string]*RouteTable),
		lastUpdate:      make(map[string]time.Time),
		ttl:             5 * time.Minute,
	}

	// Initialize managers
	peeringManager := &PeeringManager{
		client:   networksClient,
		logger:   logger.Named("peering"),
		peerings: make(map[string]*NetworkPeering),
	}

	privateServiceManager := &PrivateServiceManager{
		client:          serviceNetworkingClient,
		logger:          logger.Named("private-service"),
		connections:     make(map[string]*PrivateServiceConnection),
		allocatedRanges: make(map[string]*AllocatedRange),
	}

	loadBalancerManager := &LoadBalancerManager{
		backendServicesClient: backendServicesClient,
		healthChecksClient:    healthChecksClient,
		urlMapsClient:         urlMapsClient,
		targetPoolsClient:     targetPoolsClient,
		logger:                logger.Named("load-balancer"),
		loadBalancers:         make(map[string]*LoadBalancer),
		healthChecks:          make(map[string]*computepb.HealthCheck),
	}

	vpnManager := &VPNManager{
		vpnGatewaysClient: vpnGatewaysClient,
		vpnTunnelsClient:  vpnTunnelsClient,
		logger:            logger.Named("vpn"),
		gateways:          make(map[string]*computepb.VpnGateway),
		tunnels:           make(map[string]*computepb.VpnTunnel),
		connections:       make(map[string]*VPNConnection),
	}

	interconnectManager := &InterconnectManager{
		interconnectsClient: interconnectsClient,
		attachmentsClient:   interconnectAttachmentsClient,
		logger:              logger.Named("interconnect"),
		interconnects:       make(map[string]*computepb.Interconnect),
		attachments:         make(map[string]*computepb.InterconnectAttachment),
	}

	dnsManager := &DNSManager{
		service:  dnsService,
		logger:   logger.Named("dns"),
		zones:    make(map[string]*dns.ManagedZone),
		records:  make(map[string][]*dns.ResourceRecordSet),
		policies: make(map[string]*dns.Policy),
	}

	networkAnalyzer := &NetworkAnalyzer{
		service:              networkManagementService,
		logger:               logger.Named("analyzer"),
		connectivityTests:    make(map[string]*networkmanagement.ConnectivityTest),
		reachabilityDetails:  make(map[string]*ReachabilityAnalysis),
	}

	trafficAnalyzer := &TrafficAnalyzer{
		logger:          logger.Named("traffic"),
		flowLogs:        make(map[string][]*FlowLog),
		trafficPatterns: make(map[string]*TrafficPattern),
		anomalies:       make([]TrafficAnomaly, 0),
	}

	// Initialize metrics
	metrics := &NetworkMetrics{
		ErrorCounts:        make(map[string]int64),
		OperationLatencies: make([]time.Duration, 0),
	}

	// Initialize rate limiter
	rateLimiter := &NetworkRateLimiter{
		readLimiter:   time.NewTicker(10 * time.Millisecond),
		writeLimiter:  time.NewTicker(50 * time.Millisecond),
		deleteLimiter: time.NewTicker(50 * time.Millisecond),
		adminLimiter:  time.NewTicker(100 * time.Millisecond),
	}

	return &NetworkService{
		networksClient:                 networksClient,
		subnetworksClient:              subnetworksClient,
		firewallsClient:                firewallsClient,
		routesClient:                   routesClient,
		routersClient:                  routersClient,
		vpnGatewaysClient:              vpnGatewaysClient,
		vpnTunnelsClient:               vpnTunnelsClient,
		interconnectsClient:            interconnectsClient,
		interconnectAttachmentsClient:  interconnectAttachmentsClient,
		addressesClient:                addressesClient,
		globalAddressesClient:          globalAddressesClient,
		forwardingRulesClient:          forwardingRulesClient,
		globalForwardingRulesClient:    globalForwardingRulesClient,
		targetPoolsClient:              targetPoolsClient,
		backendServicesClient:          backendServicesClient,
		healthChecksClient:             healthChecksClient,
		urlMapsClient:                  urlMapsClient,
		targetHttpProxiesClient:        targetHttpProxiesClient,
		targetHttpsProxiesClient:       targetHttpsProxiesClient,
		sslCertificatesClient:          sslCertificatesClient,
		networkEndpointGroupsClient:    networkEndpointGroupsClient,
		packetMirroringsClient:         packetMirroringsClient,
		securityPoliciesClient:         securityPoliciesClient,
		networkConnectivityClient:      networkConnectivityClient,
		serviceNetworkingClient:        serviceNetworkingClient,
		vpcAccessClient:                vpcAccessClient,
		dnsService:                     dnsService,
		networkManagementService:       networkManagementService,
		networkCache:                   networkCache,
		subnetCache:                    subnetCache,
		firewallCache:                  firewallCache,
		routeCache:                     routeCache,
		peeringManager:                 peeringManager,
		privateServiceManager:          privateServiceManager,
		loadBalancerManager:            loadBalancerManager,
		vpnManager:                     vpnManager,
		interconnectManager:            interconnectManager,
		dnsManager:                     dnsManager,
		networkAnalyzer:                networkAnalyzer,
		trafficAnalyzer:                trafficAnalyzer,
		logger:                         logger,
		metrics:                        metrics,
		rateLimiter:                    rateLimiter,
	}, nil
}

// CreateNetwork creates a new VPC network with comprehensive configuration
func (ns *NetworkService) CreateNetwork(ctx context.Context, projectID string, config *NetworkConfig) (*computepb.Network, error) {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Creating network",
		zap.String("name", config.Name),
		zap.Bool("autoCreateSubnets", config.AutoCreateSubnetworks))

	// Apply rate limiting
	<-ns.rateLimiter.writeLimiter.C

	network := &computepb.Network{
		Name:                            proto.String(config.Name),
		Description:                     proto.String(config.Description),
		AutoCreateSubnetworks:           proto.Bool(config.AutoCreateSubnetworks),
		RoutingConfig:                   &computepb.NetworkRoutingConfig{RoutingMode: proto.String(config.RoutingMode)},
		Mtu:                             proto.Int32(config.MTU),
		EnableUlaInternalIpv6:           proto.Bool(config.EnableUlaInternalIpv6),
		InternalIpv6Range:               proto.String(config.InternalIpv6Range),
		NetworkFirewallPolicyEnforcement: proto.String(config.NetworkFirewallPolicyEnforcement),
	}

	req := &computepb.InsertNetworkRequest{
		Project:         projectID,
		NetworkResource: network,
	}

	op, err := ns.networksClient.Insert(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["network_create"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create network: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForGlobalOperation(ctx, projectID, op.GetName()); err != nil {
		return nil, fmt.Errorf("network creation operation failed: %w", err)
	}

	// Get the created network
	getReq := &computepb.GetNetworkRequest{
		Project: projectID,
		Network: config.Name,
	}

	createdNetwork, err := ns.networksClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created network: %w", err)
	}

	// Update cache
	ns.networkCache.mu.Lock()
	ns.networkCache.networks[config.Name] = createdNetwork
	ns.networkCache.lastUpdate[config.Name] = time.Now()
	ns.networkCache.mu.Unlock()

	// Create subnets if specified
	if !config.AutoCreateSubnetworks && len(config.Subnets) > 0 {
		for _, subnetConfig := range config.Subnets {
			if _, err := ns.CreateSubnet(ctx, projectID, config.Name, subnetConfig); err != nil {
				ns.logger.Warn("Failed to create subnet",
					zap.String("subnet", subnetConfig.Name),
					zap.Error(err))
			}
		}
	}

	// Create firewall rules if specified
	for _, firewallConfig := range config.FirewallRules {
		if _, err := ns.CreateFirewallRule(ctx, projectID, config.Name, firewallConfig); err != nil {
			ns.logger.Warn("Failed to create firewall rule",
				zap.String("rule", firewallConfig.Name),
				zap.Error(err))
		}
	}

	// Create routes if specified
	for _, routeConfig := range config.Routes {
		if _, err := ns.CreateRoute(ctx, projectID, config.Name, routeConfig); err != nil {
			ns.logger.Warn("Failed to create route",
				zap.String("route", routeConfig.Name),
				zap.Error(err))
		}
	}

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.NetworkOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("Network created successfully",
		zap.String("name", config.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdNetwork, nil
}

// CreateSubnet creates a new subnet
func (ns *NetworkService) CreateSubnet(ctx context.Context, projectID, networkName string, config *SubnetConfig) (*computepb.Subnetwork, error) {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Creating subnet",
		zap.String("name", config.Name),
		zap.String("network", networkName),
		zap.String("region", config.Region),
		zap.String("ipRange", config.IPCIDRRange))

	// Apply rate limiting
	<-ns.rateLimiter.writeLimiter.C

	subnet := &computepb.Subnetwork{
		Name:                     proto.String(config.Name),
		Network:                  proto.String(fmt.Sprintf("projects/%s/global/networks/%s", projectID, networkName)),
		Region:                   proto.String(fmt.Sprintf("regions/%s", config.Region)),
		IpCidrRange:              proto.String(config.IPCIDRRange),
		Purpose:                  proto.String(config.Purpose),
		Role:                     proto.String(config.Role),
		PrivateIpGoogleAccess:    proto.Bool(config.PrivateIPGoogleAccess),
		PrivateIpv6GoogleAccess:  proto.String(config.PrivateIpv6GoogleAccess),
		StackType:                proto.String(config.StackType),
		Ipv6AccessType:           proto.String(config.Ipv6AccessType),
		Ipv6CidrRange:            proto.String(config.Ipv6CidrRange),
		ExternalIpv6Prefix:       proto.String(config.ExternalIpv6Prefix),
		AggregationInterval:      proto.String(config.AggregationInterval),
		EnableL7IlbSubnet:        proto.Bool(config.EnableL7IlbSubnet),
	}

	// Configure secondary IP ranges
	if len(config.SecondaryIPRanges) > 0 {
		secondaryRanges := make([]*computepb.SubnetworkSecondaryRange, len(config.SecondaryIPRanges))
		for i, sr := range config.SecondaryIPRanges {
			secondaryRanges[i] = &computepb.SubnetworkSecondaryRange{
				RangeName:   proto.String(sr.RangeName),
				IpCidrRange: proto.String(sr.IPCIDRRange),
			}
		}
		subnet.SecondaryIpRanges = secondaryRanges
	}

	// Configure flow logs
	if config.FlowLogs != nil && config.FlowLogs.Enable {
		subnet.LogConfig = &computepb.SubnetworkLogConfig{
			Enable:              proto.Bool(config.FlowLogs.Enable),
			AggregationInterval: proto.String(config.FlowLogs.AggregationInterval),
			FlowSampling:        proto.Float32(float32(config.FlowLogs.FlowSampling)),
			Metadata:            proto.String(config.FlowLogs.Metadata),
			MetadataFields:      config.FlowLogs.MetadataFields,
			FilterExpr:          proto.String(config.FlowLogs.FilterExpression),
		}
	}

	req := &computepb.InsertSubnetworkRequest{
		Project:            projectID,
		Region:             config.Region,
		SubnetworkResource: subnet,
	}

	op, err := ns.subnetworksClient.Insert(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["subnet_create"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create subnet: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForRegionOperation(ctx, projectID, config.Region, op.GetName()); err != nil {
		return nil, fmt.Errorf("subnet creation operation failed: %w", err)
	}

	// Get the created subnet
	getReq := &computepb.GetSubnetworkRequest{
		Project:    projectID,
		Region:     config.Region,
		Subnetwork: config.Name,
	}

	createdSubnet, err := ns.subnetworksClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created subnet: %w", err)
	}

	// Update cache
	cacheKey := fmt.Sprintf("%s/%s/%s", projectID, config.Region, config.Name)
	ns.subnetCache.mu.Lock()
	ns.subnetCache.subnets[cacheKey] = createdSubnet
	ns.subnetCache.lastUpdate[cacheKey] = time.Now()

	// Calculate available IPs
	_, ipnet, _ := net.ParseCIDR(config.IPCIDRRange)
	availableIPs := calculateAvailableIPs(ipnet)
	ns.subnetCache.availableIPs[cacheKey] = availableIPs
	ns.subnetCache.mu.Unlock()

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.SubnetOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("Subnet created successfully",
		zap.String("name", config.Name),
		zap.String("region", config.Region),
		zap.Duration("duration", time.Since(startTime)))

	return createdSubnet, nil
}

// CreateFirewallRule creates a new firewall rule
func (ns *NetworkService) CreateFirewallRule(ctx context.Context, projectID, networkName string, config *FirewallConfig) (*computepb.Firewall, error) {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Creating firewall rule",
		zap.String("name", config.Name),
		zap.String("network", networkName),
		zap.String("direction", config.Direction))

	// Apply rate limiting
	<-ns.rateLimiter.writeLimiter.C

	firewall := &computepb.Firewall{
		Name:                    proto.String(config.Name),
		Description:             proto.String(config.Description),
		Network:                 proto.String(fmt.Sprintf("projects/%s/global/networks/%s", projectID, networkName)),
		Direction:               proto.String(config.Direction),
		Priority:                proto.Int32(config.Priority),
		SourceRanges:            config.SourceRanges,
		DestinationRanges:       config.DestinationRanges,
		SourceTags:              config.SourceTags,
		TargetTags:              config.TargetTags,
		SourceServiceAccounts:   config.SourceServiceAccounts,
		TargetServiceAccounts:   config.TargetServiceAccounts,
		Disabled:                proto.Bool(config.Disabled),
	}

	// Configure allowed rules
	if len(config.Allowed) > 0 {
		allowed := make([]*computepb.Allowed, len(config.Allowed))
		for i, rule := range config.Allowed {
			allowed[i] = &computepb.Allowed{
				IPProtocol: proto.String(rule.IPProtocol),
				Ports:      rule.Ports,
			}
		}
		firewall.Allowed = allowed
	}

	// Configure denied rules
	if len(config.Denied) > 0 {
		denied := make([]*computepb.Denied, len(config.Denied))
		for i, rule := range config.Denied {
			denied[i] = &computepb.Denied{
				IPProtocol: proto.String(rule.IPProtocol),
				Ports:      rule.Ports,
			}
		}
		firewall.Denied = denied
	}

	// Configure logging
	if config.LogConfig != nil {
		firewall.LogConfig = &computepb.FirewallLogConfig{
			Enable:   proto.Bool(config.LogConfig.Enable),
			Metadata: proto.String(config.LogConfig.Metadata),
		}
	}

	req := &computepb.InsertFirewallRequest{
		Project:          projectID,
		FirewallResource: firewall,
	}

	op, err := ns.firewallsClient.Insert(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["firewall_create"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create firewall rule: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForGlobalOperation(ctx, projectID, op.GetName()); err != nil {
		return nil, fmt.Errorf("firewall rule creation operation failed: %w", err)
	}

	// Get the created firewall rule
	getReq := &computepb.GetFirewallRequest{
		Project:  projectID,
		Firewall: config.Name,
	}

	createdFirewall, err := ns.firewallsClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created firewall rule: %w", err)
	}

	// Update cache
	ns.firewallCache.mu.Lock()
	ns.firewallCache.rules[config.Name] = createdFirewall
	ns.firewallCache.lastUpdate[config.Name] = time.Now()

	// Update rules by network
	if ns.firewallCache.rulesByNetwork[networkName] == nil {
		ns.firewallCache.rulesByNetwork[networkName] = make([]*computepb.Firewall, 0)
	}
	ns.firewallCache.rulesByNetwork[networkName] = append(ns.firewallCache.rulesByNetwork[networkName], createdFirewall)

	// Update rules by tag
	for _, tag := range config.TargetTags {
		if ns.firewallCache.rulesByTag[tag] == nil {
			ns.firewallCache.rulesByTag[tag] = make([]*computepb.Firewall, 0)
		}
		ns.firewallCache.rulesByTag[tag] = append(ns.firewallCache.rulesByTag[tag], createdFirewall)
	}
	ns.firewallCache.mu.Unlock()

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.FirewallOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("Firewall rule created successfully",
		zap.String("name", config.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdFirewall, nil
}

// CreateRoute creates a new route
func (ns *NetworkService) CreateRoute(ctx context.Context, projectID, networkName string, config *RouteConfig) (*computepb.Route, error) {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Creating route",
		zap.String("name", config.Name),
		zap.String("network", networkName),
		zap.String("destRange", config.DestRange))

	// Apply rate limiting
	<-ns.rateLimiter.writeLimiter.C

	route := &computepb.Route{
		Name:             proto.String(config.Name),
		Description:      proto.String(config.Description),
		Network:          proto.String(fmt.Sprintf("projects/%s/global/networks/%s", projectID, networkName)),
		DestRange:        proto.String(config.DestRange),
		Priority:         proto.Int32(config.Priority),
		Tags:             config.Tags,
	}

	// Set next hop based on configuration
	if config.NextHopGateway != "" {
		route.NextHopGateway = proto.String(config.NextHopGateway)
	}
	if config.NextHopInstance != "" {
		route.NextHopInstance = proto.String(config.NextHopInstance)
	}
	if config.NextHopIP != "" {
		route.NextHopIp = proto.String(config.NextHopIP)
	}
	if config.NextHopVpnTunnel != "" {
		route.NextHopVpnTunnel = proto.String(config.NextHopVpnTunnel)
	}
	if config.NextHopIlb != "" {
		route.NextHopIlb = proto.String(config.NextHopIlb)
	}
	if config.NextHopNetwork != "" {
		route.NextHopNetwork = proto.String(config.NextHopNetwork)
	}

	req := &computepb.InsertRouteRequest{
		Project:       projectID,
		RouteResource: route,
	}

	op, err := ns.routesClient.Insert(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["route_create"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create route: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForGlobalOperation(ctx, projectID, op.GetName()); err != nil {
		return nil, fmt.Errorf("route creation operation failed: %w", err)
	}

	// Get the created route
	getReq := &computepb.GetRouteRequest{
		Project: projectID,
		Route:   config.Name,
	}

	createdRoute, err := ns.routesClient.Get(ctx, getReq)
	if err != nil {
		return nil, fmt.Errorf("failed to get created route: %w", err)
	}

	// Update cache
	ns.routeCache.mu.Lock()
	ns.routeCache.routes[config.Name] = createdRoute
	ns.routeCache.lastUpdate[config.Name] = time.Now()

	// Update routes by network
	if ns.routeCache.routesByNetwork[networkName] == nil {
		ns.routeCache.routesByNetwork[networkName] = make([]*computepb.Route, 0)
	}
	ns.routeCache.routesByNetwork[networkName] = append(ns.routeCache.routesByNetwork[networkName], createdRoute)
	ns.routeCache.mu.Unlock()

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.RouteOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("Route created successfully",
		zap.String("name", config.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdRoute, nil
}

// CreatePeering creates a VPC peering connection
func (ns *NetworkService) CreatePeering(ctx context.Context, projectID, networkName string, config *PeeringConfig) error {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Creating VPC peering",
		zap.String("name", config.Name),
		zap.String("network", networkName),
		zap.String("peerNetwork", config.PeerNetwork))

	// Apply rate limiting
	<-ns.rateLimiter.writeLimiter.C

	peering := &computepb.NetworkPeering{
		Name:                             proto.String(config.Name),
		Network:                          proto.String(config.PeerNetwork),
		ExchangeSubnetRoutes:             proto.Bool(config.AutoCreateRoutes),
		ExportCustomRoutes:               proto.Bool(config.ExportCustomRoutes),
		ImportCustomRoutes:               proto.Bool(config.ImportCustomRoutes),
		ExportSubnetRoutesWithPublicIp:   proto.Bool(config.ExportSubnetRoutesWithPublicIP),
		ImportSubnetRoutesWithPublicIp:   proto.Bool(config.ImportSubnetRoutesWithPublicIP),
		StackType:                        proto.String(config.StackType),
	}

	req := &computepb.AddPeeringNetworkRequest{
		Project:                      projectID,
		Network:                      networkName,
		NetworksAddPeeringRequestResource: &computepb.NetworksAddPeeringRequest{
			NetworkPeering: peering,
		},
	}

	op, err := ns.networksClient.AddPeering(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["peering_create"]++
		ns.metrics.mu.Unlock()
		return fmt.Errorf("failed to create peering: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForGlobalOperation(ctx, projectID, op.GetName()); err != nil {
		return fmt.Errorf("peering creation operation failed: %w", err)
	}

	// Update peering manager
	ns.peeringManager.mu.Lock()
	ns.peeringManager.peerings[config.Name] = &NetworkPeering{
		Name:                            config.Name,
		Network:                         networkName,
		PeerNetwork:                     config.PeerNetwork,
		State:                           "ACTIVE",
		AutoCreateRoutes:                config.AutoCreateRoutes,
		ExportCustomRoutes:              config.ExportCustomRoutes,
		ImportCustomRoutes:              config.ImportCustomRoutes,
		ExportSubnetRoutesWithPublicIP:  config.ExportSubnetRoutesWithPublicIP,
		ImportSubnetRoutesWithPublicIP:  config.ImportSubnetRoutesWithPublicIP,
		StackType:                       config.StackType,
	}
	ns.peeringManager.mu.Unlock()

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.PeeringOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("VPC peering created successfully",
		zap.String("name", config.Name),
		zap.Duration("duration", time.Since(startTime)))

	return nil
}

// GetNetwork retrieves network information
func (ns *NetworkService) GetNetwork(ctx context.Context, projectID, networkName string) (*computepb.Network, error) {
	ns.mu.RLock()
	defer ns.mu.RUnlock()

	// Check cache first
	ns.networkCache.mu.RLock()
	if network, ok := ns.networkCache.networks[networkName]; ok {
		if time.Since(ns.networkCache.lastUpdate[networkName]) < ns.networkCache.ttl {
			ns.networkCache.mu.RUnlock()
			ns.logger.Debug("Returning network from cache", zap.String("network", networkName))
			return network, nil
		}
	}
	ns.networkCache.mu.RUnlock()

	// Apply rate limiting
	<-ns.rateLimiter.readLimiter.C

	req := &computepb.GetNetworkRequest{
		Project: projectID,
		Network: networkName,
	}

	network, err := ns.networksClient.Get(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["network_get"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to get network: %w", err)
	}

	// Update cache
	ns.networkCache.mu.Lock()
	ns.networkCache.networks[networkName] = network
	ns.networkCache.lastUpdate[networkName] = time.Now()
	ns.networkCache.mu.Unlock()

	return network, nil
}

// ListNetworks lists all networks in a project
func (ns *NetworkService) ListNetworks(ctx context.Context, projectID string) ([]*computepb.Network, error) {
	ns.mu.RLock()
	defer ns.mu.RUnlock()

	// Apply rate limiting
	<-ns.rateLimiter.readLimiter.C

	req := &computepb.ListNetworksRequest{
		Project: projectID,
	}

	var networks []*computepb.Network
	it := ns.networksClient.List(ctx, req)

	for {
		network, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			ns.metrics.mu.Lock()
			ns.metrics.ErrorCounts["network_list"]++
			ns.metrics.mu.Unlock()
			return nil, fmt.Errorf("failed to list networks: %w", err)
		}
		networks = append(networks, network)

		// Update cache
		ns.networkCache.mu.Lock()
		ns.networkCache.networks[network.GetName()] = network
		ns.networkCache.lastUpdate[network.GetName()] = time.Now()
		ns.networkCache.mu.Unlock()
	}

	ns.logger.Info("Listed networks",
		zap.String("project", projectID),
		zap.Int("count", len(networks)))

	return networks, nil
}

// DeleteNetwork deletes a network
func (ns *NetworkService) DeleteNetwork(ctx context.Context, projectID, networkName string) error {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	startTime := time.Now()
	ns.logger.Info("Deleting network",
		zap.String("name", networkName))

	// Apply rate limiting
	<-ns.rateLimiter.deleteLimiter.C

	req := &computepb.DeleteNetworkRequest{
		Project: projectID,
		Network: networkName,
	}

	op, err := ns.networksClient.Delete(ctx, req)
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["network_delete"]++
		ns.metrics.mu.Unlock()
		return fmt.Errorf("failed to delete network: %w", err)
	}

	// Wait for operation to complete
	if err := ns.waitForGlobalOperation(ctx, projectID, op.GetName()); err != nil {
		return fmt.Errorf("network deletion operation failed: %w", err)
	}

	// Remove from cache
	ns.networkCache.mu.Lock()
	delete(ns.networkCache.networks, networkName)
	delete(ns.networkCache.networkInfo, networkName)
	delete(ns.networkCache.lastUpdate, networkName)
	ns.networkCache.mu.Unlock()

	// Clean up related caches
	ns.firewallCache.mu.Lock()
	delete(ns.firewallCache.rulesByNetwork, networkName)
	ns.firewallCache.mu.Unlock()

	ns.routeCache.mu.Lock()
	delete(ns.routeCache.routesByNetwork, networkName)
	delete(ns.routeCache.routeTables, networkName)
	ns.routeCache.mu.Unlock()

	// Update metrics
	ns.metrics.mu.Lock()
	ns.metrics.NetworkOperations++
	ns.metrics.OperationLatencies = append(ns.metrics.OperationLatencies, time.Since(startTime))
	ns.metrics.mu.Unlock()

	ns.logger.Info("Network deleted successfully",
		zap.String("name", networkName),
		zap.Duration("duration", time.Since(startTime)))

	return nil
}

// AnalyzeNetworkConnectivity analyzes connectivity between resources
func (ns *NetworkService) AnalyzeNetworkConnectivity(ctx context.Context, projectID, source, destination string) (*ReachabilityAnalysis, error) {
	ns.mu.RLock()
	defer ns.mu.RUnlock()

	ns.logger.Info("Analyzing network connectivity",
		zap.String("source", source),
		zap.String("destination", destination))

	// Create connectivity test
	test := &networkmanagement.ConnectivityTest{
		Source: &networkmanagement.Endpoint{
			Instance: source,
		},
		Destination: &networkmanagement.Endpoint{
			Instance: destination,
		},
		Protocol: "TCP",
	}

	testName := fmt.Sprintf("connectivity-test-%d", time.Now().Unix())
	createCall := ns.networkManagementService.Projects.Locations.Global.ConnectivityTests.Create(
		fmt.Sprintf("projects/%s/locations/global", projectID),
		test,
	)
	createCall.TestId(testName)

	createdTest, err := createCall.Do()
	if err != nil {
		ns.metrics.mu.Lock()
		ns.metrics.ErrorCounts["connectivity_test"]++
		ns.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create connectivity test: %w", err)
	}

	// Wait for test to complete
	time.Sleep(5 * time.Second)

	// Get test results
	getCall := ns.networkManagementService.Projects.Locations.Global.ConnectivityTests.Get(createdTest.Name)
	result, err := getCall.Do()
	if err != nil {
		return nil, fmt.Errorf("failed to get connectivity test results: %w", err)
	}

	// Parse results
	analysis := &ReachabilityAnalysis{
		Source:      source,
		Destination: destination,
		Protocol:    "TCP",
		Result:      result.ReachabilityDetails.Result,
		VerifyTime:  time.Now(),
	}

	if result.ReachabilityDetails != nil {
		if result.ReachabilityDetails.Traces != nil {
			analysis.Traces = result.ReachabilityDetails.Traces
			analysis.Hops = int32(len(result.ReachabilityDetails.Traces))
		}
		if result.ReachabilityDetails.Error != nil {
			analysis.Result = "UNREACHABLE"
		}
	}

	// Cache results
	ns.networkAnalyzer.mu.Lock()
	cacheKey := fmt.Sprintf("%s-%s", source, destination)
	ns.networkAnalyzer.reachabilityDetails[cacheKey] = analysis
	ns.networkAnalyzer.mu.Unlock()

	// Clean up test
	deleteCall := ns.networkManagementService.Projects.Locations.Global.ConnectivityTests.Delete(createdTest.Name)
	deleteCall.Do()

	ns.logger.Info("Network connectivity analysis completed",
		zap.String("source", source),
		zap.String("destination", destination),
		zap.String("result", analysis.Result))

	return analysis, nil
}

// Helper functions

// calculateAvailableIPs calculates available IP addresses in a subnet
func calculateAvailableIPs(ipnet *net.IPNet) []string {
	var ips []string
	for ip := ipnet.IP.Mask(ipnet.Mask); ipnet.Contains(ip); incrementIP(ip) {
		ips = append(ips, ip.String())
		if len(ips) > 1000 { // Limit for large subnets
			break
		}
	}
	return ips
}

// incrementIP increments an IP address
func incrementIP(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

// waitForGlobalOperation waits for a global operation to complete
func (ns *NetworkService) waitForGlobalOperation(ctx context.Context, projectID, operationName string) error {
	// Implementation would poll for operation completion
	// This is a simplified version
	time.Sleep(5 * time.Second)
	return nil
}

// waitForRegionOperation waits for a regional operation to complete
func (ns *NetworkService) waitForRegionOperation(ctx context.Context, projectID, region, operationName string) error {
	// Implementation would poll for operation completion
	// This is a simplified version
	time.Sleep(5 * time.Second)
	return nil
}

// GetMetrics returns network service metrics
func (ns *NetworkService) GetMetrics() *NetworkMetrics {
	ns.metrics.mu.RLock()
	defer ns.metrics.mu.RUnlock()

	return &NetworkMetrics{
		NetworkOperations:      ns.metrics.NetworkOperations,
		SubnetOperations:       ns.metrics.SubnetOperations,
		FirewallOperations:     ns.metrics.FirewallOperations,
		RouteOperations:        ns.metrics.RouteOperations,
		PeeringOperations:      ns.metrics.PeeringOperations,
		VPNOperations:          ns.metrics.VPNOperations,
		LoadBalancerOperations: ns.metrics.LoadBalancerOperations,
		DNSOperations:          ns.metrics.DNSOperations,
		ErrorCounts:            copyStringInt64Map(ns.metrics.ErrorCounts),
		OperationLatencies:     append([]time.Duration{}, ns.metrics.OperationLatencies...),
		TrafficBytes:           ns.metrics.TrafficBytes,
		TrafficPackets:         ns.metrics.TrafficPackets,
	}
}

// Close closes the network service
func (ns *NetworkService) Close() error {
	ns.mu.Lock()
	defer ns.mu.Unlock()

	ns.logger.Info("Closing network service")

	// Stop rate limiters
	ns.rateLimiter.readLimiter.Stop()
	ns.rateLimiter.writeLimiter.Stop()
	ns.rateLimiter.deleteLimiter.Stop()
	ns.rateLimiter.adminLimiter.Stop()

	// Close clients
	var errs []error

	if err := ns.networksClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close networks client: %w", err))
	}
	if err := ns.subnetworksClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close subnetworks client: %w", err))
	}
	if err := ns.firewallsClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close firewalls client: %w", err))
	}
	if err := ns.routesClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close routes client: %w", err))
	}
	if err := ns.networkConnectivityClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close network connectivity client: %w", err))
	}
	if err := ns.vpcAccessClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close VPC access client: %w", err))
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors closing network service: %v", errs)
	}

	return nil
}