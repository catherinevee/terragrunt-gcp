package config

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"text/template"
	"time"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclsyntax"
	"github.com/zclconf/go-cty/cty"
	"github.com/zclconf/go-cty/cty/function"
	"github.com/zclconf/go-cty/cty/function/stdlib"
)

type EnvResolver struct {
	config          *Config
	envVars         map[string]string
	secretsProvider SecretsProvider
	funcMap         map[string]function.Function
	evalContext     *hcl.EvalContext
	cache           map[string]interface{}
	cacheExpiry     map[string]time.Time
}

type SecretsProvider interface {
	GetSecret(ctx context.Context, key string) (string, error)
	ListSecrets(ctx context.Context, prefix string) ([]string, error)
}

type ResolverOption func(*EnvResolver)

func NewEnvResolver(cfg *Config, opts ...ResolverOption) *EnvResolver {
	r := &EnvResolver{
		config:      cfg,
		envVars:     make(map[string]string),
		funcMap:     make(map[string]function.Function),
		cache:       make(map[string]interface{}),
		cacheExpiry: make(map[string]time.Time),
	}

	for _, opt := range opts {
		opt(r)
	}

	r.loadEnvVars()
	r.initFunctions()
	r.initEvalContext()

	return r
}

func WithSecretsProvider(provider SecretsProvider) ResolverOption {
	return func(r *EnvResolver) {
		r.secretsProvider = provider
	}
}

func (r *EnvResolver) loadEnvVars() {
	for _, env := range os.Environ() {
		pair := strings.SplitN(env, "=", 2)
		if len(pair) == 2 {
			r.envVars[pair[0]] = pair[1]
		}
	}
}

func (r *EnvResolver) initFunctions() {
	r.funcMap = map[string]function.Function{
		"abs":        stdlib.AbsoluteFunc,
		"ceil":       stdlib.CeilFunc,
		"floor":      stdlib.FloorFunc,
		"log":        stdlib.LogFunc,
		"max":        stdlib.MaxFunc,
		"min":        stdlib.MinFunc,
		"parseint":   stdlib.ParseIntFunc,
		"pow":        stdlib.PowFunc,
		"signum":     stdlib.SignumFunc,
		"chomp":      stdlib.ChompFunc,
		"format":     stdlib.FormatFunc,
		"formatlist": stdlib.FormatListFunc,
		"indent":     stdlib.IndentFunc,
		"join":       stdlib.JoinFunc,
		"lower":      stdlib.LowerFunc,
		"regex":      stdlib.RegexFunc,
		"regexall":   stdlib.RegexAllFunc,
		"replace":    stdlib.ReplaceFunc,
		"split":      stdlib.SplitFunc,
		"strrev":     stdlib.ReverseFunc,
		"substr":     stdlib.SubstrFunc,
		"title":      stdlib.TitleFunc,
		"trim":       stdlib.TrimFunc,
		"trimprefix": stdlib.TrimPrefixFunc,
		"trimsuffix": stdlib.TrimSuffixFunc,
		"trimspace":  stdlib.TrimSpaceFunc,
		"upper":      stdlib.UpperFunc,
		"chunklist":  stdlib.ChunklistFunc,
		"coalesce":   stdlib.CoalesceFunc,
		"coalescelist": stdlib.CoalesceListFunc,
		"compact":    stdlib.CompactFunc,
		"concat":     stdlib.ConcatFunc,
		"contains":   stdlib.ContainsFunc,
		"distinct":   stdlib.DistinctFunc,
		"element":    stdlib.ElementFunc,
		"flatten":    stdlib.FlattenFunc,
		"index":      stdlib.IndexFunc,
		"keys":       stdlib.KeysFunc,
		"length":     stdlib.LengthFunc,
		"lookup":     stdlib.LookupFunc,
		"merge":      stdlib.MergeFunc,
		"range":      stdlib.RangeFunc,
		"reverse":    stdlib.ReverseListFunc,
		"setintersection": stdlib.SetIntersectionFunc,
		"setproduct":      stdlib.SetProductFunc,
		"setsubtract":     stdlib.SetSubtractFunc,
		"setunion":        stdlib.SetUnionFunc,
		"slice":           stdlib.SliceFunc,
		"sort":            stdlib.SortFunc,
		"values":          stdlib.ValuesFunc,
		"zipmap":          stdlib.ZipmapFunc,
		"base64decode":    stdlib.Base64DecodeFunc,
		"base64encode":    stdlib.Base64EncodeFunc,
		"base64gzip":      stdlib.Base64GzipFunc,
		"csvdecode":       stdlib.CSVDecodeFunc,
		"jsondecode":      stdlib.JSONDecodeFunc,
		"jsonencode":      stdlib.JSONEncodeFunc,
		"urlencode":       stdlib.URLEncodeFunc,
		"yamldecode":      stdlib.YAMLDecodeFunc,
		"yamlencode":      stdlib.YAMLEncodeFunc,
		"formatdate":      stdlib.FormatDateFunc,
		"timeadd":         stdlib.TimeAddFunc,
		"timestamp":       stdlib.TimestampFunc,

		// Custom functions
		"env":             r.envFunc(),
		"get_env":         r.getEnvFunc(),
		"secret":          r.secretFunc(),
		"get_secret":      r.getSecretFunc(),
		"file":            r.fileFunc(),
		"find_in_parent":  r.findInParentFunc(),
		"path_relative_to": r.pathRelativeToFunc(),
		"path_relative_from": r.pathRelativeFromFunc(),
		"get_aws_account_id": r.getAWSAccountIDFunc(),
		"get_gcp_project":    r.getGCPProjectFunc(),
		"get_azure_subscription": r.getAzureSubscriptionFunc(),
		"get_terraform_commands": r.getTerraformCommandsFunc(),
		"get_terragrunt_dir":     r.getTerragruntDirFunc(),
		"get_parent_terragrunt_dir": r.getParentTerragruntDirFunc(),
		"get_original_terragrunt_dir": r.getOriginalTerragruntDirFunc(),
		"get_platform":        r.getPlatformFunc(),
		"get_repo_root":       r.getRepoRootFunc(),
		"run_cmd":             r.runCmdFunc(),
		"read_terragrunt_config": r.readTerragruntConfigFunc(),
		"generate_if":         r.generateIfFunc(),
		"templatefile":        r.templateFileFunc(),
	}
}

