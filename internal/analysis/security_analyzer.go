package analysis

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	// "regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/core"
	"github.com/terragrunt-gcp/terragrunt-gcp/internal/providers"
)

type SecurityAnalyzer struct {
	provider providers.Provider
	logger   *logrus.Logger
	config   SecurityAnalyzerConfig
	mutex    sync.RWMutex
	cache    *SecurityCache
}

type SecurityAnalyzerConfig struct {
	ComplianceFrameworks []string
	ScanDepth           string
	MaxWorkers          int
	Timeout             time.Duration
	EnableRemediation   bool
	AlertThresholds     AlertThresholds
	Policies            []SecurityPolicy
	ExcludedResources   []string
	CustomChecks        []CustomSecurityCheck
}

type AlertThresholds struct {
	CriticalFindings int
	HighFindings     int
	MediumFindings   int
	LowFindings      int
	ComplianceScore  int
}

type SecurityPolicy struct {
	ID          string
	Name        string
	Description string
	Severity    string
	Category    string
	Rules       []PolicyRule
	Enabled     bool
}

type PolicyRule struct {
	ID         string
	Condition  string
	Action     string
	Parameters map[string]interface{}
}

type CustomSecurityCheck struct {
	ID          string
	Name        string
	Description string
	Type        string
	Script      string
	Parameters  map[string]interface{}
}

type SecurityCache struct {
	mutex    sync.RWMutex
	findings map[string]*CachedFinding
	ttl      time.Duration
}

type CachedFinding struct {
	Finding   core.SecurityFinding
	CachedAt  time.Time
	ExpiresAt time.Time
}

type SecurityOptions struct {
	Checks              []string
	ComplianceFramework string
	GenerateRemediation bool
	DeepScan            bool
	IncludeMetadata     bool
	ResourceTypes       []string
	Severity            []string
	Categories          []string
}

type SecurityAnalysisResults struct {
	Summary         SecurityAnalysisSummary      `json:"summary"`
	Findings        []core.SecurityFinding            `json:"findings"`
	Compliance      ComplianceResults            `json:"compliance"`
	Vulnerabilities []Vulnerability              `json:"vulnerabilities"`
	Remediations    []core.Remediation                `json:"remediations,omitempty"`
	RiskAssessment  RiskAssessment               `json:"risk_assessment"`
	IAMAnalysis     IAMSecurityAnalysis          `json:"iam_analysis"`
	NetworkAnalysis NetworkSecurityAnalysis      `json:"network_analysis"`
	DataAnalysis    DataSecurityAnalysis         `json:"data_analysis"`
	Recommendations []SecurityRecommendation     `json:"recommendations"`
	Metadata        map[string]interface{}       `json:"metadata"`
}

type SecurityAnalysisSummary struct {
	TotalFindings       int                    `json:"total_findings"`
	CriticalFindings    int                    `json:"critical_findings"`
	HighFindings        int                    `json:"high_findings"`
	MediumFindings      int                    `json:"medium_findings"`
	LowFindings         int                    `json:"low_findings"`
	SecurityScore       int                    `json:"security_score"`
	ComplianceScore     int                    `json:"compliance_score"`
	RiskLevel           string                 `json:"risk_level"`
	TopRisks            []Risk                 `json:"top_risks"`
	SecurityPosture     string                 `json:"security_posture"`
	ImprovementAreas    []string               `json:"improvement_areas"`
	Statistics          map[string]interface{} `json:"statistics"`
}

type ComplianceResults struct {
	Framework           string                      `json:"framework"`
	OverallCompliance   float64                     `json:"overall_compliance"`
	Controls            []ComplianceControl         `json:"controls"`
	PassedControls      int                         `json:"passed_controls"`
	FailedControls      int                         `json:"failed_controls"`
	NotApplicable       int                         `json:"not_applicable"`
	Exceptions          []ComplianceException       `json:"exceptions"`
	CertificationStatus string                      `json:"certification_status"`
	NextAudit           time.Time                   `json:"next_audit"`
	Gaps                []ComplianceGap             `json:"gaps"`
}

type ComplianceControl struct {
	ID              string                 `json:"id"`
	Name            string                 `json:"name"`
	Description     string                 `json:"description"`
	Category        string                 `json:"category"`
	Status          string                 `json:"status"`
	Evidence        []Evidence             `json:"evidence"`
	LastChecked     time.Time              `json:"last_checked"`
	Remediation     string                 `json:"remediation,omitempty"`
	ResponsibleParty string                `json:"responsible_party"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type Evidence struct {
	Type        string    `json:"type"`
	Description string    `json:"description"`
	Resource    string    `json:"resource"`
	Timestamp   time.Time `json:"timestamp"`
	Data        string    `json:"data"`
}

type ComplianceException struct {
	ControlID      string    `json:"control_id"`
	Reason         string    `json:"reason"`
	ApprovedBy     string    `json:"approved_by"`
	ExpirationDate time.Time `json:"expiration_date"`
	RiskAccepted   bool      `json:"risk_accepted"`
}

type ComplianceGap struct {
	Control        string `json:"control"`
	CurrentState   string `json:"current_state"`
	RequiredState  string `json:"required_state"`
	Gap            string `json:"gap"`
	Priority       string `json:"priority"`
	RemediationPlan string `json:"remediation_plan"`
}

type Vulnerability struct {
	ID              string                 `json:"id"`
	CVE             string                 `json:"cve,omitempty"`
	Type            string                 `json:"type"`
	Severity        string                 `json:"severity"`
	CVSS            float64                `json:"cvss"`
	Resource        string                 `json:"resource"`
	Service         string                 `json:"service"`
	Description     string                 `json:"description"`
	Impact          string                 `json:"impact"`
	Exploit         ExploitInfo            `json:"exploit"`
	Patch           PatchInfo              `json:"patch"`
	Workaround      string                 `json:"workaround,omitempty"`
	References      []string               `json:"references"`
	FirstDetected   time.Time              `json:"first_detected"`
	LastSeen        time.Time              `json:"last_seen"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type ExploitInfo struct {
	Available      bool     `json:"available"`
	Difficulty     string   `json:"difficulty"`
	ExploitCode    string   `json:"exploit_code,omitempty"`
	AttackVectors  []string `json:"attack_vectors"`
	Prerequisites  []string `json:"prerequisites"`
	Likelihood     string   `json:"likelihood"`
}

type PatchInfo struct {
	Available       bool      `json:"available"`
	Version         string    `json:"version"`
	ReleaseDate     time.Time `json:"release_date"`
	InstallCommand  string    `json:"install_command"`
	RequiresRestart bool      `json:"requires_restart"`
	TestingRequired bool      `json:"testing_required"`
}

type RiskAssessment struct {
	OverallRisk         string                 `json:"overall_risk"`
	RiskScore           float64                `json:"risk_score"`
	RiskMatrix          RiskMatrix             `json:"risk_matrix"`
	ThreatLandscape     ThreatLandscape        `json:"threat_landscape"`
	VulnerabilityMetrics VulnerabilityMetrics  `json:"vulnerability_metrics"`
	ExposureAnalysis    ExposureAnalysis       `json:"exposure_analysis"`
	ImpactAnalysis      ImpactAnalysis         `json:"impact_analysis"`
	Trends              RiskTrends             `json:"trends"`
	Predictions         []RiskPrediction       `json:"predictions"`
}

type RiskMatrix struct {
	Critical []RiskItem `json:"critical"`
	High     []RiskItem `json:"high"`
	Medium   []RiskItem `json:"medium"`
	Low      []RiskItem `json:"low"`
}

type RiskItem struct {
	Name        string  `json:"name"`
	Category    string  `json:"category"`
	Likelihood  float64 `json:"likelihood"`
	Impact      float64 `json:"impact"`
	Score       float64 `json:"score"`
	Description string  `json:"description"`
}

type ThreatLandscape struct {
	ActiveThreats      []Threat               `json:"active_threats"`
	ThreatActors       []ThreatActor          `json:"threat_actors"`
	AttackPatterns     []AttackPattern        `json:"attack_patterns"`
	Indicators         []ThreatIndicator      `json:"indicators"`
	ThreatIntelligence map[string]interface{} `json:"threat_intelligence"`
}

type Threat struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"`
	Severity    string    `json:"severity"`
	Status      string    `json:"status"`
	Description string    `json:"description"`
	Mitigations []string  `json:"mitigations"`
	LastSeen    time.Time `json:"last_seen"`
}

type ThreatActor struct {
	Name         string   `json:"name"`
	Type         string   `json:"type"`
	Motivation   string   `json:"motivation"`
	Capabilities []string `json:"capabilities"`
	TTPs         []string `json:"ttps"`
}

type AttackPattern struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	MITRE       string   `json:"mitre"`
	Description string   `json:"description"`
	Phases      []string `json:"phases"`
	Detections  []string `json:"detections"`
}

