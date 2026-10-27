#!/bin/bash
# Simulate CI pipeline locally before pushing

set -e

echo "🚀 Running Local CI Pipeline..."
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_step() {
    local step_name=$1
    local command=$2

    echo -e "${YELLOW}➜ $step_name${NC}"
    if eval "$command"; then
        echo -e "${GREEN}✓ $step_name passed${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ $step_name failed${NC}"
        echo ""
        return 1
    fi
}

# Track failures
FAILED_STEPS=()

# Step 1: Unit Tests
if ! run_step "Unit Tests" "pytest tests/unit -v --tb=short"; then
    FAILED_STEPS+=("Unit Tests")
fi

# Step 2: Integration Tests (if exist)
if [ -d "tests/integration" ] && [ "$(ls -A tests/integration)" ]; then
    if ! run_step "Integration Tests" "pytest tests/integration -v --tb=short"; then
        FAILED_STEPS+=("Integration Tests")
    fi
fi

# Step 3: Code Coverage
if ! run_step "Code Coverage" "pytest --cov --cov-fail-under=80 -q"; then
    FAILED_STEPS+=("Code Coverage")
fi

# Step 4: Black Formatting
if ! run_step "Black Formatting" "black --check ."; then
    FAILED_STEPS+=("Black Formatting")
    echo -e "${YELLOW}💡 Tip: Run 'black .' to auto-format${NC}"
    echo ""
fi

# Step 5: isort Import Sorting
if ! run_step "isort Import Sorting" "isort --check-only ."; then
    FAILED_STEPS+=("isort")
    echo -e "${YELLOW}💡 Tip: Run 'isort .' to auto-sort imports${NC}"
    echo ""
fi

# Step 6: Flake8 Linting
if ! run_step "Flake8 Linting" "flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics"; then
    FAILED_STEPS+=("Flake8")
fi

# Step 7: Security - Bandit
if ! run_step "Security Scan (Bandit)" "bandit -r . -ll -q"; then
    FAILED_STEPS+=("Bandit")
fi

# Step 8: Security - Safety
if ! run_step "Dependency Security (Safety)" "safety check --json > /dev/null 2>&1"; then
    FAILED_STEPS+=("Safety")
    echo -e "${YELLOW}⚠️  Some dependencies have known vulnerabilities${NC}"
    echo ""
fi

# Summary
echo "================================"
echo "📊 CI Pipeline Summary"
echo "================================"
echo ""

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to push.${NC}"
    exit 0
else
    echo -e "${RED}❌ ${#FAILED_STEPS[@]} check(s) failed:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
        echo -e "${RED}  - $step${NC}"
    done
    echo ""
    echo -e "${YELLOW}Fix the issues above before pushing.${NC}"
    exit 1
fi
