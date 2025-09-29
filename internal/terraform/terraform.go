package terraform

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/hashicorp/go-version"
	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclparse"
	"github.com/zclconf/go-cty/cty"
	"github.com/hashicorp/hcl/v2/hclwrite"
	"github.com/hashicorp/terraform-config-inspect/tfconfig"
)

type Executor struct {
	mu sync.RWMutex

	workingDir      string
	terraformPath   string
	version         *version.Version
	env             map[string]string
	stdout          io.Writer
	stderr          io.Writer
	stdin           io.Reader
	logger          Logger
	dryRun          bool
	autoApprove     bool
	parallelism     int
	lockTimeout     time.Duration
	pluginCacheDir  string
	stateLockFile   string
	backendConfig   map[string]string
	varFiles        []string
	vars            map[string]string
	targets         []string
	replaceResources []string
	refreshOnly     bool
	upgradeMode     bool
	reconfigure     bool
	migrateState    bool
	color           bool
	input           bool
	compact         bool
	detailedExitCode bool
	jsonOutput      bool
	planFile        string
	stateFile       string
	backupFile      string
	outFile         string
	hooks           []Hook
	retryConfig     RetryConfig
	cache           *StateCache
}

type Hook struct {
	Name      string
	Type      HookType
	Command   string
	Args      []string
	Env       map[string]string
	WorkDir   string
	OnFailure HookFailureAction
}

type HookType string

const (
	HookTypeBefore HookType = "before"
	HookTypeAfter  HookType = "after"
	HookTypeError  HookType = "error"
)

type HookFailureAction string

const (
	HookFailureContinue HookFailureAction = "continue"
	HookFailureAbort    HookFailureAction = "abort"
	HookFailureRetry    HookFailureAction = "retry"
)

type RetryConfig struct {
	Enabled        bool
	MaxAttempts    int
	InitialBackoff time.Duration
	MaxBackoff     time.Duration
	BackoffFactor  float64
	RetryableErrors []string
}

type Logger interface {
	Debug(msg string, fields ...interface{})
	Info(msg string, fields ...interface{})
	Warn(msg string, fields ...interface{})
	Error(msg string, fields ...interface{})
}

type ExecutorOption func(*Executor)

func NewExecutor(workingDir string, opts ...ExecutorOption) (*Executor, error) {
	e := &Executor{
		workingDir:     workingDir,
		terraformPath:  "terraform",
		env:            make(map[string]string),
		stdout:         os.Stdout,
		stderr:         os.Stderr,
		stdin:          os.Stdin,
		parallelism:    10,
		lockTimeout:    0,
		color:          true,
		input:          false,
		vars:           make(map[string]string),
		backendConfig:  make(map[string]string),
		retryConfig: RetryConfig{
			Enabled:         true,
			MaxAttempts:     3,
			InitialBackoff:  1 * time.Second,
			MaxBackoff:      30 * time.Second,
			BackoffFactor:   2.0,
			RetryableErrors: []string{
				"Error acquiring the state lock",
				"Error locking state",
				"resource temporarily unavailable",
				"timeout while waiting for state lock",
			},
		},
	}

	for _, opt := range opts {
		opt(e)
	}

	if err := e.detectVersion(); err != nil {
		return nil, err
	}

	if e.cache == nil {
		e.cache = NewStateCache()
	}

	return e, nil
}

func WithTerraformPath(path string) ExecutorOption {
	return func(e *Executor) {
		e.terraformPath = path
	}
}

func WithEnv(env map[string]string) ExecutorOption {
	return func(e *Executor) {
		for k, v := range env {
			e.env[k] = v
		}
	}
}

func WithLogger(logger Logger) ExecutorOption {
	return func(e *Executor) {
		e.logger = logger
	}
}

func WithDryRun(dryRun bool) ExecutorOption {
	return func(e *Executor) {
		e.dryRun = dryRun
	}
}

func WithAutoApprove(autoApprove bool) ExecutorOption {
	return func(e *Executor) {
		e.autoApprove = autoApprove
	}
}

func WithParallelism(parallelism int) ExecutorOption {
	return func(e *Executor) {
		e.parallelism = parallelism
	}
}

func WithVarFiles(files ...string) ExecutorOption {
	return func(e *Executor) {
		e.varFiles = append(e.varFiles, files...)
	}
}

func WithVars(vars map[string]string) ExecutorOption {
	return func(e *Executor) {
		for k, v := range vars {
			e.vars[k] = v
		}
	}
}

func WithTargets(targets ...string) ExecutorOption {
	return func(e *Executor) {
		e.targets = append(e.targets, targets...)
	}
}

func WithBackendConfig(config map[string]string) ExecutorOption {
	return func(e *Executor) {
		for k, v := range config {
			e.backendConfig[k] = v
		}
	}
}

func WithHooks(hooks ...Hook) ExecutorOption {
	return func(e *Executor) {
		e.hooks = append(e.hooks, hooks...)
	}
}

func WithRetryConfig(config RetryConfig) ExecutorOption {
	return func(e *Executor) {
		e.retryConfig = config
	}
}

func WithStateCache(cache *StateCache) ExecutorOption {
	return func(e *Executor) {
		e.cache = cache
	}
}

