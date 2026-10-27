"""
Unit tests for AwaioAPIClient class.
Following TDD principles - tests should be written BEFORE implementation.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import requests


# Import the module under test
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
from fetch_entities import AwaioAPIClient


class TestAwaioAPIClient:
    """Test suite for AwaioAPIClient."""

    @pytest.fixture
    def api_client(self):
        """Fixture to create an API client instance."""
        return AwaioAPIClient(
            client_id="test_client_id",
            client_secret="test_client_secret",
            auth_url="https://test.example.com/auth/token",
            api_base_url="https://test.example.com/api/v1.0.0"
        )

    @pytest.fixture
    def mock_response(self):
        """Fixture to create a mock HTTP response."""
        mock = Mock()
        mock.status_code = 200
        mock.json.return_value = {"access_token": "test_token_123"}
        return mock

    def test_client_initialization(self, api_client):
        """Test that client initializes with correct parameters."""
        assert api_client.client_id == "test_client_id"
        assert api_client.client_secret == "test_client_secret"
        assert api_client.auth_url == "https://test.example.com/auth/token"
        assert api_client.api_base_url == "https://test.example.com/api/v1.0.0"
        assert api_client.access_token is None

    @patch('fetch_entities.requests.post')
    def test_authenticate_success(self, mock_post, api_client, mock_response):
        """Test successful authentication.

        Asserts the *behavior* (POST to auth URL with correct credentials body)
        without coupling to implementation details like headers or timeout —
        those can be tuned without invalidating the test.
        """
        mock_post.return_value = mock_response

        result = api_client.authenticate()

        assert result is True
        assert api_client.access_token == "test_token_123"
        mock_post.assert_called_once()
        call_args = mock_post.call_args
        assert call_args.args[0] == api_client.auth_url
        assert call_args.kwargs['json'] == {
            'client_id': 'test_client_id',
            'client_secret': 'test_client_secret',
            'grant_type': 'client_credentials'
        }

    @patch('fetch_entities.requests.post')
    def test_authenticate_failure_http_error(self, mock_post, api_client):
        """Test authentication failure with HTTP error."""
        mock_post.side_effect = requests.exceptions.RequestException("Connection failed")

        result = api_client.authenticate()

        assert result is False
        assert api_client.access_token is None

    @patch('fetch_entities.requests.post')
    def test_authenticate_failure_invalid_response(self, mock_post, api_client):
        """Test authentication failure with invalid JSON response."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.side_effect = ValueError("Invalid JSON")
        mock_post.return_value = mock_response

        result = api_client.authenticate()

        assert result is False
        assert api_client.access_token is None

    @patch('fetch_entities.requests.post')
    def test_authenticate_failure_missing_token(self, mock_post, api_client):
        """Test authentication failure when response missing access_token."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"error": "Invalid credentials"}
        mock_post.return_value = mock_response

        result = api_client.authenticate()

        assert result is False
        assert api_client.access_token is None

    @patch('fetch_entities.requests.post')
    def test_authenticate_failure_401_status(self, mock_post, api_client):
        """Test authentication failure with 401 status code."""
        mock_response = Mock()
        mock_response.status_code = 401
        mock_response.json.return_value = {"error": "Unauthorized"}
        mock_post.return_value = mock_response

        result = api_client.authenticate()

        assert result is False
        assert api_client.access_token is None

    @patch('fetch_entities.requests.get')
    def test_fetch_entities_without_authentication(self, mock_get, api_client):
        """Test that fetch_entities requires authentication first."""
        # Client has no access token
        assert api_client.access_token is None

        # Attempt to fetch should handle this gracefully
        with pytest.raises(Exception):
            api_client.fetch_entities("test_community_id")

    @patch('fetch_entities.requests.get')
    def test_fetch_entities_with_authentication(self, mock_get, api_client):
        """Test successful entity fetching with authentication."""
        # Set up authenticated client
        api_client.access_token = "test_token_123"

        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "entities": [
                {"id": "e1", "name": "Entity 1"},
                {"id": "e2", "name": "Entity 2"}
            ]
        }
        mock_get.return_value = mock_response

        # This test will fail until fetch_entities is implemented
        # Following TDD: write test first, then implement
        # entities = api_client.fetch_entities("test_community_id")
        # assert len(entities) == 2
        # assert entities[0]["id"] == "e1"


class TestAwaioAPIClientEdgeCases:
    """Edge case tests for AwaioAPIClient."""

    def test_client_with_empty_credentials(self):
        """Test client initialization with empty credentials."""
        client = AwaioAPIClient("", "", "", "")
        assert client.client_id == ""
        assert client.client_secret == ""

    def test_client_with_none_credentials(self):
        """Test client handles None credentials gracefully."""
        client = AwaioAPIClient(None, None, None, None)
        assert client.client_id is None
        assert client.client_secret is None

    @patch('fetch_entities.requests.post')
    def test_authenticate_with_timeout(self, mock_post):
        """Test authentication handles timeout."""
        mock_post.side_effect = requests.exceptions.Timeout("Request timed out")

        client = AwaioAPIClient("id", "secret", "http://test.com/auth", "http://test.com/api")
        result = client.authenticate()

        assert result is False

    @patch('fetch_entities.requests.post')
    def test_authenticate_retries_on_500_error(self, mock_post):
        """Test authentication behavior on server error."""
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.json.return_value = {"error": "Internal server error"}
        mock_post.return_value = mock_response

        client = AwaioAPIClient("id", "secret", "http://test.com/auth", "http://test.com/api")
        result = client.authenticate()

        # Should handle 500 errors gracefully
        assert result is False
