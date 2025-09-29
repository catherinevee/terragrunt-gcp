package gcp

import (
	"context"
	"errors"
	"fmt"
	"math"
	"math/rand"
	"strings"
	"sync"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// RetryConfig defines retry behavior for GCP operations
type RetryConfig struct {
	// Basic retry settings
	MaxRetries       int
	InitialBackoff   time.Duration
	MaxBackoff       time.Duration
	BackoffFactor    float64
	RetryTimeout     time.Duration

	// Advanced settings
	JitterPercent    float64
	RetryableErrors  []string
	RetryableCodes   []codes.Code
	NonRetryableErrors []string
	EnableExponentialBackoff bool
	EnableJitter     bool
	EnableAdaptiveRetry bool

	// Circuit breaker settings
	EnableCircuitBreaker bool
	CircuitBreakerThreshold int
	CircuitBreakerTimeout time.Duration

	// Rate limiting settings
	EnableRateLimiting bool
	MaxRequestsPerSecond int
	BurstSize int

	// Hooks
	OnRetry    func(attempt int, err error, delay time.Duration)
	OnSuccess  func(attempt int, duration time.Duration)
	OnFailure  func(err error, attempts int)

	// Metrics
	metrics    *RetryMetrics
}

// RetryMetrics tracks retry statistics
type RetryMetrics struct {
	mu               sync.RWMutex
	totalAttempts    int64
	successfulRetries int64
	failedRetries    int64
	totalRetryTime   time.Duration
	maxRetryCount    int
	errorCounts      map[string]int64
	lastError        error
	lastRetryTime    time.Time
}

// Retryer handles retry logic for GCP operations
type Retryer struct {
	config          *RetryConfig
	errorHandler    *ErrorHandler
	circuitBreaker  *CircuitBreaker
	rateLimiter     *AdaptiveRateLimiter
	backoffStrategy BackoffStrategy
	metrics         *RetryMetrics
	logger          Logger
}

// RetryManager is an alias for Retryer for backward compatibility
type RetryManager = Retryer

// BackoffStrategy defines the backoff calculation strategy
type BackoffStrategy interface {
	NextBackoff(attempt int) time.Duration
	Reset()
}

// ExponentialBackoff implements exponential backoff with jitter
type ExponentialBackoff struct {
	InitialInterval time.Duration
	MaxInterval     time.Duration
	Multiplier      float64
	JitterPercent   float64
	currentInterval time.Duration
	random          *rand.Rand
}

// LinearBackoff implements linear backoff strategy
type LinearBackoff struct {
	Interval      time.Duration
	MaxInterval   time.Duration
	JitterPercent float64
	random        *rand.Rand
}

// AdaptiveBackoff adjusts backoff based on error patterns
type AdaptiveBackoff struct {
	baseStrategy    BackoffStrategy
	errorHistory    []error
	adjustmentFactor float64
	minInterval     time.Duration
	maxInterval     time.Duration
}

// AdaptiveRateLimiter adjusts rate limiting based on errors
type AdaptiveRateLimiter struct {
	mu               sync.RWMutex
	currentRate      float64
	targetRate       float64
	minRate          float64
	maxRate          float64
	adjustmentFactor float64
	errorThreshold   float64
	successThreshold float64
	window           time.Duration
	requests         []requestRecord
}

type requestRecord struct {
	timestamp time.Time
	success   bool
}

// RetryableFunc is a function that can be retried
type RetryableFunc func() error

// RetryableWithResultFunc is a function that returns a result and can be retried
type RetryableWithResultFunc func() (interface{}, error)

// NewRetryer creates a new retryer with the given configuration
func NewRetryer(config *RetryConfig, errorHandler *ErrorHandler, logger Logger) *Retryer {
	if config == nil {
		config = DefaultRetryConfig()
	}

	retryer := &Retryer{
		config:       config,
		errorHandler: errorHandler,
		logger:       logger,
		metrics: &RetryMetrics{
			errorCounts: make(map[string]int64),
		},
	}

	// Initialize backoff strategy
	if config.EnableExponentialBackoff {
		retryer.backoffStrategy = &ExponentialBackoff{
			InitialInterval: config.InitialBackoff,
			MaxInterval:     config.MaxBackoff,
			Multiplier:      config.BackoffFactor,
			JitterPercent:   config.JitterPercent,
			random:          rand.New(rand.NewSource(time.Now().UnixNano())),
		}
	} else {
		retryer.backoffStrategy = &LinearBackoff{
			Interval:      config.InitialBackoff,
			MaxInterval:   config.MaxBackoff,
			JitterPercent: config.JitterPercent,
			random:        rand.New(rand.NewSource(time.Now().UnixNano())),
		}
	}

	// Initialize adaptive backoff if enabled
	if config.EnableAdaptiveRetry {
		retryer.backoffStrategy = &AdaptiveBackoff{
			baseStrategy:     retryer.backoffStrategy,
			adjustmentFactor: 1.5,
			minInterval:      100 * time.Millisecond,
			maxInterval:      config.MaxBackoff,
		}
	}

	// Initialize circuit breaker if enabled
	if config.EnableCircuitBreaker {
		retryer.circuitBreaker = &CircuitBreaker{
			threshold: config.CircuitBreakerThreshold,
			timeout:   config.CircuitBreakerTimeout,
			state:     CircuitClosed,
		}
	}

	// Initialize rate limiter if enabled
	if config.EnableRateLimiting {
		retryer.rateLimiter = &AdaptiveRateLimiter{
			currentRate:      float64(config.MaxRequestsPerSecond),
			targetRate:       float64(config.MaxRequestsPerSecond),
			minRate:          1.0,
			maxRate:          float64(config.MaxRequestsPerSecond * 2),
			adjustmentFactor: 0.1,
			errorThreshold:   0.5,
			successThreshold: 0.9,
			window:           1 * time.Minute,
			requests:         make([]requestRecord, 0),
		}
	}

	return retryer
}

// NewRetryManager creates a new retry manager (alias for NewRetryer for backward compatibility)
func NewRetryManager(config *RetryConfig) *RetryManager {
	return NewRetryer(config, nil, nil)
}

// DefaultRetryConfig returns the default retry configuration
func DefaultRetryConfig() *RetryConfig {
	return &RetryConfig{
		MaxRetries:               5,
		InitialBackoff:           1 * time.Second,
		MaxBackoff:               32 * time.Second,
		BackoffFactor:            2.0,
		RetryTimeout:             5 * time.Minute,
		JitterPercent:            0.1,
		EnableExponentialBackoff: true,
		EnableJitter:             true,
		EnableAdaptiveRetry:      false,
		EnableCircuitBreaker:     false,
		EnableRateLimiting:       false,
		RetryableErrors:          DefaultRetryableErrors(),
		RetryableCodes: []codes.Code{
			codes.Unavailable,
			codes.ResourceExhausted,
			codes.Aborted,
			codes.DeadlineExceeded,
			codes.Internal,
		},
		NonRetryableErrors: []string{
			"invalid credentials",
			"permission denied",
			"not found",
			"already exists",
			"invalid argument",
			"failed precondition",
		},
	}
}

// Execute runs a function with retry logic
func (r *Retryer) Execute(ctx context.Context, fn RetryableFunc) error {
	return r.ExecuteWithTimeout(ctx, r.config.RetryTimeout, fn)
}

// ExecuteWithTimeout runs a function with retry logic and timeout
func (r *Retryer) ExecuteWithTimeout(ctx context.Context, timeout time.Duration, fn RetryableFunc) error {
	if timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, timeout)
		defer cancel()
	}

	startTime := time.Now()
	attempt := 0

	for {
		attempt++

		// Check circuit breaker
		if r.circuitBreaker != nil && !r.circuitBreaker.Allow() {
			return fmt.Errorf("circuit breaker is open")
		}

		// Apply rate limiting
		if r.rateLimiter != nil {
			r.rateLimiter.Wait(ctx)
		}

		// Execute the function
		err := r.executeAttempt(ctx, fn, attempt)

		// Success
		if err == nil {
			r.onSuccess(attempt, time.Since(startTime))
			if r.circuitBreaker != nil {
				r.circuitBreaker.RecordSuccess()
			}
			if r.rateLimiter != nil {
				r.rateLimiter.RecordSuccess()
			}
			return nil
		}

		// Record failure
		if r.circuitBreaker != nil {
			r.circuitBreaker.RecordFailure()
		}
		if r.rateLimiter != nil {
			r.rateLimiter.RecordFailure()
		}

		// Check if retryable
		if !r.shouldRetry(err, attempt) {
			r.onFailure(err, attempt)
			return err
		}

		// Check context
		if ctx.Err() != nil {
			r.onFailure(ctx.Err(), attempt)
			return ctx.Err()
		}

		// Calculate backoff
		delay := r.calculateBackoff(attempt, err)

		// Call retry hook
		if r.config.OnRetry != nil {
			r.config.OnRetry(attempt, err, delay)
		}

		// Log retry attempt
		r.logRetry(attempt, err, delay)

		// Wait before retry
		select {
		case <-ctx.Done():
			r.onFailure(ctx.Err(), attempt)
			return ctx.Err()
		case <-time.After(delay):
			// Continue to next attempt
		}

		// Update metrics
		r.updateMetrics(attempt, err, delay)
	}
}

