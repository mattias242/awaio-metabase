# Contributing to Awaio

Vi använder **Trunk-Based Development** med **Test-Driven Development (TDD)** för att säkerställa hög kodkvalitet och snabb iteration.

## 🌳 Trunk-Based Development Workflow

### Principer

1. **En huvudgren (main/trunk)** - All kod mergas direkt till `main`
2. **Korta feature branches** - Max 1-2 dagar, oftast några timmar
3. **Små, frekventa commits** - Merga tidigt och ofta
4. **Feature flags** - För ofärdig funktionalitet
5. **CI/CD pipeline** - Automatiska tester vid varje commit
6. **Fast feedback** - Tester körs på < 10 minuter

### Branching Strategy

```
main (trunk)
  ↑
  └── feature/add-booking-validation (kort-levande, < 2 dagar)
  └── fix/database-connection-pool (kort-levande)
```

**Undvik:**
- ❌ Långlivade feature branches
- ❌ Git Flow (develop, release branches)
- ❌ Stora merge requests med hundratals rader

**Gör istället:**
- ✅ Små pull requests (< 400 rader)
- ✅ Merge till main minst en gång per dag
- ✅ Använd feature flags för ofärdig funktionalitet

## 🧪 Test-Driven Development (TDD)

### Red-Green-Refactor Cycle

1. **🔴 Red** - Skriv ett test som failar
2. **🟢 Green** - Skriv minimal kod för att få testet att passa
3. **🔵 Refactor** - Förbättra koden utan att ändra beteende
4. **Repeat** - Gå tillbaka till steg 1

### TDD Workflow för ny funktionalitet

```bash
# 1. Skapa en feature branch från main
git checkout main
git pull origin main
git checkout -b feature/add-entity-validation

# 2. Skriv test FÖRST (Red)
# Skapa tests/unit/test_entity_validation.py
cat > tests/unit/test_entity_validation.py << 'EOF'
def test_entity_name_cannot_be_empty():
    entity = Entity(name="")
    assert not entity.is_valid()
    assert "name cannot be empty" in entity.errors
EOF

# 3. Kör testet - det ska faila (Red)
pytest tests/unit/test_entity_validation.py -v
# FAIL - Entity class doesn't exist yet

# 4. Skriv minimal implementation (Green)
# Implementera Entity class i entity.py

# 5. Kör testet igen - det ska passa (Green)
pytest tests/unit/test_entity_validation.py -v
# PASS - Test passes!

# 6. Refactor (om nödvändigt)
# Förbättra kod, kör tester igen

# 7. Commit med test + implementation
git add tests/unit/test_entity_validation.py entity.py
git commit -m "Add entity name validation

- Add test for empty entity name validation
- Implement Entity.is_valid() method
- Entity name must not be empty

TDD: Red-Green-Refactor cycle"

# 8. Push och skapa PR
git push -u origin feature/add-entity-validation
gh pr create --title "Add entity name validation" --body "Implements validation for entity names following TDD"
```

### Test-struktur

```
tests/
├── unit/           # Snabba, isolerade tester (< 100ms per test)
│   ├── api/        # API client tester
│   ├── database/   # Database layer tester
│   └── chat_app/   # Chat app tester
├── integration/    # Tester med databas/externa services (< 1s per test)
└── e2e/           # End-to-end tester (< 10s per test)
```

### Skriva bra tester

**AAA Pattern:**
```python
def test_booking_creation():
    # Arrange - Sätt upp test data
    user = create_test_user()
    entity = create_test_entity()

    # Act - Utför operationen
    booking = create_booking(user, entity, start_time, end_time)

    # Assert - Verifiera resultatet
    assert booking.owner_id == user.id
    assert booking.entity_id == entity.id
```

**Test naming:**
```python
# ✅ Bra - beskriver vad som testas och förväntat beteende
def test_booking_creation_fails_when_entity_is_already_booked():
    pass

def test_user_authentication_returns_token_on_success():
    pass

# ❌ Dåligt - vaga, otydliga namn
def test_booking():
    pass

def test_auth():
    pass
```

## 📋 Pull Request Process

### 1. Innan du skapar PR

```bash
# Kör alla tester lokalt
pytest

# Kör linters
black .
flake8 .
isort .

# Kör pre-commit hooks
pre-commit run --all-files
```

### 2. PR Checklist

- [ ] **Tester skrivna FÖRE implementation** (TDD)
- [ ] Alla tester passar (`pytest`)
- [ ] Code coverage ≥ 80% (`pytest --cov`)
- [ ] Linters passa (black, flake8, isort)
- [ ] PR är < 400 rader kod
- [ ] Commit messages är tydliga
- [ ] Documentation uppdaterad (om relevant)

### 3. PR Template

