package terraform

import "time"

// InitOptions represents options for terraform init command
type InitOptions struct {
	Backend        bool
	BackendConfig  map[string]string
	FromModule     string
	GetPlugins     bool
	LockFile       string
	LockTimeout    time.Duration
	PluginDir      string
	Reconfigure    bool
	MigrateState   bool
	Upgrade        bool
	VerifyPlugins  bool
}

type InitOption func(*InitOptions)

func WithBackend(enabled bool) InitOption {
	return func(o *InitOptions) {
		o.Backend = enabled
	}
}

func WithBackendConfigOption(key, value string) InitOption {
	return func(o *InitOptions) {
		if o.BackendConfig == nil {
			o.BackendConfig = make(map[string]string)
		}
		o.BackendConfig[key] = value
	}
}

func WithFromModule(module string) InitOption {
	return func(o *InitOptions) {
		o.FromModule = module
	}
}

func WithPluginDir(dir string) InitOption {
	return func(o *InitOptions) {
		o.PluginDir = dir
	}
}

func WithReconfigure(enabled bool) InitOption {
	return func(o *InitOptions) {
		o.Reconfigure = enabled
	}
}

func WithUpgrade(enabled bool) InitOption {
	return func(o *InitOptions) {
		o.Upgrade = enabled
	}
}

// PlanOptions represents options for terraform plan command
type PlanOptions struct {
	Destroy          bool
	DetailedExitCode bool
	Lock             bool
	LockTimeout      time.Duration
	Out              string
	Parallelism      int
	Refresh          bool
	RefreshOnly      bool
	Replace          []string
	State            string
	Targets          []string
	VarFiles         []string
	Vars             map[string]string
	CompactWarnings  bool
	JSON             bool
}

type PlanOption func(*PlanOptions)

func WithDestroy(enabled bool) PlanOption {
	return func(o *PlanOptions) {
		o.Destroy = enabled
	}
}

func WithDetailedExitCode(enabled bool) PlanOption {
	return func(o *PlanOptions) {
		o.DetailedExitCode = enabled
	}
}

func WithPlanOut(file string) PlanOption {
	return func(o *PlanOptions) {
		o.Out = file
	}
}

func WithRefresh(enabled bool) PlanOption {
	return func(o *PlanOptions) {
		o.Refresh = enabled
	}
}

func WithRefreshOnly(enabled bool) PlanOption {
	return func(o *PlanOptions) {
		o.RefreshOnly = enabled
	}
}

func WithReplace(resources []string) PlanOption {
	return func(o *PlanOptions) {
		o.Replace = resources
	}
}

func WithPlanTargets(targets []string) PlanOption {
	return func(o *PlanOptions) {
		o.Targets = targets
	}
}

// ApplyOptions represents options for terraform apply command
type ApplyOptions struct {
	AutoApprove      bool
	Backup           string
	CompactWarnings  bool
	Lock             bool
	LockTimeout      time.Duration
	Parallelism      int
	PlanFile         string
	Refresh          bool
	RefreshOnly      bool
	Replace          []string
	State            string
	StateOut         string
	Targets          []string
	VarFiles         []string
	Vars             map[string]string
	JSON             bool
}

type ApplyOption func(*ApplyOptions)

func WithApplyAutoApprove(enabled bool) ApplyOption {
	return func(o *ApplyOptions) {
		o.AutoApprove = enabled
	}
}

func WithApplyBackup(file string) ApplyOption {
	return func(o *ApplyOptions) {
		o.Backup = file
	}
}

func WithApplyPlanFile(file string) ApplyOption {
	return func(o *ApplyOptions) {
		o.PlanFile = file
	}
}

func WithApplyState(file string) ApplyOption {
	return func(o *ApplyOptions) {
		o.State = file
	}
}

func WithApplyStateOut(file string) ApplyOption {
	return func(o *ApplyOptions) {
		o.StateOut = file
	}
}

// DestroyOptions represents options for terraform destroy command
type DestroyOptions struct {
	AutoApprove     bool
	Backup          string
	CompactWarnings bool
	Lock            bool
	LockTimeout     time.Duration
	Parallelism     int
	Refresh         bool
	State           string
	StateOut        string
	Targets         []string
	VarFiles        []string
	Vars            map[string]string
	JSON            bool
}