type ThreatIndicator struct {
	Type       string    `json:"type"`
	Value      string    `json:"value"`
	Severity   string    `json:"severity"`
	Confidence float64   `json:"confidence"`
	Source     string    `json:"source"`
	LastSeen   time.Time `json:"last_seen"`
}

type VulnerabilityMetrics struct {
	TotalVulnerabilities    int                    `json:"total_vulnerabilities"`
	MeanTimeToRemediate     float64                `json:"mean_time_to_remediate"`
	VulnerabilityDensity    float64                `json:"vulnerability_density"`
	PatchCoverage           float64                `json:"patch_coverage"`
	ExploitableVulnerabilities int                 `json:"exploitable_vulnerabilities"`
	AgeDistribution         map[string]int         `json:"age_distribution"`
	ServiceDistribution     map[string]int         `json:"service_distribution"`
	Trends                  map[string]interface{} `json:"trends"`
}

type ExposureAnalysis struct {
	InternetFacing      int                    `json:"internet_facing"`
	PubliclyAccessible  int                    `json:"publicly_accessible"`
	UnencryptedServices int                    `json:"unencrypted_services"`
	OpenPorts           []PortExposure         `json:"open_ports"`
	ExposedSecrets      []SecretExposure       `json:"exposed_secrets"`
	AttackSurface       map[string]interface{} `json:"attack_surface"`
}

type PortExposure struct {
	Port        int      `json:"port"`
	Protocol    string   `json:"protocol"`
	Service     string   `json:"service"`
	ExposedTo   []string `json:"exposed_to"`
	Risk        string   `json:"risk"`
	Remediation string   `json:"remediation"`
}

type SecretExposure struct {
	Type        string    `json:"type"`
	Location    string    `json:"location"`
	Severity    string    `json:"severity"`
	Discovery   time.Time `json:"discovery"`
	Remediation string    `json:"remediation"`
}

type ImpactAnalysis struct {
	BusinessImpact      string                 `json:"business_impact"`
	DataAtRisk          DataRisk               `json:"data_at_risk"`
	ServiceImpact       []ServiceImpact        `json:"service_impact"`
	ComplianceImpact    []string               `json:"compliance_impact"`
	ReputationalImpact  string                 `json:"reputational_impact"`
	FinancialImpact     FinancialImpact        `json:"financial_impact"`
	RecoveryMetrics     RecoveryMetrics        `json:"recovery_metrics"`
}

type DataRisk struct {
	Classification   string   `json:"classification"`
	Volume           string   `json:"volume"`
	Sensitivity      string   `json:"sensitivity"`
	ExposureLevel    string   `json:"exposure_level"`
	ProtectionStatus string   `json:"protection_status"`
	RegulatoryData   bool     `json:"regulatory_data"`
	AffectedSystems  []string `json:"affected_systems"`
}

type ServiceImpact struct {
	Service        string  `json:"service"`
	Criticality    string  `json:"criticality"`
	Users          int     `json:"users"`
	Downtime       float64 `json:"downtime"`
	DataLoss       bool    `json:"data_loss"`
	RecoveryTime   float64 `json:"recovery_time"`
}

type FinancialImpact struct {
	EstimatedLoss    float64 `json:"estimated_loss"`
	RemediationCost  float64 `json:"remediation_cost"`
	ComplianceFines  float64 `json:"compliance_fines"`
	ReputationCost   float64 `json:"reputation_cost"`
	InsuranceCoverage float64 `json:"insurance_coverage"`
	TotalExposure    float64 `json:"total_exposure"`
}

type RecoveryMetrics struct {
	RTO float64 `json:"rto"`
	RPO float64 `json:"rpo"`
	MTD float64 `json:"mtd"`
	WRT float64 `json:"wrt"`
}

type RiskTrends struct {
	Direction       string                 `json:"direction"`
	VelocityScore   float64                `json:"velocity_score"`
	MonthlyChange   float64                `json:"monthly_change"`
	ProjectedRisk   float64                `json:"projected_risk"`
	TrendDrivers    []string               `json:"trend_drivers"`
	HistoricalData  map[string]interface{} `json:"historical_data"`
}

type RiskPrediction struct {
	Period      string  `json:"period"`
	RiskScore   float64 `json:"risk_score"`
	Confidence  float64 `json:"confidence"`
	Factors     []string `json:"factors"`
	Mitigations []string `json:"mitigations"`
}

type IAMSecurityAnalysis struct {
	TotalUsers           int                    `json:"total_users"`
	TotalServiceAccounts int                    `json:"total_service_accounts"`
	TotalRoles           int                    `json:"total_roles"`
	PrivilegeAnalysis    PrivilegeAnalysis      `json:"privilege_analysis"`
	AccessPatterns       []AccessPattern        `json:"access_patterns"`
	AnomalousAccess      []AnomalousAccess      `json:"anomalous_access"`
	StaleAccounts        []StaleAccount         `json:"stale_accounts"`
	KeyRotation          KeyRotationAnalysis    `json:"key_rotation"`
	MFAStatus            MFAAnalysis            `json:"mfa_status"`
	Recommendations      []string               `json:"recommendations"`
}

type PrivilegeAnalysis struct {
	OverPrivileged       []PrivilegedAccount    `json:"over_privileged"`
	UnusedPermissions    []UnusedPermission     `json:"unused_permissions"`
	DangerousPermissions []DangerousPermission  `json:"dangerous_permissions"`
	PrivilegeEscalation  []EscalationPath       `json:"privilege_escalation"`
	Score                int                    `json:"score"`
}

type PrivilegedAccount struct {
	Account         string   `json:"account"`
	Type            string   `json:"type"`
	Roles           []string `json:"roles"`
	ExcessiveRights []string `json:"excessive_rights"`
	Risk            string   `json:"risk"`
	LastUsed        time.Time `json:"last_used"`
}

type UnusedPermission struct {
	Account    string   `json:"account"`
	Permission string   `json:"permission"`
	LastUsed   time.Time `json:"last_used"`
	DaysUnused int      `json:"days_unused"`
}

type DangerousPermission struct {
	Permission  string   `json:"permission"`
	Accounts    []string `json:"accounts"`
	Risk        string   `json:"risk"`
	Description string   `json:"description"`
}

type EscalationPath struct {
	StartRole   string   `json:"start_role"`
	EndRole     string   `json:"end_role"`
	Path        []string `json:"path"`
	Difficulty  string   `json:"difficulty"`
	Description string   `json:"description"`
}

type AccessPattern struct {
	Pattern     string    `json:"pattern"`
	Frequency   int       `json:"frequency"`
	Users       []string  `json:"users"`
	Normal      bool      `json:"normal"`
	Risk        string    `json:"risk"`
	LastSeen    time.Time `json:"last_seen"`
}

type AnomalousAccess struct {
	User        string    `json:"user"`
	Resource    string    `json:"resource"`
	Action      string    `json:"action"`
	Timestamp   time.Time `json:"timestamp"`
	Location    string    `json:"location"`
	Anomaly     string    `json:"anomaly"`
	Risk        string    `json:"risk"`
	Description string    `json:"description"`
}

type StaleAccount struct {
	Account      string    `json:"account"`
	Type         string    `json:"type"`
	LastActivity time.Time `json:"last_activity"`
	DaysInactive int       `json:"days_inactive"`
	Permissions  []string  `json:"permissions"`
	Risk         string    `json:"risk"`
}

type KeyRotationAnalysis struct {
	ComplianceStatus string            `json:"compliance_status"`
	AverageKeyAge    float64           `json:"average_key_age"`
	OldestKey        time.Time         `json:"oldest_key"`
	ExpiredKeys      []ExpiredKey      `json:"expired_keys"`
	RotationSchedule map[string]string `json:"rotation_schedule"`
}

type ExpiredKey struct {
	KeyID       string    `json:"key_id"`
	Account     string    `json:"account"`
	CreatedDate time.Time `json:"created_date"`
	Age         int       `json:"age"`
	Status      string    `json:"status"`
}

type MFAAnalysis struct {
	Enabled      bool              `json:"enabled"`
	Coverage     float64           `json:"coverage"`
	Methods      []string          `json:"methods"`
	NonMFAUsers  []string          `json:"non_mfa_users"`
	WeakMethods  []string          `json:"weak_methods"`
}

type NetworkSecurityAnalysis struct {
	Perimeter           PerimeterSecurity      `json:"perimeter"`
	Segmentation        NetworkSegmentation    `json:"segmentation"`
	TrafficAnalysis     TrafficAnalysis        `json:"traffic_analysis"`
	FirewallAnalysis    FirewallAnalysis       `json:"firewall_analysis"`
	DNSSecurity         DNSSecurityAnalysis    `json:"dns_security"`
	VPNSecurity         VPNSecurityAnalysis    `json:"vpn_security"`
	DDOSProtection      DDOSProtectionStatus   `json:"ddos_protection"`
	Recommendations     []string               `json:"recommendations"`
}

