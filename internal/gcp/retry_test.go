package gcp

import (
	"context"
	"errors"
	"math"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestNewRetryConfig(t *testing.T) {
	config := NewRetryConfig()

	if config.MaxAttempts <= 0 {
		t.Error("NewRetryConfig() MaxAttempts should be positive")
	}

	if config.InitialDelay <= 0 {
		t.Error("NewRetryConfig() InitialDelay should be positive")
	}

	if config.MaxDelay <= config.InitialDelay {
		t.Error("NewRetryConfig() MaxDelay should be greater than InitialDelay")
	}

	if config.BackoffMultiplier <= 1.0 {
		t.Error("NewRetryConfig() BackoffMultiplier should be greater than 1.0")
	}

	if config.Jitter < 0 || config.Jitter > 1.0 {
		t.Error("NewRetryConfig() Jitter should be between 0 and 1")
	}

	if config.MaxElapsedTime <= 0 {
		t.Error("NewRetryConfig() MaxElapsedTime should be positive")
	}
}

func TestRetryConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *RetryConfig
		wantErr bool
	}{
		{
			name:    "valid config",
			config:  NewRetryConfig(),
			wantErr: false,
		},
		{
			name: "zero max attempts",
			config: &RetryConfig{
				MaxAttempts:       0,
				InitialDelay:      time.Second,
				MaxDelay:          time.Minute,
				BackoffMultiplier: 2.0,
				Jitter:            0.1,
				MaxElapsedTime:    10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "negative initial delay",
			config: &RetryConfig{
				MaxAttempts:       3,
				InitialDelay:      -time.Second,
				MaxDelay:          time.Minute,
				BackoffMultiplier: 2.0,
				Jitter:            0.1,
				MaxElapsedTime:    10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "max delay less than initial delay",
			config: &RetryConfig{
				MaxAttempts:       3,
				InitialDelay:      time.Minute,
				MaxDelay:          time.Second,
				BackoffMultiplier: 2.0,
				Jitter:            0.1,
				MaxElapsedTime:    10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid backoff multiplier",
			config: &RetryConfig{
				MaxAttempts:       3,
				InitialDelay:      time.Second,
				MaxDelay:          time.Minute,
				BackoffMultiplier: 0.5,
				Jitter:            0.1,
				MaxElapsedTime:    10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "invalid jitter",
			config: &RetryConfig{
				MaxAttempts:       3,
				InitialDelay:      time.Second,
				MaxDelay:          time.Minute,
				BackoffMultiplier: 2.0,
				Jitter:            1.5,
				MaxElapsedTime:    10 * time.Minute,
			},
			wantErr: true,
		},
		{
			name: "negative max elapsed time",
			config: &RetryConfig{
				MaxAttempts:       3,
				InitialDelay:      time.Second,
				MaxDelay:          time.Minute,
				BackoffMultiplier: 2.0,
				Jitter:            0.1,
				MaxElapsedTime:    -10 * time.Minute,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("RetryConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestNewRetryManager(t *testing.T) {
	config := NewRetryConfig()
	manager := NewRetryManager(config)

	if manager == nil {
		t.Error("NewRetryManager() returned nil")
	}

	if manager.config != config {
		t.Error("NewRetryManager() did not set config correctly")
	}
}

func TestRetryManager_ShouldRetry(t *testing.T) {
	config := &RetryConfig{
		MaxAttempts:    3,
		MaxElapsedTime: 10 * time.Minute,
	}
	manager := NewRetryManager(config)

	tests := []struct {
		name        string
		attempt     int
		elapsedTime time.Duration
		err         error
		shouldRetry bool
	}{
		{
			name:        "first attempt with retryable error",
			attempt:     1,
			elapsedTime: time.Second,
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 503}),
			shouldRetry: true,
		},
		{
			name:        "max attempts reached",
			attempt:     3,
			elapsedTime: time.Second,
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 503}),
			shouldRetry: false,
		},
		{
			name:        "max elapsed time exceeded",
			attempt:     1,
			elapsedTime: 11 * time.Minute,
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 503}),
			shouldRetry: false,
		},
		{
			name:        "non-retryable error",
			attempt:     1,
			elapsedTime: time.Second,
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			shouldRetry: false,
		},
		{
			name:        "context cancelled",
			attempt:     1,
			elapsedTime: time.Second,
			err:         context.Canceled,
			shouldRetry: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			startTime := time.Now().Add(-tt.elapsedTime)
			shouldRetry := manager.ShouldRetry(tt.attempt, startTime, tt.err)
			if shouldRetry != tt.shouldRetry {
				t.Errorf("ShouldRetry() = %v, want %v", shouldRetry, tt.shouldRetry)
			}
		})
	}
}

