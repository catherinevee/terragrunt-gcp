package gcp

import (
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/iam/credentials/apiv1"
	"cloud.google.com/go/iam/credentials/apiv1/credentialspb"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"golang.org/x/oauth2/jwt"
	"google.golang.org/api/iamcredentials/v1"
	"google.golang.org/api/option"
	"google.golang.org/api/sts/v1"
)

// AuthProvider handles various authentication methods for GCP
type AuthProvider struct {
	mu sync.RWMutex

	config           *AuthConfig
	credentials      *google.Credentials
	tokenSource      oauth2.TokenSource
	serviceAccount   *ServiceAccountInfo
	workloadIdentity *WorkloadIdentityInfo
	oidcProvider     *OIDCProvider
	cache            *TokenCache
	logger           Logger
}

// AuthConfig contains authentication configuration
type AuthConfig struct {
	// Authentication method
	Type AuthType

	// Service Account authentication
	ServiceAccountKeyPath string
	ServiceAccountKeyJSON []byte
	ServiceAccountEmail   string

	// OAuth2 authentication
	ClientID     string
	ClientSecret string
	RefreshToken string
	AccessToken  string

	// Workload Identity Federation
	WorkloadIdentityPool     string
	WorkloadIdentityProvider string
	ServiceAccount          string
	CredentialSource        CredentialSource

	// OIDC authentication
	OIDCIssuer       string
	OIDCClientID     string
	OIDCClientSecret string
	OIDCAudience     string
	OIDCTokenURL     string

	// Impersonation
	ImpersonateServiceAccount string
	ImpersonateScopes        []string
	ImpersonateDelegates     []string
	ImpersonateLifetime      time.Duration

	// Common settings
	Scopes               []string
	Audience             string
	Subject              string
	TokenLifetime        time.Duration
	EnableCache          bool
	CacheTTL             time.Duration
	DisableAutoRefresh   bool
	CustomTokenEndpoint  string
	CustomStsEndpoint    string
}

// AuthType represents the authentication method
type AuthType string

const (
	AuthTypeDefault           AuthType = "default"
	AuthTypeServiceAccount    AuthType = "service_account"
	AuthTypeUser              AuthType = "user"
	AuthTypeImpersonated      AuthType = "impersonated"
	AuthTypeWorkloadIdentity  AuthType = "workload_identity"
	AuthTypeOIDC              AuthType = "oidc"
	AuthTypeAccessToken       AuthType = "access_token"
	AuthTypeExternal          AuthType = "external"
)

// ServiceAccountInfo contains service account details
type ServiceAccountInfo struct {
	Type                    string `json:"type"`
	ProjectID               string `json:"project_id"`
	PrivateKeyID            string `json:"private_key_id"`
	PrivateKey              string `json:"private_key"`
	ClientEmail             string `json:"client_email"`
	ClientID                string `json:"client_id"`
	AuthURI                 string `json:"auth_uri"`
	TokenURI                string `json:"token_uri"`
	AuthProviderX509CertURL string `json:"auth_provider_x509_cert_url"`
	ClientX509CertURL       string `json:"client_x509_cert_url"`
	UniverseDomain          string `json:"universe_domain,omitempty"`
}

// WorkloadIdentityInfo contains workload identity configuration
type WorkloadIdentityInfo struct {
	Pool              string
	Provider          string
	ServiceAccount    string
	CredentialSource  CredentialSource
	SubjectTokenType  string
	TokenURL          string
	ServiceAccountImpersonation *ServiceAccountImpersonation
	QuotaProjectID    string
	WorkforcePoolUserProject string
}

// CredentialSource represents the source of credentials for workload identity
type CredentialSource struct {
	File               string                 `json:"file,omitempty"`
	URL                string                 `json:"url,omitempty"`
	Executable         *ExecutableConfig      `json:"executable,omitempty"`
	EnvironmentID      string                 `json:"environment_id,omitempty"`
	RegionURL          string                 `json:"region_url,omitempty"`
	RegionalCredVerificationURL string        `json:"regional_cred_verification_url,omitempty"`
	IMDSv2SessionTokenURL string              `json:"imdsv2_session_token_url,omitempty"`
	Format             *CredentialFormat      `json:"format,omitempty"`
	Headers            map[string]string      `json:"headers,omitempty"`
}