// ExecuteWithResult runs a function that returns a result with retry logic
func (r *Retryer) ExecuteWithResult(ctx context.Context, fn RetryableWithResultFunc) (interface{}, error) {
	var result interface{}

	err := r.Execute(ctx, func() error {
		var execErr error
		result, execErr = fn()
		return execErr
	})

	return result, err
}

// executeAttempt executes a single attempt
func (r *Retryer) executeAttempt(ctx context.Context, fn RetryableFunc, attempt int) error {
	// Create attempt context with shorter timeout if needed
	// attemptCtx not used since RetryableFunc doesn't take context
	// attemptCtx := ctx
	if r.config.RetryTimeout > 0 {
		timeout := r.config.RetryTimeout / time.Duration(r.config.MaxRetries)
		_, cancel := context.WithTimeout(ctx, timeout)
		defer cancel()
	}

	// Execute with panic recovery
	var err error
	func() {
		defer func() {
			if p := recover(); p != nil {
				err = fmt.Errorf("panic recovered: %v", p)
			}
		}()

		// Execute the function
		// RetryableFunc doesn't take context - fn takes no arguments
		err = fn()
	}()

	return err
}

// shouldRetry determines if an error should be retried
func (r *Retryer) shouldRetry(err error, attempt int) bool {
	// Check max retries
	if attempt >= r.config.MaxRetries {
		return false
	}

	// Check if error is nil
	if err == nil {
		return false
	}

	// Check for context errors
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return false
	}

	// Check non-retryable patterns
	errStr := strings.ToLower(err.Error())
	for _, pattern := range r.config.NonRetryableErrors {
		if strings.Contains(errStr, strings.ToLower(pattern)) {
			return false
		}
	}

	// Check if error is a GCP error
	if gcpErr, ok := err.(*Error); ok {
		return gcpErr.ShouldRetry()
	}

	// Check gRPC status
	if st, ok := status.FromError(err); ok {
		for _, code := range r.config.RetryableCodes {
			if st.Code() == code {
				return true
			}
		}
		// Check non-retryable codes
		switch st.Code() {
		case codes.InvalidArgument, codes.NotFound, codes.AlreadyExists,
		     codes.PermissionDenied, codes.Unauthenticated, codes.FailedPrecondition:
			return false
		}
	}

	// Check retryable patterns
	for _, pattern := range r.config.RetryableErrors {
		if strings.Contains(errStr, strings.ToLower(pattern)) {
			return true
		}
	}

	// Default to retryable for unknown errors
	return true
}