func (r *EnvResolver) initEvalContext() {
	variables := make(map[string]cty.Value)

	// Add config values as variables
	variables["project"] = cty.StringVal(r.config.Project)
	variables["region"] = cty.StringVal(r.config.Region)
	variables["zone"] = cty.StringVal(r.config.Zone)
	variables["environment"] = cty.StringVal(r.config.Environment)

	// Add terraform config
	tfVars := make(map[string]cty.Value)
	tfVars["version"] = cty.StringVal(r.config.Terraform.Version)
	tfVars["working_dir"] = cty.StringVal(r.config.Terraform.WorkingDir)
	tfVars["parallelism"] = cty.NumberIntVal(int64(r.config.Terraform.Parallelism))
	variables["terraform"] = cty.ObjectVal(tfVars)

	// Add terragrunt config
	tgVars := make(map[string]cty.Value)
	tgVars["version"] = cty.StringVal(r.config.Terragrunt.Version)
	tgVars["config_file"] = cty.StringVal(r.config.Terragrunt.ConfigFile)
	tgVars["max_retries"] = cty.NumberIntVal(int64(r.config.Terragrunt.MaxRetries))
	variables["terragrunt"] = cty.ObjectVal(tgVars)

	// Add locals
	locals := make(map[string]cty.Value)
	for k, v := range r.config.Terragrunt.Locals {
		locals[k] = r.interfaceToCty(v)
	}
	if len(locals) > 0 {
		variables["local"] = cty.ObjectVal(locals)
	}

	// Add custom variables
	for k, v := range r.config.Variables {
		variables[k] = r.interfaceToCty(v)
	}

	r.evalContext = &hcl.EvalContext{
		Functions: r.funcMap,
		Variables: variables,
	}
}