// ExecutableConfig represents executable credential source configuration
type ExecutableConfig struct {
	Command       string            `json:"command"`
	TimeoutMillis int              `json:"timeout_millis,omitempty"`
	OutputFile    string            `json:"output_file,omitempty"`
	InteractiveTimeoutMillis int     `json:"interactive_timeout_millis,omitempty"`
}

// CredentialFormat represents the format of external credentials
type CredentialFormat struct {
	Type                string            `json:"type"`
	SubjectTokenFieldName string         `json:"subject_token_field_name,omitempty"`
}

// ServiceAccountImpersonation contains service account impersonation config
type ServiceAccountImpersonation struct {
	TokenLifetimeSeconds int `json:"token_lifetime_seconds,omitempty"`
}

// OIDCProvider handles OIDC authentication
type OIDCProvider struct {
	mu sync.RWMutex

	issuer       string
	clientID     string
	clientSecret string
	audience     string
	tokenURL     string
	jwksURL      string
	userInfoURL  string
	nonce        string
	state        string
	redirectURI  string
	scopes       []string
	httpClient   *http.Client
	jwks         *JSONWebKeySet
	lastUpdate   time.Time
}

// JSONWebKeySet represents a set of JSON Web Keys
type JSONWebKeySet struct {
	Keys []JSONWebKey `json:"keys"`
}

// JSONWebKey represents a single JSON Web Key
type JSONWebKey struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
	X5c []string `json:"x5c,omitempty"`
}

// TokenCache caches authentication tokens
type TokenCache struct {
	mu     sync.RWMutex
	tokens map[string]*CachedToken
	ttl    time.Duration
}

// CachedToken represents a cached token
type CachedToken struct {
	Token     *oauth2.Token
	ExpiresAt time.Time
	Scopes    []string
}

// TokenInfo contains token information
type TokenInfo struct {
	AccessToken  string    `json:"access_token"`
	TokenType    string    `json:"token_type"`
	ExpiresIn    int       `json:"expires_in"`
	RefreshToken string    `json:"refresh_token,omitempty"`
	Scope        string    `json:"scope,omitempty"`
	IDToken      string    `json:"id_token,omitempty"`
	ExpiresAt    time.Time `json:"expires_at"`
}

// ImpersonatedTokenSource provides tokens for service account impersonation
type ImpersonatedTokenSource struct {
	mu sync.RWMutex

	targetServiceAccount string
	scopes              []string
	delegates           []string
	lifetime            time.Duration
	baseTokenSource     oauth2.TokenSource
	client              *iamcredentials.Service
	currentToken        *oauth2.Token
}

// NewAuthProvider creates a new authentication provider
func NewAuthProvider(config *AuthConfig, opts ...AuthOption) (*AuthProvider, error) {
	provider := &AuthProvider{
		config: config,
	}

	// Apply options
	for _, opt := range opts {
		if err := opt(provider); err != nil {
			return nil, fmt.Errorf("applying auth option: %w", err)
		}
	}

	// Initialize token cache if enabled
	if config.EnableCache {
		provider.cache = NewTokenCache(config.CacheTTL)
	}

	// Initialize based on auth type
	if err := provider.initialize(); err != nil {
		return nil, fmt.Errorf("initializing auth provider: %w", err)
	}

	return provider, nil
}

// AuthOption is a function that configures an AuthProvider
type AuthOption func(*AuthProvider) error

// WithLogger sets the logger for the auth provider
func WithLogger(logger Logger) AuthOption {
	return func(p *AuthProvider) error {
		p.logger = logger
		return nil
	}
}

// initialize initializes the auth provider based on the configured type
func (p *AuthProvider) initialize() error {
	ctx := context.Background()

	switch p.config.Type {
	case AuthTypeServiceAccount:
		return p.initializeServiceAccount(ctx)
	case AuthTypeWorkloadIdentity:
		return p.initializeWorkloadIdentity(ctx)
	case AuthTypeOIDC:
		return p.initializeOIDC(ctx)
	case AuthTypeImpersonated:
		return p.initializeImpersonation(ctx)
	case AuthTypeAccessToken:
		return p.initializeAccessToken(ctx)
	case AuthTypeUser:
		return p.initializeUserAuth(ctx)
	case AuthTypeDefault, "":
		return p.initializeDefault(ctx)
	default:
		return fmt.Errorf("unsupported auth type: %s", p.config.Type)
	}
}