```markdown
## Beskrivning
Kort beskrivning av vad PR:en gör.

## TDD Approach
- [ ] Tester skrivna först
- [ ] Red-Green-Refactor cycle följd
- [ ] Test coverage: XX%

## Typ av ändring
- [ ] Bug fix
- [ ] Ny feature
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

När du pushar kod körs automatiskt:

1. **Unit Tests** - Alla unit tester (< 1 min)
2. **Integration Tests** - Tester mot databas (< 2 min)
3. **Linting** - Code quality checks (< 1 min)
4. **Security Scan** - Bandit, Safety (< 1 min)
5. **Docker Build** - Verifiera att containers bygger (< 3 min)

**Total CI time: < 10 minuter**

### 5. Merge till Main

PR kan mergas när:
- ✅ Alla CI checks är gröna
- ✅ Minst 80% code coverage
- ✅ Code review godkänd (om configured)
- ✅ Inga merge conflicts

```bash
# Squash merge (rekommenderat för små PRs)
gh pr merge --squash --delete-branch

# Eller via GitHub UI
```

## 🔧 Development Setup

### 1. Klona repo och installera dependencies

```bash
git clone https://github.com/mattias242/awaio.git
cd awaio
pip install -r requirements.txt
```

### 2. Installera pre-commit hooks

```bash
pip install pre-commit
pre-commit install
```

Detta kör automatiskt:
- Pytest vid varje commit
- Code formatting (black, isort)
- Linting (flake8)
- Security checks (bandit)

### 3. Kör tester

```bash
# Alla tester
pytest

# Endast unit tester
pytest tests/unit -v

# Med coverage
pytest --cov --cov-report=html

# Watch mode (kör tester vid varje fil-ändring)
pytest-watch
```

### 4. Kör linters

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

Vi siktar på **≥ 80% code coverage**.

```bash
# Generera coverage report
pytest --cov --cov-report=html

# Öppna rapporten
open htmlcov/index.html
```

**Coverage goals:**
- Unit tests: ≥ 90%
- Integration tests: ≥ 70%
- Overall: ≥ 80%

## 🚀 Continuous Integration

### GitHub Actions Workflow

Varje push till `main` eller PR triggar:

```yaml
jobs:
  test:           # Unit + integration tests
  lint:           # Code quality
  security:       # Security scanning
  build-docker:   # Docker build verification
  merge-gate:     # Final approval gate
```

### Local CI Simulation

Kör samma checks lokalt innan du pushar:

```bash
# Run full CI pipeline locally
./scripts/run_ci_locally.sh
```

## 🔐 Security

- **Secrets** - Aldrig committa secrets (`.env`, API keys)
- **Dependencies** - Safety scan körs automatiskt
- **Code** - Bandit scan för säkerhetsproblem
- **Pre-commit** - Detect private keys hook

## 📝 Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: Ny funktionalitet
- `fix`: Buggfix
- `refactor`: Kod-refactoring (inget nytt beteende)
- `test`: Lägg till eller ändra tester
- `docs`: Documentation
- `chore`: Build, dependencies, tooling

### Exempel

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

1. **Skriv tester först** - TDD approach
2. **Små commits** - En logisk ändring per commit
3. **Merge ofta** - Minst en gång per dag till main
4. **Code review** - Granska din egen kod innan PR
5. **Feature flags** - För ofärdig funktionalitet
6. **Update docs** - Håll dokumentation synkad

### DON'T ❌

1. **Stora PRs** - > 400 rader är för stort
2. **Skipping tests** - "Jag lägger till tester senare"
3. **Långlivade branches** - > 2 dagar är för länge
4. **Breaking main** - Main ska ALLTID vara deploybar
5. **Copy-paste** - Refactor istället
6. **Commented code** - Ta bort, inte kommentera

## 🐛 Bug Fix Workflow

```bash
# 1. Skapa test som reproducerar buggen (Red)
cat > tests/unit/test_bug_fix.py << 'EOF'
def test_booking_overlapping_detection():
    # This test reproduces the bug
    booking1 = create_booking(start="09:00", end="11:00")
    booking2 = create_booking(start="10:00", end="12:00")
    assert has_overlap(booking1, booking2)  # Currently fails!
EOF

# 2. Kör testet - det ska faila
pytest tests/unit/test_bug_fix.py -v
# FAIL - Bug confirmed

# 3. Fixa buggen (Green)
# Implementera fix i relevanta filer

# 4. Kör testet - det ska passa
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

### Som Reviewer

- ✅ Verifiera att tester är skrivna FÖRE implementation
- ✅ Kolla att test coverage är ≥ 80%
- ✅ Läs testerna först för att förstå intent
- ✅ Kör koden lokalt om möjligt
- ✅ Ge konstruktiv feedback

### Som Author

- ✅ Self-review innan du begär review
- ✅ Svara på feedback snabbt
- ✅ Förklara komplexa beslut i kommentarer
- ✅ Håll PR:en liten och fokuserad

## 📚 Resources

- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [Test Driven Development by Example](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [Pytest Documentation](https://docs.pytest.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

## 💬 Frågor?

Om du har frågor om development workflow:
1. Kolla denna guide först
2. Sök i closed issues
3. Öppna en discussion på GitHub

**Lycka till med din contribution! 🚀**