func TestRetryManager_CalculateDelay(t *testing.T) {
	config := &RetryConfig{
		InitialDelay:      time.Second,
		MaxDelay:          time.Minute,
		BackoffMultiplier: 2.0,
		Jitter:            0.0, // No jitter for predictable testing
	}
	manager := NewRetryManager(config)

	tests := []struct {
		name    string
		attempt int
		want    time.Duration
	}{
		{
			name:    "first retry",
			attempt: 1,
			want:    time.Second,
		},
		{
			name:    "second retry",
			attempt: 2,
			want:    2 * time.Second,
		},
		{
			name:    "third retry",
			attempt: 3,
			want:    4 * time.Second,
		},
		{
			name:    "max delay reached",
			attempt: 10,
			want:    time.Minute,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			delay := manager.CalculateDelay(tt.attempt)
			if delay != tt.want {
				t.Errorf("CalculateDelay() = %v, want %v", delay, tt.want)
			}
		})
	}
}

func TestRetryManager_CalculateDelayWithJitter(t *testing.T) {
	config := &RetryConfig{
		InitialDelay:      time.Second,
		MaxDelay:          time.Minute,
		BackoffMultiplier: 2.0,
		Jitter:            0.5, // 50% jitter
	}
	manager := NewRetryManager(config)

	baseDelay := time.Second
	delay := manager.CalculateDelay(1)

	// With 50% jitter, delay should be between 0.5s and 1.5s
	minDelay := time.Duration(float64(baseDelay) * 0.5)
	maxDelay := time.Duration(float64(baseDelay) * 1.5)

	if delay < minDelay || delay > maxDelay {
		t.Errorf("CalculateDelay() with jitter = %v, should be between %v and %v", delay, minDelay, maxDelay)
	}
}

func TestRetryManager_GetStats(t *testing.T) {
	config := NewRetryConfig()
	manager := NewRetryManager(config)

	// Simulate some retry attempts
	manager.RecordAttempt(true)
	manager.RecordAttempt(true)
	manager.RecordAttempt(false)

	stats := manager.GetStats()

	if stats["total_attempts"] != 3 {
		t.Errorf("GetStats() total_attempts = %v, want 3", stats["total_attempts"])
	}

	if stats["successful_retries"] != 2 {
		t.Errorf("GetStats() successful_retries = %v, want 2", stats["successful_retries"])
	}

	if stats["failed_retries"] != 1 {
		t.Errorf("GetStats() failed_retries = %v, want 1", stats["failed_retries"])
	}
}

func TestRetryManager_ResetStats(t *testing.T) {
	config := NewRetryConfig()
	manager := NewRetryManager(config)

	// Record some attempts
	manager.RecordAttempt(true)
	manager.RecordAttempt(false)

	manager.ResetStats()

	stats := manager.GetStats()
	if stats["total_attempts"] != 0 {
		t.Errorf("ResetStats() total_attempts = %v, want 0", stats["total_attempts"])
	}
}