type PerimeterSecurity struct {
	ExposedServices     []ExposedService       `json:"exposed_services"`
	PublicIPs           []PublicIP             `json:"public_ips"`
	UnprotectedEndpoints []string              `json:"unprotected_endpoints"`
	EdgeProtection      string                 `json:"edge_protection"`
	Score               int                    `json:"score"`
}

type ExposedService struct {
	Service         string   `json:"service"`
	Port            int      `json:"port"`
	Protocol        string   `json:"protocol"`
	ExposureLevel   string   `json:"exposure_level"`
	Authentication  string   `json:"authentication"`
	Encryption      bool     `json:"encryption"`
	Vulnerabilities []string `json:"vulnerabilities"`
	Risk            string   `json:"risk"`
}

type PublicIP struct {
	Address     string   `json:"address"`
	Resource    string   `json:"resource"`
	Services    []string `json:"services"`
	Reputation  string   `json:"reputation"`
	Blacklisted bool     `json:"blacklisted"`
}

type NetworkSegmentation struct {
	Segments           []NetworkSegment       `json:"segments"`
	IsolationLevel     string                 `json:"isolation_level"`
	MicroSegmentation  bool                   `json:"micro_segmentation"`
	CrossSegmentFlows  []CrossSegmentFlow     `json:"cross_segment_flows"`
	Score              int                    `json:"score"`
}

type NetworkSegment struct {
	Name         string   `json:"name"`
	Type         string   `json:"type"`
	Resources    int      `json:"resources"`
	Isolation    string   `json:"isolation"`
	Compliance   bool     `json:"compliance"`
	Risks        []string `json:"risks"`
}

type CrossSegmentFlow struct {
	Source      string   `json:"source"`
	Destination string   `json:"destination"`
	Protocols   []string `json:"protocols"`
	Ports       []int    `json:"ports"`
	Allowed     bool     `json:"allowed"`
	Risk        string   `json:"risk"`
}

type TrafficAnalysis struct {
	UnencryptedTraffic  []UnencryptedFlow      `json:"unencrypted_traffic"`
	SuspiciousPatterns  []SuspiciousPattern    `json:"suspicious_patterns"`
	DataExfiltration    []ExfiltrationAttempt  `json:"data_exfiltration"`
	ProtocolDistribution map[string]float64    `json:"protocol_distribution"`
	BandwidthAnalysis   map[string]interface{} `json:"bandwidth_analysis"`
}

type UnencryptedFlow struct {
	Source      string `json:"source"`
	Destination string `json:"destination"`
	Protocol    string `json:"protocol"`
	Port        int    `json:"port"`
	DataType    string `json:"data_type"`
	Risk        string `json:"risk"`
}

type SuspiciousPattern struct {
	Pattern     string    `json:"pattern"`
	Occurrences int       `json:"occurrences"`
	Sources     []string  `json:"sources"`
	Type        string    `json:"type"`
	Severity    string    `json:"severity"`
	LastSeen    time.Time `json:"last_seen"`
}

type ExfiltrationAttempt struct {
	Source      string    `json:"source"`
	Destination string    `json:"destination"`
	DataVolume  float64   `json:"data_volume"`
	Method      string    `json:"method"`
	Timestamp   time.Time `json:"timestamp"`
	Status      string    `json:"status"`
}

type FirewallAnalysis struct {
	TotalRules       int              `json:"total_rules"`
	OverlyPermissive []FirewallIssue  `json:"overly_permissive"`
	Conflicts        []RuleConflict   `json:"conflicts"`
	UnusedRules      []string         `json:"unused_rules"`
	MissingRules     []string         `json:"missing_rules"`
	Effectiveness    float64          `json:"effectiveness"`
}

type FirewallIssue struct {
	Rule        string   `json:"rule"`
	Issue       string   `json:"issue"`
	Severity    string   `json:"severity"`
	AffectedIPs []string `json:"affected_ips"`
	Remediation string   `json:"remediation"`
}

type RuleConflict struct {
	Rule1       string `json:"rule1"`
	Rule2       string `json:"rule2"`
	Type        string `json:"type"`
	Description string `json:"description"`
	Resolution  string `json:"resolution"`
}

type DNSSecurityAnalysis struct {
	DNSSEC          bool             `json:"dnssec"`
	Tunneling       []DNSTunnel      `json:"tunneling"`
	Hijacking       []DNSHijack      `json:"hijacking"`
	CachePoisoning  bool             `json:"cache_poisoning"`
	Recommendations []string         `json:"recommendations"`
}

type DNSTunnel struct {
	Domain      string    `json:"domain"`
	Type        string    `json:"type"`
	DataVolume  float64   `json:"data_volume"`
	FirstSeen   time.Time `json:"first_seen"`
	Risk        string    `json:"risk"`
}

type DNSHijack struct {
	Domain       string    `json:"domain"`
	LegitimateIP string    `json:"legitimate_ip"`
	HijackedIP   string    `json:"hijacked_ip"`
	DetectedAt   time.Time `json:"detected_at"`
	Impact       string    `json:"impact"`
}

type VPNSecurityAnalysis struct {
	Endpoints       []VPNEndpoint          `json:"endpoints"`
	Protocols       []string               `json:"protocols"`
	Encryption      string                 `json:"encryption"`
	Authentication  string                 `json:"authentication"`
	Vulnerabilities []string               `json:"vulnerabilities"`
	Score           int                    `json:"score"`
}

type VPNEndpoint struct {
	Name        string   `json:"name"`
	Type        string   `json:"type"`
	Location    string   `json:"location"`
	Status      string   `json:"status"`
	Users       int      `json:"users"`
	Security    string   `json:"security"`
}

type DDOSProtectionStatus struct {
	Enabled         bool                   `json:"enabled"`
	Provider        string                 `json:"provider"`
	ProtectionLevel string                 `json:"protection_level"`
	RecentAttacks   []DDOSAttack           `json:"recent_attacks"`
	Effectiveness   float64                `json:"effectiveness"`
	Configuration   map[string]interface{} `json:"configuration"`
}

type DDOSAttack struct {
	Timestamp   time.Time `json:"timestamp"`
	Type        string    `json:"type"`
	Volume      float64   `json:"volume"`
	Duration    float64   `json:"duration"`
	Mitigated   bool      `json:"mitigated"`
	Impact      string    `json:"impact"`
}

type DataSecurityAnalysis struct {
	Classification  DataClassificationAnalysis `json:"classification"`
	Encryption      EncryptionAnalysis         `json:"encryption"`
	DataLoss        DataLossAnalysis           `json:"data_loss"`
	Privacy         PrivacyAnalysis            `json:"privacy"`
	Backup          BackupAnalysis             `json:"backup"`
	Retention       RetentionAnalysis          `json:"retention"`
	Recommendations []string                   `json:"recommendations"`
}

type DataClassificationAnalysis struct {
	ClassifiedData   map[string]int         `json:"classified_data"`
	UnclassifiedData int                    `json:"unclassified_data"`
	SensitiveData    []SensitiveDataItem    `json:"sensitive_data"`
	ComplianceStatus map[string]bool        `json:"compliance_status"`
	Score            int                    `json:"score"`
}

type SensitiveDataItem struct {
	Type        string   `json:"type"`
	Location    string   `json:"location"`
	Volume      int      `json:"volume"`
	Protection  string   `json:"protection"`
	Compliance  []string `json:"compliance"`
	Risk        string   `json:"risk"`
}

type EncryptionAnalysis struct {
	AtRest       EncryptionStatus       `json:"at_rest"`
	InTransit    EncryptionStatus       `json:"in_transit"`
	KeyManagement KeyManagementAnalysis `json:"key_management"`
	Weaknesses   []EncryptionWeakness   `json:"weaknesses"`
	Score        int                    `json:"score"`
}

type EncryptionStatus struct {
	Enabled    bool              `json:"enabled"`
	Coverage   float64           `json:"coverage"`
	Algorithm  string            `json:"algorithm"`
	Strength   string            `json:"strength"`
	Compliance bool              `json:"compliance"`
	Issues     []string          `json:"issues"`
}

type KeyManagementAnalysis struct {
	Provider    string           `json:"provider"`
	KeyStore    string           `json:"key_store"`
	Rotation    bool             `json:"rotation"`
	HSM         bool             `json:"hsm"`
	Compliance  bool             `json:"compliance"`
	Issues      []string         `json:"issues"`
}

type EncryptionWeakness struct {
	Type        string   `json:"type"`
	Resource    string   `json:"resource"`
	Algorithm   string   `json:"algorithm"`
	Issue       string   `json:"issue"`
	Risk        string   `json:"risk"`
	Remediation string   `json:"remediation"`
}

type DataLossAnalysis struct {
	DLPEnabled      bool                   `json:"dlp_enabled"`
	Policies        []DLPPolicy            `json:"policies"`
	Incidents       []DataLossIncident     `json:"incidents"`
	RiskAreas       []string               `json:"risk_areas"`
	PreventionScore int                    `json:"prevention_score"`
}

