package core

import (
	"context"
	"fmt"
	"sync"
	"time"
)

type DiscoveryEngine struct {
	providers map[string]Provider
	config    DiscoveryConfig
	mutex     sync.RWMutex
}

func NewDiscoveryEngine(config DiscoveryConfig) *DiscoveryEngine {
	return &DiscoveryEngine{
		providers: make(map[string]Provider),
		config:    config,
	}
}

func (de *DiscoveryEngine) RegisterProvider(name string, provider Provider) {
	de.mutex.Lock()
	defer de.mutex.Unlock()
	de.providers[name] = provider
}

func (de *DiscoveryEngine) UnregisterProvider(name string) {
	de.mutex.Lock()
	defer de.mutex.Unlock()
	delete(de.providers, name)
}

func (de *DiscoveryEngine) GetProvider(name string) (Provider, bool) {
	de.mutex.RLock()
	defer de.mutex.RUnlock()
	provider, exists := de.providers[name]
	return provider, exists
}

func (de *DiscoveryEngine) ListProviders() []string {
	de.mutex.RLock()
	defer de.mutex.RUnlock()

	var names []string
	for name := range de.providers {
		names = append(names, name)
	}
	return names
}

func (de *DiscoveryEngine) DiscoverAll(ctx context.Context) (*DiscoveryResult, error) {
	result := &DiscoveryResult{
		StartTime: time.Now(),
		Summary: DiscoverySummary{
			ResourcesByType:    make(map[string]int),
			ResourcesByRegion:  make(map[string]int),
			ResourcesByStatus:  make(map[string]int),
		},
	}

	de.mutex.RLock()
	providers := make(map[string]Provider)
	for name, provider := range de.providers {
		providers[name] = provider
	}
	de.mutex.RUnlock()

	if len(providers) == 0 {
		return result, fmt.Errorf("no providers registered")
	}

	var wg sync.WaitGroup
	resultChan := make(chan DiscoveryResult, len(providers))
	errorChan := make(chan DiscoveryError, len(providers))

	semaphore := make(chan struct{}, de.config.MaxConcurrency)

	for providerName, provider := range providers {
		wg.Add(1)
		go func(name string, p Provider) {
			defer wg.Done()
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			providerResult := de.discoverProvider(ctx, name, p)
			resultChan <- providerResult
		}(providerName, provider)
	}

	go func() {
		wg.Wait()
		close(resultChan)
		close(errorChan)
	}()

	for providerResult := range resultChan {
		for _, account := range providerResult.Accounts {
			result.AddAccount(account)
		}
		for _, resource := range providerResult.Resources {
			result.AddResource(resource)
		}
		for _, err := range providerResult.Errors {
			result.AddError(err)
		}
	}

	result.EndTime = time.Now()
	result.Duration = result.EndTime.Sub(result.StartTime)

	return result, nil
}

func (de *DiscoveryEngine) discoverProvider(ctx context.Context, providerName string, provider Provider) DiscoveryResult {
	result := DiscoveryResult{
		StartTime: time.Now(),
		Summary: DiscoverySummary{
			ResourcesByType:    make(map[string]int),
			ResourcesByRegion:  make(map[string]int),
			ResourcesByStatus:  make(map[string]int),
		},
	}

	ctxWithTimeout, cancel := context.WithTimeout(ctx, de.config.Timeout)
	defer cancel()

	accounts, err := de.discoverAccountsWithRetry(ctxWithTimeout, provider)
	if err != nil {
		result.AddError(DiscoveryError{
			Provider:  providerName,
			Error:     fmt.Sprintf("failed to discover accounts: %v", err),
			Timestamp: time.Now(),
			Retryable: true,
		})
		return result
	}

	for _, account := range accounts {
		if de.shouldIncludeAccount(account) {
			result.AddAccount(account)

			resources, err := de.discoverResourcesWithRetry(ctxWithTimeout, provider, account)
			if err != nil {
				result.AddError(DiscoveryError{
					Provider:  providerName,
					Account:   account.ID,
					Error:     fmt.Sprintf("failed to discover resources: %v", err),
					Timestamp: time.Now(),
					Retryable: true,
				})
				continue
			}

			for _, resource := range resources {
				if de.shouldIncludeResource(resource) {
					result.AddResource(resource)
				}
			}
		}
	}

	result.EndTime = time.Now()
	result.Duration = result.EndTime.Sub(result.StartTime)

	return result
}