func (r *EnvResolver) Resolve(ctx context.Context) error {
	// Resolve environment variables
	if err := r.resolveEnvVars(ctx); err != nil {
		return fmt.Errorf("resolving environment variables: %w", err)
	}

	// Resolve secrets
	if err := r.resolveSecrets(ctx); err != nil {
		return fmt.Errorf("resolving secrets: %w", err)
	}

	// Resolve template expressions
	if err := r.resolveTemplates(ctx); err != nil {
		return fmt.Errorf("resolving templates: %w", err)
	}

	// Resolve dependencies
	if err := r.resolveDependencies(ctx); err != nil {
		return fmt.Errorf("resolving dependencies: %w", err)
	}

	return nil
}

func (r *EnvResolver) resolveEnvVars(ctx context.Context) error {
	// Resolve project from env
	if r.config.Project == "" {
		if project := r.getEnv("GOOGLE_PROJECT", "GCP_PROJECT", "GOOGLE_CLOUD_PROJECT"); project != "" {
			r.config.Project = project
		}
	}

	// Resolve region from env
	if r.config.Region == "" {
		if region := r.getEnv("GOOGLE_REGION", "GCP_REGION", "GOOGLE_COMPUTE_REGION"); region != "" {
			r.config.Region = region
		}
	}

	// Resolve zone from env
	if r.config.Zone == "" {
		if zone := r.getEnv("GOOGLE_ZONE", "GCP_ZONE", "GOOGLE_COMPUTE_ZONE"); zone != "" {
			r.config.Zone = zone
		}
	}

	// Resolve environment from env
	if r.config.Environment == "" {
		if env := r.getEnv("ENVIRONMENT", "ENV", "DEPLOYMENT_ENV"); env != "" {
			r.config.Environment = env
		}
	}

	// Resolve terraform version
	if r.config.Terraform.Version == "" {
		if version := r.getEnv("TERRAFORM_VERSION", "TF_VERSION"); version != "" {
			r.config.Terraform.Version = version
		}
	}

	// Resolve terragrunt version
	if r.config.Terragrunt.Version == "" {
		if version := r.getEnv("TERRAGRUNT_VERSION", "TG_VERSION"); version != "" {
			r.config.Terragrunt.Version = version
		}
	}

	// Resolve backend configuration from env
	if r.config.Backend.Type == "" {
		if backendType := r.getEnv("TERRAFORM_BACKEND", "TF_BACKEND"); backendType != "" {
			r.config.Backend.Type = backendType
		}
	}

	if r.config.Backend.Bucket == "" {
		if bucket := r.getEnv("TERRAFORM_STATE_BUCKET", "TF_STATE_BUCKET", "STATE_BUCKET"); bucket != "" {
			r.config.Backend.Bucket = bucket
		}
	}

	// Resolve authentication
	if r.config.Authentication.Type == "" {
		if authType := r.getEnv("AUTH_TYPE", "GOOGLE_AUTH_TYPE"); authType != "" {
			r.config.Authentication.Type = authType
		}
	}

	if r.config.Authentication.ServiceAccountKey == "" {
		if key := r.getEnv("GOOGLE_APPLICATION_CREDENTIALS", "GCP_SERVICE_ACCOUNT_KEY"); key != "" {
			r.config.Authentication.ServiceAccountKey = key
		}
	}

	return r.resolveStringFields(ctx)
}