// initializeServiceAccount initializes service account authentication
func (p *AuthProvider) initializeServiceAccount(ctx context.Context) error {
	var keyData []byte
	var err error

	if len(p.config.ServiceAccountKeyJSON) > 0 {
		keyData = p.config.ServiceAccountKeyJSON
	} else if p.config.ServiceAccountKeyPath != "" {
		keyData, err = os.ReadFile(p.config.ServiceAccountKeyPath)
		if err != nil {
			return fmt.Errorf("reading service account key file: %w", err)
		}
	} else {
		return fmt.Errorf("service account key not provided")
	}

	// Parse service account info
	var saInfo ServiceAccountInfo
	if err := json.Unmarshal(keyData, &saInfo); err != nil {
		return fmt.Errorf("parsing service account key: %w", err)
	}

	p.serviceAccount = &saInfo

	// Create JWT config
	jwtConfig := &jwt.Config{
		Email:        saInfo.ClientEmail,
		PrivateKey:   []byte(saInfo.PrivateKey),
		PrivateKeyID: saInfo.PrivateKeyID,
		Scopes:       p.config.Scopes,
		TokenURL:     saInfo.TokenURI,
		Subject:      p.config.Subject,
		Audience:     p.config.Audience,
	}

	// Handle custom token endpoint
	if p.config.CustomTokenEndpoint != "" {
		jwtConfig.TokenURL = p.config.CustomTokenEndpoint
	}

	p.tokenSource = jwtConfig.TokenSource(ctx)

	// Create credentials
	p.credentials = &google.Credentials{
		ProjectID:   saInfo.ProjectID,
		TokenSource: p.tokenSource,
		JSON:        keyData,
	}

	return nil
}

// initializeWorkloadIdentity initializes workload identity federation
func (p *AuthProvider) initializeWorkloadIdentity(ctx context.Context) error {
	wlInfo := &WorkloadIdentityInfo{
		Pool:             p.config.WorkloadIdentityPool,
		Provider:         p.config.WorkloadIdentityProvider,
		ServiceAccount:   p.config.ServiceAccount,
		CredentialSource: p.config.CredentialSource,
		SubjectTokenType: "urn:ietf:params:oauth:token-type:jwt",
		TokenURL:         "https://sts.googleapis.com/v1/token",
		QuotaProjectID:   p.config.ServiceAccount,
	}

	// Handle custom STS endpoint
	if p.config.CustomStsEndpoint != "" {
		wlInfo.TokenURL = p.config.CustomStsEndpoint
	}

	// Configure service account impersonation if specified
	if p.config.ImpersonateServiceAccount != "" {
		wlInfo.ServiceAccountImpersonation = &ServiceAccountImpersonation{
			TokenLifetimeSeconds: int(p.config.ImpersonateLifetime.Seconds()),
		}
	}

	p.workloadIdentity = wlInfo

	// Create workload identity token source
	tokenSource, err := p.createWorkloadIdentityTokenSource(ctx, wlInfo)
	if err != nil {
		return fmt.Errorf("creating workload identity token source: %w", err)
	}

	p.tokenSource = tokenSource

	// Create credentials
	p.credentials = &google.Credentials{
		TokenSource: p.tokenSource,
	}

	return nil
}

// createWorkloadIdentityTokenSource creates a token source for workload identity
func (p *AuthProvider) createWorkloadIdentityTokenSource(ctx context.Context, wlInfo *WorkloadIdentityInfo) (oauth2.TokenSource, error) {
	// Get subject token from credential source
	subjectToken, err := p.getSubjectToken(ctx, wlInfo.CredentialSource)
	if err != nil {
		return nil, fmt.Errorf("getting subject token: %w", err)
	}

	// Exchange for access token
	stsClient, err := sts.NewService(ctx)
	if err != nil {
		return nil, fmt.Errorf("creating STS client: %w", err)
	}

	audience := fmt.Sprintf("//iam.googleapis.com/%s", wlInfo.Pool)

	req := &sts.GoogleIdentityStsV1ExchangeTokenRequest{
		Audience:           audience,
		GrantType:          "urn:ietf:params:oauth:grant-type:token-exchange",
		RequestedTokenType: "urn:ietf:params:oauth:token-type:access_token",
		Scope:              strings.Join(p.config.Scopes, " "),
		SubjectToken:       subjectToken,
		SubjectTokenType:   wlInfo.SubjectTokenType,
	}

	resp, err := stsClient.V1.Token(req).Do()
	if err != nil {
		return nil, fmt.Errorf("exchanging token: %w", err)
	}

	// Create token source from response
	token := &oauth2.Token{
		AccessToken: resp.AccessToken,
		TokenType:   resp.TokenType,
		Expiry:      time.Now().Add(time.Duration(resp.ExpiresIn) * time.Second),
	}

	// If service account impersonation is needed
	if wlInfo.ServiceAccount != "" {
		return p.createImpersonatedTokenSource(ctx, oauth2.StaticTokenSource(token), wlInfo.ServiceAccount)
	}

	return oauth2.StaticTokenSource(token), nil
}

