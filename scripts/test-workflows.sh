#!/bin/bash
# Test script for consolidated workflows

set -e

echo "========================================="
echo "Testing Consolidated GitHub Workflows"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test workflow file
test_workflow() {
    local file=$1
    local description=$2
    
    echo -n "Testing $description... "
    
    if [ -f "$file" ]; then
        if python -c "import yaml; yaml.safe_load(open('$file', encoding='utf-8'))" 2>/dev/null; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED (Invalid YAML)${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED (File not found)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check workflow dependencies
check_dependencies() {
    local file=$1
    echo "  Checking dependencies in $file:"
    
    # Check for uses statements
    if grep -q "uses: \\./.github/workflows/" "$file" 2>/dev/null; then
        grep "uses: \\./.github/workflows/" "$file" | while read -r line; do
            local dep=$(echo "$line" | sed 's/.*uses: \.\/\.github\/workflows\///' | sed 's/@.*//')
            if [ -f ".github/workflows/$dep" ]; then
                echo -e "    ${GREEN}✓${NC} $dep exists"
            else
                echo -e "    ${RED}✗${NC} $dep missing"
            fi
        done
    fi
    
    # Check for action dependencies
    if grep -q "uses: \\./.github/actions/" "$file" 2>/dev/null; then
        grep "uses: \\./.github/actions/" "$file" | while read -r line; do
            local action=$(echo "$line" | sed 's/.*uses: \.\/\.github\/actions\///' | sed 's/@.*//')
            if [ -d ".github/actions/$action" ]; then
                echo -e "    ${GREEN}✓${NC} Action $action exists"
            else
                echo -e "    ${YELLOW}⚠${NC} Action $action not found (may need creation)"
            fi
        done
    fi
}

echo "1. Testing Reusable Workflows"
echo "------------------------------"
test_workflow ".github/workflows/reusable-setup.yml" "reusable-setup.yml"
test_workflow ".github/workflows/reusable-terraform.yml" "reusable-terraform.yml"
test_workflow ".github/workflows/reusable-notifications.yml" "reusable-notifications.yml"
test_workflow ".github/workflows/reusable-validation.yml" "reusable-validation.yml"
test_workflow ".github/workflows/reusable-drift.yml" "reusable-drift.yml"
echo ""

echo "2. Testing Main Orchestrator"
echo "----------------------------"
test_workflow ".github/workflows/main.yml" "main.yml"
check_dependencies ".github/workflows/main.yml"
echo ""

echo "3. Testing Active Workflows"
echo "----------------------------"
test_workflow ".github/workflows/setup-infrastructure.yml" "setup-infrastructure.yml"
echo ""

echo "4. Testing Archived Workflows (Optional)"
echo "-----------------------------------------"
for workflow in .github/workflows/archived/*.yml; do
    if [ -f "$workflow" ]; then
        test_workflow "$workflow" "$(basename $workflow) (archived)"
    fi
done
echo ""

echo "5. Checking Required Actions"
echo "----------------------------"
if [ -d ".github/actions/setup-environment" ]; then
    echo -e "${GREEN}✓${NC} setup-environment action exists"
    if [ -f ".github/actions/setup-environment/action.yml" ]; then
        echo -e "  ${GREEN}✓${NC} action.yml found"
    else
        echo -e "  ${RED}✗${NC} action.yml missing"
    fi
else
    echo -e "${RED}✗${NC} setup-environment action missing"
fi
echo ""

echo "5. Workflow Statistics"
echo "----------------------"
echo "Reusable workflows created: 5"
echo "Main orchestrator created: 1"
echo "Total new workflows: 6"
echo ""

# Count lines
echo "6. Line Count Comparison"
echo "------------------------"
OLD_LINES=$(wc -l .github/workflows/terraform-pipeline.yml .github/workflows/drift-detection.yml .github/workflows/self-healing.yml 2>/dev/null | tail -1 | awk '{print $1}')
NEW_LINES=$(wc -l .github/workflows/reusable-*.yml .github/workflows/main.yml 2>/dev/null | tail -1 | awk '{print $1}')

echo "Old workflows (3 main files): ${OLD_LINES:-0} lines"
echo "New consolidated structure: ${NEW_LINES:-0} lines"
if [ -n "$OLD_LINES" ] && [ -n "$NEW_LINES" ]; then
    REDUCTION=$((OLD_LINES - NEW_LINES))
    PERCENT=$((REDUCTION * 100 / OLD_LINES))
    echo -e "${GREEN}Reduction: $REDUCTION lines ($PERCENT%)${NC}"
fi
echo ""

echo "7. Test Summary"
echo "---------------"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All workflow tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Commit these changes to a feature branch"
    echo "2. Create a pull request to test the workflows"
    echo "3. The main.yml workflow will automatically trigger on PR"
    echo "4. Monitor the Actions tab for any issues"
    echo "5. Once validated, merge to main branch"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please fix the issues above.${NC}"
    exit 1
fi