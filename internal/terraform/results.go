package terraform

import (
	"regexp"
	"strconv"
	"strings"
	"time"
)

// PlanResult represents the result of a terraform plan operation
type PlanResult struct {
	Stdout           string
	Stderr           string
	HasChanges       bool
	ResourcesAdd     int
	ResourcesChange  int
	ResourcesDestroy int
	OutputChanges    map[string]OutputChange
	ResourceChanges  []ResourceChange
}

// OutputChange represents a change to an output value
type OutputChange struct {
	Name      string
	Before    interface{}
	After     interface{}
	Sensitive bool
	Action    string
}

// ResourceChange represents a change to a resource
type ResourceChange struct {
	Address       string
	Type          string
	Name          string
	Module        string
	Mode          string
	ProviderName  string
	Action        []string
	Before        map[string]interface{}
	After         map[string]interface{}
	ChangeSummary ChangeSummary
}

// ChangeSummary represents a summary of changes
type ChangeSummary struct {
	Create  int
	Update  int
	Delete  int
	Replace int
	NoOp    int
}

func (r *PlanResult) parsePlanOutput(output string) {
	// Parse resource changes count
	changeRegex := regexp.MustCompile(`Plan: (\d+) to add, (\d+) to change, (\d+) to destroy`)
	matches := changeRegex.FindStringSubmatch(output)
	if len(matches) > 3 {
		r.ResourcesAdd, _ = strconv.Atoi(matches[1])
		r.ResourcesChange, _ = strconv.Atoi(matches[2])
		r.ResourcesDestroy, _ = strconv.Atoi(matches[3])
		r.HasChanges = r.ResourcesAdd > 0 || r.ResourcesChange > 0 || r.ResourcesDestroy > 0
	}

	// Parse individual resource changes
	resourceRegex := regexp.MustCompile(`([#~+-]) (.+) will be (.+)`)
	resourceMatches := resourceRegex.FindAllStringSubmatch(output, -1)
	for _, match := range resourceMatches {
		if len(match) > 3 {
			change := ResourceChange{
				Address: match[2],
				Action:  []string{},
			}

			switch match[1] {
			case "+":
				change.Action = append(change.Action, "create")
			case "-":
				change.Action = append(change.Action, "delete")
			case "~":
				change.Action = append(change.Action, "update")
			case "#":
				change.Action = append(change.Action, "read")
			case "+-":
				change.Action = append(change.Action, "replace")
			}

			r.ResourceChanges = append(r.ResourceChanges, change)
		}
	}

	// Parse output changes
	r.OutputChanges = make(map[string]OutputChange)
	outputRegex := regexp.MustCompile(`(?m)^\s*([~+-])\s+output\s+"(.+)"`)
	outputMatches := outputRegex.FindAllStringSubmatch(output, -1)
	for _, match := range outputMatches {
		if len(match) > 2 {
			change := OutputChange{
				Name: match[2],
			}

			switch match[1] {
			case "+":
				change.Action = "create"
			case "-":
				change.Action = "delete"
			case "~":
				change.Action = "update"
			}

			r.OutputChanges[change.Name] = change
		}
	}
}

// ValidateResult represents the result of terraform validate
type ValidateResult struct {
	Valid        bool
	ErrorCount   int
	WarningCount int
	Diagnostics  []Diagnostic
}

// Diagnostic represents a validation diagnostic
type Diagnostic struct {
	Severity string
	Summary  string
	Detail   string
	Range    *DiagnosticRange
}

// DiagnosticRange represents the location of a diagnostic
type DiagnosticRange struct {
	Filename string
	Start    Position
	End      Position
}

// Position represents a position in a file
type Position struct {
	Line   int
	Column int
	Byte   int
}

// OutputValue represents a terraform output value
type OutputValue struct {
	Name       string
	Value      interface{}
	Type       string
	Sensitive  bool
	Raw        string
	AllOutputs map[string]*OutputValue
}

// ShowResult represents the result of terraform show
type ShowResult struct {
	Raw              string
	FormatVersion    string
	TerraformVersion string
	PlannedValues    map[string]interface{}
	ResourceChanges  []interface{}
	OutputChanges    map[string]interface{}
	PriorState       map[string]interface{}
	Configuration    map[string]interface{}
}