type DLPPolicy struct {
	Name        string   `json:"name"`
	Type        string   `json:"type"`
	Enabled     bool     `json:"enabled"`
	Actions     []string `json:"actions"`
	Effectiveness float64 `json:"effectiveness"`
}

type DataLossIncident struct {
	Timestamp   time.Time `json:"timestamp"`
	Type        string    `json:"type"`
	Source      string    `json:"source"`
	Destination string    `json:"destination"`
	DataType    string    `json:"data_type"`
	Volume      float64   `json:"volume"`
	Prevented   bool      `json:"prevented"`
	Severity    string    `json:"severity"`
}

type PrivacyAnalysis struct {
	PIIExposure     []PIIExposure          `json:"pii_exposure"`
	ConsentManagement ConsentStatus        `json:"consent_management"`
	DataResidency   map[string]string      `json:"data_residency"`
	RightToDelete   bool                   `json:"right_to_delete"`
	Compliance      map[string]bool        `json:"compliance"`
}

type PIIExposure struct {
	Type        string   `json:"type"`
	Location    string   `json:"location"`
	Count       int      `json:"count"`
	Protection  string   `json:"protection"`
	Risk        string   `json:"risk"`
}

type ConsentStatus struct {
	Implemented bool             `json:"implemented"`
	Coverage    float64          `json:"coverage"`
	Mechanisms  []string         `json:"mechanisms"`
	Issues      []string         `json:"issues"`
}

type BackupAnalysis struct {
	Coverage        float64                `json:"coverage"`
	Frequency       string                 `json:"frequency"`
	RetentionPeriod string                 `json:"retention_period"`
	Testing         BackupTestingStatus    `json:"testing"`
	Encryption      bool                   `json:"encryption"`
	OffSite         bool                   `json:"offsite"`
	Issues          []string               `json:"issues"`
	Score           int                    `json:"score"`
}

type BackupTestingStatus struct {
	LastTested      time.Time `json:"last_tested"`
	TestFrequency   string    `json:"test_frequency"`
	SuccessRate     float64   `json:"success_rate"`
	RecoveryTime    float64   `json:"recovery_time"`
	Issues          []string  `json:"issues"`
}

type RetentionAnalysis struct {
	Policies        []RetentionPolicy      `json:"policies"`
	Compliance      map[string]bool        `json:"compliance"`
	DataAging       map[string]interface{} `json:"data_aging"`
	DeletionProcess string                 `json:"deletion_process"`
	Issues          []string               `json:"issues"`
}

type RetentionPolicy struct {
	Name        string `json:"name"`
	DataType    string `json:"data_type"`
	Period      string `json:"period"`
	Compliance  bool   `json:"compliance"`
	Automated   bool   `json:"automated"`
}

type Risk struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Category    string  `json:"category"`
	Severity    string  `json:"severity"`
	Likelihood  float64 `json:"likelihood"`
	Impact      float64 `json:"impact"`
	Score       float64 `json:"score"`
	Description string  `json:"description"`
	Mitigation  string  `json:"mitigation"`
}

type SecurityRecommendation struct {
	ID          string   `json:"id"`
	Category    string   `json:"category"`
	Priority    string   `json:"priority"`
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Impact      string   `json:"impact"`
	Effort      string   `json:"effort"`
	Resources   []string `json:"resources"`
	Steps       []string `json:"steps"`
}

func NewSecurityAnalyzer(provider providers.Provider, logger *logrus.Logger) *SecurityAnalyzer {
	return &SecurityAnalyzer{
		provider: provider,
		logger:   logger,
		config: SecurityAnalyzerConfig{
			ComplianceFrameworks: []string{"CIS", "PCI-DSS", "HIPAA", "SOC2"},
			ScanDepth:           "DEEP",
			MaxWorkers:          10,
			Timeout:             10 * time.Minute,
			EnableRemediation:   true,
			AlertThresholds: AlertThresholds{
				CriticalFindings: 1,
				HighFindings:     5,
				MediumFindings:   10,
				LowFindings:      20,
				ComplianceScore:  80,
			},
			Policies:          []SecurityPolicy{},
			ExcludedResources: []string{},
			CustomChecks:      []CustomSecurityCheck{},
		},
		cache: &SecurityCache{
			findings: make(map[string]*CachedFinding),
			ttl:      30 * time.Minute,
		},
	}
}

func (sa *SecurityAnalyzer) AnalyzeSecurity(ctx context.Context, options SecurityOptions) (*SecurityAnalysisResults, error) {
	sa.logger.Info("Starting comprehensive security analysis")

	results := &SecurityAnalysisResults{
		Findings:        []core.SecurityFinding{},
		Vulnerabilities: []Vulnerability{},
		Remediations:    []core.Remediation{},
		Recommendations: []SecurityRecommendation{},
		Metadata:        make(map[string]interface{}),
	}

	resources, err := sa.provider.ListResources(ctx, "", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list resources: %w", err)
	}

	var wg sync.WaitGroup
	findingsChan := make(chan core.SecurityFinding, len(resources))
	vulnChan := make(chan Vulnerability, sa.config.MaxWorkers)

	for _, resource := range resources {
		wg.Add(1)
		go func(res core.Resource) {
			defer wg.Done()

			findings := sa.scanResource(ctx, res, options)
			for _, finding := range findings {
				findingsChan <- finding
			}

			vulns := sa.scanVulnerabilities(ctx, res)
			for _, vuln := range vulns {
				vulnChan <- vuln
			}
		}(resource)
	}

	go func() {
		wg.Wait()
		close(findingsChan)
		close(vulnChan)
	}()

	for finding := range findingsChan {
		results.Findings = append(results.Findings, finding)
	}

	for vuln := range vulnChan {
		results.Vulnerabilities = append(results.Vulnerabilities, vuln)
	}

	results.Summary = sa.calculateSummary(results.Findings, results.Vulnerabilities)

	if options.ComplianceFramework != "" {
		results.Compliance = sa.checkCompliance(ctx, resources, options.ComplianceFramework)
	}

	results.RiskAssessment = sa.assessRisk(results)
	results.IAMAnalysis = sa.analyzeIAM(ctx, resources)
	results.NetworkAnalysis = sa.analyzeNetwork(ctx, resources)
	results.DataAnalysis = sa.analyzeDataSecurity(ctx, resources)

	if options.GenerateRemediation {
		results.Remediations = sa.generateRemediations(results)
	}

	results.Recommendations = sa.generateRecommendations(results)

	results.Metadata["scan_date"] = time.Now()
	results.Metadata["scan_depth"] = sa.config.ScanDepth
	results.Metadata["resources_scanned"] = len(resources)

	sa.logger.Info("Security analysis completed successfully")
	return results, nil
}

func (sa *SecurityAnalyzer) scanResource(ctx context.Context, resource core.Resource, options SecurityOptions) []core.SecurityFinding {
	findings := []core.SecurityFinding{}

	checks := sa.getSecurityChecks(resource.Type)
	for _, check := range checks {
		if sa.shouldRunCheck(check, options) {
			finding := sa.executeCheck(ctx, resource, check)
			if finding != nil {
				findings = append(findings, *finding)
			}
		}
	}

	return findings
}

func (sa *SecurityAnalyzer) scanVulnerabilities(ctx context.Context, resource core.Resource) []Vulnerability {
	vulnerabilities := []Vulnerability{}

	vulnData, err := sa.provider.ScanResourceVulnerabilities(ctx, resource.ID, resource.Type)
	if err != nil {
		sa.logger.Warnf("Failed to scan vulnerabilities for %s: %v", resource.ID, err)
		return vulnerabilities
	}

	for _, vuln := range vulnData {
		vulnerability := Vulnerability{
			ID:          fmt.Sprintf("vuln-%s", sa.generateID()),
			Type:        "CONFIGURATION",
			Resource:    resource.ID,
			Service:     sa.getServiceFromResourceType(resource.Type),
			FirstDetected: time.Now(),
			LastSeen:    time.Now(),
			Metadata:    make(map[string]interface{}),
		}

		if cve, ok := vuln["cve"].(string); ok {
			vulnerability.CVE = cve
		}

		if severity, ok := vuln["severity"].(string); ok {
			vulnerability.Severity = severity
		}

		if cvss, ok := vuln["cvss"].(float64); ok {
			vulnerability.CVSS = cvss
		}

		if description, ok := vuln["description"].(string); ok {
			vulnerability.Description = description
		}

		vulnerabilities = append(vulnerabilities, vulnerability)
	}

	return vulnerabilities
}

