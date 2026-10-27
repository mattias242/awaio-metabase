"""
Shared pytest fixtures and configuration for all tests.
"""

import pytest
import os
from unittest.mock import Mock


@pytest.fixture(scope="session")
def test_env_vars():
    """Set up test environment variables. Pre-existing env vars (e.g. those set by
    CI for the integration job against a real postgres service) win over the
    defaults below."""
    defaults = {
        'AWAIO_CLIENT_ID': 'test_client_id',
        'AWAIO_CLIENT_SECRET': 'test_client_secret',
        'POSTGRES_HOST': 'localhost',
        'POSTGRES_PORT': '5432',
        'POSTGRES_DB': 'awaio_db_test',
        'POSTGRES_USER': 'test_user',
        'POSTGRES_PASSWORD': 'test_password',
        'MINDSDB_HOST': 'localhost',
        'MINDSDB_PORT': '47334'
    }

    original_values = {}
    applied = {}
    for key, value in defaults.items():
        existing = os.environ.get(key)
        if existing is None:
            original_values[key] = None
            os.environ[key] = value
            applied[key] = value
        else:
            applied[key] = existing

    yield applied

    for key, original_value in original_values.items():
        if original_value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = original_value


@pytest.fixture
def mock_db_connection():
    """Mock database connection for testing."""
    mock_conn = Mock()
    mock_cursor = Mock()
    mock_conn.cursor.return_value = mock_cursor
    return mock_conn, mock_cursor


@pytest.fixture
def sample_entity_data():
    """Sample entity data for testing."""
    return {
        "id": "entity_123",
        "name": "Test Desk 1",
        "group_tag": "desk",
        "parent_id": "floor_1",
        "community_id": "community_1",
        "metadata": {"capacity": 1}
    }


@pytest.fixture
def sample_booking_data():
    """Sample booking data for testing."""
    return {
        "id": "booking_123",
        "entity_id": "entity_123",
        "owner_id": "user_456",
        "start_time": "2025-11-19T09:00:00Z",
        "end_time": "2025-11-19T17:00:00Z",
        "cancelled": False
    }


@pytest.fixture(autouse=True)
def reset_env_for_each_test(test_env_vars):
    """Automatically set up test environment for each test."""
    yield