func (e *Executor) detectVersion() error {
	cmd := exec.Command(e.terraformPath, "version", "-json")
	output, err := cmd.Output()
	if err != nil {
		// Try non-JSON version
		cmd = exec.Command(e.terraformPath, "version")
		output, err = cmd.Output()
		if err != nil {
			return fmt.Errorf("failed to detect terraform version: %w", err)
		}

		// Parse text output
		versionRegex := regexp.MustCompile(`Terraform v(\d+\.\d+\.\d+)`)
		matches := versionRegex.FindSubmatch(output)
		if len(matches) < 2 {
			return fmt.Errorf("could not parse terraform version from output")
		}

		e.version, err = version.NewVersion(string(matches[1]))
		if err != nil {
			return fmt.Errorf("invalid terraform version: %w", err)
		}
	} else {
		// Parse JSON output
		var versionInfo struct {
			Version string `json:"terraform_version"`
		}
		if err := json.Unmarshal(output, &versionInfo); err != nil {
			return fmt.Errorf("failed to parse version JSON: %w", err)
		}

		e.version, err = version.NewVersion(versionInfo.Version)
		if err != nil {
			return fmt.Errorf("invalid terraform version: %w", err)
		}
	}

	e.logInfo("Detected Terraform version: %s", e.version)
	return nil
}

func (e *Executor) Init(ctx context.Context, opts ...InitOption) error {
	initOpts := &InitOptions{
		Backend:        true,
		BackendConfig:  e.backendConfig,
		FromModule:     "",
		GetPlugins:     true,
		LockFile:       "",
		LockTimeout:    e.lockTimeout,
		PluginDir:      e.pluginCacheDir,
		Reconfigure:    e.reconfigure,
		MigrateState:   e.migrateState,
		Upgrade:        e.upgradeMode,
		VerifyPlugins:  true,
	}

	for _, opt := range opts {
		opt(initOpts)
	}

	args := []string{"init"}

	if !initOpts.Backend {
		args = append(args, "-backend=false")
	}

	for key, value := range initOpts.BackendConfig {
		args = append(args, fmt.Sprintf("-backend-config=%s=%s", key, value))
	}

	if initOpts.FromModule != "" {
		args = append(args, fmt.Sprintf("-from-module=%s", initOpts.FromModule))
	}

	if !initOpts.GetPlugins {
		args = append(args, "-get-plugins=false")
	}

	if initOpts.LockFile != "" {
		args = append(args, fmt.Sprintf("-lockfile=%s", initOpts.LockFile))
	}

	if initOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", initOpts.LockTimeout))
	}

	if initOpts.PluginDir != "" {
		args = append(args, fmt.Sprintf("-plugin-dir=%s", initOpts.PluginDir))
	}

	if initOpts.Reconfigure {
		args = append(args, "-reconfigure")
	}

	if initOpts.MigrateState {
		args = append(args, "-migrate-state")
	}

	if initOpts.Upgrade {
		args = append(args, "-upgrade")
	}

	if !initOpts.VerifyPlugins {
		args = append(args, "-verify-plugins=false")
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) Plan(ctx context.Context, opts ...PlanOption) (*PlanResult, error) {
	planOpts := &PlanOptions{
		Destroy:          false,
		DetailedExitCode: true,
		Lock:             true,
		LockTimeout:      e.lockTimeout,
		Out:              e.planFile,
		Parallelism:      e.parallelism,
		Refresh:          true,
		RefreshOnly:      e.refreshOnly,
		Replace:          e.replaceResources,
		State:            e.stateFile,
		Targets:          e.targets,
		VarFiles:         e.varFiles,
		Vars:             e.vars,
		CompactWarnings:  e.compact,
		JSON:             e.jsonOutput,
	}

	for _, opt := range opts {
		opt(planOpts)
	}

	args := []string{"plan"}

	if planOpts.Destroy {
		args = append(args, "-destroy")
	}

	if planOpts.DetailedExitCode {
		args = append(args, "-detailed-exitcode")
	}

	if !planOpts.Lock {
		args = append(args, "-lock=false")
	}

	if planOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", planOpts.LockTimeout))
	}

	if planOpts.Out != "" {
		args = append(args, fmt.Sprintf("-out=%s", planOpts.Out))
	}

	if planOpts.Parallelism > 0 {
		args = append(args, fmt.Sprintf("-parallelism=%d", planOpts.Parallelism))
	}

	if !planOpts.Refresh {
		args = append(args, "-refresh=false")
	}

	if planOpts.RefreshOnly {
		args = append(args, "-refresh-only")
	}

	for _, resource := range planOpts.Replace {
		args = append(args, fmt.Sprintf("-replace=%s", resource))
	}

	if planOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", planOpts.State))
	}

	for _, target := range planOpts.Targets {
		args = append(args, fmt.Sprintf("-target=%s", target))
	}

	for _, varFile := range planOpts.VarFiles {
		args = append(args, fmt.Sprintf("-var-file=%s", varFile))
	}

	for key, value := range planOpts.Vars {
		args = append(args, fmt.Sprintf("-var=%s=%s", key, value))
	}

	if planOpts.CompactWarnings {
		args = append(args, "-compact-warnings")
	}

	if planOpts.JSON {
		args = append(args, "-json")
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = io.MultiWriter(&stdout, e.stdout)
	cmd.Stderr = io.MultiWriter(&stderr, e.stderr)

	err := e.runCommandWithHooks(ctx, cmd, HookTypeBefore, HookTypeAfter, HookTypeError)

	result := &PlanResult{
		Stdout:       stdout.String(),
		Stderr:       stderr.String(),
		HasChanges:   false,
		ResourcesAdd: 0,
		ResourcesChange: 0,
		ResourcesDestroy: 0,
	}

	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && planOpts.DetailedExitCode {
			// Exit code 2 means there are changes
			if exitErr.ExitCode() == 2 {
				result.HasChanges = true
				err = nil
			}
		}
	}

	// Parse plan output
	if err == nil {
		result.parsePlanOutput(stdout.String())
	}

	return result, err
}