// StateResource represents a resource in the state
type StateResource struct {
	Address       string
	Type          string
	Name          string
	Provider      string
	Module        string
	Mode          string
	ID            string
	Attributes    map[string]interface{}
	Dependencies  []string
	Tainted       bool
	CreateBefore  bool
	Sensitive     bool
}

// WorkspaceResult represents the result of workspace operations
type WorkspaceResult struct {
	Current    string
	Workspaces []string
}

// FormatResult represents the result of terraform fmt
type FormatResult struct {
	ChangedFiles []string
	Success      bool
	Diff         string
}

// ProvidersResult represents the result of providers command
type ProvidersResult struct {
	Providers []ProviderInfo
	Schemas   map[string]ProviderSchema
}

// ProviderInfo represents information about a provider
type ProviderInfo struct {
	Name       string
	Namespace  string
	Source     string
	Version    string
	Alias      string
	Attributes map[string]interface{}
}

// ProviderSchema represents a provider's schema
type ProviderSchema struct {
	Provider          SchemaBlock
	ResourceSchemas   map[string]SchemaBlock
	DataSourceSchemas map[string]SchemaBlock
}

// SchemaBlock represents a schema block
type SchemaBlock struct {
	Version     int64
	Attributes  map[string]SchemaAttribute
	BlockTypes  map[string]SchemaBlockType
	Description string
}

// SchemaAttribute represents a schema attribute
type SchemaAttribute struct {
	Type        string
	Description string
	Required    bool
	Optional    bool
	Computed    bool
	Sensitive   bool
	Default     interface{}
}

// SchemaBlockType represents a schema block type
type SchemaBlockType struct {
	NestingMode string
	Block       SchemaBlock
	MinItems    int
	MaxItems    int
}

// TestResult represents the result of terraform test
type TestResult struct {
	Success  bool
	Tests    []TestCase
	Duration time.Duration
	Summary  TestSummary
}

// TestCase represents a single test case
type TestCase struct {
	Name     string
	Status   string
	Duration time.Duration
	Error    error
	Output   string
}

// TestSummary represents a summary of test results
type TestSummary struct {
	Total   int
	Passed  int
	Failed  int
	Skipped int
	Errored int
}

// ModuleInfo represents information about a Terraform module
type ModuleInfo struct {
	Path            string
	Source          string
	Version         string
	Dir             string
	Root            bool
	Variables       map[string]Variable
	Outputs         map[string]Output
	Resources       []Resource
	DataSources     []DataSource
	Providers       map[string]string
	RequiredVersion string
	Dependencies    []string
}

// Variable represents a Terraform variable
type Variable struct {
	Name        string
	Type        string
	Description string
	Default     interface{}
	Required    bool
	Sensitive   bool
	Validation  []Validation
}

// Validation represents variable validation
type Validation struct {
	Condition    string
	ErrorMessage string
}

// Output represents a Terraform output
type Output struct {
	Name        string
	Description string
	Value       interface{}
	Sensitive   bool
	DependsOn   []string
	Precondition []Condition
}

// Condition represents a condition block
type Condition struct {
	Condition    string
	ErrorMessage string
}

// Resource represents a Terraform resource
type Resource struct {
	Type         string
	Name         string
	Provider     string
	Count        interface{}
	ForEach      interface{}
	DependsOn    []string
	Lifecycle    Lifecycle
	Provisioners []Provisioner
	Attributes   map[string]interface{}
}

// DataSource represents a Terraform data source
type DataSource struct {
	Type       string
	Name       string
	Provider   string
	Count      interface{}
	ForEach    interface{}
	DependsOn  []string
	Attributes map[string]interface{}
}

// Lifecycle represents resource lifecycle configuration
type Lifecycle struct {
	CreateBeforeDestroy bool
	PreventDestroy      bool
	IgnoreChanges       []string
	ReplaceTriggeredBy  []string
	Precondition        []Condition
	Postcondition       []Condition
}

// Provisioner represents a resource provisioner
type Provisioner struct {
	Type        string
	Connection  Connection
	When        string
	OnFailure   string
	Attributes  map[string]interface{}
}

// Connection represents a provisioner connection
type Connection struct {
	Type        string
	User        string
	Password    string
	Host        string
	Port        int
	Timeout     string
	ScriptPath  string
	PrivateKey  string
	Certificate string
	Agent       bool
	AgentIdentity string
	HostKey     string
	Bastion     BastionConnection
}