func (r *EnvResolver) resolveSecrets(ctx context.Context) error {
	if r.secretsProvider == nil {
		return nil
	}

	// Resolve authentication secrets
	if strings.HasPrefix(r.config.Authentication.ServiceAccountKey, "secret:") {
		secretKey := strings.TrimPrefix(r.config.Authentication.ServiceAccountKey, "secret:")
		secret, err := r.secretsProvider.GetSecret(ctx, secretKey)
		if err != nil {
			return fmt.Errorf("getting service account key secret: %w", err)
		}
		r.config.Authentication.ServiceAccountKey = secret
	}

	if strings.HasPrefix(r.config.Authentication.ClientSecret, "secret:") {
		secretKey := strings.TrimPrefix(r.config.Authentication.ClientSecret, "secret:")
		secret, err := r.secretsProvider.GetSecret(ctx, secretKey)
		if err != nil {
			return fmt.Errorf("getting client secret: %w", err)
		}
		r.config.Authentication.ClientSecret = secret
	}

	// Resolve OIDC secrets
	if strings.HasPrefix(r.config.Authentication.OIDC.ClientSecret, "secret:") {
		secretKey := strings.TrimPrefix(r.config.Authentication.OIDC.ClientSecret, "secret:")
		secret, err := r.secretsProvider.GetSecret(ctx, secretKey)
		if err != nil {
			return fmt.Errorf("getting OIDC client secret: %w", err)
		}
		r.config.Authentication.OIDC.ClientSecret = secret
	}

	// Resolve provider credentials
	for name, provider := range r.config.Providers {
		if strings.HasPrefix(provider.Credentials, "secret:") {
			secretKey := strings.TrimPrefix(provider.Credentials, "secret:")
			secret, err := r.secretsProvider.GetSecret(ctx, secretKey)
			if err != nil {
				return fmt.Errorf("getting provider %s credentials: %w", name, err)
			}
			provider.Credentials = secret
			r.config.Providers[name] = provider
		}

		if strings.HasPrefix(provider.AccessToken, "secret:") {
			secretKey := strings.TrimPrefix(provider.AccessToken, "secret:")
			secret, err := r.secretsProvider.GetSecret(ctx, secretKey)
			if err != nil {
				return fmt.Errorf("getting provider %s access token: %w", name, err)
			}
			provider.AccessToken = secret
			r.config.Providers[name] = provider
		}
	}

	return nil
}

func (r *EnvResolver) resolveTemplates(ctx context.Context) error {
	// Resolve template expressions in string fields
	if err := r.resolveStringField(&r.config.Project); err != nil {
		return fmt.Errorf("resolving project: %w", err)
	}

	if err := r.resolveStringField(&r.config.Region); err != nil {
		return fmt.Errorf("resolving region: %w", err)
	}

	if err := r.resolveStringField(&r.config.Zone); err != nil {
		return fmt.Errorf("resolving zone: %w", err)
	}

	if err := r.resolveStringField(&r.config.Environment); err != nil {
		return fmt.Errorf("resolving environment: %w", err)
	}

	// Resolve terraform config
	if err := r.resolveStringField(&r.config.Terraform.WorkingDir); err != nil {
		return fmt.Errorf("resolving terraform working dir: %w", err)
	}

	if err := r.resolveStringField(&r.config.Terraform.StateFile); err != nil {
		return fmt.Errorf("resolving terraform state file: %w", err)
	}

	// Resolve backend config
	if err := r.resolveStringField(&r.config.Backend.Bucket); err != nil {
		return fmt.Errorf("resolving backend bucket: %w", err)
	}

	if err := r.resolveStringField(&r.config.Backend.Prefix); err != nil {
		return fmt.Errorf("resolving backend prefix: %w", err)
	}

	// Resolve module paths
	for i, module := range r.config.Modules {
		if err := r.resolveStringField(&module.Source); err != nil {
			return fmt.Errorf("resolving module %s source: %w", module.Name, err)
		}

		if err := r.resolveStringField(&module.Path); err != nil {
			return fmt.Errorf("resolving module %s path: %w", module.Name, err)
		}

		r.config.Modules[i] = module
	}

	// Resolve variable values
	for key, value := range r.config.Variables {
		if strVal, ok := value.(string); ok {
			resolved, err := r.resolveString(strVal)
			if err != nil {
				return fmt.Errorf("resolving variable %s: %w", key, err)
			}
			r.config.Variables[key] = resolved
		}
	}

	return nil
}

func (r *EnvResolver) resolveDependencies(ctx context.Context) error {
	for i, dep := range r.config.Terragrunt.Dependencies {
		// Resolve dependency path
		if err := r.resolveStringField(&dep.Path); err != nil {
			return fmt.Errorf("resolving dependency %s path: %w", dep.Name, err)
		}

		// Make path absolute if relative
		if !filepath.IsAbs(dep.Path) {
			basePath := filepath.Dir(r.config.ConfigPath)
			dep.Path = filepath.Join(basePath, dep.Path)
		}

		// Resolve mock outputs
		for key, value := range dep.MockOutputs {
			if strVal, ok := value.(string); ok {
				resolved, err := r.resolveString(strVal)
				if err != nil {
					return fmt.Errorf("resolving dependency %s mock output %s: %w", dep.Name, key, err)
				}
				dep.MockOutputs[key] = resolved
			}
		}

		r.config.Terragrunt.Dependencies[i] = dep
	}

	return nil
}

