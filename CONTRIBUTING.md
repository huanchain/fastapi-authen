# Contributing to FastAPI Authentication API

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project follows a standard code of conduct. Please be respectful and professional in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/fastapi-authen.git
   cd fastapi-authen
   ```

3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/original-owner/fastapi-authen.git
   ```

## Development Setup

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Install pre-commit hooks:
   ```bash
   pre-commit install
   ```

4. Create `.env` file from example:
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

5. Run database migrations:
   ```bash
   alembic upgrade head
   ```

## Development Workflow

1. Create a new branch for your feature/fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following our code style guidelines

3. Write tests for your changes

4. Run tests locally:
   ```bash
   pytest
   ```

5. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

   We follow [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` - New features
   - `fix:` - Bug fixes
   - `docs:` - Documentation changes
   - `style:` - Code style changes (formatting, etc.)
   - `refactor:` - Code refactoring
   - `test:` - Test additions or changes
   - `chore:` - Maintenance tasks

## Testing

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/unit/test_security.py

# Run specific test
pytest tests/unit/test_security.py::TestPasswordHashing::test_hash_password

# Run only unit tests
pytest tests/unit -m unit

# Run only integration tests
pytest tests/integration -m integration
```

### Writing Tests

- Place unit tests in `tests/unit/`
- Place integration tests in `tests/integration/`
- Use descriptive test names
- Follow the Arrange-Act-Assert pattern
- Mock external dependencies
- Aim for >80% code coverage

Example test:
```python
@pytest.mark.unit
def test_create_user(test_db: Session):
    """Test user creation."""
    # Arrange
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "SecurePass123!",
    }
    
    # Act
    user = create_user(test_db, user_data)
    
    # Assert
    assert user.email == user_data["email"]
    assert user.username == user_data["username"]
```

## Code Style

### Python Code Style

We use:
- **Black** for code formatting
- **isort** for import sorting
- **flake8** for linting
- **mypy** for type checking

Run formatters:
```bash
# Format code
black app tests

# Sort imports
isort app tests

# Check linting
flake8 app tests

# Type check
mypy app
```

### Code Standards

- Use type hints for all function parameters and return values
- Write docstrings for all public functions, classes, and modules
- Follow PEP 8 naming conventions
- Keep functions small and focused (max 50 lines)
- Use meaningful variable names
- Avoid deep nesting (max 3 levels)

Example:
```python
from typing import Optional
from sqlalchemy.orm import Session
from app.models.user import User


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """
    Get user by email address.
    
    Args:
        db: Database session
        email: User's email address
        
    Returns:
        User object if found, None otherwise
    """
    return db.query(User).filter(User.email == email).first()
```

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md (if applicable)
5. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Create a Pull Request on GitHub

7. Wait for review and address feedback

### PR Checklist

- [ ] Code follows the project's style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] No merge conflicts
- [ ] Commit messages follow Conventional Commits
- [ ] Changes are backwards compatible (or documented)

## Project Structure

```
fastapi-authen/
├── app/
│   ├── api/          # API endpoints
│   ├── core/         # Core functionality (config, security, etc.)
│   ├── models/       # Database models
│   ├── schemas/      # Pydantic schemas
│   └── services/     # Business logic
├── tests/
│   ├── unit/         # Unit tests
│   └── integration/  # Integration tests
├── alembic/          # Database migrations
└── docs/             # Documentation
```

## Questions?

If you have questions, please:
1. Check existing issues
2. Search documentation
3. Create a new issue with the "question" label

Thank you for contributing! 🎉