func (e *Executor) Apply(ctx context.Context, opts ...ApplyOption) error {
	applyOpts := &ApplyOptions{
		AutoApprove:      e.autoApprove,
		Backup:           e.backupFile,
		CompactWarnings:  e.compact,
		Lock:             true,
		LockTimeout:      e.lockTimeout,
		Parallelism:      e.parallelism,
		PlanFile:         e.planFile,
		Refresh:          true,
		RefreshOnly:      e.refreshOnly,
		Replace:          e.replaceResources,
		State:            e.stateFile,
		StateOut:         "",
		Targets:          e.targets,
		VarFiles:         e.varFiles,
		Vars:             e.vars,
		JSON:             e.jsonOutput,
	}

	for _, opt := range opts {
		opt(applyOpts)
	}

	args := []string{"apply"}

	if applyOpts.AutoApprove {
		args = append(args, "-auto-approve")
	}

	if applyOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", applyOpts.Backup))
	}

	if applyOpts.CompactWarnings {
		args = append(args, "-compact-warnings")
	}

	if !applyOpts.Lock {
		args = append(args, "-lock=false")
	}

	if applyOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", applyOpts.LockTimeout))
	}

	if applyOpts.Parallelism > 0 {
		args = append(args, fmt.Sprintf("-parallelism=%d", applyOpts.Parallelism))
	}

	if !applyOpts.Refresh {
		args = append(args, "-refresh=false")
	}

	if applyOpts.RefreshOnly {
		args = append(args, "-refresh-only")
	}

	for _, resource := range applyOpts.Replace {
		args = append(args, fmt.Sprintf("-replace=%s", resource))
	}

	if applyOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", applyOpts.State))
	}

	if applyOpts.StateOut != "" {
		args = append(args, fmt.Sprintf("-state-out=%s", applyOpts.StateOut))
	}

	for _, target := range applyOpts.Targets {
		args = append(args, fmt.Sprintf("-target=%s", target))
	}

	if applyOpts.PlanFile != "" {
		// If using a plan file, var options are not needed
		args = append(args, applyOpts.PlanFile)
	} else {
		for _, varFile := range applyOpts.VarFiles {
			args = append(args, fmt.Sprintf("-var-file=%s", varFile))
		}

		for key, value := range applyOpts.Vars {
			args = append(args, fmt.Sprintf("-var=%s=%s", key, value))
		}
	}

	if applyOpts.JSON {
		args = append(args, "-json")
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) Destroy(ctx context.Context, opts ...DestroyOption) error {
	destroyOpts := &DestroyOptions{
		AutoApprove:     e.autoApprove,
		Backup:          e.backupFile,
		CompactWarnings: e.compact,
		Lock:            true,
		LockTimeout:     e.lockTimeout,
		Parallelism:     e.parallelism,
		Refresh:         true,
		State:           e.stateFile,
		StateOut:        "",
		Targets:         e.targets,
		VarFiles:        e.varFiles,
		Vars:            e.vars,
		JSON:            e.jsonOutput,
	}

	for _, opt := range opts {
		opt(destroyOpts)
	}

	args := []string{"destroy"}

	if destroyOpts.AutoApprove {
		args = append(args, "-auto-approve")
	}

	if destroyOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", destroyOpts.Backup))
	}

	if destroyOpts.CompactWarnings {
		args = append(args, "-compact-warnings")
	}

	if !destroyOpts.Lock {
		args = append(args, "-lock=false")
	}

	if destroyOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", destroyOpts.LockTimeout))
	}

	if destroyOpts.Parallelism > 0 {
		args = append(args, fmt.Sprintf("-parallelism=%d", destroyOpts.Parallelism))
	}

	if !destroyOpts.Refresh {
		args = append(args, "-refresh=false")
	}

	if destroyOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", destroyOpts.State))
	}

	if destroyOpts.StateOut != "" {
		args = append(args, fmt.Sprintf("-state-out=%s", destroyOpts.StateOut))
	}

	for _, target := range destroyOpts.Targets {
		args = append(args, fmt.Sprintf("-target=%s", target))
	}

	for _, varFile := range destroyOpts.VarFiles {
		args = append(args, fmt.Sprintf("-var-file=%s", varFile))
	}

	for key, value := range destroyOpts.Vars {
		args = append(args, fmt.Sprintf("-var=%s=%s", key, value))
	}

	if destroyOpts.JSON {
		args = append(args, "-json")
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) Refresh(ctx context.Context, opts ...RefreshOption) error {
	refreshOpts := &RefreshOptions{
		Backup:          e.backupFile,
		CompactWarnings: e.compact,
		Lock:            true,
		LockTimeout:     e.lockTimeout,
		State:           e.stateFile,
		StateOut:        "",
		Targets:         e.targets,
		VarFiles:        e.varFiles,
		Vars:            e.vars,
		JSON:            e.jsonOutput,
	}

	for _, opt := range opts {
		opt(refreshOpts)
	}

	args := []string{"refresh"}

	if refreshOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", refreshOpts.Backup))
	}

	if refreshOpts.CompactWarnings {
		args = append(args, "-compact-warnings")
	}

	if !refreshOpts.Lock {
		args = append(args, "-lock=false")
	}

	if refreshOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", refreshOpts.LockTimeout))
	}

	if refreshOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", refreshOpts.State))
	}

	if refreshOpts.StateOut != "" {
		args = append(args, fmt.Sprintf("-state-out=%s", refreshOpts.StateOut))
	}

	for _, target := range refreshOpts.Targets {
		args = append(args, fmt.Sprintf("-target=%s", target))
	}

	for _, varFile := range refreshOpts.VarFiles {
		args = append(args, fmt.Sprintf("-var-file=%s", varFile))
	}

	for key, value := range refreshOpts.Vars {
		args = append(args, fmt.Sprintf("-var=%s=%s", key, value))
	}

	if refreshOpts.JSON {
		args = append(args, "-json")
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) Validate(ctx context.Context, opts ...ValidateOption) (*ValidateResult, error) {
	validateOpts := &ValidateOptions{
		JSON:       e.jsonOutput,
		NoColor:    !e.color,
		TestDir:    "",
	}

	for _, opt := range opts {
		opt(validateOpts)
	}

	args := []string{"validate"}

	if validateOpts.JSON {
		args = append(args, "-json")
	}

	if validateOpts.NoColor {
		args = append(args, "-no-color")
	}

	if validateOpts.TestDir != "" {
		args = append(args, fmt.Sprintf("-test-directory=%s", validateOpts.TestDir))
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := e.runCommandWithHooks(ctx, cmd, HookTypeBefore, HookTypeAfter, HookTypeError)

	result := &ValidateResult{
		Valid:        err == nil,
		ErrorCount:   0,
		WarningCount: 0,
		Diagnostics:  []Diagnostic{},
	}

	if validateOpts.JSON && stdout.Len() > 0 {
		var jsonResult struct {
			Valid        bool `json:"valid"`
			ErrorCount   int  `json:"error_count"`
			WarningCount int  `json:"warning_count"`
			Diagnostics  []struct {
				Severity string `json:"severity"`
				Summary  string `json:"summary"`
				Detail   string `json:"detail"`
			} `json:"diagnostics"`
		}

		if err := json.Unmarshal(stdout.Bytes(), &jsonResult); err == nil {
			result.Valid = jsonResult.Valid
			result.ErrorCount = jsonResult.ErrorCount
			result.WarningCount = jsonResult.WarningCount

			for _, diag := range jsonResult.Diagnostics {
				result.Diagnostics = append(result.Diagnostics, Diagnostic{
					Severity: diag.Severity,
					Summary:  diag.Summary,
					Detail:   diag.Detail,
				})
			}
		}
	}

	return result, err
}

func (e *Executor) Output(ctx context.Context, name string, opts ...OutputOption) (*OutputValue, error) {
	outputOpts := &OutputOptions{
		JSON:  e.jsonOutput,
		Raw:   false,
		State: e.stateFile,
	}

	for _, opt := range opts {
		opt(outputOpts)
	}

	args := []string{"output"}

	if outputOpts.JSON {
		args = append(args, "-json")
	}

	if outputOpts.Raw {
		args = append(args, "-raw")
	}

	if outputOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", outputOpts.State))
	}

	if name != "" {
		args = append(args, name)
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	result := &OutputValue{
		Name: name,
		Raw:  stdout.String(),
	}

	if outputOpts.JSON {
		if name != "" {
			// Single output
			var jsonOutput struct {
				Sensitive bool        `json:"sensitive"`
				Type      interface{} `json:"type"`
				Value     interface{} `json:"value"`
			}
			if err := json.Unmarshal(stdout.Bytes(), &jsonOutput); err == nil {
				result.Sensitive = jsonOutput.Sensitive
				result.Type = fmt.Sprintf("%v", jsonOutput.Type)
				result.Value = jsonOutput.Value
			}
		} else {
			// All outputs
			var outputs map[string]struct {
				Sensitive bool        `json:"sensitive"`
				Type      interface{} `json:"type"`
				Value     interface{} `json:"value"`
			}
			if err := json.Unmarshal(stdout.Bytes(), &outputs); err == nil {
				result.AllOutputs = make(map[string]*OutputValue)
				for k, v := range outputs {
					result.AllOutputs[k] = &OutputValue{
						Name:      k,
						Sensitive: v.Sensitive,
						Type:      fmt.Sprintf("%v", v.Type),
						Value:     v.Value,
					}
				}
			}
		}
	} else {
		// Parse raw text output
		result.Value = strings.TrimSpace(stdout.String())
	}

	return result, nil
}

func (e *Executor) Show(ctx context.Context, opts ...ShowOption) (*ShowResult, error) {
	showOpts := &ShowOptions{
		JSON:     e.jsonOutput,
		NoColor:  !e.color,
		PlanFile: e.planFile,
		State:    e.stateFile,
	}

	for _, opt := range opts {
		opt(showOpts)
	}

	args := []string{"show"}

	if showOpts.JSON {
		args = append(args, "-json")
	}

	if showOpts.NoColor {
		args = append(args, "-no-color")
	}

	if showOpts.PlanFile != "" {
		args = append(args, showOpts.PlanFile)
	} else if showOpts.State != "" {
		args = append(args, showOpts.State)
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	result := &ShowResult{
		Raw: stdout.String(),
	}

	if showOpts.JSON {
		var jsonShow struct {
			FormatVersion    string                 `json:"format_version"`
			TerraformVersion string                 `json:"terraform_version"`
			PlannedValues    map[string]interface{} `json:"planned_values"`
			ResourceChanges  []interface{}          `json:"resource_changes"`
			OutputChanges    map[string]interface{} `json:"output_changes"`
			PriorState       map[string]interface{} `json:"prior_state"`
			Configuration    map[string]interface{} `json:"configuration"`
		}

		if err := json.Unmarshal(stdout.Bytes(), &jsonShow); err == nil {
			result.FormatVersion = jsonShow.FormatVersion
			result.TerraformVersion = jsonShow.TerraformVersion
			result.PlannedValues = jsonShow.PlannedValues
			result.ResourceChanges = jsonShow.ResourceChanges
			result.OutputChanges = jsonShow.OutputChanges
			result.PriorState = jsonShow.PriorState
			result.Configuration = jsonShow.Configuration
		}
	}

	return result, nil
}

func (e *Executor) Import(ctx context.Context, address, id string, opts ...ImportOption) error {
	importOpts := &ImportOptions{
		Backup:           e.backupFile,
		Config:           "",
		Lock:             true,
		LockTimeout:      e.lockTimeout,
		NoColor:          !e.color,
		Parallelism:      e.parallelism,
		Provider:         "",
		State:            e.stateFile,
		StateOut:         "",
		VarFiles:         e.varFiles,
		Vars:             e.vars,
		AllowMissingConfig: false,
	}

	for _, opt := range opts {
		opt(importOpts)
	}

	args := []string{"import"}

	if importOpts.AllowMissingConfig {
		args = append(args, "-allow-missing-config")
	}

	if importOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", importOpts.Backup))
	}

	if importOpts.Config != "" {
		args = append(args, fmt.Sprintf("-config=%s", importOpts.Config))
	}

	if !importOpts.Lock {
		args = append(args, "-lock=false")
	}

	if importOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", importOpts.LockTimeout))
	}

	if importOpts.NoColor {
		args = append(args, "-no-color")
	}

	if importOpts.Parallelism > 0 {
		args = append(args, fmt.Sprintf("-parallelism=%d", importOpts.Parallelism))
	}

	if importOpts.Provider != "" {
		args = append(args, fmt.Sprintf("-provider=%s", importOpts.Provider))
	}

	if importOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", importOpts.State))
	}

	if importOpts.StateOut != "" {
		args = append(args, fmt.Sprintf("-state-out=%s", importOpts.StateOut))
	}

	for _, varFile := range importOpts.VarFiles {
		args = append(args, fmt.Sprintf("-var-file=%s", varFile))
	}

	for key, value := range importOpts.Vars {
		args = append(args, fmt.Sprintf("-var=%s=%s", key, value))
	}

	if !e.input {
		args = append(args, "-input=false")
	}

	args = append(args, address, id)

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) StateList(ctx context.Context, addresses []string, opts ...StateListOption) ([]string, error) {
	stateOpts := &StateListOptions{
		State: e.stateFile,
		ID:    "",
	}

	for _, opt := range opts {
		opt(stateOpts)
	}

	args := []string{"state", "list"}

	if stateOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", stateOpts.State))
	}

	if stateOpts.ID != "" {
		args = append(args, fmt.Sprintf("-id=%s", stateOpts.ID))
	}

	args = append(args, addresses...)

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	var resources []string
	scanner := bufio.NewScanner(&stdout)
	for scanner.Scan() {
		resource := strings.TrimSpace(scanner.Text())
		if resource != "" {
			resources = append(resources, resource)
		}
	}

	return resources, nil
}