func (r *EnvResolver) resolveStringFields(ctx context.Context) error {
	// Use reflection to find and resolve all string fields
	// This is a simplified version - in production you'd use reflection
	return nil
}

func (r *EnvResolver) resolveStringField(field *string) error {
	if field == nil || *field == "" {
		return nil
	}

	resolved, err := r.resolveString(*field)
	if err != nil {
		return err
	}

	*field = resolved
	return nil
}

func (r *EnvResolver) resolveString(input string) (string, error) {
	// Check for ${...} expressions
	if !strings.Contains(input, "${") {
		return input, nil
	}

	// Find all ${...} expressions
	re := regexp.MustCompile(`\$\{([^}]+)\}`)
	matches := re.FindAllStringSubmatch(input, -1)

	result := input
	for _, match := range matches {
		expr := match[1]
		value, err := r.evaluateExpression(expr)
		if err != nil {
			return "", fmt.Errorf("evaluating expression %s: %w", expr, err)
		}

		result = strings.Replace(result, match[0], value, 1)
	}

	return result, nil
}

func (r *EnvResolver) evaluateExpression(expr string) (string, error) {
	// Parse and evaluate HCL expression
	exp, diags := hclsyntax.ParseExpression([]byte(expr), "", hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		return "", fmt.Errorf("parsing expression: %w", diags)
	}

	val, diags := exp.Value(r.evalContext)
	if diags.HasErrors() {
		return "", fmt.Errorf("evaluating expression: %w", diags)
	}

	// Convert cty.Value to string
	if val.Type() == cty.String {
		return val.AsString(), nil
	}

	// Convert other types to JSON string
	jsonBytes, err := stdlib.JSONEncode(val)
	if err != nil {
		return "", fmt.Errorf("encoding value to JSON: %w", err)
	}

	return string(jsonBytes), nil
}

func (r *EnvResolver) getEnv(keys ...string) string {
	for _, key := range keys {
		if value, exists := r.envVars[key]; exists && value != "" {
			return value
		}
	}
	return ""
}

func (r *EnvResolver) interfaceToCty(val interface{}) cty.Value {
	switch v := val.(type) {
	case string:
		return cty.StringVal(v)
	case int:
		return cty.NumberIntVal(int64(v))
	case int64:
		return cty.NumberIntVal(v)
	case float64:
		return cty.NumberFloatVal(v)
	case bool:
		return cty.BoolVal(v)
	case []interface{}:
		vals := make([]cty.Value, len(v))
		for i, item := range v {
			vals[i] = r.interfaceToCty(item)
		}
		return cty.ListVal(vals)
	case map[string]interface{}:
		vals := make(map[string]cty.Value)
		for k, item := range v {
			vals[k] = r.interfaceToCty(item)
		}
		return cty.ObjectVal(vals)
	default:
		return cty.NullVal(cty.DynamicPseudoType)
	}
}

// Custom function implementations

func (r *EnvResolver) envFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "key", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			key := args[0].AsString()
			value := os.Getenv(key)
			return cty.StringVal(value), nil
		},
	})
}

func (r *EnvResolver) getEnvFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "key", Type: cty.String},
			{Name: "default", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			key := args[0].AsString()
			defaultVal := args[1].AsString()
			value := os.Getenv(key)
			if value == "" {
				value = defaultVal
			}
			return cty.StringVal(value), nil
		},
	})
}

func (r *EnvResolver) secretFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "key", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			if r.secretsProvider == nil {
				return cty.StringVal(""), fmt.Errorf("secrets provider not configured")
			}

			key := args[0].AsString()
			secret, err := r.secretsProvider.GetSecret(context.Background(), key)
			if err != nil {
				return cty.StringVal(""), err
			}

			return cty.StringVal(secret), nil
		},
	})
}

