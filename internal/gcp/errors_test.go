package gcp

import (
	"context"
	"errors"
	"net"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"google.golang.org/api/googleapi"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestNewGCPError(t *testing.T) {
	tests := []struct {
		name      string
		operation string
		resource  string
		err       error
		want      ErrorCode
	}{
		{
			name:      "basic error",
			operation: "CreateInstance",
			resource:  "instance-1",
			err:       errors.New("basic error"),
			want:      ErrorCodeInternal,
		},
		{
			name:      "googleapi not found error",
			operation: "GetInstance",
			resource:  "instance-1",
			err:       &googleapi.Error{Code: 404, Message: "Instance not found"},
			want:      ErrorCodeNotFound,
		},
		{
			name:      "googleapi permission denied error",
			operation: "DeleteInstance",
			resource:  "instance-1",
			err:       &googleapi.Error{Code: 403, Message: "Permission denied"},
			want:      ErrorCodePermissionDenied,
		},
		{
			name:      "googleapi conflict error",
			operation: "CreateInstance",
			resource:  "instance-1",
			err:       &googleapi.Error{Code: 409, Message: "Instance already exists"},
			want:      ErrorCodeAlreadyExists,
		},
		{
			name:      "grpc not found error",
			operation: "GetBucket",
			resource:  "bucket-1",
			err:       status.Error(codes.NotFound, "Bucket not found"),
			want:      ErrorCodeNotFound,
		},
		{
			name:      "grpc permission denied error",
			operation: "CreateBucket",
			resource:  "bucket-1",
			err:       status.Error(codes.PermissionDenied, "Permission denied"),
			want:      ErrorCodePermissionDenied,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gcpErr := NewGCPError(tt.operation, tt.resource, tt.err)

			if gcpErr.Code != tt.want {
				t.Errorf("NewGCPError() Code = %v, want %v", gcpErr.Code, tt.want)
			}

			if gcpErr.Operation != tt.operation {
				t.Errorf("NewGCPError() Operation = %v, want %v", gcpErr.Operation, tt.operation)
			}

			if gcpErr.Resource != tt.resource {
				t.Errorf("NewGCPError() Resource = %v, want %v", gcpErr.Resource, tt.resource)
			}

			if gcpErr.OriginalError != tt.err {
				t.Errorf("NewGCPError() OriginalError = %v, want %v", gcpErr.OriginalError, tt.err)
			}

			if gcpErr.Timestamp.IsZero() {
				t.Error("NewGCPError() Timestamp should not be zero")
			}
		})
	}
}

func TestGCPError_Error(t *testing.T) {
	originalErr := errors.New("original error message")
	gcpErr := NewGCPError("TestOperation", "test-resource", originalErr)

	errorMsg := gcpErr.Error()

	if !strings.Contains(errorMsg, "TestOperation") {
		t.Error("Error() should contain operation name")
	}

	if !strings.Contains(errorMsg, "test-resource") {
		t.Error("Error() should contain resource name")
	}

	if !strings.Contains(errorMsg, "original error message") {
		t.Error("Error() should contain original error message")
	}

	if !strings.Contains(errorMsg, gcpErr.Code.String()) {
		t.Error("Error() should contain error code")
	}
}

func TestGCPError_Is(t *testing.T) {
	originalErr := errors.New("test error")
	gcpErr := NewGCPError("TestOperation", "test-resource", originalErr)

	if !gcpErr.Is(originalErr) {
		t.Error("Is() should return true for original error")
	}

	otherErr := errors.New("other error")
	if gcpErr.Is(otherErr) {
		t.Error("Is() should return false for different error")
	}

	anotherGCPErr := NewGCPError("OtherOperation", "other-resource", originalErr)
	if !gcpErr.Is(anotherGCPErr) {
		t.Error("Is() should return true for GCPError with same original error")
	}
}

func TestGCPError_Unwrap(t *testing.T) {
	originalErr := errors.New("test error")
	gcpErr := NewGCPError("TestOperation", "test-resource", originalErr)

	unwrapped := gcpErr.Unwrap()
	if unwrapped != originalErr {
		t.Errorf("Unwrap() = %v, want %v", unwrapped, originalErr)
	}
}

