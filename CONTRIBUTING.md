# Contributing to Awaio

We use **Trunk-Based Development** with **Test-Driven Development (TDD)** to keep code quality high and iteration fast.

## 🌳 Trunk-Based Development Workflow

### Principles

1. **One main branch (main/trunk)** - all code is merged directly to `main`
2. **Short feature branches** - at most 1-2 days, usually a few hours
3. **Small, frequent commits** - merge early and often
4. **Feature flags** - for unfinished functionality
5. **CI/CD pipeline** - automatic tests on every commit
6. **Fast feedback** - tests run in < 10 minutes

### Branching Strategy

```
main (trunk)
  ↑
  └── feature/add-booking-validation (short-lived, < 2 days)
  └── fix/database-connection-pool (short-lived)
```

**Avoid:**
- ❌ Long-lived feature branches
- ❌ Git Flow (develop, release branches)
- ❌ Large merge requests with hundreds of lines

**Do instead:**
- ✅ Small pull requests (< 400 lines)
- ✅ Merge to main at least once a day
- ✅ Use feature flags for unfinished functionality

## 🧪 Test-Driven Development (TDD)

### Red-Green-Refactor Cycle

1. **🔴 Red** - write a test that fails
2. **🟢 Green** - write the minimal code to make the test pass
3. **🔵 Refactor** - improve the code without changing behaviour
4. **Repeat** - go back to step 1

### TDD workflow for new functionality

```bash
# 1. Create a feature branch from main
git checkout main
git pull origin main
git checkout -b feature/add-entity-validation

# 2. Write the test FIRST (Red)
# Create tests/unit/test_entity_validation.py
cat > tests/unit/test_entity_validation.py << 'EOF'
def test_entity_name_cannot_be_empty():
    entity = Entity(name="")
    assert not entity.is_valid()
    assert "name cannot be empty" in entity.errors
EOF

# 3. Run the test - it should fail (Red)
pytest tests/unit/test_entity_validation.py -v
# FAIL - Entity class doesn't exist yet

# 4. Write a minimal implementation (Green)
# Implement the Entity class in entity.py

# 5. Run the test again - it should pass (Green)
pytest tests/unit/test_entity_validation.py -v
# PASS - Test passes!

# 6. Refactor (if needed)
# Improve the code, run the tests again

# 7. Commit test + implementation
git add tests/unit/test_entity_validation.py entity.py
git commit -m "Add entity name validation

- Add test for empty entity name validation
- Implement Entity.is_valid() method
- Entity name must not be empty

TDD: Red-Green-Refactor cycle"

# 8. Push and create a PR
git push -u origin feature/add-entity-validation
gh pr create --title "Add entity name validation" --body "Implements validation for entity names following TDD"
```

### Test structure

```
tests/
├── unit/           # Fast, isolated tests (< 100ms per test)
│   ├── api/        # API client tests
│   ├── database/   # Database layer tests
│   └── chat_app/   # Chat app tests
├── integration/    # Tests against the database/external services (< 1s per test)
└── e2e/           # End-to-end tests (< 10s per test)
```

### Writing good tests

**AAA Pattern:**
```python
def test_booking_creation():
    # Arrange - set up test data
    user = create_test_user()
    entity = create_test_entity()

    # Act - perform the operation
    booking = create_booking(user, entity, start_time, end_time)

    # Assert - verify the result
    assert booking.owner_id == user.id
    assert booking.entity_id == entity.id
```

**Test naming:**
```python
# ✅ Good - describes what is tested and the expected behaviour
def test_booking_creation_fails_when_entity_is_already_booked():
    pass

def test_user_authentication_returns_token_on_success():
    pass

# ❌ Bad - vague, unclear names
def test_booking():
    pass

def test_auth():
    pass
```

## 📋 Pull Request Process

### 1. Before you create a PR

```bash
# Run all tests locally
pytest

# Run linters
black .
flake8 .
isort .

# Run pre-commit hooks
pre-commit run --all-files
```

### 2. PR Checklist

- [ ] **Tests written BEFORE the implementation** (TDD)
- [ ] All tests pass (`pytest`)
- [ ] Code coverage ≥ 80% (`pytest --cov`)
- [ ] Linters pass (black, flake8, isort)
- [ ] PR is < 400 lines of code
- [ ] Commit messages are clear
- [ ] Documentation updated (if relevant)

### 3. PR Template

```markdown
## Description
Short description of what the PR does.

## TDD Approach
- [ ] Tests written first
- [ ] Red-Green-Refactor cycle followed
- [ ] Test coverage: XX%

## Type of change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] All tests passing locally

## Checklist
- [ ] Code follows project style guide
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
```

### 4. CI/CD Pipeline

When you push code, these run automatically:

1. **Unit Tests** - all unit tests (< 1 min)
2. **Integration Tests** - tests against the database (< 2 min)
3. **Linting** - code quality checks (< 1 min)
4. **Security Scan** - Bandit, Safety (< 1 min)
5. **Docker Build** - verify that the containers build (< 3 min)

