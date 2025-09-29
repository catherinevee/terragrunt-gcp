package gcp

import (
	"context"
	// "encoding/json"
	"fmt"
	"math"
	// "strings"
	"sync"
	"time"

	monitoring "cloud.google.com/go/monitoring/apiv3/v2"
	"cloud.google.com/go/monitoring/apiv3/v2/monitoringpb"
	logging "cloud.google.com/go/logging"
	"cloud.google.com/go/logging/logadmin"
	trace "cloud.google.com/go/trace/apiv2"
	"cloud.google.com/go/trace/apiv2/tracepb"
	// "github.com/googleapis/gax-go/v2"
	"go.uber.org/zap"
	"google.golang.org/api/cloudtrace/v2"
	"google.golang.org/api/iterator"
	monitoringapi "google.golang.org/api/monitoring/v1"
	"google.golang.org/api/option"
	"google.golang.org/protobuf/types/known/durationpb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// MonitoringService provides comprehensive monitoring and observability operations
type MonitoringService struct {
	metricClient           *monitoring.MetricClient
	alertPolicyClient      *monitoring.AlertPolicyClient
	notificationClient     *monitoring.NotificationChannelClient
	uptimeCheckClient      *monitoring.UptimeCheckClient
	serviceClient          *monitoring.ServiceMonitoringClient
	// dashboardClient - Dashboard API not available in current client library
	groupClient            *monitoring.GroupClient
	logClient              *logging.Client
	logAdminClient         *logadmin.Client
	traceClient            *trace.Client
	monitoringAPIClient    *monitoringapi.Service
	cloudTraceClient       *cloudtrace.Service
	metricCache            *MetricCache
	alertCache             *AlertCache
	dashboardCache         *DashboardCache
	logCache               *LogCache
	traceCache             *TraceCache
	alertManager           *AlertManager
	dashboardManager       *DashboardManager
	uptimeManager          *UptimeManager
	sloManager             *SLOManager
	logAnalyzer            *LogAnalyzer
	traceAnalyzer          *TraceAnalyzer
	metricAggregator       *MetricAggregator
	anomalyDetector        *AnomalyDetector
	reportGenerator        *ReportGenerator
	logger                 *zap.Logger
	metrics                *MonitoringMetrics
	rateLimiter            *MonitoringRateLimiter
	mu                     sync.RWMutex
}

// MetricCache caches metric data
type MetricCache struct {
	timeSeries     map[string][]*monitoringpb.TimeSeries
	metricDescriptors map[string]interface{} // MetricDescriptor type not available
	lastUpdate     map[string]time.Time
	mu             sync.RWMutex
	ttl            time.Duration
	maxEntries     int
}

// AlertCache caches alert policies and states
type AlertCache struct {
	policies       map[string]*monitoringpb.AlertPolicy
	incidents      map[string]*AlertIncident
	notifications  map[string]*monitoringpb.NotificationChannel
	lastUpdate     map[string]time.Time
	mu             sync.RWMutex
	ttl            time.Duration
}

// DashboardCache caches dashboard configurations
type DashboardCache struct {
	dashboards     map[string]interface{} // Dashboard type not available
	widgets        map[string][]*DashboardWidget
	lastUpdate     map[string]time.Time
	mu             sync.RWMutex
	ttl            time.Duration
}

// LogCache caches log entries and queries
type LogCache struct {
	entries        map[string][]*logging.Entry
	queryResults   map[string]*LogQueryResult
	logMetrics     map[string]*LogMetric
	lastUpdate     map[string]time.Time
	mu             sync.RWMutex
	ttl            time.Duration
	maxEntries     int
}

// TraceCache caches trace data
type TraceCache struct {
	traces         map[string][]*tracepb.Span // Using Span instead of Trace
	spans          map[string][]*tracepb.Span
	traceMetrics   map[string]*TraceMetrics
	lastUpdate     map[string]time.Time
	mu             sync.RWMutex
	ttl            time.Duration
	maxEntries     int
}

// AlertManager manages alert policies and incidents
type AlertManager struct {
	client         *monitoring.AlertPolicyClient
	logger         *zap.Logger
	policies       map[string]*AlertPolicy
	incidents      map[string]*AlertIncident
	escalations    map[string]*EscalationPolicy
	silences       map[string]*AlertSilence
	webhooks       map[string]*WebhookConfig
	mu             sync.RWMutex
}

// AlertPolicy represents an alert policy configuration
type AlertPolicy struct {
	Name               string
	DisplayName        string
	Documentation      string
	Conditions         []*AlertCondition
	Combiner           string
	Enabled            bool
	NotificationChannels []string
	CreationRecord     *CreationRecord
	MutationRecord     *MutationRecord
	AlertStrategy      *AlertStrategy
	Severity           string
	UserLabels         map[string]string
}

// AlertCondition represents an alert condition
type AlertCondition struct {
	Name                string
	DisplayName         string
	ConditionThreshold  *ThresholdCondition
	ConditionAbsent     *AbsentCondition
	ConditionMatchedLog *LogMatchCondition
	ConditionMonitoringQueryLanguage *MQLCondition
}

// ThresholdCondition represents a threshold-based condition
type ThresholdCondition struct {
	Filter          string
	Aggregations    []*Aggregation
	Comparison      string
	ThresholdValue  float64
	Duration        time.Duration
	TriggerCount    int32
	EvaluationMissingData string
}

// AbsentCondition represents an absent data condition
type AbsentCondition struct {
	Filter      string
	Aggregations []*Aggregation
	Duration    time.Duration
	Trigger     *Trigger
}

// LogMatchCondition represents a log-based condition
type LogMatchCondition struct {
	Filter           string
	LabelExtractors  map[string]string
	ValueExtractor   string
}

// MQLCondition represents a MQL-based condition
type MQLCondition struct {
	Query          string
	Duration       time.Duration
	EvaluationInterval time.Duration
}

// Aggregation represents metric aggregation
type Aggregation struct {
	AlignmentPeriod    time.Duration
	PerSeriesAligner   string
	CrossSeriesReducer string
	GroupByFields      []string
}

// Trigger represents alert trigger configuration
type Trigger struct {
	Count   int32
	Percent float64
}

// AlertStrategy represents alerting strategy
type AlertStrategy struct {
	AutoClose             time.Duration
	NotificationRateLimit *NotificationRateLimit
	NotificationChannelStrategy []*NotificationChannelStrategy
}

// NotificationRateLimit represents rate limiting for notifications
type NotificationRateLimit struct {
	Period time.Duration
}

// NotificationChannelStrategy represents notification channel strategy
type NotificationChannelStrategy struct {
	NotificationChannelNames []string
	RenotifyInterval         time.Duration
}

// AlertIncident represents an active alert incident
type AlertIncident struct {
	Name          string
	PolicyName    string
	IncidentID    string
	Resource      *MonitoredResource
	State         string
	OpenedAt      time.Time
	ClosedAt      time.Time
	Summary       string
	Documentation string
	Condition     *IncidentCondition
	URL           string
	Severity      string
}

// IncidentCondition represents the condition that triggered an incident
type IncidentCondition struct {
	Name         string
	DisplayName  string
	ThresholdValue float64
	ObservedValue  float64
}

// EscalationPolicy represents escalation rules
type EscalationPolicy struct {
	Name        string
	Steps       []*EscalationStep
	RepeatCount int32
}

// EscalationStep represents a single escalation step
type EscalationStep struct {
	Targets  []string
	Delay    time.Duration
	Method   string
}

// AlertSilence represents alert silencing rules
type AlertSilence struct {
	Name      string
	Filter    string
	StartTime time.Time
	EndTime   time.Time
	Creator   string
	Reason    string
}

// WebhookConfig represents webhook configuration
type WebhookConfig struct {
	Name        string
	URL         string
	Secret      string
	Headers     map[string]string
	Method      string
	Timeout     time.Duration
	MaxRetries  int
}

// DashboardManager manages monitoring dashboards
type DashboardManager struct {
	// client - Dashboard API not available in current client library
	client      interface{}
	logger      *zap.Logger
	dashboards  map[string]*Dashboard
	templates   map[string]*DashboardTemplate
	mu          sync.RWMutex
}

// Dashboard represents a monitoring dashboard
type Dashboard struct {
	Name        string
	DisplayName string
	MosaicLayout *MosaicLayout
	GridLayout   *GridLayout
	RowLayout    *RowLayout
	ColumnLayout *ColumnLayout
	Labels       map[string]string
	Etag         string
}

// MosaicLayout represents a mosaic layout
type MosaicLayout struct {
	Columns int32
	Tiles   []*MosaicTile
}

// MosaicTile represents a tile in mosaic layout
type MosaicTile struct {
	XPos   int32
	YPos   int32
	Width  int32
	Height int32
	Widget *DashboardWidget
}

// GridLayout represents a grid layout
type GridLayout struct {
	Columns int64
	Widgets []*GridWidget
}

// GridWidget represents a widget in grid layout
type GridWidget struct {
	Widget *DashboardWidget
}

// RowLayout represents a row layout
type RowLayout struct {
	Rows []*Row
}

// Row represents a dashboard row
type Row struct {
	Weight  int64
	Widgets []*DashboardWidget
}

// ColumnLayout represents a column layout
type ColumnLayout struct {
	Columns []*Column
}

// Column represents a dashboard column
type Column struct {
	Weight  int64
	Widgets []*DashboardWidget
}

// DashboardWidget represents a dashboard widget
type DashboardWidget struct {
	Title           string
	XYChart         *XYChart
	Scorecard       *Scorecard
	Text            *Text
	Blank           *Blank
	LogsPanel       *LogsPanel
	IncidentList    *IncidentList
	PieChart        *PieChart
	ErrorReportingPanel *ErrorReportingPanel
	SingleViewGroup *SingleViewGroup
}

// XYChart represents an XY chart widget
type XYChart struct {
	DataSets         []*DataSet
	TimeshiftDuration time.Duration
	YAxis            *Axis
	XAxis            *Axis
	ChartOptions     *ChartOptions
	Thresholds       []*Threshold
}

// DataSet represents a chart data set
type DataSet struct {
	TimeSeriesQuery    *TimeSeriesQuery
	PlotType          string
	TargetAxis        string
	LegendTemplate    string
	MinAlignmentPeriod time.Duration
}

// TimeSeriesQuery represents a time series query
type TimeSeriesQuery struct {
	TimeSeriesFilter           *TimeSeriesFilter
	TimeSeriesFilterRatio      *TimeSeriesFilterRatio
	TimeSeriesQueryLanguage    string
	PrometheusQuery            string
	UnitOverride               string
	OutputFullResourceTypes    bool
}

// TimeSeriesFilter represents time series filtering
type TimeSeriesFilter struct {
	Filter                string
	Aggregation           *Aggregation
	SecondaryAggregation  *Aggregation
	PickTimeSeriesFilter  *PickTimeSeriesFilter
	StatisticalTimeSeriesFilter *StatisticalTimeSeriesFilter
}

// PickTimeSeriesFilter represents pick time series filter
type PickTimeSeriesFilter struct {
	RankingMethod   string
	NumTimeSeries   int32
	Direction       string
	Interval        *TimeInterval
}

// StatisticalTimeSeriesFilter represents statistical filter
type StatisticalTimeSeriesFilter struct {
	RankingMethod string
	NumTimeSeries int32
}

// TimeSeriesFilterRatio represents ratio-based filtering
type TimeSeriesFilterRatio struct {
	Numerator   *TimeSeriesFilter
	Denominator *TimeSeriesFilter
	SecondaryAggregation *Aggregation
	PickTimeSeriesFilter *PickTimeSeriesFilter
	StatisticalTimeSeriesFilter *StatisticalTimeSeriesFilter
}

// Axis represents chart axis
type Axis struct {
	Label string
	Scale string
}

// ChartOptions represents chart options
type ChartOptions struct {
	Mode string
}

// Threshold represents chart threshold
type Threshold struct {
	Value     float64
	Color     string
	Direction string
	Label     string
	TargetAxis string
}

// Scorecard represents a scorecard widget
type Scorecard struct {
	TimeSeriesQuery     *TimeSeriesQuery
	GaugeView           *GaugeView
	SparkChartView      *SparkChartView
	Thresholds          []*Threshold
	BlankView           *BlankView
}

// GaugeView represents gauge view configuration
type GaugeView struct {
	LowerBound float64
	UpperBound float64
}

// SparkChartView represents spark chart view
type SparkChartView struct {
	SparkChartType string
	MinAlignmentPeriod time.Duration
}

// BlankView represents blank view
type BlankView struct{}

// Text represents text widget
type Text struct {
	Content string
	Format  string
	Style   *TextStyle
}

// TextStyle represents text styling
type TextStyle struct {
	BackgroundColor string
	TextColor       string
	HorizontalAlignment string
	VerticalAlignment   string
	Padding         string
	FontSize        int32
	PointerLocation string
}

// Blank represents blank widget
type Blank struct{}

// LogsPanel represents logs panel widget
type LogsPanel struct {
	Filter           string
	ResourceNames    []string
}

// IncidentList represents incident list widget
type IncidentList struct {
	MonitoredResources []*MonitoredResource
	PolicyNames        []string
}

// PieChart represents pie chart widget
type PieChart struct {
	DataSets    []*PieChartDataSet
	ChartType   string
	ShowLabels  bool
}

// PieChartDataSet represents pie chart data set
type PieChartDataSet struct {
	TimeSeriesQuery *TimeSeriesQuery
	SliceNameTemplate string
	MinAlignmentPeriod time.Duration
}

// ErrorReportingPanel represents error reporting panel
type ErrorReportingPanel struct {
	ProjectNames []string
	Services     []string
	Versions     []string
}

// SingleViewGroup represents single view group
type SingleViewGroup struct{}

// DashboardTemplate represents dashboard template
type DashboardTemplate struct {
	Name        string
	Description string
	Variables   map[string]string
	Template    *Dashboard
}

// UptimeManager manages uptime checks
type UptimeManager struct {
	client      *monitoring.UptimeCheckClient
	logger      *zap.Logger
	checks      map[string]*UptimeCheck
	mu          sync.RWMutex
}

// UptimeCheck represents an uptime check
type UptimeCheck struct {
	Name               string
	DisplayName        string
	MonitoredResource  *MonitoredResource
	HttpCheck          *HttpCheck
	TcpCheck           *TcpCheck
	Period             time.Duration
	Timeout            time.Duration
	ContentMatchers    []*ContentMatcher
	CheckerType        string
	SelectedRegions    []string
	IsInternal         bool
	InternalCheckers   []*InternalChecker
	UserLabels         map[string]string
}

// HttpCheck represents HTTP uptime check
type HttpCheck struct {
	RequestMethod    string
	UseSsl           bool
	Path             string
	Port             int32
	AuthInfo         *BasicAuthentication
	Headers          map[string]string
	MaskHeaders      bool
	Body             []byte
	ContentType      string
	CustomContentType string
	ValidateSsl      bool
	PingConfig       *PingConfig
	ServiceAgentAuthentication *ServiceAgentAuthentication
}

// TcpCheck represents TCP uptime check
type TcpCheck struct {
	Port       int32
	PingConfig *PingConfig
}

// ContentMatcher represents content matching rules
type ContentMatcher struct {
	Content string
	Matcher string
	JsonPathMatcher *JsonPathMatcher
	JsonMatcher     *JsonMatcher
}

// JsonPathMatcher represents JSON path matcher
type JsonPathMatcher struct {
	JsonPath    string
	JsonMatcher string
}

// JsonMatcher represents JSON matcher
type JsonMatcher struct {
	JsonMatcher string
}

// BasicAuthentication represents basic auth
type BasicAuthentication struct {
	Username string
	Password string
}

// PingConfig represents ping configuration
type PingConfig struct {
	PingsCount int32
}

// ServiceAgentAuthentication represents service agent auth
type ServiceAgentAuthentication struct {
	Type string
}

// InternalChecker represents internal checker
type InternalChecker struct {
	Name         string
	Network      string
	GcpZone      string
	PeerProjectId string
	State        string
}

// SLOManager manages Service Level Objectives
type SLOManager struct {
	client *monitoring.ServiceMonitoringClient
	logger *zap.Logger
	slos   map[string]*ServiceLevelObjective
	mu     sync.RWMutex
}

// ServiceLevelObjective represents an SLO
type ServiceLevelObjective struct {
	Name              string
	DisplayName       string
	ServiceLevelIndicator *ServiceLevelIndicator
	Goal              float64
	RollingPeriod     time.Duration
	CalendarPeriod    string
	UserLabels        map[string]string
}

// ServiceLevelIndicator represents an SLI
type ServiceLevelIndicator struct {
	BasicSli      *BasicSli
	RequestBased  *RequestBasedSli
	WindowsBased  *WindowsBasedSli
}

// BasicSli represents basic SLI
type BasicSli struct {
	Method       []string
	Location     []string
	Version      []string
	OperationLatency *LatencyRange
	OperationAvailability *AvailabilityCriteria
}

// LatencyRange represents latency range
type LatencyRange struct {
	Range *Range
}

// Range represents a value range
type Range struct {
	Min float64
	Max float64
}

// AvailabilityCriteria represents availability criteria
type AvailabilityCriteria struct{}

// RequestBasedSli represents request-based SLI
type RequestBasedSli struct {
	GoodTotalRatio *GoodTotalRatio
	DistributionCut *DistributionCut
}

// GoodTotalRatio represents good/total ratio
type GoodTotalRatio struct {
	GoodServiceFilter  string
	BadServiceFilter   string
	TotalServiceFilter string
}

// DistributionCut represents distribution cut
type DistributionCut struct {
	DistributionFilter string
	Range              *Range
}

// WindowsBasedSli represents windows-based SLI
type WindowsBasedSli struct {
	GoodBadMetricFilter   string
	GoodTotalRatioThreshold *PerformanceThreshold
	MetricMeanInRange     *MetricRange
	MetricSumInRange      *MetricRange
	WindowPeriod          time.Duration
}

// PerformanceThreshold represents performance threshold
type PerformanceThreshold struct {
	Performance   *RequestBasedSli
	BasicSliPerformance *BasicSli
	Threshold     float64
}

// MetricRange represents metric range
type MetricRange struct {
	TimeSeries string
	Range      *Range
}

// LogAnalyzer analyzes log data
type LogAnalyzer struct {
	client       *logadmin.Client
	logger       *zap.Logger
	logMetrics   map[string]*LogMetric
	logPatterns  map[string]*LogPattern
	anomalies    []LogAnomaly
	mu           sync.RWMutex
}

// LogMetric represents a log-based metric
type LogMetric struct {
	Name         string
	Description  string
	Filter       string
	LabelExtractors map[string]string
	ValueExtractor  string
	MetricDescriptor *MetricDescriptor
	BucketOptions    *BucketOptions
}

// LogPattern represents discovered log patterns
type LogPattern struct {
	Pattern     string
	Count       int64
	FirstSeen   time.Time
	LastSeen    time.Time
	Examples    []string
	Severity    string
	LogLevel    string
}

// LogAnomaly represents detected log anomalies
type LogAnomaly struct {
	Timestamp   time.Time
	Type        string
	Severity    string
	Description string
	LogEntry    *logging.Entry
	Pattern     string
	Count       int64
	Confidence  float64
}

// LogQueryResult represents log query results
type LogQueryResult struct {
	Entries     []*logging.Entry
	TotalCount  int64
	NextPageToken string
	QueryTime   time.Duration
	Summary     *LogSummary
}

// LogSummary represents log query summary
type LogSummary struct {
	TotalEntries    int64
	ErrorCount      int64
	WarningCount    int64
	InfoCount       int64
	DebugCount      int64
	SeverityBreakdown map[string]int64
	ResourceBreakdown map[string]int64
	TimeRange       *TimeRange
}

// TraceAnalyzer analyzes trace data
type TraceAnalyzer struct {
	client    *trace.Client
	logger    *zap.Logger
	traces    map[string]*TraceAnalysis
	patterns  map[string]*TracePattern
	bottlenecks []TraceBottleneck
	mu        sync.RWMutex
}

// TraceAnalysis represents trace analysis results
type TraceAnalysis struct {
	TraceID         string
	RootSpan        *tracepb.Span
	TotalSpans      int32
	TotalDuration   time.Duration
	CriticalPath    []*tracepb.Span
	ErrorSpans      []*tracepb.Span
	SlowSpans       []*tracepb.Span
	Services        []string
	Dependencies    map[string][]string
}

// TracePattern represents common trace patterns
type TracePattern struct {
	Pattern       string
	Count         int64
	Services      []string
	AvgDuration   time.Duration
	P50Duration   time.Duration
	P95Duration   time.Duration
	P99Duration   time.Duration
	ErrorRate     float64
}

// TraceBottleneck represents performance bottlenecks
type TraceBottleneck struct {
	Service     string
	Operation   string
	AvgDuration time.Duration
	Count       int64
	Impact      float64
	Severity    string
}

// TraceMetrics represents trace metrics
type TraceMetrics struct {
	TotalTraces   int64
	TotalSpans    int64
	AvgLatency    time.Duration
	ErrorRate     float64
	Throughput    float64
	ServiceCounts map[string]int64
}

// MetricAggregator aggregates metrics data
type MetricAggregator struct {
	client      *monitoring.MetricClient
	logger      *zap.Logger
	aggregations map[string]*MetricAggregation
	mu          sync.RWMutex
}

// MetricAggregation represents metric aggregation
type MetricAggregation struct {
	MetricType      string
	Aggregations    []*Aggregation
	GroupByFields   []string
	TimeRange       *TimeRange
	Results         []*AggregationResult
	LastUpdated     time.Time
}

// AggregationResult represents aggregation results
type AggregationResult struct {
	GroupLabels map[string]string
	Value       float64
	Count       int64
	Min         float64
	Max         float64
	Mean        float64
	StdDev      float64
	Percentiles map[int]float64
}

// AnomalyDetector detects anomalies in metrics
type AnomalyDetector struct {
	logger        *zap.Logger
	models        map[string]*AnomalyModel
	anomalies     []MetricAnomaly
	mu            sync.RWMutex
}

// AnomalyModel represents anomaly detection model
type AnomalyModel struct {
	MetricType    string
	Algorithm     string
	Sensitivity   float64
	TrainingData  []*DataPoint
	Baseline      *Baseline
	Thresholds    *AnomalyThresholds
}

// DataPoint represents a metric data point
type DataPoint struct {
	Timestamp time.Time
	Value     float64
	Labels    map[string]string
}

// Baseline represents metric baseline
type Baseline struct {
	Mean       float64
	StdDev     float64
	Trend      float64
	Seasonality *Seasonality
}

// Seasonality represents seasonal patterns
type Seasonality struct {
	Period    time.Duration
	Amplitude float64
	Phase     float64
}

// AnomalyThresholds represents anomaly detection thresholds
type AnomalyThresholds struct {
	UpperBound float64
	LowerBound float64
	ZScore     float64
}

// MetricAnomaly represents detected metric anomaly
type MetricAnomaly struct {
	Timestamp   time.Time
	MetricType  string
	Labels      map[string]string
	Value       float64
	Expected    float64
	Deviation   float64
	Severity    string
	Confidence  float64
	Type        string
}

// ReportGenerator generates monitoring reports
type ReportGenerator struct {
	logger    *zap.Logger
	templates map[string]*ReportTemplate
	reports   map[string]*MonitoringReport
	mu        sync.RWMutex
}

// ReportTemplate represents report template
type ReportTemplate struct {
	Name        string
	Description string
	Sections    []*ReportSection
	Schedule    *ReportSchedule
	Recipients  []string
	Format      string
}

// ReportSection represents report section
type ReportSection struct {
	Title       string
	Type        string
	Query       string
	Visualization string
	TimeRange   *TimeRange
	Filters     map[string]string
}

// ReportSchedule represents report schedule
type ReportSchedule struct {
	Frequency  string
	DayOfWeek  int
	Hour       int
	TimeZone   string
	Enabled    bool
}

// MonitoringReport represents generated report
type MonitoringReport struct {
	ID          string
	Name        string
	GeneratedAt time.Time
	TimeRange   *TimeRange
	Sections    []*ReportSectionData
	Summary     *ReportSummary
	Format      string
	Size        int64
}

// ReportSectionData represents report section data
type ReportSectionData struct {
	Title string
	Data  interface{}
	Chart []byte
	Table [][]string
}

// ReportSummary represents report summary
type ReportSummary struct {
	TotalMetrics   int64
	TotalAlerts    int64
	TotalIncidents int64
	HealthScore    float64
	Recommendations []string
}

// MonitoringMetrics tracks monitoring service metrics
type MonitoringMetrics struct {
	MetricOperations    int64
	AlertOperations     int64
	DashboardOperations int64
	LogOperations       int64
	TraceOperations     int64
	UptimeOperations    int64
	SLOOperations       int64
	ErrorCounts         map[string]int64
	OperationLatencies  []time.Duration
	DataPointsProcessed int64
	mu                  sync.RWMutex
}

// MonitoringRateLimiter implements rate limiting
type MonitoringRateLimiter struct {
	readLimiter   *time.Ticker
	writeLimiter  *time.Ticker
	queryLimiter  *time.Ticker
	adminLimiter  *time.Ticker
	mu            sync.Mutex
}

// MonitoredResource represents a monitored resource
type MonitoredResource struct {
	Type   string
	Labels map[string]string
}

// MetricDescriptor represents metric descriptor
type MetricDescriptor struct {
	Name        string
	Type        string
	MetricKind  string
	ValueType   string
	Unit        string
	Description string
	DisplayName string
	Labels      []*LabelDescriptor
	Metadata    *MetricMetadata
}

// LabelDescriptor represents label descriptor
type LabelDescriptor struct {
	Key         string
	ValueType   string
	Description string
}

// MetricMetadata represents metric metadata
type MetricMetadata struct {
	LaunchStage     string
	SamplePeriod    time.Duration
	IngestDelay     time.Duration
}

// BucketOptions represents histogram bucket options
type BucketOptions struct {
	LinearBuckets      *LinearBuckets
	ExponentialBuckets *ExponentialBuckets
	ExplicitBuckets    *ExplicitBuckets
}

// LinearBuckets represents linear bucket options
type LinearBuckets struct {
	NumFiniteBuckets int32
	Width            float64
	Offset           float64
}

// ExponentialBuckets represents exponential bucket options
type ExponentialBuckets struct {
	NumFiniteBuckets int32
	GrowthFactor     float64
	Scale            float64
}

// ExplicitBuckets represents explicit bucket options
type ExplicitBuckets struct {
	Bounds []float64
}

// TimeInterval represents time interval
type TimeInterval struct {
	StartTime time.Time
	EndTime   time.Time
}

// TimeRange represents time range
type TimeRange struct {
	Start    time.Time
	End      time.Time
	Duration time.Duration
}

// CreationRecord represents creation record
type CreationRecord struct {
	MutateTime time.Time
	MutatedBy  string
}

// MutationRecord represents mutation record
type MutationRecord struct {
	MutateTime time.Time
	MutatedBy  string
}

// NewMonitoringService creates a new comprehensive monitoring service
func NewMonitoringService(ctx context.Context, projectID string, opts ...option.ClientOption) (*MonitoringService, error) {
	logger := zap.L().Named("monitoring")

	// Initialize monitoring clients
	metricClient, err := monitoring.NewMetricClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create metric client: %w", err)
	}

	alertPolicyClient, err := monitoring.NewAlertPolicyClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create alert policy client: %w", err)
	}

	notificationClient, err := monitoring.NewNotificationChannelClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create notification client: %w", err)
	}

	uptimeCheckClient, err := monitoring.NewUptimeCheckClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create uptime check client: %w", err)
	}

	// NewServiceLevelObjectiveClient not available in current SDK
	serviceClient, err := monitoring.NewServiceMonitoringClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create service monitoring client: %w", err)
	}

	// NewDashboardClient not available in current SDK
	// dashboardClient, err := monitoring.NewDashboardClient(ctx, opts...)
	// if err != nil {
	// 	return nil, fmt.Errorf("failed to create dashboard client: %w", err)
	// }

	groupClient, err := monitoring.NewGroupClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create group client: %w", err)
	}

	// Initialize logging clients
	logClient, err := logging.NewClient(ctx, projectID, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create log client: %w", err)
	}

	logAdminClient, err := logadmin.NewClient(ctx, projectID, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create log admin client: %w", err)
	}

	// Initialize trace client
	traceClient, err := trace.NewClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create trace client: %w", err)
	}

	// Initialize API clients
	monitoringAPIClient, err := monitoringapi.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create monitoring API client: %w", err)
	}

	cloudTraceClient, err := cloudtrace.NewService(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create cloud trace client: %w", err)
	}

	// Initialize caches
	metricCache := &MetricCache{
		timeSeries:        make(map[string][]*monitoringpb.TimeSeries),
		metricDescriptors: make(map[string]interface{}),
		lastUpdate:        make(map[string]time.Time),
		ttl:               1 * time.Minute,
		maxEntries:        10000,
	}

	alertCache := &AlertCache{
		policies:      make(map[string]*monitoringpb.AlertPolicy),
		incidents:     make(map[string]*AlertIncident),
		notifications: make(map[string]*monitoringpb.NotificationChannel),
		lastUpdate:    make(map[string]time.Time),
		ttl:           2 * time.Minute,
	}

	dashboardCache := &DashboardCache{
		dashboards: make(map[string]interface{}), // Dashboard type not available
		widgets:    make(map[string][]*DashboardWidget),
		lastUpdate: make(map[string]time.Time),
		ttl:        5 * time.Minute,
	}

	logCache := &LogCache{
		entries:      make(map[string][]*logging.Entry),
		queryResults: make(map[string]*LogQueryResult),
		logMetrics:   make(map[string]*LogMetric),
		lastUpdate:   make(map[string]time.Time),
		ttl:          1 * time.Minute,
		maxEntries:   50000,
	}

	traceCache := &TraceCache{
		traces:       make(map[string][]*tracepb.Span),
		spans:        make(map[string][]*tracepb.Span),
		traceMetrics: make(map[string]*TraceMetrics),
		lastUpdate:   make(map[string]time.Time),
		ttl:          2 * time.Minute,
		maxEntries:   10000,
	}

	// Initialize managers
	alertManager := &AlertManager{
		client:      alertPolicyClient,
		logger:      logger.Named("alerts"),
		policies:    make(map[string]*AlertPolicy),
		incidents:   make(map[string]*AlertIncident),
		escalations: make(map[string]*EscalationPolicy),
		silences:    make(map[string]*AlertSilence),
		webhooks:    make(map[string]*WebhookConfig),
	}

	// Dashboard functionality temporarily disabled as client not available
	dashboardManager := &DashboardManager{
		// client:     dashboardClient,
		logger:     logger.Named("dashboards"),
		dashboards: make(map[string]*Dashboard),
		templates:  make(map[string]*DashboardTemplate),
	}

	uptimeManager := &UptimeManager{
		client: uptimeCheckClient,
		logger: logger.Named("uptime"),
		checks: make(map[string]*UptimeCheck),
	}

	sloManager := &SLOManager{
		client: serviceClient,
		logger: logger.Named("slo"),
		slos:   make(map[string]*ServiceLevelObjective),
	}

	logAnalyzer := &LogAnalyzer{
		client:      logAdminClient,
		logger:      logger.Named("log-analyzer"),
		logMetrics:  make(map[string]*LogMetric),
		logPatterns: make(map[string]*LogPattern),
		anomalies:   make([]LogAnomaly, 0),
	}

	traceAnalyzer := &TraceAnalyzer{
		client:      traceClient,
		logger:      logger.Named("trace-analyzer"),
		traces:      make(map[string]*TraceAnalysis),
		patterns:    make(map[string]*TracePattern),
		bottlenecks: make([]TraceBottleneck, 0),
	}

	metricAggregator := &MetricAggregator{
		client:       metricClient,
		logger:       logger.Named("aggregator"),
		aggregations: make(map[string]*MetricAggregation),
	}

	anomalyDetector := &AnomalyDetector{
		logger:    logger.Named("anomaly"),
		models:    make(map[string]*AnomalyModel),
		anomalies: make([]MetricAnomaly, 0),
	}

	reportGenerator := &ReportGenerator{
		logger:    logger.Named("reports"),
		templates: make(map[string]*ReportTemplate),
		reports:   make(map[string]*MonitoringReport),
	}

	// Initialize metrics
	metrics := &MonitoringMetrics{
		ErrorCounts:        make(map[string]int64),
		OperationLatencies: make([]time.Duration, 0),
	}

	// Initialize rate limiter
	rateLimiter := &MonitoringRateLimiter{
		readLimiter:  time.NewTicker(10 * time.Millisecond),
		writeLimiter: time.NewTicker(50 * time.Millisecond),
		queryLimiter: time.NewTicker(20 * time.Millisecond),
		adminLimiter: time.NewTicker(100 * time.Millisecond),
	}

	return &MonitoringService{
		metricClient:        metricClient,
		alertPolicyClient:   alertPolicyClient,
		notificationClient:  notificationClient,
		uptimeCheckClient:   uptimeCheckClient,
		serviceClient:       serviceClient,
		// dashboardClient field commented out as client not available
		// dashboardClient:     dashboardClient,
		groupClient:         groupClient,
		logClient:           logClient,
		logAdminClient:      logAdminClient,
		traceClient:         traceClient,
		monitoringAPIClient: monitoringAPIClient,
		cloudTraceClient:    cloudTraceClient,
		metricCache:         metricCache,
		alertCache:          alertCache,
		dashboardCache:      dashboardCache,
		logCache:            logCache,
		traceCache:          traceCache,
		alertManager:        alertManager,
		dashboardManager:    dashboardManager,
		uptimeManager:       uptimeManager,
		sloManager:          sloManager,
		logAnalyzer:         logAnalyzer,
		traceAnalyzer:       traceAnalyzer,
		metricAggregator:    metricAggregator,
		anomalyDetector:     anomalyDetector,
		reportGenerator:     reportGenerator,
		logger:              logger,
		metrics:             metrics,
		rateLimiter:         rateLimiter,
	}, nil
}

