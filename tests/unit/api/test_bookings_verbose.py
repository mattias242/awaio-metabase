"""
Unit tests for --verbose API request logging in fetch_bookings.

The purpose of verbose mode is to produce a log that can be handed to Awaio
support for debugging, so the tests assert on what a reader of that log sees:
the exact request that went over the wire, and no leaked credentials.
"""

import re

import pytest
from unittest.mock import Mock, patch

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
from fetch_bookings import AwaioAPIClient


SENT_URL = (
    "https://test.example.com/api/v1.1.0/communities/COMM1/bookings"
    "?%24filter=start+ge+%272026-05-01T00%3A00%3A00.000Z%27"
    "+and+end+le+%272026-05-31T23%3A59%3A59.999Z%27"
)


def make_response(payload, status_code=200, sent_url=SENT_URL):
    """A mock response shaped like the parts of requests.Response we read."""
    response = Mock()
    response.status_code = status_code
    response.json.return_value = payload
    response.text = str(payload)
    response.headers = {'Content-Type': 'application/json'}
    response.request = Mock()
    response.request.method = 'GET'
    response.request.url = sent_url
    return response


@pytest.fixture
def verbose_client():
    return AwaioAPIClient(
        client_id="test_client_id",
        client_secret="test_client_secret",
        auth_url="https://test.example.com/auth/token",
        api_base_url="https://test.example.com/api/v1.1.0",
        verbose=True,
    )


class TestVerboseRequestLogging:

    @patch('fetch_bookings.requests.get')
    def test_logs_exact_url_that_was_sent(self, mock_get, verbose_client, capsys):
        """The log must show the fully-resolved URL, query string included, so
        Awaio can replay the identical request."""
        verbose_client.access_token = "token123"
        mock_get.return_value = make_response([])

        verbose_client.get_bookings("COMM1", "2026-05-01T00:00:00.000Z",
                                    "2026-05-31T23:59:59.999Z")

        assert SENT_URL in capsys.readouterr().out

    @patch('fetch_bookings.requests.get')
    def test_logs_request_headers_with_bearer_token_redacted(self, mock_get, verbose_client, capsys):
        """The log is meant to be emailed to Awaio, so the token must never
        appear in it — but the reader still needs to see that one was sent."""
        verbose_client.access_token = "supersecrettoken"
        mock_get.return_value = make_response([])

        verbose_client.get_bookings("COMM1", "2026-05-01T00:00:00.000Z",
                                    "2026-05-31T23:59:59.999Z")

        out = capsys.readouterr().out
        assert "supersecrettoken" not in out
        assert "Authorization: Bearer <redacted>" in out

    @patch('fetch_bookings.requests.get')
    def test_logs_response_status_and_raw_body(self, mock_get, verbose_client, capsys):
        """An empty 200 is the whole anomaly being reported, so the log must show
        the status and the literal body Awaio returned."""
        verbose_client.access_token = "token123"
        empty = make_response([])
        empty.text = "[]"
        mock_get.return_value = empty

        verbose_client.get_bookings("COMM1", "2026-05-01T00:00:00.000Z",
                                    "2026-05-31T23:59:59.999Z")

        out = capsys.readouterr().out
        assert "HTTP 200" in out
        assert "[]" in out

    @patch('fetch_bookings.requests.get')
    def test_logs_utc_timestamp_for_the_exchange(self, mock_get, verbose_client, capsys):
        """Awaio locates a request in their own logs by time, so each exchange
        carries an ISO-8601 UTC timestamp."""
        verbose_client.access_token = "token123"
        mock_get.return_value = make_response([])

        verbose_client.get_bookings("COMM1", "2026-05-01T00:00:00.000Z",
                                    "2026-05-31T23:59:59.999Z")

        out = capsys.readouterr().out
        # Anchored to the request line, so an OData date echoed elsewhere in the
        # output cannot satisfy this.
        assert re.search(
            r"\[verbose\] \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|\+00:00) GET ",
            out,
        )


class TestVerboseAuthLogging:

    @patch('fetch_bookings.requests.post')
    def test_logs_auth_request_with_client_id_but_not_secret(self, mock_post, verbose_client, capsys):
        """Awaio needs the client_id to locate the call in their own logs; the
        secret must not travel with the report."""
        token_response = make_response({"access_token": "tok"})
        token_response.request.method = 'POST'
        token_response.request.url = "https://test.example.com/auth/token"
        mock_post.return_value = token_response

        verbose_client.authenticate()

        out = capsys.readouterr().out
        assert "test_client_id" in out
        assert "test_client_secret" not in out
        assert "<redacted>" in out


class TestVerboseFlagWiring:

    @patch('fetch_bookings.CLIENT_SECRET', 'test_client_secret')
    @patch('fetch_bookings.CLIENT_ID', 'test_client_id')
    @patch('fetch_bookings.AwaioAPIClient')
    def _run_main(self, argv, mock_client_cls):
        """Run main() with a stubbed client that reports zero bookings, which
        makes main() exit before it touches the database."""
        import fetch_bookings
        instance = mock_client_cls.return_value
        instance.authenticate.return_value = True
        instance.get_bookings.return_value = []

        with patch.object(sys, 'argv', ['fetch_bookings.py'] + argv):
            with pytest.raises(SystemExit) as exit_info:
                fetch_bookings.main()

        assert exit_info.value.code == 0
        return mock_client_cls.call_args

    def test_verbose_flag_enables_verbose_client(self):
        call_args = self._run_main(['--verbose'])
        assert call_args.kwargs['verbose'] is True

    def test_client_is_quiet_without_the_flag(self):
        call_args = self._run_main([])
        assert call_args.kwargs['verbose'] is False