func (e *Executor) StateShow(ctx context.Context, address string, opts ...StateShowOption) (*StateResource, error) {
	stateOpts := &StateShowOptions{
		State: e.stateFile,
	}

	for _, opt := range opts {
		opt(stateOpts)
	}

	args := []string{"state", "show"}

	if stateOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", stateOpts.State))
	}

	args = append(args, address)

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	// Parse state show output
	resource := &StateResource{
		Address:    address,
		Type:       "",
		Name:       "",
		Provider:   "",
		Attributes: make(map[string]interface{}),
	}

	scanner := bufio.NewScanner(&stdout)
	for scanner.Scan() {
		line := scanner.Text()

		// Parse resource header
		if strings.HasPrefix(line, "# ") {
			parts := strings.Fields(line[2:])
			if len(parts) > 0 {
				resource.Address = parts[0]
			}
			continue
		}

		// Parse resource type
		if strings.HasPrefix(line, "resource \"") {
			typeRegex := regexp.MustCompile(`resource "([^"]+)" "([^"]+)"`)
			matches := typeRegex.FindStringSubmatch(line)
			if len(matches) > 2 {
				resource.Type = matches[1]
				resource.Name = matches[2]
			}
			continue
		}

		// Parse provider
		if strings.HasPrefix(line, "provider = ") {
			resource.Provider = strings.TrimPrefix(line, "provider = ")
			continue
		}

		// Parse attributes
		if strings.Contains(line, " = ") {
			parts := strings.SplitN(line, " = ", 2)
			if len(parts) == 2 {
				key := strings.TrimSpace(parts[0])
				value := strings.Trim(strings.TrimSpace(parts[1]), "\"")
				resource.Attributes[key] = value
			}
		}
	}

	return resource, nil
}