func (de *DiscoveryEngine) discoverAccountsWithRetry(ctx context.Context, provider Provider) ([]Account, error) {
	var lastErr error

	for attempt := 0; attempt <= de.config.RetryAttempts; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(de.config.RetryDelay):
			}
		}

		accounts, err := provider.DiscoverAccounts(ctx)
		if err == nil {
			return accounts, nil
		}

		lastErr = err

		if !de.isRetryableError(err) {
			break
		}
	}

	return nil, lastErr
}

func (de *DiscoveryEngine) discoverResourcesWithRetry(ctx context.Context, provider Provider, account Account) ([]Resource, error) {
	var lastErr error

	for attempt := 0; attempt <= de.config.RetryAttempts; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(de.config.RetryDelay):
			}
		}

		resources, err := provider.DiscoverResources(ctx, account)
		if err == nil {
			return resources, nil
		}

		lastErr = err

		if !de.isRetryableError(err) {
			break
		}
	}

	return nil, lastErr
}

func (de *DiscoveryEngine) shouldIncludeAccount(account Account) bool {
	for _, filter := range de.config.AccountFilters {
		if de.matchesAccountFilter(account, filter) {
			return filter.Include
		}
	}
	return true
}

func (de *DiscoveryEngine) shouldIncludeResource(resource Resource) bool {
	for _, filter := range de.config.ResourceFilters {
		if de.matchesResourceFilter(resource, filter) {
			return filter.Include
		}
	}
	return true
}

func (de *DiscoveryEngine) matchesAccountFilter(account Account, filter AccountFilter) bool {
	if filter.ID != "" && account.ID != filter.ID {
		return false
	}
	if filter.Name != "" && account.Name != filter.Name {
		return false
	}
	if filter.Type != "" && account.Type != filter.Type {
		return false
	}
	return true
}

func (de *DiscoveryEngine) matchesResourceFilter(resource Resource, filter ResourceFilter) bool {
	if filter.Type != "" && resource.Type != filter.Type {
		return false
	}
	if filter.Region != "" && resource.Region != filter.Region {
		return false
	}

	for key, value := range filter.Tags {
		if resourceValue, exists := resource.Tags[key]; !exists || resourceValue != value {
			return false
		}
	}

	return true
}

func (de *DiscoveryEngine) isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	errorStr := err.Error()

	retryableErrors := []string{
		"timeout",
		"rate limit",
		"throttle",
		"too many requests",
		"temporary failure",
		"connection reset",
		"connection refused",
		"network",
	}

	for _, retryable := range retryableErrors {
		if contains(errorStr, retryable) {
			return true
		}
	}

	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr ||
		(len(s) > len(substr) &&
			(s[:len(substr)] == substr ||
			 s[len(s)-len(substr):] == substr ||
			 containsSubstring(s, substr))))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// DiscoverWithOptions uses options defined in discoverer.go
func (de *DiscoveryEngine) DiscoverWithOptions(ctx context.Context, options DiscoveryOptions) (*DiscoveryResult, error) {
	oldConfig := de.config

	// Fields not available in DiscoveryOptions
	// de.config.AccountFilters = options.AccountFilters
	// de.config.ResourceFilters = options.ResourceFilters
	// if options.MaxConcurrency > 0 {
	// 	de.config.MaxConcurrency = options.MaxConcurrency
	// }
	if options.Timeout > 0 {
		de.config.Timeout = options.Timeout
	}
	if options.RetryAttempts >= 0 {
		de.config.RetryAttempts = options.RetryAttempts
	}
	if options.RetryDelay > 0 {
		de.config.RetryDelay = options.RetryDelay
	}

	defer func() {
		de.config = oldConfig
	}()

	// Providers field not available in DiscoveryOptions
	if true { // len(options.Providers) == 0 {
		return de.DiscoverAll(ctx)
	}

	result := &DiscoveryResult{
		StartTime: time.Now(),
		Summary: DiscoverySummary{
			ResourcesByType:    make(map[string]int),
			ResourcesByRegion:  make(map[string]int),
			ResourcesByStatus:  make(map[string]int),
		},
	}

	// Providers field not available in DiscoveryOptions
	/*for _, providerName := range options.Providers {
		provider, exists := de.GetProvider(providerName)
		if !exists {
			result.AddError(DiscoveryError{
				Provider:  providerName,
				Error:     "provider not found",
				Timestamp: time.Now(),
				Retryable: false,
			})
			continue
		}

		providerResult := de.discoverProvider(ctx, providerName, provider)
		for _, account := range providerResult.Accounts {
			result.AddAccount(account)
		}
		for _, resource := range providerResult.Resources {
			result.AddResource(resource)
		}
		for _, err := range providerResult.Errors {
			result.AddError(err)
		}
	}*/

	result.EndTime = time.Now()
	result.Duration = result.EndTime.Sub(result.StartTime)

	return result, nil
}