// getSubjectToken retrieves the subject token from the credential source
func (p *AuthProvider) getSubjectToken(ctx context.Context, source CredentialSource) (string, error) {
	// File-based credential source
	if source.File != "" {
		data, err := os.ReadFile(source.File)
		if err != nil {
			return "", fmt.Errorf("reading credential file: %w", err)
		}

		if source.Format != nil && source.Format.Type == "json" {
			var result map[string]interface{}
			if err := json.Unmarshal(data, &result); err != nil {
				return "", fmt.Errorf("parsing JSON credential: %w", err)
			}

			if source.Format.SubjectTokenFieldName != "" {
				if token, ok := result[source.Format.SubjectTokenFieldName].(string); ok {
					return token, nil
				}
				return "", fmt.Errorf("subject token field not found")
			}
		}

		return string(data), nil
	}

	// URL-based credential source
	if source.URL != "" {
		req, err := http.NewRequestWithContext(ctx, "GET", source.URL, nil)
		if err != nil {
			return "", fmt.Errorf("creating request: %w", err)
		}

		// Add headers if specified
		for k, v := range source.Headers {
			req.Header.Set(k, v)
		}

		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			return "", fmt.Errorf("fetching credential: %w", err)
		}
		defer resp.Body.Close()

		data, err := io.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("reading response: %w", err)
		}

		if source.Format != nil && source.Format.Type == "json" {
			var result map[string]interface{}
			if err := json.Unmarshal(data, &result); err != nil {
				return "", fmt.Errorf("parsing JSON credential: %w", err)
			}

			if source.Format.SubjectTokenFieldName != "" {
				if token, ok := result[source.Format.SubjectTokenFieldName].(string); ok {
					return token, nil
				}
				return "", fmt.Errorf("subject token field not found")
			}
		}

		return string(data), nil
	}

	// Executable-based credential source
	if source.Executable != nil {
		return p.getExecutableToken(ctx, source.Executable)
	}

	// Environment-based (AWS/Azure metadata)
	if source.EnvironmentID != "" {
		return p.getEnvironmentToken(ctx, source)
	}

	return "", fmt.Errorf("no valid credential source specified")
}

// getExecutableToken retrieves token from an executable
func (p *AuthProvider) getExecutableToken(ctx context.Context, config *ExecutableConfig) (string, error) {
	// Implementation would execute the command and parse output
	// This is a placeholder
	return "", fmt.Errorf("executable credential source not implemented")
}

// getEnvironmentToken retrieves token from environment (AWS/Azure metadata)
func (p *AuthProvider) getEnvironmentToken(ctx context.Context, source CredentialSource) (string, error) {
	// Implementation would query AWS/Azure metadata service
	// This is a placeholder
	return "", fmt.Errorf("environment credential source not implemented")
}

// initializeOIDC initializes OIDC authentication
func (p *AuthProvider) initializeOIDC(ctx context.Context) error {
	oidcProvider := &OIDCProvider{
		issuer:       p.config.OIDCIssuer,
		clientID:     p.config.OIDCClientID,
		clientSecret: p.config.OIDCClientSecret,
		audience:     p.config.OIDCAudience,
		tokenURL:     p.config.OIDCTokenURL,
		scopes:       p.config.Scopes,
		httpClient:   &http.Client{Timeout: 30 * time.Second},
	}

	// Discover OIDC endpoints
	if err := oidcProvider.discover(ctx); err != nil {
		return fmt.Errorf("discovering OIDC endpoints: %w", err)
	}

	p.oidcProvider = oidcProvider

	// Create OIDC token source
	tokenSource, err := oidcProvider.createTokenSource(ctx)
	if err != nil {
		return fmt.Errorf("creating OIDC token source: %w", err)
	}

	p.tokenSource = tokenSource

	// Create credentials
	p.credentials = &google.Credentials{
		TokenSource: p.tokenSource,
	}

	return nil
}