// calculateBackoff calculates the backoff delay for the next retry
func (r *Retryer) calculateBackoff(attempt int, err error) time.Duration {
	// Get base backoff from strategy
	baseDelay := r.backoffStrategy.NextBackoff(attempt)

	// Adjust based on error type if it's a GCP error
	if gcpErr, ok := err.(*Error); ok {
		// Use error-specific delay if available
		if errorDelay := gcpErr.GetRetryDelay(); errorDelay > 0 {
			baseDelay = errorDelay
		}

		// Respect RetryAfter header
		if !gcpErr.RetryAfter.IsZero() {
			retryAfter := time.Until(gcpErr.RetryAfter)
			if retryAfter > baseDelay {
				baseDelay = retryAfter
			}
		}
	}

	// Apply max backoff limit
	if baseDelay > r.config.MaxBackoff {
		baseDelay = r.config.MaxBackoff
	}

	return baseDelay
}

// onSuccess handles successful execution
func (r *Retryer) onSuccess(attempt int, duration time.Duration) {
	r.metrics.mu.Lock()
	if attempt > 1 {
		r.metrics.successfulRetries++
	}
	r.metrics.mu.Unlock()

	if r.config.OnSuccess != nil {
		r.config.OnSuccess(attempt, duration)
	}

	if r.logger != nil {
		r.logger.Debug("Operation succeeded",
			"attempt", attempt,
			"duration", duration,
		)
	}
}

// onFailure handles failed execution
func (r *Retryer) onFailure(err error, attempts int) {
	r.metrics.mu.Lock()
	r.metrics.failedRetries++
	r.metrics.lastError = err
	r.metrics.errorCounts[err.Error()]++
	r.metrics.mu.Unlock()

	if r.config.OnFailure != nil {
		r.config.OnFailure(err, attempts)
	}

	if r.logger != nil {
		r.logger.Error("Operation failed after retries",
			"error", err,
			"attempts", attempts,
		)
	}
}

