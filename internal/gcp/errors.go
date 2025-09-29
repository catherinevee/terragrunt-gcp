package gcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"google.golang.org/api/googleapi"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Error represents a GCP-specific error with additional context
type Error struct {
	// Basic error information
	Code       string    `json:"code"`
	Message    string    `json:"message"`
	Status     int       `json:"status,omitempty"`
	Details    []ErrorDetail `json:"details,omitempty"`

	// GCP-specific information
	Service    string    `json:"service,omitempty"`
	Resource   string    `json:"resource,omitempty"`
	Operation  string    `json:"operation,omitempty"`
	Project    string    `json:"project,omitempty"`
	Location   string    `json:"location,omitempty"`

	// Request information
	RequestID  string    `json:"request_id,omitempty"`
	TraceID    string    `json:"trace_id,omitempty"`

	// Retry information
	Retryable  bool      `json:"retryable"`
	RetryAfter time.Time `json:"retry_after,omitempty"`
	RetryCount int       `json:"retry_count,omitempty"`

	// Rate limit information
	RateLimited     bool      `json:"rate_limited"`
	QuotaExceeded   bool      `json:"quota_exceeded"`
	QuotaMetric     string    `json:"quota_metric,omitempty"`
	QuotaLimit      int64     `json:"quota_limit,omitempty"`
	QuotaUsage      int64     `json:"quota_usage,omitempty"`
	QuotaResetTime  time.Time `json:"quota_reset_time,omitempty"`

	// Original error
	Cause      error     `json:"-"`
	Timestamp  time.Time `json:"timestamp"`
}

