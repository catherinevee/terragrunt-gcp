package core

import (
	"context"
	"time"
)

type Provider interface {
	Name() string
	DiscoverAccounts(ctx context.Context) ([]Account, error)
	DiscoverResources(ctx context.Context, account Account) ([]Resource, error)
	ValidateConfig() error
	GetConfig() interface{}
}

type CloudProvider interface {
	Provider
	GetRegions(ctx context.Context) ([]string, error)
	GetServices(ctx context.Context) ([]string, error)
}

type ProviderFactory interface {
	CreateProvider(config interface{}) (Provider, error)
	SupportedProviders() []string
}

type ProviderRegistry struct {
	providers map[string]ProviderFactory
}

func NewProviderRegistry() *ProviderRegistry {
	return &ProviderRegistry{
		providers: make(map[string]ProviderFactory),
	}
}

func (r *ProviderRegistry) Register(name string, factory ProviderFactory) {
	r.providers[name] = factory
}

func (r *ProviderRegistry) Create(name string, config interface{}) (Provider, error) {
	factory, exists := r.providers[name]
	if !exists {
		return nil, &ProviderNotFoundError{Provider: name}
	}
	return factory.CreateProvider(config)
}

func (r *ProviderRegistry) List() []string {
	var names []string
	for name := range r.providers {
		names = append(names, name)
	}
	return names
}

type ProviderNotFoundError struct {
	Provider string
}

func (e *ProviderNotFoundError) Error() string {
	return "provider not found: " + e.Provider
}

type ProviderConfigError struct {
	Provider string
	Message  string
}

func (e *ProviderConfigError) Error() string {
	return "provider config error for " + e.Provider + ": " + e.Message
}

type DiscoveryConfig struct {
	MaxConcurrency    int
	Timeout          time.Duration
	RetryAttempts    int
	RetryDelay       time.Duration
	ResourceFilters  []ResourceFilter
	AccountFilters   []AccountFilter
}

type ResourceFilter struct {
	Type    string
	Region  string
	Tags    map[string]string
	Include bool
}

type AccountFilter struct {
	ID      string
	Name    string
	Type    string
	Include bool
}