func (e *Executor) StateMv(ctx context.Context, source, destination string, opts ...StateMvOption) error {
	stateOpts := &StateMvOptions{
		Backup:       e.backupFile,
		BackupOut:    "",
		DryRun:       e.dryRun,
		Lock:         true,
		LockTimeout:  e.lockTimeout,
		State:        e.stateFile,
		StateOut:     "",
		IgnoreRemoteVersion: false,
	}

	for _, opt := range opts {
		opt(stateOpts)
	}

	args := []string{"state", "mv"}

	if stateOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", stateOpts.Backup))
	}

	if stateOpts.BackupOut != "" {
		args = append(args, fmt.Sprintf("-backup-out=%s", stateOpts.BackupOut))
	}

	if stateOpts.DryRun {
		args = append(args, "-dry-run")
	}

	if !stateOpts.Lock {
		args = append(args, "-lock=false")
	}

	if stateOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", stateOpts.LockTimeout))
	}

	if stateOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", stateOpts.State))
	}

	if stateOpts.StateOut != "" {
		args = append(args, fmt.Sprintf("-state-out=%s", stateOpts.StateOut))
	}

	if stateOpts.IgnoreRemoteVersion {
		args = append(args, "-ignore-remote-version")
	}

	args = append(args, source, destination)

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) StateRm(ctx context.Context, addresses []string, opts ...StateRmOption) error {
	stateOpts := &StateRmOptions{
		Backup:       e.backupFile,
		DryRun:       e.dryRun,
		Lock:         true,
		LockTimeout:  e.lockTimeout,
		State:        e.stateFile,
		IgnoreRemoteVersion: false,
	}

	for _, opt := range opts {
		opt(stateOpts)
	}

	args := []string{"state", "rm"}

	if stateOpts.Backup != "" {
		args = append(args, fmt.Sprintf("-backup=%s", stateOpts.Backup))
	}

	if stateOpts.DryRun {
		args = append(args, "-dry-run")
	}

	if !stateOpts.Lock {
		args = append(args, "-lock=false")
	}

	if stateOpts.LockTimeout > 0 {
		args = append(args, fmt.Sprintf("-lock-timeout=%s", stateOpts.LockTimeout))
	}

	if stateOpts.State != "" {
		args = append(args, fmt.Sprintf("-state=%s", stateOpts.State))
	}

	if stateOpts.IgnoreRemoteVersion {
		args = append(args, "-ignore-remote-version")
	}

	args = append(args, addresses...)

	return e.runWithRetry(ctx, args...)
}