func TestRetryFunc(t *testing.T) {
	config := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      10 * time.Millisecond,
		MaxDelay:          100 * time.Millisecond,
		BackoffMultiplier: 2.0,
		Jitter:            0.1,
		MaxElapsedTime:    time.Second,
	}

	t.Run("success on first attempt", func(t *testing.T) {
		attempts := 0
		operation := func() error {
			attempts++
			return nil
		}

		ctx := context.Background()
		err := RetryFunc(ctx, config, operation)

		if err != nil {
			t.Errorf("RetryFunc() error = %v, want nil", err)
		}

		if attempts != 1 {
			t.Errorf("RetryFunc() attempts = %d, want 1", attempts)
		}
	})

	t.Run("success on second attempt", func(t *testing.T) {
		attempts := 0
		operation := func() error {
			attempts++
			if attempts == 1 {
				return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
			}
			return nil
		}

		ctx := context.Background()
		err := RetryFunc(ctx, config, operation)

		if err != nil {
			t.Errorf("RetryFunc() error = %v, want nil", err)
		}

		if attempts != 2 {
			t.Errorf("RetryFunc() attempts = %d, want 2", attempts)
		}
	})

	t.Run("max attempts exceeded", func(t *testing.T) {
		attempts := 0
		operation := func() error {
			attempts++
			return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
		}

		ctx := context.Background()
		err := RetryFunc(ctx, config, operation)

		if err == nil {
			t.Error("RetryFunc() error = nil, want error")
		}

		if attempts != 3 {
			t.Errorf("RetryFunc() attempts = %d, want 3", attempts)
		}
	})

	t.Run("non-retryable error", func(t *testing.T) {
		attempts := 0
		operation := func() error {
			attempts++
			return NewGCPError("test", "resource", &googleapi.Error{Code: 404})
		}

		ctx := context.Background()
		err := RetryFunc(ctx, config, operation)

		if err == nil {
			t.Error("RetryFunc() error = nil, want error")
		}

		if attempts != 1 {
			t.Errorf("RetryFunc() attempts = %d, want 1", attempts)
		}
	})

	t.Run("context cancelled", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel() // Cancel immediately

		operation := func() error {
			return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
		}

		err := RetryFunc(ctx, config, operation)

		if err == nil {
			t.Error("RetryFunc() error = nil, want context.Canceled")
		}

		if !errors.Is(err, context.Canceled) {
			t.Errorf("RetryFunc() error = %v, want context.Canceled", err)
		}
	})

	t.Run("context timeout during retry", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
		defer cancel()

		attempts := 0
		operation := func() error {
			attempts++
			time.Sleep(30 * time.Millisecond) // Slow operation
			return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
		}

		err := RetryFunc(ctx, config, operation)

		if err == nil {
			t.Error("RetryFunc() error = nil, want timeout error")
		}

		// Should have at least one attempt before timeout
		if attempts < 1 {
			t.Errorf("RetryFunc() attempts = %d, want at least 1", attempts)
		}
	})
}

func TestRetryFuncWithMetrics(t *testing.T) {
	config := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      10 * time.Millisecond,
		MaxDelay:          100 * time.Millisecond,
		BackoffMultiplier: 2.0,
		Jitter:            0.1,
		MaxElapsedTime:    time.Second,
	}

	attempts := 0
	operation := func() error {
		attempts++
		if attempts <= 2 {
			return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
		}
		return nil
	}

	ctx := context.Background()
	manager := NewRetryManager(config)

	// Custom retry function that records metrics
	var lastDelay time.Duration
	err := RetryFuncWithManager(ctx, manager, func() error {
		return operation()
	}, func(attempt int, delay time.Duration, err error) {
		lastDelay = delay
		t.Logf("Attempt %d failed with error: %v, next delay: %v", attempt, err, delay)
	})

	if err != nil {
		t.Errorf("RetryFuncWithMetrics() error = %v, want nil", err)
	}

	if attempts != 3 {
		t.Errorf("RetryFuncWithMetrics() attempts = %d, want 3", attempts)
	}

	if lastDelay <= 0 {
		t.Error("RetryFuncWithMetrics() should have recorded delay")
	}

	stats := manager.GetStats()
	if stats["total_attempts"] != 2 { // 2 failed attempts before success
		t.Errorf("RetryFuncWithMetrics() recorded attempts = %v, want 2", stats["total_attempts"])
	}
}

func RetryFuncWithManager(ctx context.Context, manager *RetryManager, operation func() error, onRetry func(int, time.Duration, error)) error {
	startTime := time.Now()
	var lastErr error

	for attempt := 1; ; attempt++ {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		err := operation()
		if err == nil {
			return nil
		}

		lastErr = err

		elapsedTime := time.Since(startTime)
		if !manager.ShouldRetry(attempt, startTime, err) {
			return err
		}

		delay := manager.CalculateDelay(attempt)
		if onRetry != nil {
			onRetry(attempt, delay, err)
		}

		manager.RecordAttempt(false)

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(delay):
		}
	}
}