func (r *EnvResolver) getSecretFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "key", Type: cty.String},
			{Name: "default", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			if r.secretsProvider == nil {
				return args[1], nil // Return default if no provider
			}

			key := args[0].AsString()
			defaultVal := args[1].AsString()

			secret, err := r.secretsProvider.GetSecret(context.Background(), key)
			if err != nil {
				return cty.StringVal(defaultVal), nil
			}

			return cty.StringVal(secret), nil
		},
	})
}

func (r *EnvResolver) fileFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "path", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			path := args[0].AsString()

			// Make path relative to config file if not absolute
			if !filepath.IsAbs(path) && r.config.ConfigPath != "" {
				path = filepath.Join(filepath.Dir(r.config.ConfigPath), path)
			}

			content, err := os.ReadFile(path)
			if err != nil {
				return cty.StringVal(""), err
			}

			return cty.StringVal(string(content)), nil
		},
	})
}

func (r *EnvResolver) findInParentFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "filename", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			filename := args[0].AsString()
			startDir := filepath.Dir(r.config.ConfigPath)

			for dir := startDir; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
				path := filepath.Join(dir, filename)
				if _, err := os.Stat(path); err == nil {
					return cty.StringVal(path), nil
				}
			}

			return cty.StringVal(""), fmt.Errorf("file %s not found in parent directories", filename)
		},
	})
}

func (r *EnvResolver) pathRelativeToFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "basePath", Type: cty.String},
			{Name: "path", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			basePath := args[0].AsString()
			path := args[1].AsString()

			rel, err := filepath.Rel(basePath, path)
			if err != nil {
				return cty.StringVal(""), err
			}

			return cty.StringVal(rel), nil
		},
	})
}

func (r *EnvResolver) pathRelativeFromFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "basePath", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			basePath := args[0].AsString()
			currentPath := filepath.Dir(r.config.ConfigPath)

			rel, err := filepath.Rel(basePath, currentPath)
			if err != nil {
				return cty.StringVal(""), err
			}

			return cty.StringVal(rel), nil
		},
	})
}

func (r *EnvResolver) getAWSAccountIDFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			// This would normally call AWS STS
			accountID := os.Getenv("AWS_ACCOUNT_ID")
			if accountID == "" {
				accountID = "123456789012" // Default for local testing
			}
			return cty.StringVal(accountID), nil
		},
	})
}

func (r *EnvResolver) getGCPProjectFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			return cty.StringVal(r.config.Project), nil
		},
	})
}

func (r *EnvResolver) getAzureSubscriptionFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			subID := os.Getenv("AZURE_SUBSCRIPTION_ID")
			if subID == "" {
				subID = "00000000-0000-0000-0000-000000000000" // Default for local testing
			}
			return cty.StringVal(subID), nil
		},
	})
}

func (r *EnvResolver) getTerraformCommandsFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.List(cty.String)),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			commands := []cty.Value{
				cty.StringVal("init"),
				cty.StringVal("plan"),
				cty.StringVal("apply"),
				cty.StringVal("destroy"),
				cty.StringVal("validate"),
				cty.StringVal("output"),
			}
			return cty.ListVal(commands), nil
		},
	})
}

func (r *EnvResolver) getTerragruntDirFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			dir := filepath.Dir(r.config.ConfigPath)
			return cty.StringVal(dir), nil
		},
	})
}

func (r *EnvResolver) getParentTerragruntDirFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			dir := filepath.Dir(filepath.Dir(r.config.ConfigPath))
			return cty.StringVal(dir), nil
		},
	})
}

func (r *EnvResolver) getOriginalTerragruntDirFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			// This would track the original dir where terragrunt was invoked
			originalDir := os.Getenv("TERRAGRUNT_ORIGINAL_DIR")
			if originalDir == "" {
				originalDir, _ = os.Getwd()
			}
			return cty.StringVal(originalDir), nil
		},
	})
}

func (r *EnvResolver) getPlatformFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			return cty.StringVal(os.Getenv("GOOS")), nil
		},
	})
}

func (r *EnvResolver) getRepoRootFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{},
		Type:   function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			startDir := filepath.Dir(r.config.ConfigPath)

			for dir := startDir; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
				gitPath := filepath.Join(dir, ".git")
				if _, err := os.Stat(gitPath); err == nil {
					return cty.StringVal(dir), nil
				}
			}

			return cty.StringVal(""), fmt.Errorf("git repository root not found")
		},
	})
}