// ErrorDetail provides additional error context
type ErrorDetail struct {
	Type        string                 `json:"@type"`
	Reason      string                 `json:"reason,omitempty"`
	Domain      string                 `json:"domain,omitempty"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
	Violations  []Violation           `json:"violations,omitempty"`
	Links       []Link                `json:"links,omitempty"`
}

// Violation represents a policy or constraint violation
type Violation struct {
	Type        string `json:"type"`
	Subject     string `json:"subject"`
	Description string `json:"description"`
}

// Link provides helpful links related to the error
type Link struct {
	Description string `json:"description"`
	URL         string `json:"url"`
}

// ErrorCategory represents the category of error
type ErrorCategory string

const (
	ErrorCategoryAuthentication ErrorCategory = "AUTHENTICATION"
	ErrorCategoryAuthorization  ErrorCategory = "AUTHORIZATION"
	ErrorCategoryRateLimit      ErrorCategory = "RATE_LIMIT"
	ErrorCategoryQuota          ErrorCategory = "QUOTA"
	ErrorCategoryValidation     ErrorCategory = "VALIDATION"
	ErrorCategoryResource       ErrorCategory = "RESOURCE"
	ErrorCategoryNetwork        ErrorCategory = "NETWORK"
	ErrorCategoryTimeout        ErrorCategory = "TIMEOUT"
	ErrorCategoryInternal       ErrorCategory = "INTERNAL"
	ErrorCategoryUnknown        ErrorCategory = "UNKNOWN"
)

// ErrorCode represents common GCP error codes
type ErrorCode string

const (
	ErrorCodeNotFound            ErrorCode = "NOT_FOUND"
	ErrorCodeAlreadyExists       ErrorCode = "ALREADY_EXISTS"
	ErrorCodePermissionDenied    ErrorCode = "PERMISSION_DENIED"
	ErrorCodeUnauthenticated     ErrorCode = "UNAUTHENTICATED"
	ErrorCodeResourceExhausted   ErrorCode = "RESOURCE_EXHAUSTED"
	ErrorCodeFailedPrecondition  ErrorCode = "FAILED_PRECONDITION"
	ErrorCodeAborted             ErrorCode = "ABORTED"
	ErrorCodeOutOfRange          ErrorCode = "OUT_OF_RANGE"
	ErrorCodeUnimplemented       ErrorCode = "UNIMPLEMENTED"
	ErrorCodeInternal            ErrorCode = "INTERNAL"
	ErrorCodeUnavailable         ErrorCode = "UNAVAILABLE"
	ErrorCodeDataLoss            ErrorCode = "DATA_LOSS"
	ErrorCodeInvalidArgument     ErrorCode = "INVALID_ARGUMENT"
	ErrorCodeDeadlineExceeded    ErrorCode = "DEADLINE_EXCEEDED"
	ErrorCodeCancelled           ErrorCode = "CANCELLED"
	ErrorCodeConflict            ErrorCode = "CONFLICT"
	ErrorCodeTooManyRequests     ErrorCode = "TOO_MANY_REQUESTS"
	ErrorCodePreconditionFailed  ErrorCode = "PRECONDITION_FAILED"
	ErrorCodeBadRequest          ErrorCode = "BAD_REQUEST"
)

// ErrorHandler handles and categorizes GCP errors
type ErrorHandler struct {
	mu               sync.RWMutex
	patterns         map[ErrorCategory][]*regexp.Regexp
	retryablePatterns []string
	errorMetrics     *ErrorMetrics
	logger           Logger
}

// ErrorMetrics tracks error statistics
type ErrorMetrics struct {
	mu            sync.RWMutex
	totalErrors   int64
	errorsByCode  map[string]int64
	errorsByType  map[ErrorCategory]int64
	retryableErrors int64
	permanentErrors int64
	lastError     *Error
	recentErrors  []*Error
	maxRecent     int
}

// Error returns the error message
func (e *Error) Error() string {
	if e.Message != "" {
		return e.Message
	}
	if e.Cause != nil {
		return e.Cause.Error()
	}
	return fmt.Sprintf("GCP error: %s", e.Code)
}

// Unwrap returns the underlying error
func (e *Error) Unwrap() error {
	return e.Cause
}

// Is checks if the error matches the target
func (e *Error) Is(target error) bool {
	if target == nil {
		return false
	}

	if gcpErr, ok := target.(*Error); ok {
		return e.Code == gcpErr.Code
	}

	return errors.Is(e.Cause, target)
}

// GetCategory returns the error category
func (e *Error) GetCategory() ErrorCategory {
	switch e.Code {
	case string(ErrorCodeUnauthenticated):
		return ErrorCategoryAuthentication
	case string(ErrorCodePermissionDenied):
		return ErrorCategoryAuthorization
	case string(ErrorCodeResourceExhausted), string(ErrorCodeTooManyRequests):
		return ErrorCategoryRateLimit
	case string(ErrorCodeInvalidArgument), string(ErrorCodeOutOfRange), string(ErrorCodeBadRequest):
		return ErrorCategoryValidation
	case string(ErrorCodeNotFound), string(ErrorCodeAlreadyExists), string(ErrorCodeConflict):
		return ErrorCategoryResource
	case string(ErrorCodeUnavailable), string(ErrorCodeAborted):
		return ErrorCategoryNetwork
	case string(ErrorCodeDeadlineExceeded), string(ErrorCodeCancelled):
		return ErrorCategoryTimeout
	case string(ErrorCodeInternal), string(ErrorCodeDataLoss):
		return ErrorCategoryInternal
	default:
		return ErrorCategoryUnknown
	}
}

// ShouldRetry determines if the error is retryable
func (e *Error) ShouldRetry() bool {
	if e.Retryable {
		return true
	}

	// Check category
	category := e.GetCategory()
	switch category {
	case ErrorCategoryRateLimit, ErrorCategoryNetwork, ErrorCategoryTimeout:
		return true
	case ErrorCategoryAuthentication, ErrorCategoryAuthorization, ErrorCategoryValidation:
		return false
	}

	// Check specific error codes
	switch e.Code {
	case string(ErrorCodeUnavailable), string(ErrorCodeAborted),
	     string(ErrorCodeDeadlineExceeded), string(ErrorCodeResourceExhausted):
		return true
	case string(ErrorCodeNotFound), string(ErrorCodeAlreadyExists),
	     string(ErrorCodeInvalidArgument), string(ErrorCodePermissionDenied):
		return false
	}

	// Check HTTP status if available
	if e.Status >= 500 && e.Status < 600 {
		return true
	}

	if e.Status == http.StatusTooManyRequests {
		return true
	}

	return false
}

// GetRetryDelay returns the recommended retry delay
func (e *Error) GetRetryDelay() time.Duration {
	// If RetryAfter is set, use it
	if !e.RetryAfter.IsZero() {
		delay := time.Until(e.RetryAfter)
		if delay > 0 {
			return delay
		}
	}

	// Base delay on error category
	category := e.GetCategory()
	switch category {
	case ErrorCategoryRateLimit:
		return 30 * time.Second
	case ErrorCategoryQuota:
		return 60 * time.Second
	case ErrorCategoryNetwork:
		return 5 * time.Second
	case ErrorCategoryTimeout:
		return 10 * time.Second
	default:
		return 2 * time.Second
	}
}

// NewErrorHandler creates a new error handler
func NewErrorHandler(logger Logger) *ErrorHandler {
	handler := &ErrorHandler{
		patterns: make(map[ErrorCategory][]*regexp.Regexp),
		errorMetrics: &ErrorMetrics{
			errorsByCode: make(map[string]int64),
			errorsByType: make(map[ErrorCategory]int64),
			recentErrors: make([]*Error, 0),
			maxRecent:    100,
		},
		logger: logger,
	}

	// Initialize error patterns
	handler.initializePatterns()
	handler.initializeRetryablePatterns()

	return handler
}

// initializePatterns sets up error pattern recognition
func (h *ErrorHandler) initializePatterns() {
	h.patterns[ErrorCategoryAuthentication] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)unauthenticated`),
		regexp.MustCompile(`(?i)authentication.*failed`),
		regexp.MustCompile(`(?i)invalid.*credentials`),
		regexp.MustCompile(`(?i)token.*expired`),
		regexp.MustCompile(`(?i)access.*token.*invalid`),
	}

	h.patterns[ErrorCategoryAuthorization] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)permission.*denied`),
		regexp.MustCompile(`(?i)forbidden`),
		regexp.MustCompile(`(?i)unauthorized`),
		regexp.MustCompile(`(?i)insufficient.*permissions`),
		regexp.MustCompile(`(?i)access.*denied`),
	}

	h.patterns[ErrorCategoryRateLimit] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)rate.*limit`),
		regexp.MustCompile(`(?i)too.*many.*requests`),
		regexp.MustCompile(`(?i)quota.*exceeded`),
		regexp.MustCompile(`(?i)throttl`),
		regexp.MustCompile(`(?i)resource.*exhausted`),
	}

	h.patterns[ErrorCategoryValidation] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)invalid.*argument`),
		regexp.MustCompile(`(?i)bad.*request`),
		regexp.MustCompile(`(?i)validation.*error`),
		regexp.MustCompile(`(?i)invalid.*format`),
		regexp.MustCompile(`(?i)missing.*required`),
	}

	h.patterns[ErrorCategoryResource] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)not.*found`),
		regexp.MustCompile(`(?i)already.*exists`),
		regexp.MustCompile(`(?i)conflict`),
		regexp.MustCompile(`(?i)duplicate`),
		regexp.MustCompile(`(?i)resource.*not.*exist`),
	}

	h.patterns[ErrorCategoryNetwork] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)connection.*refused`),
		regexp.MustCompile(`(?i)connection.*reset`),
		regexp.MustCompile(`(?i)network.*error`),
		regexp.MustCompile(`(?i)unavailable`),
		regexp.MustCompile(`(?i)service.*down`),
	}

	h.patterns[ErrorCategoryTimeout] = []*regexp.Regexp{
		regexp.MustCompile(`(?i)timeout`),
		regexp.MustCompile(`(?i)deadline.*exceeded`),
		regexp.MustCompile(`(?i)timed.*out`),
		regexp.MustCompile(`(?i)context.*cancel`),
	}
}

// initializeRetryablePatterns sets up retryable error patterns
func (h *ErrorHandler) initializeRetryablePatterns() {
	h.retryablePatterns = []string{
		"rate limit",
		"quota exceeded",
		"service unavailable",
		"deadline exceeded",
		"resource exhausted",
		"temporary failure",
		"connection refused",
		"connection reset",
		"timeout",
		"too many requests",
		"throttled",
		"backoff",
		"retry",
		"unavailable",
		"aborted",
		"transient",
		"temporary",
	}
}

// HandleError processes and categorizes an error
func (h *ErrorHandler) HandleError(ctx context.Context, err error, operation string) *Error {
	if err == nil {
		return nil
	}

	// Check if already a GCP Error
	if gcpErr, ok := err.(*Error); ok {
		h.recordError(gcpErr)
		return gcpErr
	}

	// Create new GCP error
	gcpErr := &Error{
		Message:   err.Error(),
		Cause:     err,
		Operation: operation,
		Timestamp: time.Now(),
	}

	// Extract error details based on error type
	h.extractErrorDetails(ctx, gcpErr, err)

	// Categorize the error
	gcpErr.Code = string(h.categorizeError(gcpErr))

	// Determine if retryable
	gcpErr.Retryable = h.isRetryable(gcpErr)

	// Record metrics
	h.recordError(gcpErr)

	// Log the error
	if h.logger != nil {
		h.logError(gcpErr)
	}

	return gcpErr
}

// extractErrorDetails extracts details from various error types
func (h *ErrorHandler) extractErrorDetails(ctx context.Context, gcpErr *Error, err error) {
	// Check for Google API error
	if apiErr, ok := err.(*googleapi.Error); ok {
		gcpErr.Code = fmt.Sprintf("%d", apiErr.Code)
		gcpErr.Status = apiErr.Code
		gcpErr.Message = apiErr.Message

		// Extract details from errors
		for _, e := range apiErr.Errors {
			detail := ErrorDetail{
				Reason:  e.Reason,
				Domain:  e.Domain,
			}

			if e.Message != "" {
				detail.Metadata = map[string]interface{}{
					"message": e.Message,
				}
			}

			gcpErr.Details = append(gcpErr.Details, detail)
		}

		// Check for rate limiting
		if apiErr.Code == http.StatusTooManyRequests {
			gcpErr.RateLimited = true
		}

		// Check for quota exceeded
		for _, e := range apiErr.Errors {
			if strings.Contains(strings.ToLower(e.Reason), "quota") {
				gcpErr.QuotaExceeded = true
				gcpErr.QuotaMetric = e.Domain
				break
			}
		}

		return
	}

	// Check for gRPC status error
	if st, ok := status.FromError(err); ok {
		gcpErr.Code = st.Code().String()
		gcpErr.Message = st.Message()
		gcpErr.Status = httpStatusFromGRPC(st.Code())

		// Extract details from status
		for _, detail := range st.Details() {
			if data, err := json.Marshal(detail); err == nil {
				var metadata map[string]interface{}
				json.Unmarshal(data, &metadata)

				gcpErr.Details = append(gcpErr.Details, ErrorDetail{
					Type:     fmt.Sprintf("%T", detail),
					Metadata: metadata,
				})
			}
		}

		// Check for rate limiting
		if st.Code() == codes.ResourceExhausted {
			gcpErr.RateLimited = true
		}

		return
	}

	// Check for context errors
	if errors.Is(err, context.Canceled) {
		gcpErr.Code = string(ErrorCodeCancelled)
		gcpErr.Message = "Operation was cancelled"
		return
	}

	if errors.Is(err, context.DeadlineExceeded) {
		gcpErr.Code = string(ErrorCodeDeadlineExceeded)
		gcpErr.Message = "Operation deadline exceeded"
		return
	}
}

// categorizeError determines the error category
func (h *ErrorHandler) categorizeError(err *Error) ErrorCode {
	message := strings.ToLower(err.Message)

	// Check patterns
	for category, patterns := range h.patterns {
		for _, pattern := range patterns {
			if pattern.MatchString(message) {
				return h.categoryToCode(category)
			}
		}
	}

	// Check HTTP status
	if err.Status > 0 {
		return h.statusToCode(err.Status)
	}

	return ErrorCodeInternal
}

// categoryToCode converts category to error code
func (h *ErrorHandler) categoryToCode(category ErrorCategory) ErrorCode {
	switch category {
	case ErrorCategoryAuthentication:
		return ErrorCodeUnauthenticated
	case ErrorCategoryAuthorization:
		return ErrorCodePermissionDenied
	case ErrorCategoryRateLimit:
		return ErrorCodeResourceExhausted
	case ErrorCategoryValidation:
		return ErrorCodeInvalidArgument
	case ErrorCategoryResource:
		return ErrorCodeNotFound
	case ErrorCategoryNetwork:
		return ErrorCodeUnavailable
	case ErrorCategoryTimeout:
		return ErrorCodeDeadlineExceeded
	default:
		return ErrorCodeInternal
	}
}

// statusToCode converts HTTP status to error code
func (h *ErrorHandler) statusToCode(status int) ErrorCode {
	switch status {
	case http.StatusBadRequest:
		return ErrorCodeBadRequest
	case http.StatusUnauthorized:
		return ErrorCodeUnauthenticated
	case http.StatusForbidden:
		return ErrorCodePermissionDenied
	case http.StatusNotFound:
		return ErrorCodeNotFound
	case http.StatusConflict:
		return ErrorCodeConflict
	case http.StatusPreconditionFailed:
		return ErrorCodePreconditionFailed
	case http.StatusTooManyRequests:
		return ErrorCodeTooManyRequests
	case http.StatusInternalServerError:
		return ErrorCodeInternal
	case http.StatusServiceUnavailable:
		return ErrorCodeUnavailable
	case http.StatusGatewayTimeout:
		return ErrorCodeDeadlineExceeded
	default:
		if status >= 400 && status < 500 {
			return ErrorCodeInvalidArgument
		}
		if status >= 500 && status < 600 {
			return ErrorCodeInternal
		}
		return ErrorCodeUnknown
	}
}

// isRetryable determines if an error is retryable
func (h *ErrorHandler) isRetryable(err *Error) bool {
	// Check explicit retryable flag
	if err.Retryable {
		return true
	}

	// Check error code
	switch ErrorCode(err.Code) {
	case ErrorCodeUnavailable, ErrorCodeAborted, ErrorCodeDeadlineExceeded,
	     ErrorCodeResourceExhausted, ErrorCodeTooManyRequests:
		return true
	case ErrorCodeNotFound, ErrorCodeAlreadyExists, ErrorCodeInvalidArgument,
	     ErrorCodePermissionDenied, ErrorCodeUnauthenticated:
		return false
	}

	// Check error message patterns
	message := strings.ToLower(err.Message)
	for _, pattern := range h.retryablePatterns {
		if strings.Contains(message, pattern) {
			return true
		}
	}

	// Check HTTP status
	if err.Status >= 500 && err.Status < 600 {
		return true
	}

	if err.Status == http.StatusTooManyRequests {
		return true
	}

	return false
}

// recordError records error metrics
func (h *ErrorHandler) recordError(err *Error) {
	h.errorMetrics.mu.Lock()
	defer h.errorMetrics.mu.Unlock()

	h.errorMetrics.totalErrors++
	h.errorMetrics.errorsByCode[err.Code]++

	category := err.GetCategory()
	h.errorMetrics.errorsByType[category]++

	if err.Retryable {
		h.errorMetrics.retryableErrors++
	} else {
		h.errorMetrics.permanentErrors++
	}

	h.errorMetrics.lastError = err

	// Add to recent errors
	h.errorMetrics.recentErrors = append(h.errorMetrics.recentErrors, err)
	if len(h.errorMetrics.recentErrors) > h.errorMetrics.maxRecent {
		h.errorMetrics.recentErrors = h.errorMetrics.recentErrors[1:]
	}
}

// logError logs the error details
func (h *ErrorHandler) logError(err *Error) {
	if h.logger == nil {
		return
	}

	fields := []interface{}{
		"code", err.Code,
		"message", err.Message,
		"operation", err.Operation,
		"retryable", err.Retryable,
		"category", err.GetCategory(),
	}

	if err.Status > 0 {
		fields = append(fields, "status", err.Status)
	}

	if err.Project != "" {
		fields = append(fields, "project", err.Project)
	}

	if err.Resource != "" {
		fields = append(fields, "resource", err.Resource)
	}

	if err.RequestID != "" {
		fields = append(fields, "request_id", err.RequestID)
	}

	if err.RateLimited {
		fields = append(fields, "rate_limited", true)
	}

	if err.QuotaExceeded {
		fields = append(fields, "quota_exceeded", true)
		if err.QuotaMetric != "" {
			fields = append(fields, "quota_metric", err.QuotaMetric)
		}
	}

	h.logger.Error("GCP error occurred", fields...)
}

// GetMetrics returns error metrics
func (h *ErrorHandler) GetMetrics() map[string]interface{} {
	h.errorMetrics.mu.RLock()
	defer h.errorMetrics.mu.RUnlock()

	return map[string]interface{}{
		"total_errors":      h.errorMetrics.totalErrors,
		"errors_by_code":    h.errorMetrics.errorsByCode,
		"errors_by_type":    h.errorMetrics.errorsByType,
		"retryable_errors":  h.errorMetrics.retryableErrors,
		"permanent_errors":  h.errorMetrics.permanentErrors,
		"recent_error_count": len(h.errorMetrics.recentErrors),
	}
}

// httpStatusFromGRPC converts gRPC code to HTTP status
func httpStatusFromGRPC(code codes.Code) int {
	switch code {
	case codes.OK:
		return http.StatusOK
	case codes.Canceled:
		return 499 // Client Closed Request
	case codes.Unknown:
		return http.StatusInternalServerError
	case codes.InvalidArgument:
		return http.StatusBadRequest
	case codes.DeadlineExceeded:
		return http.StatusGatewayTimeout
	case codes.NotFound:
		return http.StatusNotFound
	case codes.AlreadyExists:
		return http.StatusConflict
	case codes.PermissionDenied:
		return http.StatusForbidden
	case codes.ResourceExhausted:
		return http.StatusTooManyRequests
	case codes.FailedPrecondition:
		return http.StatusPreconditionFailed
	case codes.Aborted:
		return http.StatusConflict
	case codes.OutOfRange:
		return http.StatusBadRequest
	case codes.Unimplemented:
		return http.StatusNotImplemented
	case codes.Internal:
		return http.StatusInternalServerError
	case codes.Unavailable:
		return http.StatusServiceUnavailable
	case codes.DataLoss:
		return http.StatusInternalServerError
	case codes.Unauthenticated:
		return http.StatusUnauthorized
	default:
		return http.StatusInternalServerError
	}
}

// WrapError wraps a standard error with GCP error context
func WrapError(err error, code ErrorCode, message string) *Error {
	return &Error{
		Code:      string(code),
		Message:   message,
		Cause:     err,
		Timestamp: time.Now(),
		Retryable: isRetryableCode(code),
	}
}

// isRetryableCode checks if an error code is retryable
func isRetryableCode(code ErrorCode) bool {
	switch code {
	case ErrorCodeUnavailable, ErrorCodeAborted, ErrorCodeDeadlineExceeded,
	     ErrorCodeResourceExhausted, ErrorCodeTooManyRequests:
		return true
	default:
		return false
	}
}

// NewNotFoundError creates a NOT_FOUND error
func NewNotFoundError(resource string) *Error {
	return &Error{
		Code:      string(ErrorCodeNotFound),
		Message:   fmt.Sprintf("Resource not found: %s", resource),
		Resource:  resource,
		Timestamp: time.Now(),
		Retryable: false,
	}
}

// NewPermissionError creates a PERMISSION_DENIED error
func NewPermissionError(operation, resource string) *Error {
	return &Error{
		Code:      string(ErrorCodePermissionDenied),
		Message:   fmt.Sprintf("Permission denied for operation '%s' on resource '%s'", operation, resource),
		Operation: operation,
		Resource:  resource,
		Timestamp: time.Now(),
		Retryable: false,
	}
}

// NewValidationError creates an INVALID_ARGUMENT error
func NewValidationError(field, reason string) *Error {
	return &Error{
		Code:      string(ErrorCodeInvalidArgument),
		Message:   fmt.Sprintf("Validation failed for field '%s': %s", field, reason),
		Timestamp: time.Now(),
		Retryable: false,
		Details: []ErrorDetail{{
			Type:   "validation",
			Reason: reason,
			Metadata: map[string]interface{}{
				"field": field,
			},
		}},
	}
}

// NewQuotaError creates a quota exceeded error
func NewQuotaError(metric string, limit, usage int64) *Error {
	return &Error{
		Code:          string(ErrorCodeResourceExhausted),
		Message:       fmt.Sprintf("Quota exceeded for metric '%s': usage %d exceeds limit %d", metric, usage, limit),
		QuotaExceeded: true,
		QuotaMetric:   metric,
		QuotaLimit:    limit,
		QuotaUsage:    usage,
		Timestamp:     time.Now(),
		Retryable:     true,
	}
}

// NewRateLimitError creates a rate limit error
func NewRateLimitError(retryAfter time.Duration) *Error {
	return &Error{
		Code:        string(ErrorCodeTooManyRequests),
		Message:     "Rate limit exceeded",
		RateLimited: true,
		RetryAfter:  time.Now().Add(retryAfter),
		Timestamp:   time.Now(),
		Retryable:   true,
	}
}