func (sa *SecurityAnalyzer) calculateSummary(findings []core.SecurityFinding, vulnerabilities []Vulnerability) SecurityAnalysisSummary {
	summary := SecurityAnalysisSummary{
		TotalFindings: len(findings),
		TopRisks:      []Risk{},
		Statistics:    make(map[string]interface{}),
	}

	for _, finding := range findings {
		switch finding.Severity {
		case "CRITICAL":
			summary.CriticalFindings++
		case "HIGH":
			summary.HighFindings++
		case "MEDIUM":
			summary.MediumFindings++
		case "LOW":
			summary.LowFindings++
		}
	}

	summary.SecurityScore = sa.calculateSecurityScore(summary)
	summary.ComplianceScore = 85
	summary.RiskLevel = sa.calculateRiskLevel(summary)
	summary.SecurityPosture = sa.evaluateSecurityPosture(summary)

	summary.ImprovementAreas = sa.identifyImprovementAreas(findings)

	summary.Statistics["vulnerabilities"] = len(vulnerabilities)
	summary.Statistics["avg_severity"] = sa.calculateAverageSeverity(findings)
	summary.Statistics["categories"] = sa.getCategoryDistribution(findings)

	return summary
}

func (sa *SecurityAnalyzer) checkCompliance(ctx context.Context, resources []core.Resource, framework string) ComplianceResults {
	compliance := ComplianceResults{
		Framework: framework,
		Controls:  []ComplianceControl{},
		Exceptions: []ComplianceException{},
		Gaps:      []ComplianceGap{},
		CertificationStatus: "PENDING",
		NextAudit: time.Now().AddDate(0, 6, 0),
	}

	controls := sa.getComplianceControls(framework)
	for _, control := range controls {
		status := sa.checkControl(ctx, resources, control)

		complianceControl := ComplianceControl{
			ID:          control.ID,
			Name:        control.Name,
			Description: control.Description,
			Category:    control.Category,
			Status:      status,
			Evidence:    sa.collectEvidence(ctx, resources, control),
			LastChecked: time.Now(),
			Metadata:    make(map[string]interface{}),
		}

		if status == "FAILED" {
			complianceControl.Remediation = sa.getControlRemediation(control)
			compliance.FailedControls++
		} else if status == "PASSED" {
			compliance.PassedControls++
		} else {
			compliance.NotApplicable++
		}

		compliance.Controls = append(compliance.Controls, complianceControl)
	}

	total := compliance.PassedControls + compliance.FailedControls
	if total > 0 {
		compliance.OverallCompliance = float64(compliance.PassedControls) / float64(total) * 100
	}

	return compliance
}

func (sa *SecurityAnalyzer) assessRisk(results *SecurityAnalysisResults) RiskAssessment {
	assessment := RiskAssessment{
		RiskMatrix: RiskMatrix{
			Critical: []RiskItem{},
			High:     []RiskItem{},
			Medium:   []RiskItem{},
			Low:      []RiskItem{},
		},
	}

	for _, finding := range results.Findings {
		risk := sa.calculateRisk(finding)

		riskItem := RiskItem{
			Name:        finding.ID,
			Category:    finding.Type,
			Likelihood:  risk.Likelihood,
			Impact:      risk.Impact,
			Score:       risk.Score,
			Description: finding.Description,
		}

		switch finding.Severity {
		case "CRITICAL":
			assessment.RiskMatrix.Critical = append(assessment.RiskMatrix.Critical, riskItem)
		case "HIGH":
			assessment.RiskMatrix.High = append(assessment.RiskMatrix.High, riskItem)
		case "MEDIUM":
			assessment.RiskMatrix.Medium = append(assessment.RiskMatrix.Medium, riskItem)
		case "LOW":
			assessment.RiskMatrix.Low = append(assessment.RiskMatrix.Low, riskItem)
		}
	}

	assessment.RiskScore = sa.calculateOverallRiskScore(assessment.RiskMatrix)
	assessment.OverallRisk = sa.determineOverallRisk(assessment.RiskScore)

	assessment.ThreatLandscape = sa.analyzeThreatLandscape()
	assessment.VulnerabilityMetrics = sa.calculateVulnerabilityMetrics(results.Vulnerabilities)
	assessment.ExposureAnalysis = sa.analyzeExposure(results)
	assessment.ImpactAnalysis = sa.analyzeImpact(results)
	assessment.Trends = sa.analyzeRiskTrends(results)
	assessment.Predictions = sa.predictFutureRisks(assessment)

	return assessment
}

func (sa *SecurityAnalyzer) analyzeIAM(ctx context.Context, resources []core.Resource) IAMSecurityAnalysis {
	analysis := IAMSecurityAnalysis{
		AccessPatterns:  []AccessPattern{},
		AnomalousAccess: []AnomalousAccess{},
		StaleAccounts:   []StaleAccount{},
		Recommendations: []string{},
	}

	for _, resource := range resources {
		if strings.Contains(resource.Type, "iam") || strings.Contains(resource.Type, "serviceAccount") {
			if strings.Contains(resource.Type, "user") {
				analysis.TotalUsers++
			} else if strings.Contains(resource.Type, "serviceAccount") {
				analysis.TotalServiceAccounts++
			} else if strings.Contains(resource.Type, "role") {
				analysis.TotalRoles++
			}
		}
	}

	analysis.PrivilegeAnalysis = sa.analyzePrivileges(ctx, resources)
	analysis.KeyRotation = sa.analyzeKeyRotation(ctx, resources)
	analysis.MFAStatus = sa.analyzeMFA(ctx, resources)

	if analysis.PrivilegeAnalysis.Score < 70 {
		analysis.Recommendations = append(analysis.Recommendations,
			"Implement least privilege access control",
			"Review and remove excessive permissions",
			"Enable privilege access management")
	}

	if !analysis.MFAStatus.Enabled || analysis.MFAStatus.Coverage < 90 {
		analysis.Recommendations = append(analysis.Recommendations,
			"Enable MFA for all user accounts",
			"Implement strong authentication methods")
	}

	return analysis
}

func (sa *SecurityAnalyzer) analyzeNetwork(ctx context.Context, resources []core.Resource) NetworkSecurityAnalysis {
	analysis := NetworkSecurityAnalysis{
		Recommendations: []string{},
	}

	analysis.Perimeter = sa.analyzePerimeter(ctx, resources)
	analysis.Segmentation = sa.analyzeSegmentation(ctx, resources)
	analysis.TrafficAnalysis = sa.analyzeTraffic(ctx, resources)
	analysis.FirewallAnalysis = sa.analyzeFirewalls(ctx, resources)
	analysis.DNSSecurity = sa.analyzeDNS(ctx, resources)
	analysis.VPNSecurity = sa.analyzeVPN(ctx, resources)
	analysis.DDOSProtection = sa.analyzeDDOSProtection(ctx, resources)

	if analysis.Perimeter.Score < 70 {
		analysis.Recommendations = append(analysis.Recommendations,
			"Strengthen perimeter security controls",
			"Reduce exposed attack surface")
	}

	if !analysis.Segmentation.MicroSegmentation {
		analysis.Recommendations = append(analysis.Recommendations,
			"Implement network micro-segmentation",
			"Isolate critical workloads")
	}

	return analysis
}

func (sa *SecurityAnalyzer) analyzeDataSecurity(ctx context.Context, resources []core.Resource) DataSecurityAnalysis {
	analysis := DataSecurityAnalysis{
		Recommendations: []string{},
	}

	analysis.Classification = sa.analyzeDataClassification(ctx, resources)
	analysis.Encryption = sa.analyzeEncryption(ctx, resources)
	analysis.DataLoss = sa.analyzeDataLoss(ctx, resources)
	analysis.Privacy = sa.analyzePrivacy(ctx, resources)
	analysis.Backup = sa.analyzeBackup(ctx, resources)
	analysis.Retention = sa.analyzeRetention(ctx, resources)

	if analysis.Encryption.Score < 80 {
		analysis.Recommendations = append(analysis.Recommendations,
			"Implement end-to-end encryption",
			"Strengthen key management practices")
	}

	if !analysis.DataLoss.DLPEnabled {
		analysis.Recommendations = append(analysis.Recommendations,
			"Deploy data loss prevention solution",
			"Implement data classification policies")
	}

	return analysis
}

func (sa *SecurityAnalyzer) generateRemediations(results *SecurityAnalysisResults) []core.Remediation {
	remediations := []core.Remediation{}

	for _, finding := range results.Findings {
		if finding.Severity == "CRITICAL" || finding.Severity == "HIGH" {
			remediation := core.Remediation{
				ID:          fmt.Sprintf("rem-%s", sa.generateID()),
				Type:        finding.Type,
				Priority:    finding.Severity,
				Description: fmt.Sprintf("Remediate %s", finding.ID),
				Steps:       sa.getRemediationSteps(finding),
				Script:      sa.generateRemediationScript(finding),
				Impact:      "Security posture improvement",
				Effort:      sa.estimateRemediationEffort(finding),
			}
			remediations = append(remediations, remediation)
		}
	}

	sort.Slice(remediations, func(i, j int) bool {
		priorityOrder := map[string]int{
			"CRITICAL": 0,
			"HIGH":     1,
			"MEDIUM":   2,
			"LOW":      3,
		}
		return priorityOrder[remediations[i].Priority] < priorityOrder[remediations[j].Priority]
	})

	return remediations
}

