#!/bin/bash
# Quick test runner for TDD workflow

set -e

echo "🧪 Running Awaio Test Suite..."
echo ""

# Default to all tests if no argument provided
TEST_TYPE="${1:-all}"

case "$TEST_TYPE" in
  unit)
    echo "Running unit tests only..."
    pytest tests/unit -v --tb=short
    ;;
  integration)
    echo "Running integration tests only..."
    pytest tests/integration -v --tb=short
    ;;
  e2e)
    echo "Running end-to-end tests only..."
    pytest tests/e2e -v --tb=short
    ;;
  fast)
    echo "Running fast tests only (excluding slow markers)..."
    pytest -m "not slow" -v --tb=short
    ;;
  coverage)
    echo "Running tests with coverage report..."
    pytest --cov --cov-report=term-missing --cov-report=html
    echo ""
    echo "📊 Coverage report generated in htmlcov/index.html"
    ;;
  watch)
    echo "Running tests in watch mode..."
    pytest-watch -- -v --tb=short
    ;;
  all)
    echo "Running all tests..."
    pytest -v --tb=short
    ;;
  *)
    echo "Usage: $0 {unit|integration|e2e|fast|coverage|watch|all}"
    exit 1
    ;;
esac

echo ""
echo "✅ Tests complete!"