// discover performs OIDC discovery
func (o *OIDCProvider) discover(ctx context.Context) error {
	discoveryURL := strings.TrimSuffix(o.issuer, "/") + "/.well-known/openid-configuration"

	req, err := http.NewRequestWithContext(ctx, "GET", discoveryURL, nil)
	if err != nil {
		return fmt.Errorf("creating discovery request: %w", err)
	}

	resp, err := o.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("performing discovery: %w", err)
	}
	defer resp.Body.Close()

	var discovery struct {
		TokenEndpoint     string `json:"token_endpoint"`
		JwksURI          string `json:"jwks_uri"`
		UserInfoEndpoint string `json:"userinfo_endpoint"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&discovery); err != nil {
		return fmt.Errorf("parsing discovery response: %w", err)
	}

	if o.tokenURL == "" {
		o.tokenURL = discovery.TokenEndpoint
	}
	o.jwksURL = discovery.JwksURI
	o.userInfoURL = discovery.UserInfoEndpoint

	// Fetch JWKS
	if o.jwksURL != "" {
		if err := o.fetchJWKS(ctx); err != nil {
			return fmt.Errorf("fetching JWKS: %w", err)
		}
	}

	return nil
}

// fetchJWKS fetches the JSON Web Key Set
func (o *OIDCProvider) fetchJWKS(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, "GET", o.jwksURL, nil)
	if err != nil {
		return fmt.Errorf("creating JWKS request: %w", err)
	}

	resp, err := o.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("fetching JWKS: %w", err)
	}
	defer resp.Body.Close()

	var jwks JSONWebKeySet
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return fmt.Errorf("parsing JWKS: %w", err)
	}

	o.mu.Lock()
	o.jwks = &jwks
	o.lastUpdate = time.Now()
	o.mu.Unlock()

	return nil
}

// createTokenSource creates an OAuth2 token source for OIDC
func (o *OIDCProvider) createTokenSource(ctx context.Context) (oauth2.TokenSource, error) {
	config := &oauth2.Config{
		ClientID:     o.clientID,
		ClientSecret: o.clientSecret,
		Endpoint: oauth2.Endpoint{
			TokenURL: o.tokenURL,
		},
		Scopes: o.scopes,
	}

	// For now, return a static token source
	// In a real implementation, this would handle the OIDC flow
	token := &oauth2.Token{
		AccessToken: "oidc-token-placeholder",
		TokenType:   "Bearer",
		Expiry:      time.Now().Add(1 * time.Hour),
	}

	return oauth2.StaticTokenSource(token), nil
}

// initializeImpersonation initializes service account impersonation
func (p *AuthProvider) initializeImpersonation(ctx context.Context) error {
	// First get base credentials
	baseCreds, err := google.FindDefaultCredentials(ctx, p.config.Scopes...)
	if err != nil {
		return fmt.Errorf("finding base credentials: %w", err)
	}

	// Create impersonated token source
	tokenSource, err := p.createImpersonatedTokenSource(ctx, baseCreds.TokenSource, p.config.ImpersonateServiceAccount)
	if err != nil {
		return fmt.Errorf("creating impersonated token source: %w", err)
	}

	p.tokenSource = tokenSource

	// Create credentials
	p.credentials = &google.Credentials{
		ProjectID:   baseCreds.ProjectID,
		TokenSource: p.tokenSource,
	}

	return nil
}

// createImpersonatedTokenSource creates a token source for service account impersonation
func (p *AuthProvider) createImpersonatedTokenSource(ctx context.Context, baseTokenSource oauth2.TokenSource, targetServiceAccount string) (oauth2.TokenSource, error) {
	// Create IAM credentials client
	httpClient := oauth2.NewClient(ctx, baseTokenSource)
	iamClient, err := iamcredentials.NewService(ctx, option.WithHTTPClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("creating IAM credentials client: %w", err)
	}

	its := &ImpersonatedTokenSource{
		targetServiceAccount: targetServiceAccount,
		scopes:              p.config.ImpersonateScopes,
		delegates:           p.config.ImpersonateDelegates,
		lifetime:            p.config.ImpersonateLifetime,
		baseTokenSource:     baseTokenSource,
		client:              iamClient,
	}

	return its, nil
}

// Token returns an access token for the impersonated service account
func (its *ImpersonatedTokenSource) Token() (*oauth2.Token, error) {
	its.mu.RLock()
	if its.currentToken != nil && its.currentToken.Valid() {
		its.mu.RUnlock()
		return its.currentToken, nil
	}
	its.mu.RUnlock()

	its.mu.Lock()
	defer its.mu.Unlock()

	// Double-check after acquiring write lock
	if its.currentToken != nil && its.currentToken.Valid() {
		return its.currentToken, nil
	}

	// Generate access token
	name := fmt.Sprintf("projects/-/serviceAccounts/%s", its.targetServiceAccount)
	req := &iamcredentials.GenerateAccessTokenRequest{
		Scope:     its.scopes,
		Delegates: its.delegates,
		Lifetime:  fmt.Sprintf("%ds", int(its.lifetime.Seconds())),
	}

	resp, err := its.client.Projects.ServiceAccounts.GenerateAccessToken(name, req).Do()
	if err != nil {
		return nil, fmt.Errorf("generating access token: %w", err)
	}

	expireTime, err := time.Parse(time.RFC3339, resp.ExpireTime)
	if err != nil {
		return nil, fmt.Errorf("parsing expire time: %w", err)
	}

	token := &oauth2.Token{
		AccessToken: resp.AccessToken,
		TokenType:   "Bearer",
		Expiry:      expireTime,
	}

	its.currentToken = token
	return token, nil
}

// initializeAccessToken initializes with a static access token
func (p *AuthProvider) initializeAccessToken(ctx context.Context) error {
	if p.config.AccessToken == "" {
		return fmt.Errorf("access token not provided")
	}

	token := &oauth2.Token{
		AccessToken: p.config.AccessToken,
		TokenType:   "Bearer",
		// Set a far future expiry for static tokens
		Expiry: time.Now().Add(365 * 24 * time.Hour),
	}

	p.tokenSource = oauth2.StaticTokenSource(token)

	// Create credentials
	p.credentials = &google.Credentials{
		TokenSource: p.tokenSource,
	}

	return nil
}

// initializeUserAuth initializes user authentication (3-legged OAuth)
func (p *AuthProvider) initializeUserAuth(ctx context.Context) error {
	config := &oauth2.Config{
		ClientID:     p.config.ClientID,
		ClientSecret: p.config.ClientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       p.config.Scopes,
	}

	// If refresh token is available, use it
	if p.config.RefreshToken != "" {
		token := &oauth2.Token{
			RefreshToken: p.config.RefreshToken,
		}
		p.tokenSource = config.TokenSource(ctx, token)
	} else {
		// Would need to implement OAuth flow here
		return fmt.Errorf("user authentication requires OAuth flow implementation")
	}

	// Create credentials
	p.credentials = &google.Credentials{
		TokenSource: p.tokenSource,
	}

	return nil
}

// initializeDefault initializes with application default credentials
func (p *AuthProvider) initializeDefault(ctx context.Context) error {
	creds, err := google.FindDefaultCredentials(ctx, p.config.Scopes...)
	if err != nil {
		return fmt.Errorf("finding default credentials: %w", err)
	}

	p.credentials = creds
	p.tokenSource = creds.TokenSource

	return nil
}

// GetCredentials returns the Google credentials
func (p *AuthProvider) GetCredentials() *google.Credentials {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.credentials
}

// GetTokenSource returns the OAuth2 token source
func (p *AuthProvider) GetTokenSource() oauth2.TokenSource {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.tokenSource
}

// GetToken returns a valid access token
func (p *AuthProvider) GetToken(ctx context.Context) (*oauth2.Token, error) {
	// Check cache first
	if p.cache != nil {
		if token := p.cache.Get(p.getCacheKey()); token != nil {
			return token.Token, nil
		}
	}

	// Get token from source
	token, err := p.tokenSource.Token()
	if err != nil {
		return nil, fmt.Errorf("getting token: %w", err)
	}

	// Cache the token
	if p.cache != nil {
		p.cache.Put(p.getCacheKey(), token, p.config.Scopes)
	}

	return token, nil
}

// RefreshToken forces a token refresh
func (p *AuthProvider) RefreshToken(ctx context.Context) (*oauth2.Token, error) {
	// Clear cache
	if p.cache != nil {
		p.cache.Delete(p.getCacheKey())
	}

	// Get fresh token
	return p.GetToken(ctx)
}

// getCacheKey generates a cache key for the current auth configuration
func (p *AuthProvider) getCacheKey() string {
	parts := []string{string(p.config.Type)}

	switch p.config.Type {
	case AuthTypeServiceAccount:
		if p.serviceAccount != nil {
			parts = append(parts, p.serviceAccount.ClientEmail)
		}
	case AuthTypeImpersonated:
		parts = append(parts, p.config.ImpersonateServiceAccount)
	case AuthTypeWorkloadIdentity:
		if p.workloadIdentity != nil {
			parts = append(parts, p.workloadIdentity.Pool, p.workloadIdentity.Provider)
		}
	case AuthTypeOIDC:
		if p.oidcProvider != nil {
			parts = append(parts, p.oidcProvider.clientID)
		}
	}

	// Add scopes to key
	parts = append(parts, strings.Join(p.config.Scopes, ","))

	return strings.Join(parts, ":")
}

// ValidateToken validates an access token
func (p *AuthProvider) ValidateToken(ctx context.Context, token string) (*TokenInfo, error) {
	// Use Google's tokeninfo endpoint
	url := fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?access_token=%s", url.QueryEscape(token))

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("validating token: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("token validation failed: status %d", resp.StatusCode)
	}

	var info TokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, fmt.Errorf("parsing response: %w", err)
	}

	// Calculate expiry time
	info.ExpiresAt = time.Now().Add(time.Duration(info.ExpiresIn) * time.Second)

	return &info, nil
}

// GetProjectID attempts to determine the GCP project ID
func (p *AuthProvider) GetProjectID(ctx context.Context) (string, error) {
	if p.credentials != nil && p.credentials.ProjectID != "" {
		return p.credentials.ProjectID, nil
	}

	if p.serviceAccount != nil && p.serviceAccount.ProjectID != "" {
		return p.serviceAccount.ProjectID, nil
	}

	// Try to get from metadata service
	projectID, err := p.getProjectIDFromMetadata(ctx)
	if err == nil && projectID != "" {
		return projectID, nil
	}

	// Try environment variable
	if projectID := os.Getenv("GOOGLE_CLOUD_PROJECT"); projectID != "" {
		return projectID, nil
	}

	if projectID := os.Getenv("GCP_PROJECT"); projectID != "" {
		return projectID, nil
	}

	return "", fmt.Errorf("unable to determine project ID")
}

// getProjectIDFromMetadata gets project ID from metadata service
func (p *AuthProvider) getProjectIDFromMetadata(ctx context.Context) (string, error) {
	url := "http://metadata.google.internal/computeMetadata/v1/project/project-id"

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return "", err
	}

	req.Header.Set("Metadata-Flavor", "Google")

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("metadata request failed: status %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

// NewTokenCache creates a new token cache
func NewTokenCache(ttl time.Duration) *TokenCache {
	return &TokenCache{
		tokens: make(map[string]*CachedToken),
		ttl:    ttl,
	}
}

// Get retrieves a token from the cache
func (c *TokenCache) Get(key string) *CachedToken {
	c.mu.RLock()
	defer c.mu.RUnlock()

	token, exists := c.tokens[key]
	if !exists {
		return nil
	}

	if time.Now().After(token.ExpiresAt) {
		return nil
	}

	return token
}

// Put stores a token in the cache
func (c *TokenCache) Put(key string, token *oauth2.Token, scopes []string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	expiresAt := token.Expiry
	if c.ttl > 0 && time.Now().Add(c.ttl).Before(expiresAt) {
		expiresAt = time.Now().Add(c.ttl)
	}

	c.tokens[key] = &CachedToken{
		Token:     token,
		ExpiresAt: expiresAt,
		Scopes:    scopes,
	}

	// Clean up expired tokens
	c.cleanup()
}

// Delete removes a token from the cache
func (c *TokenCache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.tokens, key)
}

// cleanup removes expired tokens
func (c *TokenCache) cleanup() {
	now := time.Now()
	for key, token := range c.tokens {
		if now.After(token.ExpiresAt) {
			delete(c.tokens, key)
		}
	}
}

// Clear removes all tokens from the cache
func (c *TokenCache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.tokens = make(map[string]*CachedToken)
}