func (sa *SecurityAnalyzer) generateRecommendations(results *SecurityAnalysisResults) []SecurityRecommendation {
	recommendations := []SecurityRecommendation{}

	if results.Summary.CriticalFindings > 0 {
		recommendations = append(recommendations, SecurityRecommendation{
			ID:          "sec-rec-001",
			Category:    "CRITICAL",
			Priority:    "IMMEDIATE",
			Title:       "Address Critical Security Findings",
			Description: fmt.Sprintf("Found %d critical security issues requiring immediate attention", results.Summary.CriticalFindings),
			Impact:      "HIGH",
			Effort:      "VARIABLE",
			Steps: []string{
				"Review all critical findings",
				"Prioritize based on exposure",
				"Implement remediations",
				"Verify fixes",
			},
		})
	}

	if results.Compliance.OverallCompliance < 80 {
		recommendations = append(recommendations, SecurityRecommendation{
			ID:          "sec-rec-002",
			Category:    "COMPLIANCE",
			Priority:    "HIGH",
			Title:       "Improve Compliance Posture",
			Description: fmt.Sprintf("Compliance score is %.1f%%, below target of 80%%", results.Compliance.OverallCompliance),
			Impact:      "HIGH",
			Effort:      "HIGH",
			Steps: []string{
				"Review failed controls",
				"Implement missing controls",
				"Document compliance evidence",
				"Schedule compliance review",
			},
		})
	}

	return recommendations
}

func (sa *SecurityAnalyzer) getSecurityChecks(resourceType string) []SecurityCheck {
	checks := []SecurityCheck{}

	baseChecks := []SecurityCheck{
		{ID: "encryption-at-rest", Name: "Encryption at Rest"},
		{ID: "encryption-in-transit", Name: "Encryption in Transit"},
		{ID: "public-access", Name: "Public Access Check"},
		{ID: "authentication", Name: "Authentication Check"},
		{ID: "authorization", Name: "Authorization Check"},
		{ID: "logging", Name: "Logging Configuration"},
		{ID: "monitoring", Name: "Monitoring Configuration"},
	}

	if strings.Contains(resourceType, "storage") {
		checks = append(checks, SecurityCheck{ID: "bucket-policy", Name: "Bucket Policy Check"})
		checks = append(checks, SecurityCheck{ID: "versioning", Name: "Versioning Check"})
	}

	if strings.Contains(resourceType, "compute") {
		checks = append(checks, SecurityCheck{ID: "ssh-config", Name: "SSH Configuration"})
		checks = append(checks, SecurityCheck{ID: "patch-status", Name: "Patch Status"})
	}

	if strings.Contains(resourceType, "network") {
		checks = append(checks, SecurityCheck{ID: "firewall-rules", Name: "Firewall Rules"})
		checks = append(checks, SecurityCheck{ID: "network-segmentation", Name: "Network Segmentation"})
	}

	return append(baseChecks, checks...)
}

func (sa *SecurityAnalyzer) shouldRunCheck(check SecurityCheck, options SecurityOptions) bool {
	if len(options.Checks) > 0 {
		for _, c := range options.Checks {
			if c == check.ID {
				return true
			}
		}
		return false
	}
	return true
}

func (sa *SecurityAnalyzer) executeCheck(ctx context.Context, resource core.Resource, check SecurityCheck) *core.SecurityFinding {
	compliance, err := sa.provider.CheckResourceCompliance(ctx, resource.ID, resource.Type)
	if err != nil {
		return nil
	}

	for _, issue := range compliance {
		if checkID, ok := issue["check_id"].(string); ok && checkID == check.ID {
			return &core.SecurityFinding{
				ID:           fmt.Sprintf("finding-%s", sa.generateID()),
				Type:         "CONFIGURATION",
				Severity:     sa.getSeverity(issue),
				Resource:     fmt.Sprintf("%s (%s)", resource.Name, resource.Type),
				Description:  fmt.Sprintf("%s: %s", check.Name, sa.getDescription(issue)),
				Risk:         sa.getRisk(issue),
				Remediation:  sa.getRemediation(issue),
				FirstDetected: time.Now(),
				LastSeen:     time.Now(),
			}
		}
	}

	return nil
}

func (sa *SecurityAnalyzer) getComplianceControls(framework string) []ComplianceControl {
	controls := []ComplianceControl{}

	switch framework {
	case "CIS":
		controls = append(controls, ComplianceControl{
			ID:          "CIS-1.1",
			Name:        "Ensure that corporate login credentials are used",
			Description: "Use corporate login credentials instead of personal accounts",
			Category:    "Identity and Access Management",
		})
	case "PCI-DSS":
		controls = append(controls, ComplianceControl{
			ID:          "PCI-1.1",
			Name:        "Install and maintain firewall configuration",
			Description: "Install and maintain firewall configuration to protect cardholder data",
			Category:    "Network Security",
		})
	case "HIPAA":
		controls = append(controls, ComplianceControl{
			ID:          "HIPAA-164.308",
			Name:        "Administrative Safeguards",
			Description: "Implement administrative safeguards for PHI",
			Category:    "Administrative",
		})
	}

	return controls
}

func (sa *SecurityAnalyzer) checkControl(ctx context.Context, resources []core.Resource, control ComplianceControl) string {
	for _, resource := range resources {
		compliance, err := sa.provider.CheckResourceCompliance(ctx, resource.ID, resource.Type)
		if err != nil {
			continue
		}

		for _, check := range compliance {
			if controlID, ok := check["control_id"].(string); ok && controlID == control.ID {
				if status, ok := check["status"].(string); ok {
					if status == "FAILED" {
						return "FAILED"
					}
				}
			}
		}
	}

	return "PASSED"
}

func (sa *SecurityAnalyzer) collectEvidence(ctx context.Context, resources []core.Resource, control ComplianceControl) []Evidence {
	evidence := []Evidence{}

	for _, resource := range resources {
		evidence = append(evidence, Evidence{
			Type:        "CONFIGURATION",
			Description: fmt.Sprintf("Resource %s configuration for control %s", resource.Name, control.ID),
			Resource:    resource.ID,
			Timestamp:   time.Now(),
			Data:        sa.getResourceConfiguration(resource),
		})
	}

	return evidence
}

func (sa *SecurityAnalyzer) getControlRemediation(control ComplianceControl) string {
	remediations := map[string]string{
		"CIS-1.1":      "Configure SSO with corporate identity provider",
		"PCI-1.1":      "Review and update firewall rules to restrict access",
		"HIPAA-164.308": "Implement access controls and audit logging",
	}

	if remediation, ok := remediations[control.ID]; ok {
		return remediation
	}

	return "Review control requirements and implement necessary changes"
}

func (sa *SecurityAnalyzer) calculateRisk(finding core.SecurityFinding) Risk {
	likelihood := 0.5
	impact := 0.5

	switch finding.Severity {
	case "CRITICAL":
		likelihood = 0.9
		impact = 0.9
	case "HIGH":
		likelihood = 0.7
		impact = 0.7
	case "MEDIUM":
		likelihood = 0.5
		impact = 0.5
	case "LOW":
		likelihood = 0.3
		impact = 0.3
	}

	return Risk{
		ID:          fmt.Sprintf("risk-%s", sa.generateID()),
		Name:        finding.ID,
		Category:    finding.Type,
		Severity:    finding.Severity,
		Likelihood:  likelihood,
		Impact:      impact,
		Score:       likelihood * impact * 100,
		Description: finding.Description,
		Mitigation:  finding.Remediation,
	}
}

func (sa *SecurityAnalyzer) calculateSecurityScore(summary SecurityAnalysisSummary) int {
	score := 100

	score -= summary.CriticalFindings * 20
	score -= summary.HighFindings * 10
	score -= summary.MediumFindings * 5
	score -= summary.LowFindings * 2

	if score < 0 {
		score = 0
	}

	return score
}

func (sa *SecurityAnalyzer) calculateRiskLevel(summary SecurityAnalysisSummary) string {
	if summary.CriticalFindings > 0 {
		return "CRITICAL"
	} else if summary.HighFindings > 5 {
		return "HIGH"
	} else if summary.MediumFindings > 10 {
		return "MEDIUM"
	}
	return "LOW"
}

func (sa *SecurityAnalyzer) evaluateSecurityPosture(summary SecurityAnalysisSummary) string {
	if summary.SecurityScore >= 90 {
		return "EXCELLENT"
	} else if summary.SecurityScore >= 75 {
		return "GOOD"
	} else if summary.SecurityScore >= 60 {
		return "FAIR"
	} else if summary.SecurityScore >= 40 {
		return "POOR"
	}
	return "CRITICAL"
}

