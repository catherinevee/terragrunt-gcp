# Tests

## Structure
```
test/
├── unit/         # Unit tests for individual modules
├── integration/  # Integration tests for combined modules
└── e2e/         # End-to-end tests (future)
```

## Running Tests

### Unit Tests
```bash
cd test/unit
go test -v ./...
```

### Integration Tests
```bash
cd test/integration
go test -v ./...
```

## Writing Tests

1. Create a new test file: `module_name_test.go`
2. Import the testing framework
3. Write test functions starting with `Test`
4. Run tests to verify

## Test Coverage
Target: 80% coverage for critical modules