func (e *Executor) Workspace(ctx context.Context, subcommand string, name string, opts ...WorkspaceOption) (*WorkspaceResult, error) {
	wsOpts := &WorkspaceOptions{
		Lock:        true,
		LockTimeout: e.lockTimeout,
		State:       e.stateFile,
		StatePath:   "",
	}

	for _, opt := range opts {
		opt(wsOpts)
	}

	args := []string{"workspace", subcommand}

	switch subcommand {
	case "list", "show":
		// These commands don't take additional arguments
	case "new", "select", "delete":
		if !wsOpts.Lock {
			args = append(args, "-lock=false")
		}

		if wsOpts.LockTimeout > 0 {
			args = append(args, fmt.Sprintf("-lock-timeout=%s", wsOpts.LockTimeout))
		}

		if wsOpts.State != "" && subcommand == "new" {
			args = append(args, fmt.Sprintf("-state=%s", wsOpts.State))
		}

		if wsOpts.StatePath != "" && subcommand == "new" {
			args = append(args, fmt.Sprintf("-state-path=%s", wsOpts.StatePath))
		}

		if subcommand == "delete" {
			args = append(args, "-force")
		}

		args = append(args, name)
	default:
		return nil, fmt.Errorf("unsupported workspace subcommand: %s", subcommand)
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	result := &WorkspaceResult{
		Current:    "",
		Workspaces: []string{},
	}

	if subcommand == "list" {
		scanner := bufio.NewScanner(&stdout)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "* ") {
				result.Current = strings.TrimSpace(line[2:])
				result.Workspaces = append(result.Workspaces, result.Current)
			} else {
				workspace := strings.TrimSpace(line)
				if workspace != "" {
					result.Workspaces = append(result.Workspaces, workspace)
				}
			}
		}
	} else if subcommand == "show" {
		result.Current = strings.TrimSpace(stdout.String())
	}

	return result, err
}

func (e *Executor) Format(ctx context.Context, paths []string, opts ...FormatOption) (*FormatResult, error) {
	fmtOpts := &FormatOptions{
		List:      true,
		Write:     false,
		Diff:      false,
		Check:     false,
		NoColor:   !e.color,
		Recursive: true,
	}

	for _, opt := range opts {
		opt(fmtOpts)
	}

	args := []string{"fmt"}

	if fmtOpts.List {
		args = append(args, "-list=true")
	} else {
		args = append(args, "-list=false")
	}

	if fmtOpts.Write {
		args = append(args, "-write=true")
	} else {
		args = append(args, "-write=false")
	}

	if fmtOpts.Diff {
		args = append(args, "-diff")
	}

	if fmtOpts.Check {
		args = append(args, "-check")
	}

	if fmtOpts.NoColor {
		args = append(args, "-no-color")
	}

	if fmtOpts.Recursive {
		args = append(args, "-recursive")
	}

	if len(paths) == 0 {
		paths = []string{"."}
	}
	args = append(args, paths...)

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	result := &FormatResult{
		ChangedFiles: []string{},
		Success:      err == nil,
	}

	if fmtOpts.List && stdout.Len() > 0 {
		scanner := bufio.NewScanner(&stdout)
		for scanner.Scan() {
			file := strings.TrimSpace(scanner.Text())
			if file != "" {
				result.ChangedFiles = append(result.ChangedFiles, file)
			}
		}
	}

	// Check mode returns non-zero if files need formatting
	if fmtOpts.Check && err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 3 {
			result.Success = false
			err = nil // Not a real error, just indicates files need formatting
		}
	}

	return result, err
}