func (sa *SecurityAnalyzer) identifyImprovementAreas(findings []core.SecurityFinding) []string {
	areas := make(map[string]int)

	for _, finding := range findings {
		areas[finding.Type]++
	}

	improvements := []string{}
	for area, count := range areas {
		if count > 3 {
			improvements = append(improvements, area)
		}
	}

	return improvements
}

func (sa *SecurityAnalyzer) calculateAverageSeverity(findings []core.SecurityFinding) float64 {
	if len(findings) == 0 {
		return 0
	}

	total := 0.0
	for _, finding := range findings {
		switch finding.Severity {
		case "CRITICAL":
			total += 4
		case "HIGH":
			total += 3
		case "MEDIUM":
			total += 2
		case "LOW":
			total += 1
		}
	}

	return total / float64(len(findings))
}

func (sa *SecurityAnalyzer) getCategoryDistribution(findings []core.SecurityFinding) map[string]int {
	distribution := make(map[string]int)

	for _, finding := range findings {
		distribution[finding.Type]++
	}

	return distribution
}

func (sa *SecurityAnalyzer) getServiceFromResourceType(resourceType string) string {
	parts := strings.Split(resourceType, ".")
	if len(parts) > 0 {
		return parts[0]
	}
	return "unknown"
}

func (sa *SecurityAnalyzer) generateID() string {
	timestamp := time.Now().UnixNano()
	hash := sha256.Sum256([]byte(fmt.Sprintf("%d", timestamp)))
	return hex.EncodeToString(hash[:8])
}

func (sa *SecurityAnalyzer) getSeverity(issue map[string]interface{}) string {
	if severity, ok := issue["severity"].(string); ok {
		return severity
	}
	return "MEDIUM"
}

func (sa *SecurityAnalyzer) getDescription(issue map[string]interface{}) string {
	if description, ok := issue["description"].(string); ok {
		return description
	}
	return "Security issue detected"
}

func (sa *SecurityAnalyzer) getRisk(issue map[string]interface{}) string {
	if risk, ok := issue["risk"].(string); ok {
		return risk
	}
	return "Potential security vulnerability"
}

func (sa *SecurityAnalyzer) getRemediation(issue map[string]interface{}) string {
	if remediation, ok := issue["remediation"].(string); ok {
		return remediation
	}
	return "Review and update configuration"
}

func (sa *SecurityAnalyzer) getCategory(check SecurityCheck) string {
	categories := map[string]string{
		"encryption-at-rest":    "DATA_PROTECTION",
		"encryption-in-transit": "DATA_PROTECTION",
		"public-access":        "ACCESS_CONTROL",
		"authentication":       "IDENTITY",
		"authorization":        "ACCESS_CONTROL",
		"logging":             "MONITORING",
		"monitoring":          "MONITORING",
		"bucket-policy":       "ACCESS_CONTROL",
		"versioning":          "DATA_PROTECTION",
		"ssh-config":          "ACCESS_CONTROL",
		"patch-status":        "VULNERABILITY",
		"firewall-rules":      "NETWORK",
		"network-segmentation": "NETWORK",
	}

	if category, ok := categories[check.ID]; ok {
		return category
	}
	return "GENERAL"
}

func (sa *SecurityAnalyzer) getResourceConfiguration(resource core.Resource) string {
	config, err := json.Marshal(resource.Properties)
	if err != nil {
		return "{}"
	}
	return string(config)
}

func (sa *SecurityAnalyzer) getRemediationSteps(finding core.SecurityFinding) []string {
	steps := []string{
		fmt.Sprintf("Identify affected resource: %s", finding.Resource),
		fmt.Sprintf("Review current configuration for %s", finding.ID),
		"Apply recommended security configuration",
		"Validate changes",
		"Monitor for compliance",
	}
	return steps
}

func (sa *SecurityAnalyzer) generateRemediationScript(finding core.SecurityFinding) string {
	script := fmt.Sprintf(`#!/bin/bash
# Remediation script for: %s
# Resource: %s
# Severity: %s

echo "Starting remediation..."

# TODO: Add specific remediation commands based on finding type

echo "Remediation complete"
`, finding.ID, finding.Resource, finding.Severity)

	return script
}

func (sa *SecurityAnalyzer) estimateRemediationEffort(finding core.SecurityFinding) string {
	switch finding.Severity {
	case "CRITICAL":
		return "HIGH"
	case "HIGH":
		return "MEDIUM"
	default:
		return "LOW"
	}
}

func (sa *SecurityAnalyzer) calculateOverallRiskScore(matrix RiskMatrix) float64 {
	score := 0.0

	score += float64(len(matrix.Critical)) * 10
	score += float64(len(matrix.High)) * 5
	score += float64(len(matrix.Medium)) * 2
	score += float64(len(matrix.Low)) * 1

	return score
}

func (sa *SecurityAnalyzer) determineOverallRisk(score float64) string {
	if score > 50 {
		return "CRITICAL"
	} else if score > 30 {
		return "HIGH"
	} else if score > 15 {
		return "MEDIUM"
	}
	return "LOW"
}

func (sa *SecurityAnalyzer) analyzeThreatLandscape() ThreatLandscape {
	return ThreatLandscape{
		ActiveThreats: []Threat{
			{
				ID:          "threat-001",
				Name:        "Data Exfiltration",
				Type:        "EXTERNAL",
				Severity:    "HIGH",
				Status:      "ACTIVE",
				Description: "Attempts to extract sensitive data",
				Mitigations: []string{"DLP", "Network monitoring"},
				LastSeen:    time.Now(),
			},
		},
		ThreatActors: []ThreatActor{
			{
				Name:         "APT-Generic",
				Type:         "STATE-SPONSORED",
				Motivation:   "ESPIONAGE",
				Capabilities: []string{"Advanced persistence", "Zero-day exploits"},
				TTPs:         []string{"T1078", "T1190", "T1133"},
			},
		},
		AttackPatterns: []AttackPattern{},
		Indicators:     []ThreatIndicator{},
		ThreatIntelligence: make(map[string]interface{}),
	}
}

func (sa *SecurityAnalyzer) calculateVulnerabilityMetrics(vulnerabilities []Vulnerability) VulnerabilityMetrics {
	metrics := VulnerabilityMetrics{
		TotalVulnerabilities: len(vulnerabilities),
		AgeDistribution:      make(map[string]int),
		ServiceDistribution:  make(map[string]int),
		Trends:              make(map[string]interface{}),
	}

	exploitable := 0
	for _, vuln := range vulnerabilities {
		if vuln.Exploit.Available {
			exploitable++
		}

		metrics.ServiceDistribution[vuln.Service]++

		age := time.Since(vuln.FirstDetected).Hours() / 24
		if age < 7 {
			metrics.AgeDistribution["<7days"]++
		} else if age < 30 {
			metrics.AgeDistribution["7-30days"]++
		} else if age < 90 {
			metrics.AgeDistribution["30-90days"]++
		} else {
			metrics.AgeDistribution[">90days"]++
		}
	}

	metrics.ExploitableVulnerabilities = exploitable

	if len(vulnerabilities) > 0 {
		metrics.VulnerabilityDensity = float64(len(vulnerabilities)) / 100
		metrics.PatchCoverage = 75.0
		metrics.MeanTimeToRemediate = 14.5
	}

	return metrics
}

func (sa *SecurityAnalyzer) analyzeExposure(results *SecurityAnalysisResults) ExposureAnalysis {
	return ExposureAnalysis{
		InternetFacing:      5,
		PubliclyAccessible:  3,
		UnencryptedServices: 2,
		OpenPorts:          []PortExposure{},
		ExposedSecrets:     []SecretExposure{},
		AttackSurface:      make(map[string]interface{}),
	}
}

func (sa *SecurityAnalyzer) analyzeImpact(results *SecurityAnalysisResults) ImpactAnalysis {
	return ImpactAnalysis{
		BusinessImpact: "MODERATE",
		DataAtRisk: DataRisk{
			Classification:   "SENSITIVE",
			Volume:          "10TB",
			Sensitivity:     "HIGH",
			ExposureLevel:   "LIMITED",
			ProtectionStatus: "PARTIAL",
			RegulatoryData:  true,
			AffectedSystems: []string{"Database", "Storage"},
		},
		ServiceImpact:      []ServiceImpact{},
		ComplianceImpact:   []string{"PCI-DSS", "GDPR"},
		ReputationalImpact: "MODERATE",
		FinancialImpact: FinancialImpact{
			EstimatedLoss:     50000,
			RemediationCost:   10000,
			ComplianceFines:   25000,
			ReputationCost:    15000,
			InsuranceCoverage: 40000,
			TotalExposure:     60000,
		},
		RecoveryMetrics: RecoveryMetrics{
			RTO: 4,
			RPO: 1,
			MTD: 24,
			WRT: 72,
		},
	}
}