type DestroyOption func(*DestroyOptions)

func WithDestroyAutoApprove(enabled bool) DestroyOption {
	return func(o *DestroyOptions) {
		o.AutoApprove = enabled
	}
}

func WithDestroyTargets(targets []string) DestroyOption {
	return func(o *DestroyOptions) {
		o.Targets = targets
	}
}

// RefreshOptions represents options for terraform refresh command
type RefreshOptions struct {
	Backup          string
	CompactWarnings bool
	Lock            bool
	LockTimeout     time.Duration
	State           string
	StateOut        string
	Targets         []string
	VarFiles        []string
	Vars            map[string]string
	JSON            bool
}

type RefreshOption func(*RefreshOptions)

func WithRefreshState(file string) RefreshOption {
	return func(o *RefreshOptions) {
		o.State = file
	}
}

func WithRefreshTargets(targets []string) RefreshOption {
	return func(o *RefreshOptions) {
		o.Targets = targets
	}
}

// ValidateOptions represents options for terraform validate command
type ValidateOptions struct {
	JSON    bool
	NoColor bool
	TestDir string
}

type ValidateOption func(*ValidateOptions)

func WithValidateJSON(enabled bool) ValidateOption {
	return func(o *ValidateOptions) {
		o.JSON = enabled
	}
}

func WithValidateTestDir(dir string) ValidateOption {
	return func(o *ValidateOptions) {
		o.TestDir = dir
	}
}

// OutputOptions represents options for terraform output command
type OutputOptions struct {
	JSON  bool
	Raw   bool
	State string
}

type OutputOption func(*OutputOptions)

func WithOutputJSON(enabled bool) OutputOption {
	return func(o *OutputOptions) {
		o.JSON = enabled
	}
}

func WithOutputRaw(enabled bool) OutputOption {
	return func(o *OutputOptions) {
		o.Raw = enabled
	}
}

func WithOutputState(file string) OutputOption {
	return func(o *OutputOptions) {
		o.State = file
	}
}

// ShowOptions represents options for terraform show command
type ShowOptions struct {
	JSON     bool
	NoColor  bool
	PlanFile string
	State    string
}

type ShowOption func(*ShowOptions)

func WithShowJSON(enabled bool) ShowOption {
	return func(o *ShowOptions) {
		o.JSON = enabled
	}
}

func WithShowPlanFile(file string) ShowOption {
	return func(o *ShowOptions) {
		o.PlanFile = file
	}
}

func WithShowState(file string) ShowOption {
	return func(o *ShowOptions) {
		o.State = file
	}
}

// ImportOptions represents options for terraform import command
type ImportOptions struct {
	AllowMissingConfig bool
	Backup            string
	Config            string
	Lock              bool
	LockTimeout       time.Duration
	NoColor           bool
	Parallelism       int
	Provider          string
	State             string
	StateOut          string
	VarFiles          []string
	Vars              map[string]string
}

type ImportOption func(*ImportOptions)

func WithImportAllowMissingConfig(enabled bool) ImportOption {
	return func(o *ImportOptions) {
		o.AllowMissingConfig = enabled
	}
}

func WithImportConfig(path string) ImportOption {
	return func(o *ImportOptions) {
		o.Config = path
	}
}

func WithImportProvider(provider string) ImportOption {
	return func(o *ImportOptions) {
		o.Provider = provider
	}
}

// StateListOptions represents options for terraform state list command
type StateListOptions struct {
	State string
	ID    string
}

type StateListOption func(*StateListOptions)

func WithStateListState(file string) StateListOption {
	return func(o *StateListOptions) {
		o.State = file
	}
}

func WithStateListID(id string) StateListOption {
	return func(o *StateListOptions) {
		o.ID = id
	}
}

// StateShowOptions represents options for terraform state show command
type StateShowOptions struct {
	State string
}

type StateShowOption func(*StateShowOptions)

func WithStateShowState(file string) StateShowOption {
	return func(o *StateShowOptions) {
		o.State = file
	}
}

// StateMvOptions represents options for terraform state mv command
type StateMvOptions struct {
	Backup              string
	BackupOut           string
	DryRun              bool
	Lock                bool
	LockTimeout         time.Duration
	State               string
	StateOut            string
	IgnoreRemoteVersion bool
}