func (e *Executor) Graph(ctx context.Context, opts ...GraphOption) (string, error) {
	graphOpts := &GraphOptions{
		Type:     "plan",
		DrawCycles: false,
		ModuleDepth: -1,
		Plan:     e.planFile,
	}

	for _, opt := range opts {
		opt(graphOpts)
	}

	args := []string{"graph"}

	if graphOpts.Type != "" {
		args = append(args, fmt.Sprintf("-type=%s", graphOpts.Type))
	}

	if graphOpts.DrawCycles {
		args = append(args, "-draw-cycles")
	}

	if graphOpts.ModuleDepth >= 0 {
		args = append(args, fmt.Sprintf("-module-depth=%d", graphOpts.ModuleDepth))
	}

	if graphOpts.Plan != "" {
		args = append(args, graphOpts.Plan)
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return "", err
	}

	return stdout.String(), nil
}

func (e *Executor) Providers(ctx context.Context, subcommand string, opts ...ProvidersOption) (*ProvidersResult, error) {
	provOpts := &ProvidersOptions{
		State: e.stateFile,
	}

	for _, opt := range opts {
		opt(provOpts)
	}

	args := []string{"providers"}

	if subcommand != "" {
		args = append(args, subcommand)
	}

	if provOpts.State != "" && subcommand != "mirror" && subcommand != "lock" {
		// State option only works with certain subcommands
		args = append(args, fmt.Sprintf("-state=%s", provOpts.State))
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, err
	}

	result := &ProvidersResult{
		Providers: []ProviderInfo{},
	}

	// Parse providers output
	scanner := bufio.NewScanner(&stdout)
	for scanner.Scan() {
		line := scanner.Text()

		// Parse provider information
		if strings.Contains(line, "provider[") {
			providerRegex := regexp.MustCompile(`provider\[([^\]]+)\]`)
			matches := providerRegex.FindStringSubmatch(line)
			if len(matches) > 1 {
				provider := ProviderInfo{
					Name: matches[1],
				}

				// Try to extract version if present
				versionRegex := regexp.MustCompile(`(\d+\.\d+\.\d+)`)
				versionMatches := versionRegex.FindStringSubmatch(line)
				if len(versionMatches) > 1 {
					provider.Version = versionMatches[1]
				}

				result.Providers = append(result.Providers, provider)
			}
		}
	}

	return result, nil
}

func (e *Executor) Test(ctx context.Context, opts ...TestOption) (*TestResult, error) {
	testOpts := &TestOptions{
		Filter:      "",
		JSON:        e.jsonOutput,
		TestDir:     "",
		Verbose:     false,
		NoColor:     !e.color,
	}

	for _, opt := range opts {
		opt(testOpts)
	}

	args := []string{"test"}

	if testOpts.Filter != "" {
		args = append(args, fmt.Sprintf("-filter=%s", testOpts.Filter))
	}

	if testOpts.JSON {
		args = append(args, "-json")
	}

	if testOpts.TestDir != "" {
		args = append(args, fmt.Sprintf("-test-directory=%s", testOpts.TestDir))
	}

	if testOpts.Verbose {
		args = append(args, "-verbose")
	}

	if testOpts.NoColor {
		args = append(args, "-no-color")
	}

	var stdout, stderr bytes.Buffer
	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	result := &TestResult{
		Success: err == nil,
		Tests:   []TestCase{},
	}

	if testOpts.JSON {
		// Parse JSON output for test results
		scanner := bufio.NewScanner(&stdout)
		for scanner.Scan() {
			var testEvent struct {
				Type     string `json:"@type"`
				TestName string `json:"test_name"`
				Status   string `json:"status"`
				Duration float64 `json:"duration"`
			}

			if err := json.Unmarshal(scanner.Bytes(), &testEvent); err == nil {
				if testEvent.Type == "test_summary" {
					result.Tests = append(result.Tests, TestCase{
						Name:     testEvent.TestName,
						Status:   testEvent.Status,
						Duration: time.Duration(testEvent.Duration * float64(time.Second)),
					})
				}
			}
		}
	}

	return result, err
}

func (e *Executor) buildCommand(ctx context.Context, args ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, e.terraformPath, args...)
	cmd.Dir = e.workingDir

	// Set environment variables
	cmd.Env = os.Environ()
	for key, value := range e.env {
		cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", key, value))
	}

	// Set TF_IN_AUTOMATION
	cmd.Env = append(cmd.Env, "TF_IN_AUTOMATION=true")

	// Set plugin cache dir if specified
	if e.pluginCacheDir != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("TF_PLUGIN_CACHE_DIR=%s", e.pluginCacheDir))
	}

	// Set input mode
	if !e.input {
		cmd.Env = append(cmd.Env, "TF_INPUT=false")
	}

	return cmd
}

func (e *Executor) runWithRetry(ctx context.Context, args ...string) error {
	if !e.retryConfig.Enabled {
		return e.run(ctx, args...)
	}

	var lastErr error
	backoff := e.retryConfig.InitialBackoff

	for attempt := 1; attempt <= e.retryConfig.MaxAttempts; attempt++ {
		err := e.run(ctx, args...)
		if err == nil {
			return nil
		}

		lastErr = err

		// Check if error is retryable
		if !e.isRetryableError(err) {
			return err
		}

		if attempt < e.retryConfig.MaxAttempts {
			e.logInfo("Command failed (attempt %d/%d), retrying in %v: %v",
				attempt, e.retryConfig.MaxAttempts, backoff, err)

			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(backoff):
				// Continue to next attempt
			}

			// Increase backoff
			backoff = time.Duration(float64(backoff) * e.retryConfig.BackoffFactor)
			if backoff > e.retryConfig.MaxBackoff {
				backoff = e.retryConfig.MaxBackoff
			}
		}
	}

	return fmt.Errorf("command failed after %d attempts: %w", e.retryConfig.MaxAttempts, lastErr)
}