func TestErrorCode_String(t *testing.T) {
	tests := []struct {
		code ErrorCode
		want string
	}{
		{ErrorCodeUnknown, "UNKNOWN"},
		{ErrorCodeInvalidArgument, "INVALID_ARGUMENT"},
		{ErrorCodeDeadlineExceeded, "DEADLINE_EXCEEDED"},
		{ErrorCodeNotFound, "NOT_FOUND"},
		{ErrorCodeAlreadyExists, "ALREADY_EXISTS"},
		{ErrorCodePermissionDenied, "PERMISSION_DENIED"},
		{ErrorCodeResourceExhausted, "RESOURCE_EXHAUSTED"},
		{ErrorCodeFailedPrecondition, "FAILED_PRECONDITION"},
		{ErrorCodeAborted, "ABORTED"},
		{ErrorCodeOutOfRange, "OUT_OF_RANGE"},
		{ErrorCodeUnimplemented, "UNIMPLEMENTED"},
		{ErrorCodeInternal, "INTERNAL"},
		{ErrorCodeUnavailable, "UNAVAILABLE"},
		{ErrorCodeDataLoss, "DATA_LOSS"},
		{ErrorCodeUnauthenticated, "UNAUTHENTICATED"},
		{ErrorCodeQuotaExceeded, "QUOTA_EXCEEDED"},
		{ErrorCodeRateLimited, "RATE_LIMITED"},
		{ErrorCodeTimeout, "TIMEOUT"},
		{ErrorCodeNetworkError, "NETWORK_ERROR"},
		{ErrorCodeCancelled, "CANCELLED"},
		{ErrorCode(999), "UNKNOWN"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.code.String(); got != tt.want {
				t.Errorf("ErrorCode.String() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestErrorCode_IsRetryable(t *testing.T) {
	tests := []struct {
		code      ErrorCode
		retryable bool
	}{
		{ErrorCodeUnknown, false},
		{ErrorCodeInvalidArgument, false},
		{ErrorCodeDeadlineExceeded, true},
		{ErrorCodeNotFound, false},
		{ErrorCodeAlreadyExists, false},
		{ErrorCodePermissionDenied, false},
		{ErrorCodeResourceExhausted, true},
		{ErrorCodeFailedPrecondition, false},
		{ErrorCodeAborted, true},
		{ErrorCodeOutOfRange, false},
		{ErrorCodeUnimplemented, false},
		{ErrorCodeInternal, true},
		{ErrorCodeUnavailable, true},
		{ErrorCodeDataLoss, false},
		{ErrorCodeUnauthenticated, false},
		{ErrorCodeQuotaExceeded, true},
		{ErrorCodeRateLimited, true},
		{ErrorCodeTimeout, true},
		{ErrorCodeNetworkError, true},
		{ErrorCodeCancelled, false},
	}

	for _, tt := range tests {
		t.Run(tt.code.String(), func(t *testing.T) {
			if got := tt.code.IsRetryable(); got != tt.retryable {
				t.Errorf("ErrorCode.IsRetryable() = %v, want %v", got, tt.retryable)
			}
		})
	}
}

func TestClassifyGoogleAPIError(t *testing.T) {
	tests := []struct {
		name string
		err  *googleapi.Error
		want ErrorCode
	}{
		{
			name: "bad request",
			err:  &googleapi.Error{Code: 400, Message: "Bad request"},
			want: ErrorCodeInvalidArgument,
		},
		{
			name: "unauthorized",
			err:  &googleapi.Error{Code: 401, Message: "Unauthorized"},
			want: ErrorCodeUnauthenticated,
		},
		{
			name: "forbidden",
			err:  &googleapi.Error{Code: 403, Message: "Forbidden"},
			want: ErrorCodePermissionDenied,
		},
		{
			name: "not found",
			err:  &googleapi.Error{Code: 404, Message: "Not found"},
			want: ErrorCodeNotFound,
		},
		{
			name: "conflict",
			err:  &googleapi.Error{Code: 409, Message: "Conflict"},
			want: ErrorCodeAlreadyExists,
		},
		{
			name: "precondition failed",
			err:  &googleapi.Error{Code: 412, Message: "Precondition failed"},
			want: ErrorCodeFailedPrecondition,
		},
		{
			name: "too many requests",
			err:  &googleapi.Error{Code: 429, Message: "Too many requests"},
			want: ErrorCodeRateLimited,
		},
		{
			name: "internal server error",
			err:  &googleapi.Error{Code: 500, Message: "Internal server error"},
			want: ErrorCodeInternal,
		},
		{
			name: "bad gateway",
			err:  &googleapi.Error{Code: 502, Message: "Bad gateway"},
			want: ErrorCodeUnavailable,
		},
		{
			name: "service unavailable",
			err:  &googleapi.Error{Code: 503, Message: "Service unavailable"},
			want: ErrorCodeUnavailable,
		},
		{
			name: "gateway timeout",
			err:  &googleapi.Error{Code: 504, Message: "Gateway timeout"},
			want: ErrorCodeTimeout,
		},
		{
			name: "quota exceeded specific message",
			err:  &googleapi.Error{Code: 403, Message: "Quota exceeded for quota metric"},
			want: ErrorCodeQuotaExceeded,
		},
		{
			name: "rate limited specific message",
			err:  &googleapi.Error{Code: 403, Message: "Rate limit exceeded"},
			want: ErrorCodeRateLimited,
		},
		{
			name: "unknown code",
			err:  &googleapi.Error{Code: 999, Message: "Unknown error"},
			want: ErrorCodeUnknown,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := classifyGoogleAPIError(tt.err); got != tt.want {
				t.Errorf("classifyGoogleAPIError() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestClassifyGRPCError(t *testing.T) {
	tests := []struct {
		name string
		code codes.Code
		want ErrorCode
	}{
		{codes.OK, ErrorCodeUnknown},
		{codes.Canceled, ErrorCodeCancelled},
		{codes.Unknown, ErrorCodeUnknown},
		{codes.InvalidArgument, ErrorCodeInvalidArgument},
		{codes.DeadlineExceeded, ErrorCodeDeadlineExceeded},
		{codes.NotFound, ErrorCodeNotFound},
		{codes.AlreadyExists, ErrorCodeAlreadyExists},
		{codes.PermissionDenied, ErrorCodePermissionDenied},
		{codes.ResourceExhausted, ErrorCodeResourceExhausted},
		{codes.FailedPrecondition, ErrorCodeFailedPrecondition},
		{codes.Aborted, ErrorCodeAborted},
		{codes.OutOfRange, ErrorCodeOutOfRange},
		{codes.Unimplemented, ErrorCodeUnimplemented},
		{codes.Internal, ErrorCodeInternal},
		{codes.Unavailable, ErrorCodeUnavailable},
		{codes.DataLoss, ErrorCodeDataLoss},
		{codes.Unauthenticated, ErrorCodeUnauthenticated},
	}

	for _, tt := range tests {
		t.Run(tt.code.String(), func(t *testing.T) {
			err := status.Error(tt.code, "test message")
			if got := classifyGRPCError(err); got != tt.want {
				t.Errorf("classifyGRPCError() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestClassifyNetworkError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want ErrorCode
	}{
		{
			name: "timeout error",
			err:  &net.OpError{Op: "dial", Err: &timeoutError{}},
			want: ErrorCodeTimeout,
		},
		{
			name: "dns error",
			err:  &net.DNSError{Err: "no such host", IsTimeout: false},
			want: ErrorCodeNetworkError,
		},
		{
			name: "connection refused",
			err:  &net.OpError{Op: "dial", Err: errors.New("connection refused")},
			want: ErrorCodeNetworkError,
		},
		{
			name: "other network error",
			err:  &net.OpError{Op: "read", Err: errors.New("network unreachable")},
			want: ErrorCodeNetworkError,
		},
		{
			name: "non-network error",
			err:  errors.New("regular error"),
			want: ErrorCodeUnknown,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := classifyNetworkError(tt.err); got != tt.want {
				t.Errorf("classifyNetworkError() = %v, want %v", got, tt.want)
			}
		})
	}
}

type timeoutError struct{}

func (e *timeoutError) Error() string   { return "timeout" }
func (e *timeoutError) Timeout() bool   { return true }
func (e *timeoutError) Temporary() bool { return true }

func TestClassifyHTTPError(t *testing.T) {
	tests := []struct {
		name       string
		statusCode int
		want       ErrorCode
	}{
		{name: "bad request", statusCode: 400, want: ErrorCodeInvalidArgument},
		{name: "unauthorized", statusCode: 401, want: ErrorCodeUnauthenticated},
		{name: "forbidden", statusCode: 403, want: ErrorCodePermissionDenied},
		{name: "not found", statusCode: 404, want: ErrorCodeNotFound},
		{name: "conflict", statusCode: 409, want: ErrorCodeAlreadyExists},
		{name: "precondition failed", statusCode: 412, want: ErrorCodeFailedPrecondition},
		{name: "too many requests", statusCode: 429, want: ErrorCodeRateLimited},
		{name: "internal server error", statusCode: 500, want: ErrorCodeInternal},
		{name: "bad gateway", statusCode: 502, want: ErrorCodeUnavailable},
		{name: "service unavailable", statusCode: 503, want: ErrorCodeUnavailable},
		{name: "gateway timeout", statusCode: 504, want: ErrorCodeTimeout},
		{name: "unknown status", statusCode: 999, want: ErrorCodeUnknown},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := &httpError{statusCode: tt.statusCode}
			if got := classifyHTTPError(err); got != tt.want {
				t.Errorf("classifyHTTPError() = %v, want %v", got, tt.want)
			}
		})
	}
}

type httpError struct {
	statusCode int
}

func (e *httpError) Error() string {
	return "HTTP " + strconv.Itoa(e.statusCode)
}

func TestIsRetryableError(t *testing.T) {
	tests := []struct {
		name      string
		err       error
		retryable bool
	}{
		{
			name:      "retryable GCP error",
			err:       NewGCPError("test", "resource", &googleapi.Error{Code: 503}),
			retryable: true,
		},
		{
			name:      "non-retryable GCP error",
			err:       NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			retryable: false,
		},
		{
			name:      "timeout error",
			err:       context.DeadlineExceeded,
			retryable: true,
		},
		{
			name:      "cancelled error",
			err:       context.Canceled,
			retryable: false,
		},
		{
			name:      "network timeout",
			err:       &net.OpError{Op: "dial", Err: &timeoutError{}},
			retryable: true,
		},
		{
			name:      "regular error",
			err:       errors.New("regular error"),
			retryable: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsRetryableError(tt.err); got != tt.retryable {
				t.Errorf("IsRetryableError() = %v, want %v", got, tt.retryable)
			}
		})
	}
}

func TestIsTimeoutError(t *testing.T) {
	tests := []struct {
		name    string
		err     error
		timeout bool
	}{
		{
			name:    "context deadline exceeded",
			err:     context.DeadlineExceeded,
			timeout: true,
		},
		{
			name:    "GCP timeout error",
			err:     NewGCPError("test", "resource", &googleapi.Error{Code: 504}),
			timeout: true,
		},
		{
			name:    "network timeout",
			err:     &net.OpError{Op: "dial", Err: &timeoutError{}},
			timeout: true,
		},
		{
			name:    "DNS timeout",
			err:     &net.DNSError{Err: "timeout", IsTimeout: true},
			timeout: true,
		},
		{
			name:    "regular error",
			err:     errors.New("regular error"),
			timeout: false,
		},
		{
			name:    "not found error",
			err:     NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			timeout: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsTimeoutError(tt.err); got != tt.timeout {
				t.Errorf("IsTimeoutError() = %v, want %v", got, tt.timeout)
			}
		})
	}
}

func TestIsNotFoundError(t *testing.T) {
	tests := []struct {
		name     string
		err      error
		notFound bool
	}{
		{
			name:     "GCP not found error",
			err:      NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			notFound: true,
		},
		{
			name:     "GRPC not found error",
			err:      NewGCPError("test", "resource", status.Error(codes.NotFound, "not found")),
			notFound: true,
		},
		{
			name:     "regular error",
			err:      errors.New("regular error"),
			notFound: false,
		},
		{
			name:     "permission denied error",
			err:      NewGCPError("test", "resource", &googleapi.Error{Code: 403}),
			notFound: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsNotFoundError(tt.err); got != tt.notFound {
				t.Errorf("IsNotFoundError() = %v, want %v", got, tt.notFound)
			}
		})
	}
}

func TestIsPermissionDeniedError(t *testing.T) {
	tests := []struct {
		name             string
		err              error
		permissionDenied bool
	}{
		{
			name:             "GCP permission denied error",
			err:              NewGCPError("test", "resource", &googleapi.Error{Code: 403}),
			permissionDenied: true,
		},
		{
			name:             "GRPC permission denied error",
			err:              NewGCPError("test", "resource", status.Error(codes.PermissionDenied, "permission denied")),
			permissionDenied: true,
		},
		{
			name:             "regular error",
			err:              errors.New("regular error"),
			permissionDenied: false,
		},
		{
			name:             "not found error",
			err:              NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			permissionDenied: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsPermissionDeniedError(tt.err); got != tt.permissionDenied {
				t.Errorf("IsPermissionDeniedError() = %v, want %v", got, tt.permissionDenied)
			}
		})
	}
}

func TestIsAlreadyExistsError(t *testing.T) {
	tests := []struct {
		name          string
		err           error
		alreadyExists bool
	}{
		{
			name:          "GCP already exists error",
			err:           NewGCPError("test", "resource", &googleapi.Error{Code: 409}),
			alreadyExists: true,
		},
		{
			name:          "GRPC already exists error",
			err:           NewGCPError("test", "resource", status.Error(codes.AlreadyExists, "already exists")),
			alreadyExists: true,
		},
		{
			name:          "regular error",
			err:           errors.New("regular error"),
			alreadyExists: false,
		},
		{
			name:          "not found error",
			err:           NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			alreadyExists: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsAlreadyExistsError(tt.err); got != tt.alreadyExists {
				t.Errorf("IsAlreadyExistsError() = %v, want %v", got, tt.alreadyExists)
			}
		})
	}
}

func TestIsQuotaExceededError(t *testing.T) {
	tests := []struct {
		name          string
		err           error
		quotaExceeded bool
	}{
		{
			name:          "quota exceeded in message",
			err:           NewGCPError("test", "resource", &googleapi.Error{Code: 403, Message: "Quota exceeded"}),
			quotaExceeded: true,
		},
		{
			name:          "quota limit in message",
			err:           NewGCPError("test", "resource", &googleapi.Error{Code: 403, Message: "Quota limit exceeded"}),
			quotaExceeded: true,
		},
		{
			name:          "GRPC resource exhausted",
			err:           NewGCPError("test", "resource", status.Error(codes.ResourceExhausted, "quota exceeded")),
			quotaExceeded: true,
		},
		{
			name:          "regular permission denied",
			err:           NewGCPError("test", "resource", &googleapi.Error{Code: 403, Message: "Access denied"}),
			quotaExceeded: false,
		},
		{
			name:          "regular error",
			err:           errors.New("regular error"),
			quotaExceeded: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsQuotaExceededError(tt.err); got != tt.quotaExceeded {
				t.Errorf("IsQuotaExceededError() = %v, want %v", got, tt.quotaExceeded)
			}
		})
	}
}

func TestIsRateLimitedError(t *testing.T) {
	tests := []struct {
		name        string
		err         error
		rateLimited bool
	}{
		{
			name:        "rate limit exceeded in message",
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 403, Message: "Rate limit exceeded"}),
			rateLimited: true,
		},
		{
			name:        "too many requests",
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 429, Message: "Too many requests"}),
			rateLimited: true,
		},
		{
			name:        "GRPC resource exhausted with rate limit",
			err:         NewGCPError("test", "resource", status.Error(codes.ResourceExhausted, "rate limit exceeded")),
			rateLimited: true,
		},
		{
			name:        "regular error",
			err:         errors.New("regular error"),
			rateLimited: false,
		},
		{
			name:        "not found error",
			err:         NewGCPError("test", "resource", &googleapi.Error{Code: 404}),
			rateLimited: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsRateLimitedError(tt.err); got != tt.rateLimited {
				t.Errorf("IsRateLimitedError() = %v, want %v", got, tt.rateLimited)
			}
		})
	}
}