type StateMvOption func(*StateMvOptions)

func WithStateMvBackup(file string) StateMvOption {
	return func(o *StateMvOptions) {
		o.Backup = file
	}
}

func WithStateMvDryRun(enabled bool) StateMvOption {
	return func(o *StateMvOptions) {
		o.DryRun = enabled
	}
}

func WithStateMvStateOut(file string) StateMvOption {
	return func(o *StateMvOptions) {
		o.StateOut = file
	}
}

// StateRmOptions represents options for terraform state rm command
type StateRmOptions struct {
	Backup              string
	DryRun              bool
	Lock                bool
	LockTimeout         time.Duration
	State               string
	IgnoreRemoteVersion bool
}

type StateRmOption func(*StateRmOptions)

func WithStateRmBackup(file string) StateRmOption {
	return func(o *StateRmOptions) {
		o.Backup = file
	}
}

func WithStateRmDryRun(enabled bool) StateRmOption {
	return func(o *StateRmOptions) {
		o.DryRun = enabled
	}
}

// WorkspaceOptions represents options for terraform workspace commands
type WorkspaceOptions struct {
	Lock        bool
	LockTimeout time.Duration
	State       string
	StatePath   string
}

type WorkspaceOption func(*WorkspaceOptions)

func WithWorkspaceLock(enabled bool) WorkspaceOption {
	return func(o *WorkspaceOptions) {
		o.Lock = enabled
	}
}

func WithWorkspaceState(file string) WorkspaceOption {
	return func(o *WorkspaceOptions) {
		o.State = file
	}
}

// FormatOptions represents options for terraform fmt command
type FormatOptions struct {
	List      bool
	Write     bool
	Diff      bool
	Check     bool
	NoColor   bool
	Recursive bool
}

type FormatOption func(*FormatOptions)

func WithFormatList(enabled bool) FormatOption {
	return func(o *FormatOptions) {
		o.List = enabled
	}
}

func WithFormatWrite(enabled bool) FormatOption {
	return func(o *FormatOptions) {
		o.Write = enabled
	}
}

func WithFormatDiff(enabled bool) FormatOption {
	return func(o *FormatOptions) {
		o.Diff = enabled
	}
}

func WithFormatCheck(enabled bool) FormatOption {
	return func(o *FormatOptions) {
		o.Check = enabled
	}
}

func WithFormatRecursive(enabled bool) FormatOption {
	return func(o *FormatOptions) {
		o.Recursive = enabled
	}
}

// GraphOptions represents options for terraform graph command
type GraphOptions struct {
	Type        string
	DrawCycles  bool
	ModuleDepth int
	Plan        string
}

type GraphOption func(*GraphOptions)

func WithGraphType(graphType string) GraphOption {
	return func(o *GraphOptions) {
		o.Type = graphType
	}
}

func WithGraphDrawCycles(enabled bool) GraphOption {
	return func(o *GraphOptions) {
		o.DrawCycles = enabled
	}
}

func WithGraphModuleDepth(depth int) GraphOption {
	return func(o *GraphOptions) {
		o.ModuleDepth = depth
	}
}

func WithGraphPlan(file string) GraphOption {
	return func(o *GraphOptions) {
		o.Plan = file
	}
}

// ProvidersOptions represents options for terraform providers commands
type ProvidersOptions struct {
	State string
}

type ProvidersOption func(*ProvidersOptions)

func WithProvidersState(file string) ProvidersOption {
	return func(o *ProvidersOptions) {
		o.State = file
	}
}

// TestOptions represents options for terraform test command
type TestOptions struct {
	Filter   string
	JSON     bool
	TestDir  string
	Verbose  bool
	NoColor  bool
}

type TestOption func(*TestOptions)

func WithTestFilter(filter string) TestOption {
	return func(o *TestOptions) {
		o.Filter = filter
	}
}

func WithTestJSON(enabled bool) TestOption {
	return func(o *TestOptions) {
		o.JSON = enabled
	}
}

func WithTestDirectory(dir string) TestOption {
	return func(o *TestOptions) {
		o.TestDir = dir
	}
}

func WithTestVerbose(enabled bool) TestOption {
	return func(o *TestOptions) {
		o.Verbose = enabled
	}
}