func (e *Executor) run(ctx context.Context, args ...string) error {
	if e.dryRun {
		e.logInfo("DRY RUN: terraform %s", strings.Join(args, " "))
		return nil
	}

	cmd := e.buildCommand(ctx, args...)
	cmd.Stdout = e.stdout
	cmd.Stderr = e.stderr
	cmd.Stdin = e.stdin

	return e.runCommandWithHooks(ctx, cmd, HookTypeBefore, HookTypeAfter, HookTypeError)
}

func (e *Executor) runCommandWithHooks(ctx context.Context, cmd *exec.Cmd, hookTypes ...HookType) error {
	// Run before hooks
	for _, hookType := range hookTypes {
		if hookType == HookTypeBefore {
			if err := e.runHooks(ctx, HookTypeBefore); err != nil {
				return fmt.Errorf("before hook failed: %w", err)
			}
		}
	}

	// Run the command
	err := cmd.Run()

	// Run after or error hooks
	for _, hookType := range hookTypes {
		if hookType == HookTypeAfter && err == nil {
			if hookErr := e.runHooks(ctx, HookTypeAfter); hookErr != nil {
				return fmt.Errorf("after hook failed: %w", hookErr)
			}
		} else if hookType == HookTypeError && err != nil {
			if hookErr := e.runHooks(ctx, HookTypeError); hookErr != nil {
				e.logError("Error hook failed: %v", hookErr)
			}
		}
	}

	return err
}

func (e *Executor) runHooks(ctx context.Context, hookType HookType) error {
	for _, hook := range e.hooks {
		if hook.Type != hookType {
			continue
		}

		hookCmd := exec.CommandContext(ctx, hook.Command, hook.Args...)

		if hook.WorkDir != "" {
			hookCmd.Dir = hook.WorkDir
		} else {
			hookCmd.Dir = e.workingDir
		}

		hookCmd.Env = os.Environ()
		for key, value := range hook.Env {
			hookCmd.Env = append(hookCmd.Env, fmt.Sprintf("%s=%s", key, value))
		}

		e.logInfo("Running %s hook: %s", hookType, hook.Name)

		if err := hookCmd.Run(); err != nil {
			switch hook.OnFailure {
			case HookFailureAbort:
				return fmt.Errorf("hook %s failed: %w", hook.Name, err)
			case HookFailureRetry:
				// Retry the hook once
				if err := hookCmd.Run(); err != nil {
					return fmt.Errorf("hook %s failed after retry: %w", hook.Name, err)
				}
			case HookFailureContinue:
				e.logWarn("Hook %s failed but continuing: %v", hook.Name, err)
			}
		}
	}

	return nil
}

func (e *Executor) isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	errStr := err.Error()
	for _, pattern := range e.retryConfig.RetryableErrors {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}

	return false
}

func (e *Executor) logDebug(format string, args ...interface{}) {
	if e.logger != nil {
		e.logger.Debug(fmt.Sprintf(format, args...))
	}
}

func (e *Executor) logInfo(format string, args ...interface{}) {
	if e.logger != nil {
		e.logger.Info(fmt.Sprintf(format, args...))
	}
}

func (e *Executor) logWarn(format string, args ...interface{}) {
	if e.logger != nil {
		e.logger.Warn(fmt.Sprintf(format, args...))
	}
}

func (e *Executor) logError(format string, args ...interface{}) {
	if e.logger != nil {
		e.logger.Error(fmt.Sprintf(format, args...))
	}
}

func (e *Executor) GetWorkingDir() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.workingDir
}

func (e *Executor) SetWorkingDir(dir string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.workingDir = dir
}

func (e *Executor) GetVersion() *version.Version {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.version
}

func (e *Executor) LoadModule(path string) (*tfconfig.Module, error) {
	module, diags := tfconfig.LoadModule(path)
	if diags.HasErrors() {
		return nil, fmt.Errorf("loading module: %w", diags.Err())
	}
	return module, nil
}

func (e *Executor) FormatHCL(content []byte) ([]byte, error) {
	file, diags := hclwrite.ParseConfig(content, "", hcl.InitialPos)
	if diags.HasErrors() {
		return nil, fmt.Errorf("parsing HCL: %w", diags)
	}

	return file.Bytes(), nil
}

func (e *Executor) ParseHCL(content []byte) (*hcl.File, error) {
	parser := hclparse.NewParser()
	file, diags := parser.ParseHCL(content, "config.hcl")
	if diags.HasErrors() {
		return nil, fmt.Errorf("parsing HCL: %w", diags)
	}

	return file, nil
}

func (e *Executor) GenerateHCL(data interface{}) ([]byte, error) {
	file := hclwrite.NewEmptyFile()
	body := file.Body()

	// Convert data to HCL
	// This is a simplified version - would need proper type conversion
	if m, ok := data.(map[string]interface{}); ok {
		for key, value := range m {
			switch v := value.(type) {
			case string:
				body.SetAttributeValue(key, cty.StringVal(v))
			case int:
				body.SetAttributeValue(key, cty.NumberIntVal(int64(v)))
			case bool:
				body.SetAttributeValue(key, cty.BoolVal(v))
			}
		}
	}

	return file.Bytes(), nil
}