func (r *EnvResolver) runCmdFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "cmd", Type: cty.String},
			{Name: "args", Type: cty.List(cty.String)},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			// This is disabled for security - would need proper sandboxing
			return cty.StringVal(""), fmt.Errorf("run_cmd is disabled for security")
		},
	})
}

func (r *EnvResolver) readTerragruntConfigFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "path", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.DynamicPseudoType),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			path := args[0].AsString()

			// Make path relative to config file if not absolute
			if !filepath.IsAbs(path) && r.config.ConfigPath != "" {
				path = filepath.Join(filepath.Dir(r.config.ConfigPath), path)
			}

			loader := NewLoader()
			cfg, err := loader.LoadConfig(context.Background(), path)
			if err != nil {
				return cty.NullVal(cty.DynamicPseudoType), err
			}

			// Convert config to cty.Value
			data, err := json.Marshal(cfg)
			if err != nil {
				return cty.NullVal(cty.DynamicPseudoType), err
			}

			var result interface{}
			if err := json.Unmarshal(data, &result); err != nil {
				return cty.NullVal(cty.DynamicPseudoType), err
			}

			return r.interfaceToCty(result), nil
		},
	})
}

func (r *EnvResolver) generateIfFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "condition", Type: cty.Bool},
			{Name: "content", Type: cty.String},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			if args[0].True() {
				return args[1], nil
			}
			return cty.StringVal(""), nil
		},
	})
}

func (r *EnvResolver) templateFileFunc() function.Function {
	return function.New(&function.Spec{
		Params: []function.Parameter{
			{Name: "path", Type: cty.String},
			{Name: "vars", Type: cty.Map(cty.String)},
		},
		Type: function.StaticReturnType(cty.String),
		Impl: func(args []cty.Value, retType cty.Type) (cty.Value, error) {
			path := args[0].AsString()
			vars := args[1].AsValueMap()

			// Make path relative to config file if not absolute
			if !filepath.IsAbs(path) && r.config.ConfigPath != "" {
				path = filepath.Join(filepath.Dir(r.config.ConfigPath), path)
			}

			content, err := os.ReadFile(path)
			if err != nil {
				return cty.StringVal(""), err
			}

			tmpl, err := template.New("template").Parse(string(content))
			if err != nil {
				return cty.StringVal(""), err
			}

			templateVars := make(map[string]string)
			for k, v := range vars {
				templateVars[k] = v.AsString()
			}

			var buf strings.Builder
			if err := tmpl.Execute(&buf, templateVars); err != nil {
				return cty.StringVal(""), err
			}

			return cty.StringVal(buf.String()), nil
		},
	})
}

func (r *EnvResolver) GetResolvedValue(key string) (interface{}, error) {
	parts := strings.Split(key, ".")
	if len(parts) == 0 {
		return nil, fmt.Errorf("invalid key")
	}

	// Check cache
	if cached, exists := r.cache[key]; exists {
		if expiry, ok := r.cacheExpiry[key]; ok && time.Now().Before(expiry) {
			return cached, nil
		}
	}

	var value interface{}

	switch parts[0] {
	case "project":
		value = r.config.Project
	case "region":
		value = r.config.Region
	case "zone":
		value = r.config.Zone
	case "environment":
		value = r.config.Environment
	case "variables":
		if len(parts) > 1 {
			value = r.config.Variables[parts[1]]
		}
	case "tags":
		if len(parts) > 1 {
			value = r.config.Tags[parts[1]]
		}
	default:
		value = r.config.Variables[key]
	}

	// Cache the result
	r.cache[key] = value
	r.cacheExpiry[key] = time.Now().Add(5 * time.Minute)

	return value, nil
}

func (r *EnvResolver) ExpandVariables(input string) (string, error) {
	return r.resolveString(input)
}

func (r *EnvResolver) GetEnvVariable(key string) string {
	return r.getEnv(key)
}

func (r *EnvResolver) SetEnvVariable(key, value string) {
	r.envVars[key] = value
	os.Setenv(key, value)
}

func (r *EnvResolver) ClearCache() {
	r.cache = make(map[string]interface{})
	r.cacheExpiry = make(map[string]time.Time)
}