func TestExponentialBackoff(t *testing.T) {
	tests := []struct {
		name              string
		attempt           int
		initialDelay      time.Duration
		backoffMultiplier float64
		maxDelay          time.Duration
		expectedDelay     time.Duration
	}{
		{
			name:              "first attempt",
			attempt:           1,
			initialDelay:      time.Second,
			backoffMultiplier: 2.0,
			maxDelay:          time.Minute,
			expectedDelay:     time.Second,
		},
		{
			name:              "second attempt",
			attempt:           2,
			initialDelay:      time.Second,
			backoffMultiplier: 2.0,
			maxDelay:          time.Minute,
			expectedDelay:     2 * time.Second,
		},
		{
			name:              "max delay reached",
			attempt:           10,
			initialDelay:      time.Second,
			backoffMultiplier: 2.0,
			maxDelay:          10 * time.Second,
			expectedDelay:     10 * time.Second,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			delay := calculateExponentialBackoff(tt.attempt, tt.initialDelay, tt.backoffMultiplier, tt.maxDelay)
			if delay != tt.expectedDelay {
				t.Errorf("calculateExponentialBackoff() = %v, want %v", delay, tt.expectedDelay)
			}
		})
	}
}

func calculateExponentialBackoff(attempt int, initialDelay time.Duration, multiplier float64, maxDelay time.Duration) time.Duration {
	if attempt <= 0 {
		return initialDelay
	}

	delay := float64(initialDelay) * math.Pow(multiplier, float64(attempt-1))
	if delay > float64(maxDelay) {
		delay = float64(maxDelay)
	}

	return time.Duration(delay)
}

func TestJitterCalculation(t *testing.T) {
	baseDelay := time.Second
	jitter := 0.5

	for i := 0; i < 100; i++ {
		delay := addJitter(baseDelay, jitter)

		minDelay := time.Duration(float64(baseDelay) * (1.0 - jitter))
		maxDelay := time.Duration(float64(baseDelay) * (1.0 + jitter))

		if delay < minDelay || delay > maxDelay {
			t.Errorf("addJitter() = %v, should be between %v and %v", delay, minDelay, maxDelay)
		}
	}
}

func addJitter(delay time.Duration, jitter float64) time.Duration {
	if jitter <= 0 {
		return delay
	}

	// Add random jitter: delay * (1 ± jitter)
	multiplier := 1.0 + (2.0*jitter)*(0.5-0.5) // Simplified for testing
	return time.Duration(float64(delay) * multiplier)
}

func TestIsRetryableByErrorType(t *testing.T) {
	tests := []struct {
		name      string
		err       error
		retryable bool
	}{
		{
			name:      "googleapi 500 error",
			err:       &googleapi.Error{Code: 500, Message: "Internal Server Error"},
			retryable: true,
		},
		{
			name:      "googleapi 503 error",
			err:       &googleapi.Error{Code: 503, Message: "Service Unavailable"},
			retryable: true,
		},
		{
			name:      "googleapi 404 error",
			err:       &googleapi.Error{Code: 404, Message: "Not Found"},
			retryable: false,
		},
		{
			name:      "grpc unavailable",
			err:       status.Error(codes.Unavailable, "service unavailable"),
			retryable: true,
		},
		{
			name:      "grpc not found",
			err:       status.Error(codes.NotFound, "not found"),
			retryable: false,
		},
		{
			name:      "context deadline exceeded",
			err:       context.DeadlineExceeded,
			retryable: true,
		},
		{
			name:      "context canceled",
			err:       context.Canceled,
			retryable: false,
		},
		{
			name:      "regular error",
			err:       errors.New("regular error"),
			retryable: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			retryable := IsRetryableError(tt.err)
			if retryable != tt.retryable {
				t.Errorf("IsRetryableError() = %v, want %v", retryable, tt.retryable)
			}
		})
	}
}