// logRetry logs a retry attempt
func (r *Retryer) logRetry(attempt int, err error, delay time.Duration) {
	if r.logger == nil {
		return
	}

	r.logger.Warn("Retrying operation",
		"attempt", attempt,
		"error", err.Error(),
		"delay", delay,
		"max_attempts", r.config.MaxRetries,
	)
}

// updateMetrics updates retry metrics
func (r *Retryer) updateMetrics(attempt int, err error, delay time.Duration) {
	r.metrics.mu.Lock()
	defer r.metrics.mu.Unlock()

	r.metrics.totalAttempts++
	r.metrics.totalRetryTime += delay
	r.metrics.lastRetryTime = time.Now()

	if attempt > r.metrics.maxRetryCount {
		r.metrics.maxRetryCount = attempt
	}

	r.metrics.errorCounts[err.Error()]++
	r.metrics.lastError = err
}

// GetMetrics returns retry metrics
func (r *Retryer) GetMetrics() map[string]interface{} {
	r.metrics.mu.RLock()
	defer r.metrics.mu.RUnlock()

	return map[string]interface{}{
		"total_attempts":     r.metrics.totalAttempts,
		"successful_retries": r.metrics.successfulRetries,
		"failed_retries":     r.metrics.failedRetries,
		"total_retry_time":   r.metrics.totalRetryTime.String(),
		"max_retry_count":    r.metrics.maxRetryCount,
		"error_counts":       r.metrics.errorCounts,
		"last_retry_time":    r.metrics.lastRetryTime,
	}
}

// NextBackoff returns the next backoff duration for exponential backoff
func (eb *ExponentialBackoff) NextBackoff(attempt int) time.Duration {
	if attempt <= 0 {
		attempt = 1
	}

	// Calculate exponential backoff
	backoff := float64(eb.InitialInterval) * math.Pow(eb.Multiplier, float64(attempt-1))

	// Apply max limit
	if backoff > float64(eb.MaxInterval) {
		backoff = float64(eb.MaxInterval)
	}

	// Apply jitter if enabled
	if eb.JitterPercent > 0 {
		jitter := backoff * eb.JitterPercent
		backoff = backoff - jitter + (eb.random.Float64() * 2 * jitter)
	}

	return time.Duration(backoff)
}

// Reset resets the exponential backoff
func (eb *ExponentialBackoff) Reset() {
	eb.currentInterval = eb.InitialInterval
}

// NextBackoff returns the next backoff duration for linear backoff
func (lb *LinearBackoff) NextBackoff(attempt int) time.Duration {
	if attempt <= 0 {
		attempt = 1
	}

	// Calculate linear backoff
	backoff := float64(lb.Interval) * float64(attempt)

	// Apply max limit
	if backoff > float64(lb.MaxInterval) {
		backoff = float64(lb.MaxInterval)
	}

	// Apply jitter if enabled
	if lb.JitterPercent > 0 {
		jitter := backoff * lb.JitterPercent
		backoff = backoff - jitter + (lb.random.Float64() * 2 * jitter)
	}

	return time.Duration(backoff)
}

// Reset resets the linear backoff
func (lb *LinearBackoff) Reset() {
	// No state to reset for linear backoff
}

// NextBackoff returns the next backoff duration for adaptive backoff
func (ab *AdaptiveBackoff) NextBackoff(attempt int) time.Duration {
	// Get base backoff
	baseBackoff := ab.baseStrategy.NextBackoff(attempt)

	// Analyze error patterns
	adjustment := ab.calculateAdjustment()

	// Apply adjustment
	adjustedBackoff := time.Duration(float64(baseBackoff) * adjustment)

	// Apply limits
	if adjustedBackoff < ab.minInterval {
		adjustedBackoff = ab.minInterval
	}
	if adjustedBackoff > ab.maxInterval {
		adjustedBackoff = ab.maxInterval
	}

	return adjustedBackoff
}

// Reset resets the adaptive backoff
func (ab *AdaptiveBackoff) Reset() {
	ab.errorHistory = nil
	ab.baseStrategy.Reset()
}

// calculateAdjustment calculates the adjustment factor based on error patterns
func (ab *AdaptiveBackoff) calculateAdjustment() float64 {
	if len(ab.errorHistory) < 2 {
		return 1.0
	}

	// Count consecutive similar errors
	lastErr := ab.errorHistory[len(ab.errorHistory)-1]
	consecutiveSimilar := 0

	for i := len(ab.errorHistory) - 2; i >= 0; i-- {
		if isSimilarError(ab.errorHistory[i], lastErr) {
			consecutiveSimilar++
		} else {
			break
		}
	}

	// Increase backoff for consecutive similar errors
	if consecutiveSimilar > 2 {
		return ab.adjustmentFactor * float64(consecutiveSimilar)
	}

	return 1.0
}