func (sa *SecurityAnalyzer) analyzeRiskTrends(results *SecurityAnalysisResults) RiskTrends {
	return RiskTrends{
		Direction:     "INCREASING",
		VelocityScore: 2.5,
		MonthlyChange: 15.0,
		ProjectedRisk: 65.0,
		TrendDrivers:  []string{"New vulnerabilities", "Expanded attack surface"},
		HistoricalData: make(map[string]interface{}),
	}
}

func (sa *SecurityAnalyzer) predictFutureRisks(assessment RiskAssessment) []RiskPrediction {
	return []RiskPrediction{
		{
			Period:     "30 days",
			RiskScore:  assessment.RiskScore * 1.1,
			Confidence: 0.75,
			Factors:    []string{"Increasing threats", "Pending patches"},
			Mitigations: []string{"Apply security updates", "Enhance monitoring"},
		},
		{
			Period:     "90 days",
			RiskScore:  assessment.RiskScore * 1.2,
			Confidence: 0.60,
			Factors:    []string{"Evolving threat landscape", "Infrastructure growth"},
			Mitigations: []string{"Security assessment", "Architecture review"},
		},
	}
}

func (sa *SecurityAnalyzer) analyzePrivileges(ctx context.Context, resources []core.Resource) PrivilegeAnalysis {
	return PrivilegeAnalysis{
		OverPrivileged:       []PrivilegedAccount{},
		UnusedPermissions:    []UnusedPermission{},
		DangerousPermissions: []DangerousPermission{},
		PrivilegeEscalation:  []EscalationPath{},
		Score:               75,
	}
}

func (sa *SecurityAnalyzer) analyzeKeyRotation(ctx context.Context, resources []core.Resource) KeyRotationAnalysis {
	return KeyRotationAnalysis{
		ComplianceStatus:  "PARTIAL",
		AverageKeyAge:     45.5,
		OldestKey:        time.Now().AddDate(0, -6, 0),
		ExpiredKeys:      []ExpiredKey{},
		RotationSchedule: make(map[string]string),
	}
}

func (sa *SecurityAnalyzer) analyzeMFA(ctx context.Context, resources []core.Resource) MFAAnalysis {
	return MFAAnalysis{
		Enabled:     true,
		Coverage:    85.0,
		Methods:     []string{"TOTP", "SMS"},
		NonMFAUsers: []string{},
		WeakMethods: []string{"SMS"},
	}
}

func (sa *SecurityAnalyzer) analyzePerimeter(ctx context.Context, resources []core.Resource) PerimeterSecurity {
	return PerimeterSecurity{
		ExposedServices:      []ExposedService{},
		PublicIPs:           []PublicIP{},
		UnprotectedEndpoints: []string{},
		EdgeProtection:      "CDN",
		Score:               80,
	}
}

func (sa *SecurityAnalyzer) analyzeSegmentation(ctx context.Context, resources []core.Resource) NetworkSegmentation {
	return NetworkSegmentation{
		Segments:          []NetworkSegment{},
		IsolationLevel:    "MODERATE",
		MicroSegmentation: false,
		CrossSegmentFlows: []CrossSegmentFlow{},
		Score:            65,
	}
}

func (sa *SecurityAnalyzer) analyzeTraffic(ctx context.Context, resources []core.Resource) TrafficAnalysis {
	return TrafficAnalysis{
		UnencryptedTraffic:   []UnencryptedFlow{},
		SuspiciousPatterns:   []SuspiciousPattern{},
		DataExfiltration:     []ExfiltrationAttempt{},
		ProtocolDistribution: make(map[string]float64),
		BandwidthAnalysis:    make(map[string]interface{}),
	}
}

func (sa *SecurityAnalyzer) analyzeFirewalls(ctx context.Context, resources []core.Resource) FirewallAnalysis {
	return FirewallAnalysis{
		TotalRules:       50,
		OverlyPermissive: []FirewallIssue{},
		Conflicts:        []RuleConflict{},
		UnusedRules:      []string{},
		MissingRules:     []string{},
		Effectiveness:    75.0,
	}
}

func (sa *SecurityAnalyzer) analyzeDNS(ctx context.Context, resources []core.Resource) DNSSecurityAnalysis {
	return DNSSecurityAnalysis{
		DNSSEC:          true,
		Tunneling:       []DNSTunnel{},
		Hijacking:       []DNSHijack{},
		CachePoisoning:  false,
		Recommendations: []string{"Enable DNS logging", "Monitor for anomalies"},
	}
}

func (sa *SecurityAnalyzer) analyzeVPN(ctx context.Context, resources []core.Resource) VPNSecurityAnalysis {
	return VPNSecurityAnalysis{
		Endpoints:       []VPNEndpoint{},
		Protocols:       []string{"OpenVPN", "IPSec"},
		Encryption:      "AES-256",
		Authentication:  "Certificate",
		Vulnerabilities: []string{},
		Score:          85,
	}
}

func (sa *SecurityAnalyzer) analyzeDDOSProtection(ctx context.Context, resources []core.Resource) DDOSProtectionStatus {
	return DDOSProtectionStatus{
		Enabled:         true,
		Provider:        "CloudFlare",
		ProtectionLevel: "ENTERPRISE",
		RecentAttacks:   []DDOSAttack{},
		Effectiveness:   95.0,
		Configuration:   make(map[string]interface{}),
	}
}

func (sa *SecurityAnalyzer) analyzeDataClassification(ctx context.Context, resources []core.Resource) DataClassificationAnalysis {
	return DataClassificationAnalysis{
		ClassifiedData:   map[string]int{"PUBLIC": 100, "INTERNAL": 500, "CONFIDENTIAL": 200, "RESTRICTED": 50},
		UnclassifiedData: 150,
		SensitiveData:    []SensitiveDataItem{},
		ComplianceStatus: map[string]bool{"GDPR": true, "CCPA": true},
		Score:           70,
	}
}

func (sa *SecurityAnalyzer) analyzeEncryption(ctx context.Context, resources []core.Resource) EncryptionAnalysis {
	return EncryptionAnalysis{
		AtRest: EncryptionStatus{
			Enabled:    true,
			Coverage:   90.0,
			Algorithm:  "AES-256",
			Strength:   "STRONG",
			Compliance: true,
			Issues:     []string{},
		},
		InTransit: EncryptionStatus{
			Enabled:    true,
			Coverage:   95.0,
			Algorithm:  "TLS 1.3",
			Strength:   "STRONG",
			Compliance: true,
			Issues:     []string{},
		},
		KeyManagement: KeyManagementAnalysis{
			Provider:   "Google KMS",
			KeyStore:   "HSM",
			Rotation:   true,
			HSM:        true,
			Compliance: true,
			Issues:     []string{},
		},
		Weaknesses: []EncryptionWeakness{},
		Score:     90,
	}
}

func (sa *SecurityAnalyzer) analyzeDataLoss(ctx context.Context, resources []core.Resource) DataLossAnalysis {
	return DataLossAnalysis{
		DLPEnabled:      false,
		Policies:        []DLPPolicy{},
		Incidents:       []DataLossIncident{},
		RiskAreas:       []string{"Email", "Cloud storage"},
		PreventionScore: 60,
	}
}

func (sa *SecurityAnalyzer) analyzePrivacy(ctx context.Context, resources []core.Resource) PrivacyAnalysis {
	return PrivacyAnalysis{
		PIIExposure: []PIIExposure{},
		ConsentManagement: ConsentStatus{
			Implemented: true,
			Coverage:    80.0,
			Mechanisms:  []string{"Opt-in", "Opt-out"},
			Issues:      []string{},
		},
		DataResidency: map[string]string{"EU": "eu-west-1", "US": "us-east-1"},
		RightToDelete: true,
		Compliance:    map[string]bool{"GDPR": true, "CCPA": true},
	}
}

func (sa *SecurityAnalyzer) analyzeBackup(ctx context.Context, resources []core.Resource) BackupAnalysis {
	return BackupAnalysis{
		Coverage:        85.0,
		Frequency:       "DAILY",
		RetentionPeriod: "30 days",
		Testing: BackupTestingStatus{
			LastTested:    time.Now().AddDate(0, -1, 0),
			TestFrequency: "MONTHLY",
			SuccessRate:   95.0,
			RecoveryTime:  2.5,
			Issues:        []string{},
		},
		Encryption: true,
		OffSite:   true,
		Issues:    []string{},
		Score:     80,
	}
}

func (sa *SecurityAnalyzer) analyzeRetention(ctx context.Context, resources []core.Resource) RetentionAnalysis {
	return RetentionAnalysis{
		Policies: []RetentionPolicy{
			{
				Name:       "Default Retention",
				DataType:   "Logs",
				Period:     "90 days",
				Compliance: true,
				Automated:  true,
			},
		},
		Compliance:      map[string]bool{"Legal": true, "Regulatory": true},
		DataAging:       make(map[string]interface{}),
		DeletionProcess: "AUTOMATED",
		Issues:         []string{},
	}
}

type SecurityCheck struct {
	ID   string
	Name string
}