func TestExtractErrorDetails(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want map[string]interface{}
	}{
		{
			name: "GCP error with details",
			err: &GCPError{
				Code:      ErrorCodeNotFound,
				Operation: "GetInstance",
				Resource:  "instance-1",
				Message:   "Instance not found",
				Details: map[string]interface{}{
					"project": "test-project",
					"zone":    "us-central1-a",
				},
			},
			want: map[string]interface{}{
				"code":      "NOT_FOUND",
				"operation": "GetInstance",
				"resource":  "instance-1",
				"message":   "Instance not found",
				"project":   "test-project",
				"zone":      "us-central1-a",
			},
		},
		{
			name: "googleapi error",
			err:  &googleapi.Error{Code: 404, Message: "Not found"},
			want: map[string]interface{}{
				"http_status_code": 404,
				"message":          "Not found",
			},
		},
		{
			name: "regular error",
			err:  errors.New("regular error"),
			want: map[string]interface{}{
				"message": "regular error",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractErrorDetails(tt.err)

			for key, expectedValue := range tt.want {
				if gotValue, exists := got[key]; !exists || gotValue != expectedValue {
					t.Errorf("ExtractErrorDetails() key %s = %v, want %v", key, gotValue, expectedValue)
				}
			}
		})
	}
}

func TestGCPError_WithDetails(t *testing.T) {
	originalErr := errors.New("original error")
	gcpErr := NewGCPError("TestOperation", "test-resource", originalErr)

	details := map[string]interface{}{
		"project": "test-project",
		"zone":    "us-central1-a",
		"attempt": 1,
	}

	updatedErr := gcpErr.WithDetails(details)

	for key, expectedValue := range details {
		if gotValue, exists := updatedErr.Details[key]; !exists || gotValue != expectedValue {
			t.Errorf("WithDetails() key %s = %v, want %v", key, gotValue, expectedValue)
		}
	}

	// Verify original error is not modified
	if len(gcpErr.Details) != 0 {
		t.Error("WithDetails() should not modify original error")
	}
}