// isSimilarError checks if two errors are similar
func isSimilarError(err1, err2 error) bool {
	if err1 == nil || err2 == nil {
		return false
	}

	// Check if both are GCP errors
	gcpErr1, ok1 := err1.(*Error)
	gcpErr2, ok2 := err2.(*Error)

	if ok1 && ok2 {
		return gcpErr1.Code == gcpErr2.Code
	}

	// Check gRPC status codes
	st1, ok1 := status.FromError(err1)
	st2, ok2 := status.FromError(err2)

	if ok1 && ok2 {
		return st1.Code() == st2.Code()
	}

	// Compare error messages
	return strings.Contains(err1.Error(), err2.Error()) ||
	       strings.Contains(err2.Error(), err1.Error())
}

// Wait waits according to rate limit
func (rl *AdaptiveRateLimiter) Wait(ctx context.Context) error {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	// Clean up old requests
	rl.cleanup()

	// Calculate current rate
	currentRate := rl.calculateCurrentRate()

	// Wait if necessary
	if currentRate >= rl.currentRate {
		waitTime := time.Duration(float64(time.Second) / rl.currentRate)

		rl.mu.Unlock()
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(waitTime):
		}
		rl.mu.Lock()
	}

	return nil
}

// RecordSuccess records a successful request
func (rl *AdaptiveRateLimiter) RecordSuccess() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	rl.requests = append(rl.requests, requestRecord{
		timestamp: time.Now(),
		success:   true,
	})

	// Adjust rate based on success rate
	rl.adjustRate()
}

// RecordFailure records a failed request
func (rl *AdaptiveRateLimiter) RecordFailure() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	rl.requests = append(rl.requests, requestRecord{
		timestamp: time.Now(),
		success:   false,
	})

	// Adjust rate based on success rate
	rl.adjustRate()
}

// cleanup removes old request records
func (rl *AdaptiveRateLimiter) cleanup() {
	cutoff := time.Now().Add(-rl.window)
	newRequests := make([]requestRecord, 0)

	for _, req := range rl.requests {
		if req.timestamp.After(cutoff) {
			newRequests = append(newRequests, req)
		}
	}

	rl.requests = newRequests
}

// calculateCurrentRate calculates the current request rate
func (rl *AdaptiveRateLimiter) calculateCurrentRate() float64 {
	if len(rl.requests) == 0 {
		return 0
	}

	duration := time.Since(rl.requests[0].timestamp)
	if duration < time.Second {
		duration = time.Second
	}

	return float64(len(rl.requests)) / duration.Seconds()
}

// adjustRate adjusts the rate limit based on success rate
func (rl *AdaptiveRateLimiter) adjustRate() {
	if len(rl.requests) < 10 {
		return
	}

	// Calculate success rate
	successCount := 0
	for _, req := range rl.requests {
		if req.success {
			successCount++
		}
	}

	successRate := float64(successCount) / float64(len(rl.requests))

	// Adjust rate based on success rate
	if successRate >= rl.successThreshold {
		// Increase rate
		rl.currentRate = math.Min(rl.currentRate*(1+rl.adjustmentFactor), rl.maxRate)
	} else if successRate <= rl.errorThreshold {
		// Decrease rate
		rl.currentRate = math.Max(rl.currentRate*(1-rl.adjustmentFactor), rl.minRate)
	}

	// Move towards target rate
	if math.Abs(rl.currentRate-rl.targetRate) > 0.1 {
		diff := (rl.targetRate - rl.currentRate) * 0.1
		rl.currentRate += diff
	}
}

// Allow checks if a request is allowed by the circuit breaker
func (cb *CircuitBreaker) Allow() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case CircuitOpen:
		if time.Since(cb.lastFailureTime) > cb.timeout {
			cb.state = CircuitHalfOpen
			cb.successCount = 0
			return true
		}
		return false

	case CircuitHalfOpen:
		return cb.successCount < cb.halfOpenMax

	case CircuitClosed:
		return true

	default:
		return true
	}
}

// RecordSuccess records a successful request for the circuit breaker
func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures = 0

	if cb.state == CircuitHalfOpen {
		cb.successCount++
		if cb.successCount >= cb.halfOpenMax {
			cb.state = CircuitClosed
		}
	}
}

// RecordFailure records a failed request for the circuit breaker
func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures++
	cb.lastFailureTime = time.Now()

	if cb.failures >= cb.threshold {
		cb.state = CircuitOpen
	}
}