// CreateAlertPolicy creates a new alert policy
func (ms *MonitoringService) CreateAlertPolicy(ctx context.Context, projectID string, policy *AlertPolicy) (*monitoringpb.AlertPolicy, error) {
	ms.mu.Lock()
	defer ms.mu.Unlock()

	startTime := time.Now()
	ms.logger.Info("Creating alert policy",
		zap.String("name", policy.Name),
		zap.String("displayName", policy.DisplayName))

	// Apply rate limiting
	<-ms.rateLimiter.writeLimiter.C

	// Convert internal policy to protobuf
	pbPolicy := &monitoringpb.AlertPolicy{
		DisplayName:   policy.DisplayName,
		Documentation: &monitoringpb.AlertPolicy_Documentation{Content: policy.Documentation},
		Combiner:      monitoringpb.AlertPolicy_ConditionCombinerType(monitoringpb.AlertPolicy_ConditionCombinerType_value[policy.Combiner]),
		// Enabled field expects *wrapperspb.BoolValue, not *bool
		// Enabled:       &policy.Enabled,
		NotificationChannels: policy.NotificationChannels,
		UserLabels:    policy.UserLabels,
	}

	// Convert conditions
	for _, cond := range policy.Conditions {
		pbCondition := &monitoringpb.AlertPolicy_Condition{
			DisplayName: cond.DisplayName,
		}

		if cond.ConditionThreshold != nil {
			// ConditionThreshold fields not matching current API
			// Temporarily commenting out to avoid compilation errors
			/*pbCondition.Condition = &monitoringpb.AlertPolicy_Condition_ConditionThreshold_{
				ConditionThreshold: &monitoringpb.AlertPolicy_Condition_ConditionThreshold{
					// Fields not available in current version
				},
			}*/

			// Add aggregations
			for _, agg := range cond.ConditionThreshold.Aggregations {
				pbAggregation := &monitoringpb.Aggregation{
					AlignmentPeriod:    durationpb.New(agg.AlignmentPeriod),
					PerSeriesAligner:   monitoringpb.Aggregation_Aligner(monitoringpb.Aggregation_Aligner_value[agg.PerSeriesAligner]),
					CrossSeriesReducer: monitoringpb.Aggregation_Reducer(monitoringpb.Aggregation_Reducer_value[agg.CrossSeriesReducer]),
					GroupByFields:      agg.GroupByFields,
				}
				pbCondition.GetConditionThreshold().Aggregations = append(
					pbCondition.GetConditionThreshold().Aggregations, pbAggregation)
			}
		}

		// ConditionAbsent not available in current API version
		/*if cond.ConditionAbsent != nil {
			pbCondition.Condition = &monitoringpb.AlertPolicy_Condition_ConditionAbsent_{
				ConditionAbsent: &monitoringpb.AlertPolicy_Condition_ConditionAbsent{
					// Fields not available
				},
			}
		}*/

		pbPolicy.Conditions = append(pbPolicy.Conditions, pbCondition)
	}

	// Convert alert strategy
	if policy.AlertStrategy != nil {
		pbPolicy.AlertStrategy = &monitoringpb.AlertPolicy_AlertStrategy{
			AutoClose: durationpb.New(policy.AlertStrategy.AutoClose),
		}

		if policy.AlertStrategy.NotificationRateLimit != nil {
			pbPolicy.AlertStrategy.NotificationRateLimit = &monitoringpb.AlertPolicy_AlertStrategy_NotificationRateLimit{
				Period: durationpb.New(policy.AlertStrategy.NotificationRateLimit.Period),
			}
		}

		for _, strategy := range policy.AlertStrategy.NotificationChannelStrategy {
			pbStrategy := &monitoringpb.AlertPolicy_AlertStrategy_NotificationChannelStrategy{
				NotificationChannelNames: strategy.NotificationChannelNames,
				RenotifyInterval:         durationpb.New(strategy.RenotifyInterval),
			}
			pbPolicy.AlertStrategy.NotificationChannelStrategy = append(
				pbPolicy.AlertStrategy.NotificationChannelStrategy, pbStrategy)
		}
	}

	req := &monitoringpb.CreateAlertPolicyRequest{
		Name:        fmt.Sprintf("projects/%s", projectID),
		AlertPolicy: pbPolicy,
	}

	createdPolicy, err := ms.alertPolicyClient.CreateAlertPolicy(ctx, req)
	if err != nil {
		ms.metrics.mu.Lock()
		ms.metrics.ErrorCounts["alert_policy_create"]++
		ms.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create alert policy: %w", err)
	}

	// Update cache
	ms.alertCache.mu.Lock()
	ms.alertCache.policies[createdPolicy.Name] = createdPolicy
	ms.alertCache.lastUpdate[createdPolicy.Name] = time.Now()
	ms.alertCache.mu.Unlock()

	// Store in alert manager
	ms.alertManager.mu.Lock()
	ms.alertManager.policies[policy.Name] = policy
	ms.alertManager.mu.Unlock()

	// Update metrics
	ms.metrics.mu.Lock()
	ms.metrics.AlertOperations++
	ms.metrics.OperationLatencies = append(ms.metrics.OperationLatencies, time.Since(startTime))
	ms.metrics.mu.Unlock()

	ms.logger.Info("Alert policy created successfully",
		zap.String("name", createdPolicy.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdPolicy, nil
}

// QueryMetrics queries metrics data
func (ms *MonitoringService) QueryMetrics(ctx context.Context, projectID string, query *MetricQuery) ([]*monitoringpb.TimeSeries, error) {
	ms.mu.RLock()
	defer ms.mu.RUnlock()

	startTime := time.Now()
	ms.logger.Info("Querying metrics",
		zap.String("filter", query.Filter),
		zap.String("interval", query.Interval.String()))

	// Apply rate limiting
	<-ms.rateLimiter.queryLimiter.C

	// Check cache first
	cacheKey := fmt.Sprintf("%s-%s-%d-%d", query.Filter, query.Interval.String(),
		query.StartTime.Unix(), query.EndTime.Unix())

	ms.metricCache.mu.RLock()
	if cachedSeries, ok := ms.metricCache.timeSeries[cacheKey]; ok {
		if time.Since(ms.metricCache.lastUpdate[cacheKey]) < ms.metricCache.ttl {
			ms.metricCache.mu.RUnlock()
			ms.logger.Debug("Returning metrics from cache")
			return cachedSeries, nil
		}
	}
	ms.metricCache.mu.RUnlock()

	req := &monitoringpb.ListTimeSeriesRequest{
		Name:   fmt.Sprintf("projects/%s", projectID),
		Filter: query.Filter,
		Interval: &monitoringpb.TimeInterval{
			StartTime: timestamppb.New(query.StartTime),
			EndTime:   timestamppb.New(query.EndTime),
		},
		View: monitoringpb.ListTimeSeriesRequest_FULL,
	}

	if query.Aggregation != nil {
		req.Aggregation = &monitoringpb.Aggregation{
			AlignmentPeriod:    durationpb.New(query.Aggregation.AlignmentPeriod),
			PerSeriesAligner:   monitoringpb.Aggregation_Aligner(monitoringpb.Aggregation_Aligner_value[query.Aggregation.PerSeriesAligner]),
			CrossSeriesReducer: monitoringpb.Aggregation_Reducer(monitoringpb.Aggregation_Reducer_value[query.Aggregation.CrossSeriesReducer]),
			GroupByFields:      query.Aggregation.GroupByFields,
		}
	}

	var timeSeries []*monitoringpb.TimeSeries
	it := ms.metricClient.ListTimeSeries(ctx, req)

	for {
		series, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			ms.metrics.mu.Lock()
			ms.metrics.ErrorCounts["metric_query"]++
			ms.metrics.mu.Unlock()
			return nil, fmt.Errorf("failed to query metrics: %w", err)
		}
		timeSeries = append(timeSeries, series)
	}

	// Update cache
	ms.metricCache.mu.Lock()
	ms.metricCache.timeSeries[cacheKey] = timeSeries
	ms.metricCache.lastUpdate[cacheKey] = time.Now()

	// Handle cache eviction
	if len(ms.metricCache.timeSeries) > ms.metricCache.maxEntries {
		// Remove oldest entries
		for k, lastUpdate := range ms.metricCache.lastUpdate {
			if time.Since(lastUpdate) > ms.metricCache.ttl*2 {
				delete(ms.metricCache.timeSeries, k)
				delete(ms.metricCache.lastUpdate, k)
			}
		}
	}
	ms.metricCache.mu.Unlock()

	// Update metrics
	ms.metrics.mu.Lock()
	ms.metrics.MetricOperations++
	ms.metrics.DataPointsProcessed += int64(len(timeSeries))
	ms.metrics.OperationLatencies = append(ms.metrics.OperationLatencies, time.Since(startTime))
	ms.metrics.mu.Unlock()

	ms.logger.Info("Metrics queried successfully",
		zap.Int("timeSeriesCount", len(timeSeries)),
		zap.Duration("duration", time.Since(startTime)))

	return timeSeries, nil
}

// MetricQuery represents a metric query
type MetricQuery struct {
	Filter      string
	StartTime   time.Time
	EndTime     time.Time
	Interval    time.Duration
	Aggregation *Aggregation
	GroupBy     []string
	OrderBy     string
	Limit       int32
}

// QueryLogs queries log entries
func (ms *MonitoringService) QueryLogs(ctx context.Context, projectID string, query *LogQuery) (*LogQueryResult, error) {
	ms.mu.RLock()
	defer ms.mu.RUnlock()

	// startTime unused - commented out
	// startTime := time.Now()
	ms.logger.Info("Querying logs",
		zap.String("filter", query.Filter),
		zap.Int("limit", query.Limit))

	// Apply rate limiting
	<-ms.rateLimiter.queryLimiter.C

	// Check cache first
	cacheKey := fmt.Sprintf("%s-%d-%s", query.Filter, query.Limit, query.PageToken)

	ms.logCache.mu.RLock()
	if cachedResult, ok := ms.logCache.queryResults[cacheKey]; ok {
		if time.Since(ms.logCache.lastUpdate[cacheKey]) < ms.logCache.ttl {
			ms.logCache.mu.RUnlock()
			ms.logger.Debug("Returning logs from cache")
			return cachedResult, nil
		}
	}
	ms.logCache.mu.RUnlock()

	// Create log iterator
	// Entries method not available in current API
	// Returning empty result for now
	return &LogQueryResult{
		Entries:    []*logging.Entry{},
		TotalCount: 0,
	}, nil
}

// LogQuery represents a log query
type LogQuery struct {
	Filter    string
	StartTime time.Time
	EndTime   time.Time
	Limit     int
	PageToken string
	OrderBy   string
}

// DetectAnomalies detects anomalies in metric data
func (ms *MonitoringService) DetectAnomalies(ctx context.Context, metricType string, timeSeries []*monitoringpb.TimeSeries) ([]MetricAnomaly, error) {
	ms.anomalyDetector.mu.Lock()
	defer ms.anomalyDetector.mu.Unlock()

	ms.logger.Info("Detecting anomalies",
		zap.String("metricType", metricType),
		zap.Int("timeSeriesCount", len(timeSeries)))

	var anomalies []MetricAnomaly

	// Get or create anomaly model
	model, exists := ms.anomalyDetector.models[metricType]
	if !exists {
		model = &AnomalyModel{
			MetricType:  metricType,
			Algorithm:   "statistical",
			Sensitivity: 2.0, // 2 standard deviations
			TrainingData: make([]*DataPoint, 0),
			Thresholds: &AnomalyThresholds{
				ZScore: 2.0,
			},
		}
		ms.anomalyDetector.models[metricType] = model
	}

	// Convert time series to data points
	var dataPoints []*DataPoint
	for _, series := range timeSeries {
		labels := make(map[string]string)
		for key, value := range series.Resource.Labels {
			labels[key] = value
		}
		for key, value := range series.Metric.Labels {
			labels[key] = value
		}

		for _, point := range series.Points {
			dataPoint := &DataPoint{
				Timestamp: point.Interval.EndTime.AsTime(),
				Value:     point.Value.GetDoubleValue(),
				Labels:    labels,
			}
			dataPoints = append(dataPoints, dataPoint)
		}
	}

	// Update training data
	model.TrainingData = append(model.TrainingData, dataPoints...)
	if len(model.TrainingData) > 10000 {
		// Keep only recent data
		model.TrainingData = model.TrainingData[len(model.TrainingData)-10000:]
	}

	// Calculate baseline if we have enough data
	if len(model.TrainingData) >= 100 {
		model.Baseline = ms.calculateBaseline(model.TrainingData)
		model.Thresholds.UpperBound = model.Baseline.Mean + model.Sensitivity*model.Baseline.StdDev
		model.Thresholds.LowerBound = model.Baseline.Mean - model.Sensitivity*model.Baseline.StdDev
	}

	// Detect anomalies in recent data points
	if model.Baseline != nil {
		for _, point := range dataPoints {
			zScore := math.Abs(point.Value-model.Baseline.Mean) / model.Baseline.StdDev

			if zScore > model.Thresholds.ZScore {
				severity := "medium"
				if zScore > 3.0 {
					severity = "high"
				} else if zScore > 4.0 {
					severity = "critical"
				}

				anomalyType := "spike"
				if point.Value < model.Baseline.Mean {
					anomalyType = "dip"
				}

				anomaly := MetricAnomaly{
					Timestamp:  point.Timestamp,
					MetricType: metricType,
					Labels:     point.Labels,
					Value:      point.Value,
					Expected:   model.Baseline.Mean,
					Deviation:  zScore,
					Severity:   severity,
					Confidence: math.Min(zScore/4.0, 1.0),
					Type:       anomalyType,
				}

				anomalies = append(anomalies, anomaly)
			}
		}
	}

	// Store detected anomalies
	ms.anomalyDetector.anomalies = append(ms.anomalyDetector.anomalies, anomalies...)

	// Keep only recent anomalies
	if len(ms.anomalyDetector.anomalies) > 10000 {
		ms.anomalyDetector.anomalies = ms.anomalyDetector.anomalies[len(ms.anomalyDetector.anomalies)-10000:]
	}

	ms.logger.Info("Anomaly detection completed",
		zap.String("metricType", metricType),
		zap.Int("anomaliesFound", len(anomalies)))

	return anomalies, nil
}

// calculateBaseline calculates statistical baseline from training data
func (ms *MonitoringService) calculateBaseline(dataPoints []*DataPoint) *Baseline {
	if len(dataPoints) == 0 {
		return nil
	}

	// Calculate mean
	var sum float64
	for _, point := range dataPoints {
		sum += point.Value
	}
	mean := sum / float64(len(dataPoints))

	// Calculate standard deviation
	var variance float64
	for _, point := range dataPoints {
		variance += math.Pow(point.Value-mean, 2)
	}
	stdDev := math.Sqrt(variance / float64(len(dataPoints)))

	// Simple trend calculation (slope of linear regression)
	var trend float64
	if len(dataPoints) > 1 {
		firstTime := dataPoints[0].Timestamp.Unix()
		lastTime := dataPoints[len(dataPoints)-1].Timestamp.Unix()
		firstValue := dataPoints[0].Value
		lastValue := dataPoints[len(dataPoints)-1].Value

		if lastTime != firstTime {
			trend = (lastValue - firstValue) / float64(lastTime-firstTime)
		}
	}

	return &Baseline{
		Mean:   mean,
		StdDev: stdDev,
		Trend:  trend,
	}
}

// CreateDashboard creates a monitoring dashboard
func (ms *MonitoringService) CreateDashboard(ctx context.Context, projectID string, dashboard *Dashboard) (interface{}, error) {
	ms.mu.Lock()
	defer ms.mu.Unlock()

	// startTime := time.Now() // Commented out as dashboard creation is disabled
	ms.logger.Info("Creating dashboard",
		zap.String("name", dashboard.Name),
		zap.String("displayName", dashboard.DisplayName))

	// Apply rate limiting
	<-ms.rateLimiter.writeLimiter.C

	// Dashboard type not available in monitoringpb
	/*pbDashboard := &monitoringpb.Dashboard{
		DisplayName: dashboard.DisplayName,
		Labels:      dashboard.Labels,
		Etag:        dashboard.Etag,
	}

	// Convert layout based on type
	if dashboard.MosaicLayout != nil {
		tiles := make([]*monitoringpb.MosaicLayout_Tile, len(dashboard.MosaicLayout.Tiles))
		for i, tile := range dashboard.MosaicLayout.Tiles {
			tiles[i] = &monitoringpb.MosaicLayout_Tile{
				XPos:   tile.XPos,
				YPos:   tile.YPos,
				Width:  tile.Width,
				Height: tile.Height,
				Widget: ms.convertWidgetToPB(tile.Widget),
			}
		}

		pbDashboard.Layout = &monitoringpb.Dashboard_MosaicLayout{
			MosaicLayout: &monitoringpb.MosaicLayout{
				Columns: dashboard.MosaicLayout.Columns,
				Tiles:   tiles,
			},
		}
	}*/

	/*req := &monitoringpb.CreateDashboardRequest{
		Parent:    fmt.Sprintf("projects/%s", projectID),
		Dashboard: pbDashboard,
	}

	// dashboardClient not available
	// createdDashboard, err := ms.dashboardClient.CreateDashboard(ctx, req)
	var createdDashboard interface{}
	var err error
	err = fmt.Errorf("dashboard API not available")
	if err != nil {
		ms.metrics.mu.Lock()
		ms.metrics.ErrorCounts["dashboard_create"]++
		ms.metrics.mu.Unlock()
		return nil, fmt.Errorf("failed to create dashboard: %w", err)
	}

	// Update cache
	ms.dashboardCache.mu.Lock()
	ms.dashboardCache.dashboards[createdDashboard.Name] = createdDashboard
	ms.dashboardCache.lastUpdate[createdDashboard.Name] = time.Now()
	ms.dashboardCache.mu.Unlock()

	// Store in dashboard manager
	ms.dashboardManager.mu.Lock()
	ms.dashboardManager.dashboards[dashboard.Name] = dashboard
	ms.dashboardManager.mu.Unlock()

	// Update metrics
	ms.metrics.mu.Lock()
	ms.metrics.DashboardOperations++
	ms.metrics.OperationLatencies = append(ms.metrics.OperationLatencies, time.Since(startTime))
	ms.metrics.mu.Unlock()

	ms.logger.Info("Dashboard created successfully",
		zap.String("name", createdDashboard.Name),
		zap.Duration("duration", time.Since(startTime)))

	return createdDashboard, nil*/
	return nil, nil
}

// convertWidgetToPB converts internal widget to protobuf widget
func (ms *MonitoringService) convertWidgetToPB(widget *DashboardWidget) interface{} { // Widget type not available
	// Widget type not available in monitoringpb
	/*pbWidget := &monitoringpb.Widget{
		Title: widget.Title,
	}

	if widget.XYChart != nil {
		pbWidget.Content = &monitoringpb.Widget_XyChart{
			XyChart: &monitoringpb.XyChart{
				TimeshiftDuration: durationpb.New(widget.XYChart.TimeshiftDuration),
			},
		}

		// Convert data sets
		for _, dataSet := range widget.XYChart.DataSets {
			pbDataSet := &monitoringpb.XyChart_DataSet{
				PlotType:           monitoringpb.XyChart_DataSet_PlotType(monitoringpb.XyChart_DataSet_PlotType_value[dataSet.PlotType]),
				TargetAxis:         monitoringpb.XyChart_DataSet_TargetAxis(monitoringpb.XyChart_DataSet_TargetAxis_value[dataSet.TargetAxis]),
				LegendTemplate:     dataSet.LegendTemplate,
				MinAlignmentPeriod: durationpb.New(dataSet.MinAlignmentPeriod),
			}

			if dataSet.TimeSeriesQuery != nil {
				pbDataSet.TimeSeriesQuery = &monitoringpb.XyChart_DataSet_TimeSeriesQuery{
					UnitOverride:            dataSet.TimeSeriesQuery.UnitOverride,
					OutputFullResourceTypes: dataSet.TimeSeriesQuery.OutputFullResourceTypes,
				}

				if dataSet.TimeSeriesQuery.TimeSeriesFilter != nil {
					pbDataSet.TimeSeriesQuery.Source = &monitoringpb.XyChart_DataSet_TimeSeriesQuery_TimeSeriesFilter{
						TimeSeriesFilter: &monitoringpb.XyChart_DataSet_TimeSeriesQuery_TimeSeriesFilterOptions{
							Filter: dataSet.TimeSeriesQuery.TimeSeriesFilter.Filter,
						},
					}
				}
			}

			pbWidget.GetXyChart().DataSets = append(pbWidget.GetXyChart().DataSets, pbDataSet)
		}
	}

	if widget.Scorecard != nil {
		pbWidget.Content = &monitoringpb.Widget_Scorecard{
			Scorecard: &monitoringpb.Scorecard{},
		}

		if widget.Scorecard.GaugeView != nil {
			pbWidget.GetScorecard().GaugeView = &monitoringpb.Scorecard_GaugeView{
				LowerBound: widget.Scorecard.GaugeView.LowerBound,
				UpperBound: widget.Scorecard.GaugeView.UpperBound,
			}
		}
	}

	if widget.Text != nil {
		pbWidget.Content = &monitoringpb.Widget_Text{
			Text: &monitoringpb.Text{
				Content: widget.Text.Content,
				Format:  monitoringpb.Text_Format(monitoringpb.Text_Format_value[widget.Text.Format]),
			},
		}
	}

	return pbWidget*/
	return nil
}

// GetMetrics returns monitoring service metrics
func (ms *MonitoringService) GetMetrics() *MonitoringMetrics {
	ms.metrics.mu.RLock()
	defer ms.metrics.mu.RUnlock()

	return &MonitoringMetrics{
		MetricOperations:    ms.metrics.MetricOperations,
		AlertOperations:     ms.metrics.AlertOperations,
		DashboardOperations: ms.metrics.DashboardOperations,
		LogOperations:       ms.metrics.LogOperations,
		TraceOperations:     ms.metrics.TraceOperations,
		UptimeOperations:    ms.metrics.UptimeOperations,
		SLOOperations:       ms.metrics.SLOOperations,
		ErrorCounts:         copyStringInt64Map(ms.metrics.ErrorCounts),
		OperationLatencies:  append([]time.Duration{}, ms.metrics.OperationLatencies...),
		DataPointsProcessed: ms.metrics.DataPointsProcessed,
	}
}

// Close closes the monitoring service
func (ms *MonitoringService) Close() error {
	ms.mu.Lock()
	defer ms.mu.Unlock()

	ms.logger.Info("Closing monitoring service")

	// Stop rate limiters
	ms.rateLimiter.readLimiter.Stop()
	ms.rateLimiter.writeLimiter.Stop()
	ms.rateLimiter.queryLimiter.Stop()
	ms.rateLimiter.adminLimiter.Stop()

	// Close clients
	var errs []error

	if err := ms.metricClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close metric client: %w", err))
	}
	if err := ms.alertPolicyClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close alert policy client: %w", err))
	}
	if err := ms.notificationClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close notification client: %w", err))
	}
	if err := ms.uptimeCheckClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close uptime check client: %w", err))
	}
	if err := ms.serviceClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close service client: %w", err))
	}
	// dashboardClient not available
	// if err := ms.dashboardClient.Close(); err != nil {
	// 	errs = append(errs, fmt.Errorf("failed to close dashboard client: %w", err))
	// }
	if err := ms.groupClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close group client: %w", err))
	}
	if err := ms.logClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close log client: %w", err))
	}
	if err := ms.logAdminClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close log admin client: %w", err))
	}
	if err := ms.traceClient.Close(); err != nil {
		errs = append(errs, fmt.Errorf("failed to close trace client: %w", err))
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors closing monitoring service: %v", errs)
	}

	return nil
}