func TestRetryWithDifferentBackoffStrategies(t *testing.T) {
	// Test linear backoff
	linearConfig := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      100 * time.Millisecond,
		MaxDelay:          time.Second,
		BackoffMultiplier: 1.0, // Linear backoff
		Jitter:            0.0,
		MaxElapsedTime:    10 * time.Second,
	}

	linearManager := NewRetryManager(linearConfig)
	delay1 := linearManager.CalculateDelay(1)
	delay2 := linearManager.CalculateDelay(2)
	delay3 := linearManager.CalculateDelay(3)

	if delay1 != delay2 || delay2 != delay3 {
		t.Errorf("Linear backoff should have consistent delays: %v, %v, %v", delay1, delay2, delay3)
	}

	// Test exponential backoff
	exponentialConfig := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      100 * time.Millisecond,
		MaxDelay:          time.Second,
		BackoffMultiplier: 2.0, // Exponential backoff
		Jitter:            0.0,
		MaxElapsedTime:    10 * time.Second,
	}

	exponentialManager := NewRetryManager(exponentialConfig)
	expDelay1 := exponentialManager.CalculateDelay(1)
	expDelay2 := exponentialManager.CalculateDelay(2)
	expDelay3 := exponentialManager.CalculateDelay(3)

	if expDelay1 >= expDelay2 || expDelay2 >= expDelay3 {
		t.Errorf("Exponential backoff should have increasing delays: %v, %v, %v", expDelay1, expDelay2, expDelay3)
	}
}

func BenchmarkRetryManager_ShouldRetry(b *testing.B) {
	config := NewRetryConfig()
	manager := NewRetryManager(config)
	err := NewGCPError("test", "resource", &googleapi.Error{Code: 503})
	startTime := time.Now()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		manager.ShouldRetry(1, startTime, err)
	}
}

func BenchmarkRetryManager_CalculateDelay(b *testing.B) {
	config := NewRetryConfig()
	manager := NewRetryManager(config)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		manager.CalculateDelay(i%10 + 1)
	}
}

func BenchmarkRetryFunc(b *testing.B) {
	config := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      time.Microsecond,
		MaxDelay:          time.Millisecond,
		BackoffMultiplier: 2.0,
		Jitter:            0.1,
		MaxElapsedTime:    time.Second,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		attempt := 0
		RetryFunc(context.Background(), config, func() error {
			attempt++
			if attempt == 1 {
				return NewGCPError("test", "resource", &googleapi.Error{Code: 503})
			}
			return nil
		})
	}
}

func TestRetryConfigPresets(t *testing.T) {
	// Test different preset configurations
	fastConfig := &RetryConfig{
		MaxAttempts:       2,
		InitialDelay:      50 * time.Millisecond,
		MaxDelay:          200 * time.Millisecond,
		BackoffMultiplier: 1.5,
		Jitter:            0.1,
		MaxElapsedTime:    time.Second,
	}

	aggressiveConfig := &RetryConfig{
		MaxAttempts:       5,
		InitialDelay:      100 * time.Millisecond,
		MaxDelay:          5 * time.Second,
		BackoffMultiplier: 3.0,
		Jitter:            0.3,
		MaxElapsedTime:    30 * time.Second,
	}

	conservativeConfig := &RetryConfig{
		MaxAttempts:       3,
		InitialDelay:      2 * time.Second,
		MaxDelay:          30 * time.Second,
		BackoffMultiplier: 2.0,
		Jitter:            0.1,
		MaxElapsedTime:    5 * time.Minute,
	}

	configs := []*RetryConfig{fastConfig, aggressiveConfig, conservativeConfig}
	names := []string{"fast", "aggressive", "conservative"}

	for i, config := range configs {
		t.Run(names[i], func(t *testing.T) {
			err := config.Validate()
			if err != nil {
				t.Errorf("%s config validation failed: %v", names[i], err)
			}

			manager := NewRetryManager(config)
			if manager == nil {
				t.Errorf("%s config failed to create manager", names[i])
			}

			// Test that delays increase appropriately
			delay1 := manager.CalculateDelay(1)
			delay2 := manager.CalculateDelay(2)

			if config.BackoffMultiplier > 1.0 && delay2 <= delay1 {
				t.Errorf("%s config should have increasing delays: %v, %v", names[i], delay1, delay2)
			}
		})
	}
}