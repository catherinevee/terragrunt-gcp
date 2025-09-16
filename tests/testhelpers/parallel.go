package testhelpers

import (
	"sync"
	"testing"
	"time"
)

// ParallelTestConfig represents configuration for parallel test execution
type ParallelTestConfig struct {
	MaxConcurrency int
	Timeout        time.Duration
	RetryCount     int
	RetryDelay     time.Duration
}

// GetDefaultParallelTestConfig returns default parallel test configuration
func GetDefaultParallelTestConfig() *ParallelTestConfig {
	return &ParallelTestConfig{
		MaxConcurrency: 5,
		Timeout:        30 * time.Minute,
		RetryCount:     3,
		RetryDelay:     5 * time.Second,
	}
}

// RunParallelTests runs multiple tests in parallel
func RunParallelTests(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
	}

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, config.MaxConcurrency)

	for _, test := range tests {
		wg.Add(1)
		go func(testFunc func(*testing.T)) {
			defer wg.Done()

			// Acquire semaphore
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			// Run test with timeout
			done := make(chan bool, 1)
			go func() {
				testFunc(t)
				done <- true
			}()

			select {
			case <-done:
				// Test completed successfully
			case <-time.After(config.Timeout):
				t.Errorf("Test timed out after %v", config.Timeout)
			}
		}(test)
	}

	wg.Wait()
}

// RunParallelTestsWithRetry runs tests in parallel with retry logic
func RunParallelTestsWithRetry(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
	}

	var wg sync.WaitGroup
	semaphore := make(chan struct{}, config.MaxConcurrency)

	for _, test := range tests {
		wg.Add(1)
		go func(testFunc func(*testing.T)) {
			defer wg.Done()

			// Acquire semaphore
			semaphore <- struct{}{}
			defer func() { <-semaphore }()

			// Run test with retry logic
			for attempt := 0; attempt <= config.RetryCount; attempt++ {
				if attempt > 0 {
					t.Logf("Retrying test (attempt %d/%d)", attempt+1, config.RetryCount+1)
					time.Sleep(config.RetryDelay)
				}

				done := make(chan bool, 1)
				go func() {
					testFunc(t)
					done <- true
				}()

				select {
				case <-done:
					// Test completed successfully
					return
				case <-time.After(config.Timeout):
					if attempt == config.RetryCount {
						t.Errorf("Test timed out after %v (final attempt)", config.Timeout)
					} else {
						t.Logf("Test timed out after %v (attempt %d), retrying...", config.Timeout, attempt+1)
					}
				}
			}
		}(test)
	}

	wg.Wait()
}

// RunSequentialTests runs tests sequentially
func RunSequentialTests(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
	}

	for i, test := range tests {
		t.Logf("Running test %d/%d", i+1, len(tests))

		done := make(chan bool, 1)
		go func() {
			test(t)
			done <- true
		}()

		select {
		case <-done:
			// Test completed successfully
		case <-time.After(config.Timeout):
			t.Errorf("Test %d timed out after %v", i+1, config.Timeout)
		}
	}
}

// RunConditionalTests runs tests based on conditions
func RunConditionalTests(t *testing.T, testConditions []TestCondition) {
	for _, condition := range testConditions {
		if condition.Condition() {
			t.Logf("Running conditional test: %s", condition.Name)
			condition.Test(t)
		} else {
			t.Logf("Skipping conditional test: %s", condition.Name)
		}
	}
}

// TestCondition represents a conditional test
type TestCondition struct {
	Name      string
	Condition func() bool
	Test      func(*testing.T)
}

// RunEnvironmentSpecificTests runs tests based on environment
func RunEnvironmentSpecificTests(t *testing.T, environment string, tests map[string]func(*testing.T)) {
	envTests, exists := tests[environment]
	if !exists {
		t.Logf("No tests defined for environment: %s", environment)
		return
	}

	t.Logf("Running environment-specific tests for: %s", environment)
	envTests(t)
}

// RunResourceSpecificTests runs tests based on resource type
func RunResourceSpecificTests(t *testing.T, resourceType string, tests map[string]func(*testing.T)) {
	resourceTests, exists := tests[resourceType]
	if !exists {
		t.Logf("No tests defined for resource type: %s", resourceType)
		return
	}

	t.Logf("Running resource-specific tests for: %s", resourceType)
	resourceTests(t)
}

// RunPerformanceTests runs performance tests
func RunPerformanceTests(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
		config.MaxConcurrency = 1 // Performance tests should run sequentially
	}

	t.Log("Running performance tests")
	RunSequentialTests(t, tests, config)
}

// RunSecurityTests runs security tests
func RunSecurityTests(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
	}

	t.Log("Running security tests")
	RunParallelTests(t, tests, config)
}

// RunComplianceTests runs compliance tests
func RunComplianceTests(t *testing.T, tests []func(*testing.T), config *ParallelTestConfig) {
	if config == nil {
		config = GetDefaultParallelTestConfig()
	}

	t.Log("Running compliance tests")
	RunSequentialTests(t, tests, config)
}