**Total CI time: < 10 minutes**

### 5. Merging to Main

A PR can be merged when:
- ✅ All CI checks are green
- ✅ At least 80% code coverage
- ✅ Code review approved (if configured)
- ✅ No merge conflicts

```bash
# Squash merge (recommended for small PRs)
gh pr merge --squash --delete-branch

# Or via the GitHub UI
```

## 🔧 Development Setup

### 1. Clone the repo and install dependencies

```bash
git clone https://github.com/mattias242/awaio-metabase.git
cd awaio-metabase
pip install -r requirements.txt
```

### 2. Install pre-commit hooks

```bash
pip install pre-commit
pre-commit install
```

This runs automatically:
- Pytest on every commit
- Code formatting (black, isort)
- Linting (flake8)
- Security checks (bandit)

### 3. Run tests

```bash
# All tests
pytest

# Unit tests only
pytest tests/unit -v

# With coverage
pytest --cov --cov-report=html

# Watch mode (runs tests on every file change)
pytest-watch
```

### 4. Run linters

```bash
# Format code
black .
isort .

# Check linting
flake8 .

# Type checking
mypy .
```

## 📊 Code Coverage

We aim for **≥ 80% code coverage**.

```bash
# Generate a coverage report
pytest --cov --cov-report=html

# Open the report
open htmlcov/index.html
```

**Coverage goals:**
- Unit tests: ≥ 90%
- Integration tests: ≥ 70%
- Overall: ≥ 80%

## 🚀 Continuous Integration

### GitHub Actions Workflow

Every push to `main` or PR triggers:

```yaml
jobs:
  test:           # Unit + integration tests
  lint:           # Code quality
  security:       # Security scanning
  build-docker:   # Docker build verification
  merge-gate:     # Final approval gate
```

### Local CI Simulation

Run the same checks locally before you push:

```bash
# Run full CI pipeline locally
./scripts/run_ci_locally.sh
```

## 🔐 Security

- **Secrets** - never commit secrets (`.env`, API keys)
- **Dependencies** - a Safety scan runs automatically
- **Code** - Bandit scan for security issues
- **Pre-commit** - detect-private-keys hook

## 📝 Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New functionality
- `fix`: Bug fix
- `refactor`: Code refactoring (no new behaviour)
- `test`: Add or change tests
- `docs`: Documentation
- `chore`: Build, dependencies, tooling

### Example

```
feat(api): Add entity validation

- Implement entity name validation
- Add tests for empty name handling
- Update API error responses

TDD: Red-Green-Refactor cycle followed
Test coverage: 95%
```

## 🎯 Best Practices

### DO ✅

1. **Write tests first** - TDD approach
2. **Small commits** - one logical change per commit
3. **Merge often** - at least once a day to main
4. **Code review** - review your own code before the PR
5. **Feature flags** - for unfinished functionality
6. **Update docs** - keep the documentation in sync

### DON'T ❌

1. **Large PRs** - > 400 lines is too big
2. **Skipping tests** - "I'll add tests later"
3. **Long-lived branches** - > 2 days is too long
4. **Breaking main** - main must ALWAYS be deployable
5. **Copy-paste** - refactor instead
6. **Commented-out code** - delete it, don't comment it out

## 🐛 Bug Fix Workflow

```bash
# 1. Write a test that reproduces the bug (Red)
cat > tests/unit/test_bug_fix.py << 'EOF'
def test_booking_overlapping_detection():
    # This test reproduces the bug
    booking1 = create_booking(start="09:00", end="11:00")
    booking2 = create_booking(start="10:00", end="12:00")
    assert has_overlap(booking1, booking2)  # Currently fails!
EOF

# 2. Run the test - it should fail
pytest tests/unit/test_bug_fix.py -v
# FAIL - Bug confirmed

# 3. Fix the bug (Green)
# Implement the fix in the relevant files

# 4. Run the test - it should pass
pytest tests/unit/test_bug_fix.py -v
# PASS - Bug fixed!

# 5. Commit fix + test
git add tests/unit/test_bug_fix.py booking.py
git commit -m "fix(booking): Fix overlapping booking detection

- Add test to reproduce overlapping booking bug
- Fix has_overlap() function logic
- All existing tests still pass

Fixes #123"
```

## 🌟 Code Review Guidelines

### As a reviewer

- ✅ Verify that the tests were written BEFORE the implementation
- ✅ Check that test coverage is ≥ 80%
- ✅ Read the tests first to understand the intent
- ✅ Run the code locally if possible
- ✅ Give constructive feedback

### As an author

- ✅ Self-review before requesting a review
- ✅ Respond to feedback quickly
- ✅ Explain complex decisions in comments
- ✅ Keep the PR small and focused

## 📚 Resources

- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [Test Driven Development by Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [Pytest Documentation](https://docs.pytest.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

## 💬 Questions?

If you have questions about the development workflow:
1. Check this guide first
2. Search the closed issues
3. Open a discussion on GitHub

**Good luck with your contribution! 🚀**