func TestGCPError_WithContext(t *testing.T) {
	originalErr := errors.New("original error")
	gcpErr := NewGCPError("TestOperation", "test-resource", originalErr)

	context := map[string]interface{}{
		"request_id": "req-123",
		"user_id":    "user-456",
	}

	updatedErr := gcpErr.WithContext(context)

	for key, expectedValue := range context {
		if gotValue, exists := updatedErr.Context[key]; !exists || gotValue != expectedValue {
			t.Errorf("WithContext() key %s = %v, want %v", key, gotValue, expectedValue)
		}
	}

	// Verify original error is not modified
	if len(gcpErr.Context) != 0 {
		t.Error("WithContext() should not modify original error")
	}
}

func TestErrorAggregation(t *testing.T) {
	err1 := NewGCPError("Op1", "resource1", errors.New("error 1"))
	err2 := NewGCPError("Op2", "resource2", errors.New("error 2"))
	err3 := errors.New("regular error")

	errors := []error{err1, err2, err3}

	// Test that we can collect and analyze multiple errors
	var gcpErrors []*GCPError
	var otherErrors []error

	for _, err := range errors {
		if gcpErr, ok := err.(*GCPError); ok {
			gcpErrors = append(gcpErrors, gcpErr)
		} else {
			otherErrors = append(otherErrors, err)
		}
	}

	if len(gcpErrors) != 2 {
		t.Errorf("Expected 2 GCP errors, got %d", len(gcpErrors))
	}

	if len(otherErrors) != 1 {
		t.Errorf("Expected 1 other error, got %d", len(otherErrors))
	}
}

func BenchmarkNewGCPError(b *testing.B) {
	originalErr := &googleapi.Error{Code: 404, Message: "Not found"}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		NewGCPError("TestOperation", "test-resource", originalErr)
	}
}

func BenchmarkErrorClassification(b *testing.B) {
	googleAPIErr := &googleapi.Error{Code: 404, Message: "Not found"}
	grpcErr := status.Error(codes.NotFound, "not found")
	networkErr := &net.OpError{Op: "dial", Err: &timeoutError{}}

	b.Run("GoogleAPI", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			classifyGoogleAPIError(googleAPIErr)
		}
	})

	b.Run("GRPC", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			classifyGRPCError(grpcErr)
		}
	})

	b.Run("Network", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			classifyNetworkError(networkErr)
		}
	})
}

func BenchmarkErrorChecking(b *testing.B) {
	err := NewGCPError("test", "resource", &googleapi.Error{Code: 503})

	b.Run("IsRetryable", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			IsRetryableError(err)
		}
	})

	b.Run("IsTimeout", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			IsTimeoutError(err)
		}
	})

	b.Run("IsNotFound", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			IsNotFoundError(err)
		}
	})
}