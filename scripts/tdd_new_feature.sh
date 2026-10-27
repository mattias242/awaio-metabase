#!/bin/bash
# TDD workflow helper - creates test file and feature branch

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <feature-name>"
    echo "Example: $0 add-booking-validation"
    exit 1
fi

FEATURE_NAME=$1
FEATURE_BRANCH="feature/$FEATURE_NAME"
TEST_FILE="tests/unit/test_${FEATURE_NAME//-/_}.py"

echo "🌳 Starting TDD workflow for: $FEATURE_NAME"
echo ""

# 1. Create feature branch
echo "1️⃣ Creating feature branch: $FEATURE_BRANCH"
git checkout main
git pull origin main
git checkout -b "$FEATURE_BRANCH"
echo "✅ Branch created"
echo ""

# 2. Create test file with template
echo "2️⃣ Creating test file: $TEST_FILE"
mkdir -p "$(dirname "$TEST_FILE")"

cat > "$TEST_FILE" << 'EOF'
"""
Unit tests for FEATURE_NAME
TDD: Write tests FIRST, then implementation
"""

import pytest


class TestFEATURE_CLASS:
    """Test suite for FEATURE_NAME."""

    def test_basic_functionality(self):
        """
        🔴 RED: This test should FAIL initially.
        Write your failing test here.
        """
        # Arrange
        # TODO: Set up test data

        # Act
        # TODO: Call the function/method being tested
        # result = my_function()

        # Assert
        # TODO: Verify expected behavior
        # assert result == expected_value
        pass

    def test_edge_case_empty_input(self):
        """
        Test edge case: empty input
        """
        pass

    def test_error_handling(self):
        """
        Test that errors are handled correctly
        """
        pass


class TestFEATURE_CLASSIntegration:
    """Integration tests for FEATURE_NAME."""

    @pytest.mark.integration
    def test_integration_scenario(self):
        """
        Integration test for complete workflow
        """
        pass
EOF

# Replace placeholders
FEATURE_CLASS=$(echo "$FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' | sed 's/ //g')
sed -i.bak "s/FEATURE_NAME/$FEATURE_NAME/g" "$TEST_FILE"
sed -i.bak "s/FEATURE_CLASS/$FEATURE_CLASS/g" "$TEST_FILE"
rm "${TEST_FILE}.bak"

echo "✅ Test file created with TDD template"
echo ""

# 3. Run the test (should fail)
echo "3️⃣ Running test (expecting FAILURE - this is RED phase)..."
echo ""

if pytest "$TEST_FILE" -v; then
    echo "⚠️  Warning: Test passed but shouldn't (no implementation yet)"
else
    echo "✅ Test failed as expected (RED phase complete)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TDD Workflow Ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Next steps:"
echo ""
echo "1. Edit test file: $TEST_FILE"
echo "   - Write failing tests (RED)"
echo ""
echo "2. Run tests to confirm failure:"
echo "   pytest $TEST_FILE -v"
echo ""
echo "3. Implement minimal code (GREEN):"
echo "   - Create implementation file"
echo "   - Make tests pass"
echo ""
echo "4. Refactor if needed (REFACTOR):"
echo "   - Improve code quality"
echo "   - Keep tests passing"
echo ""
echo "5. Commit:"
echo "   git add $TEST_FILE <implementation-file>"
echo "   git commit -m \"feat: $FEATURE_NAME\""
echo ""
echo "6. Push and create PR:"
echo "   git push -u origin $FEATURE_BRANCH"
echo "   gh pr create"
echo ""
echo "Happy TDD! 🚀"