// BastionConnection represents a bastion host connection
type BastionConnection struct {
	Host        string
	Port        int
	User        string
	Password    string
	PrivateKey  string
	Certificate string
	HostKey     string
}

// BackendState represents the backend state configuration
type BackendState struct {
	Type   string
	Config map[string]interface{}
	Hash   uint64
}

// LockInfo represents state lock information
type LockInfo struct {
	ID        string
	Operation string
	Who       string
	Version   string
	Created   time.Time
	Path      string
	Info      string
}

// ParsePlanSummary parses a plan output summary line
func ParsePlanSummary(line string) *ChangeSummary {
	summary := &ChangeSummary{}

	// Parse format: "Plan: X to add, Y to change, Z to destroy."
	addRegex := regexp.MustCompile(`(\d+) to add`)
	changeRegex := regexp.MustCompile(`(\d+) to change`)
	destroyRegex := regexp.MustCompile(`(\d+) to destroy`)
	replaceRegex := regexp.MustCompile(`(\d+) to replace`)

	if matches := addRegex.FindStringSubmatch(line); len(matches) > 1 {
		summary.Create, _ = strconv.Atoi(matches[1])
	}

	if matches := changeRegex.FindStringSubmatch(line); len(matches) > 1 {
		summary.Update, _ = strconv.Atoi(matches[1])
	}

	if matches := destroyRegex.FindStringSubmatch(line); len(matches) > 1 {
		summary.Delete, _ = strconv.Atoi(matches[1])
	}

	if matches := replaceRegex.FindStringSubmatch(line); len(matches) > 1 {
		summary.Replace, _ = strconv.Atoi(matches[1])
	}

	// Check for "No changes" or similar
	if strings.Contains(line, "No changes") || strings.Contains(line, "Infrastructure is up-to-date") {
		summary.NoOp = 1
	}

	return summary
}

// IsError checks if a test case has failed
func (tc *TestCase) IsError() bool {
	return tc.Status == "error" || tc.Status == "failed" || tc.Error != nil
}

// IsPassed checks if a test case has passed
func (tc *TestCase) IsPassed() bool {
	return tc.Status == "passed" || tc.Status == "success"
}

// IsSkipped checks if a test case was skipped
func (tc *TestCase) IsSkipped() bool {
	return tc.Status == "skipped" || tc.Status == "skip"
}

// HasErrors checks if validation has errors
func (vr *ValidateResult) HasErrors() bool {
	return !vr.Valid || vr.ErrorCount > 0
}

// HasWarnings checks if validation has warnings
func (vr *ValidateResult) HasWarnings() bool {
	return vr.WarningCount > 0
}

// GetErrors returns only error diagnostics
func (vr *ValidateResult) GetErrors() []Diagnostic {
	var errors []Diagnostic
	for _, diag := range vr.Diagnostics {
		if diag.Severity == "error" {
			errors = append(errors, diag)
		}
	}
	return errors
}

// GetWarnings returns only warning diagnostics
func (vr *ValidateResult) GetWarnings() []Diagnostic {
	var warnings []Diagnostic
	for _, diag := range vr.Diagnostics {
		if diag.Severity == "warning" {
			warnings = append(warnings, diag)
		}
	}
	return warnings
}

// IsCreate checks if resource change is a create action
func (rc *ResourceChange) IsCreate() bool {
	for _, action := range rc.Action {
		if action == "create" {
			return true
		}
	}
	return false
}

// IsUpdate checks if resource change is an update action
func (rc *ResourceChange) IsUpdate() bool {
	for _, action := range rc.Action {
		if action == "update" {
			return true
		}
	}
	return false
}

// IsDelete checks if resource change is a delete action
func (rc *ResourceChange) IsDelete() bool {
	for _, action := range rc.Action {
		if action == "delete" {
			return true
		}
	}
	return false
}

// IsReplace checks if resource change is a replace action
func (rc *ResourceChange) IsReplace() bool {
	for _, action := range rc.Action {
		if action == "replace" {
			return true
		}
	}
	return false
}

// IsNoOp checks if resource change is a no-op
func (rc *ResourceChange) IsNoOp() bool {
	return len(rc.Action) == 0 || (len(rc.Action) == 1 && rc.Action[0] == "no-op")
}