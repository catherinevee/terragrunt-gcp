package testhelpers

import (
    "context"
    "testing"

    "cloud.google.com/go/storage"
    "github.com/stretchr/testify/mock"
    "google.golang.org/api/option"
)

// MockGCPClient provides a mock GCP client for testing
type MockGCPClient struct {
    mock.Mock
}

// NewMockGCPClient creates a new mock GCP client
func NewMockGCPClient(t *testing.T) *MockGCPClient {
    return &MockGCPClient{}
}

// GetProject returns mock project ID
func (m *MockGCPClient) GetProject(ctx context.Context) (string, error) {
    args := m.Called(ctx)
    return args.String(0), args.Error(1)
}

// GetStorageClient returns mock storage client
func (m *MockGCPClient) GetStorageClient(ctx context.Context) (*storage.Client, error) {
    args := m.Called(ctx)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*storage.Client), args.Error(1)
}

// MockAuthService provides auth service mocking
type MockAuthService struct {
    mock.Mock
}

// GetCredentials returns mock credentials
func (m *MockAuthService) GetCredentials(ctx context.Context) (string, error) {
    args := m.Called(ctx)
    return args.String(0), args.Error(1)
}

// GetToken returns mock token
func (m *MockAuthService) GetToken(ctx context.Context) (string, error) {
    args := m.Called(ctx)
    return args.String(0), args.Error(1)
}

// CreateTestContext creates a test context with timeout
func CreateTestContext(t *testing.T) (context.Context, context.CancelFunc) {
    return context.WithTimeout(context.Background(), 30*time.Second)
}

// SetupTestEnvironment sets up test environment variables
func SetupTestEnvironment(t *testing.T) {
    t.Setenv("GCP_PROJECT_ID", "test-project")
    t.Setenv("GCP_REGION", "us-central1")
    t.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "test-credentials.json")
}
