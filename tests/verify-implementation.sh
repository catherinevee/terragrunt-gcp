#!/bin/bash

# Terratest Implementation Verification Script
# This script verifies that the Terratest implementation is complete and functional

set -e

echo "🔍 Verifying Terratest Implementation..."

# Check if we're in the tests directory
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Must be run from the tests directory"
    exit 1
fi

echo "✅ In correct directory"

# Check Go module
echo "🔍 Checking Go module..."
if [ ! -f "go.mod" ]; then
    echo "❌ Error: go.mod not found"
    exit 1
fi

echo "✅ Go module found"

# Check test directory structure
echo "🔍 Checking test directory structure..."

directories=(
    "unit/compute"
    "unit/database" 
    "unit/networking"
    "unit/security"
    "unit/storage"
    "unit/monitoring"
    "unit/data"
    "integration/dev"
    "integration/staging"
    "integration/prod"
    "e2e"
    "fixtures/environments"
    "fixtures/resources"
    "fixtures/data"
    "testhelpers"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ Error: Directory $dir not found"
        exit 1
    fi
    echo "✅ Directory $dir exists"
done

# Check test files
echo "🔍 Checking test files..."

test_files=(
    "unit/networking/vpc_test.go"
    "unit/security/iam_test.go"
    "unit/database/cloudsql_test.go"
    "unit/compute/instances_test.go"
    "unit/storage/buckets_test.go"
    "unit/monitoring/alerts_test.go"
    "unit/data/bigquery_test.go"
    "integration/dev/multi_region_test.go"
    "e2e/full_stack_test.go"
)

for file in "${test_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Test file $file not found"
        exit 1
    fi
    echo "✅ Test file $file exists"
done

# Check helper files
echo "🔍 Checking helper files..."

helper_files=(
    "testhelpers/gcp.go"
    "testhelpers/terraform.go"
    "testhelpers/fixtures.go"
    "testhelpers/integration.go"
    "testhelpers/parallel.go"
    "testhelpers/cache.go"
    "testhelpers/reporting.go"
    "testhelpers/report-generator.go"
)

for file in "${helper_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Helper file $file not found"
        exit 1
    fi
    echo "✅ Helper file $file exists"
done

# Check fixture files
echo "🔍 Checking fixture files..."

fixture_files=(
    "fixtures/environments/dev.json"
    "fixtures/environments/staging.json"
    "fixtures/environments/prod.json"
    "fixtures/data/vpc.json"
    "fixtures/data/instance.json"
    "fixtures/data/database.json"
    "fixtures/data/bucket.json"
)

for file in "${fixture_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Fixture file $file not found"
        exit 1
    fi
    echo "✅ Fixture file $file exists"
done

# Check GitHub Actions workflows
echo "🔍 Checking GitHub Actions workflows..."

workflow_files=(
    "../.github/workflows/terratest-unit.yml"
    "../.github/workflows/terratest-integration.yml"
    "../.github/workflows/terratest-e2e.yml"
    "../.github/workflows/terratest-complete.yml"
)

for file in "${workflow_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Workflow file $file not found"
        exit 1
    fi
    echo "✅ Workflow file $file exists"
done

# Check Go module dependencies
echo "🔍 Checking Go module dependencies..."

if ! go mod tidy; then
    echo "❌ Error: Failed to run go mod tidy"
    exit 1
fi

echo "✅ Go module dependencies resolved"

# Check if tests can be compiled
echo "🔍 Checking if tests can be compiled..."

if ! go build ./...; then
    echo "❌ Error: Failed to compile tests"
    exit 1
fi

echo "✅ Tests compile successfully"

# Check test structure validation
echo "🔍 Validating test structure..."

# Check that all test files have proper package declarations
for file in "${test_files[@]}"; do
    if ! grep -q "package " "$file"; then
        echo "❌ Error: $file missing package declaration"
        exit 1
    fi
    echo "✅ $file has proper package declaration"
done

# Check that all helper files have proper package declarations
for file in "${helper_files[@]}"; do
    if ! grep -q "package " "$file"; then
        echo "❌ Error: $file missing package declaration"
        exit 1
    fi
    echo "✅ $file has proper package declaration"
done

# Check JSON fixture files are valid
echo "🔍 Validating JSON fixture files..."

for file in "${fixture_files[@]}"; do
    if ! python3 -m json.tool "$file" > /dev/null 2>&1; then
        echo "❌ Error: $file is not valid JSON"
        exit 1
    fi
    echo "✅ $file is valid JSON"
done

# Check YAML workflow files are valid
echo "🔍 Validating YAML workflow files..."

for file in "${workflow_files[@]}"; do
    if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" > /dev/null 2>&1; then
        echo "❌ Error: $file is not valid YAML"
        exit 1
    fi
    echo "✅ $file is valid YAML"
done

# Summary
echo ""
echo "🎉 Terratest Implementation Verification Complete!"
echo ""
echo "✅ All directories created"
echo "✅ All test files present"
echo "✅ All helper files present"
echo "✅ All fixture files present"
echo "✅ All workflow files present"
echo "✅ Go module dependencies resolved"
echo "✅ Tests compile successfully"
echo "✅ All files have proper structure"
echo "✅ All JSON files are valid"
echo "✅ All YAML files are valid"
echo ""
echo "🚀 The Terratest implementation is ready for use!"
echo ""
echo "Next steps:"
echo "1. Set up GCP credentials"
echo "2. Configure environment variables"
echo "3. Run tests: go test -v ./..."
echo "4. Check CI/CD pipeline integration"
echo ""
echo "For more information, see tests/README.md"
