"""
Unit tests for fetching historical ("obsolete") bookings.

Awaio hides bookings that ended more than ~7 days ago unless the request
carries includeObsolete=true (Awaio support, 2026-10-22). The flag is only
accepted together with a $filter time window of at most 92 days, so long
ranges are fetched window by window. Those bookings come
back with status 'obsolete'; every downstream view counts status 'reserved',
so the importer stores them as 'reserved' — the same convention used by
import/import_awaio_export.py for historical rows.
"""

import re
from datetime import datetime, timedelta

import pytest
from unittest.mock import Mock, patch

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
from fetch_bookings import AwaioAPIClient, BookingImporter


@pytest.fixture
def client():
    c = AwaioAPIClient(
        client_id="test_client_id",
        client_secret="test_client_secret",
        auth_url="https://test.example.com/auth/token",
        api_base_url="https://test.example.com/v1.1.0",
    )
    c.access_token = "token123"
    return c


def ok_response(payload):
    response = Mock()
    response.status_code = 200
    response.json.return_value = payload
    return response


WINDOW_RE = re.compile(r"end ge '([^']+)' and start le '([^']+)'")


def requested_windows(mock_get):
    """(lower, upper) datetimes of every $filter sent, in call order."""
    windows = []
    for call in mock_get.call_args_list:
        lower, upper = WINDOW_RE.fullmatch(call.kwargs['params']['$filter']).groups()
        windows.append((parse_iso(lower), parse_iso(upper)))
    return windows


def parse_iso(value):
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%S.%fZ')


class TestIncludeObsolete:

    @patch('fetch_bookings.requests.get')
    def test_date_filtered_request_includes_obsolete(self, mock_get, client):
        mock_get.return_value = ok_response([])

        client.get_bookings("COMM1", "2026-06-01T00:00:00.000Z",
                            "2026-07-01T23:59:59.999Z")

        params = mock_get.call_args.kwargs['params']
        assert params['includeObsolete'] == 'true'
        assert '$filter' in params

    @patch('fetch_bookings.requests.get')
    def test_unfiltered_request_omits_obsolete(self, mock_get, client):
        """Awaio rejects includeObsolete without a time window (HTTP 400)."""
        mock_get.return_value = ok_response([])

        client.get_bookings("COMM1")

        assert 'includeObsolete' not in mock_get.call_args.kwargs['params']

    @patch('fetch_bookings.requests.get')
    def test_filter_selects_bookings_overlapping_the_window(self, mock_get, client):
        """Long-running bookings (lockers booked a year ago, ending next year)
        must be included, so the filter is overlap, not containment."""
        mock_get.return_value = ok_response([])

        client.get_bookings("COMM1", "2026-06-01T00:00:00.000Z",
                            "2026-07-01T23:59:59.999Z")

        assert mock_get.call_args.kwargs['params']['$filter'] == (
            "end ge '2026-06-01T00:00:00.000Z' and start le '2026-07-01T23:59:59.999Z'"
        )


class TestWindowChunking:
    """Awaio caps an includeObsolete window at 92 days."""

    @patch('fetch_bookings.requests.get')
    def test_long_range_is_split_into_windows_of_at_most_92_days(self, mock_get, client):
        mock_get.return_value = ok_response([])

        client.get_bookings("COMM1", "2025-01-01T00:00:00.000Z",
                            "2027-12-31T23:59:59.999Z")

        windows = requested_windows(mock_get)
        assert len(windows) > 1
        assert all(upper - lower <= timedelta(days=92) for lower, upper in windows)

    @patch('fetch_bookings.requests.get')
    def test_windows_cover_the_whole_range_without_gaps(self, mock_get, client):
        mock_get.return_value = ok_response([])

        client.get_bookings("COMM1", "2025-01-01T00:00:00.000Z",
                            "2027-12-31T23:59:59.999Z")

        windows = requested_windows(mock_get)
        assert windows[0][0] == parse_iso("2025-01-01T00:00:00.000Z")
        assert windows[-1][1] == parse_iso("2027-12-31T23:59:59.999Z")
        for (_, prev_upper), (next_lower, _) in zip(windows, windows[1:]):
            assert next_lower <= prev_upper

    @patch('fetch_bookings.requests.get')
    def test_booking_returned_by_several_windows_is_kept_once(self, mock_get, client):
        locker = {"id": "locker1"}
        mock_get.side_effect = lambda *a, **kw: ok_response([locker, {"id": kw['params']['$filter']}])

        bookings = client.get_bookings("COMM1", "2026-01-01T00:00:00.000Z",
                                       "2026-12-31T23:59:59.999Z")

        ids = [b["id"] for b in bookings]
        assert ids.count("locker1") == 1
        assert len(ids) == len(set(ids)) == mock_get.call_count + 1

    @patch('fetch_bookings.requests.get')
    def test_failure_in_any_window_fails_the_whole_fetch(self, mock_get, client):
        failed = Mock(status_code=400, text='{"message": "bad window"}')
        mock_get.side_effect = [ok_response([{"id": "a"}]), failed] + [ok_response([])] * 20

        assert client.get_bookings("COMM1", "2026-01-01T00:00:00.000Z",
                                   "2026-12-31T23:59:59.999Z") is None


def stored_status(booking):
    """Run insert_booking against a mocked cursor and return the status value
    that would be written to the bookings table."""
    importer = BookingImporter(db_config={})
    importer.cursor = Mock()
    importer.booking_exists = Mock(return_value=False)

    importer.insert_booking(booking)

    sql, values = importer.cursor.execute.call_args.args
    return values[6]


BASE_BOOKING = {
    "id": "b1", "community": "COMM1", "entity": "E1", "owner": None,
    "start": "2026-06-01T06:00:00.000Z", "end": "2026-06-01T07:00:00.000Z",
    "cancelled": False,
}


class TestObsoleteStatusNormalization:

    def test_obsolete_booking_is_stored_as_reserved(self):
        assert stored_status(dict(BASE_BOOKING, status="obsolete")) == "reserved"

    def test_reserved_booking_is_unchanged(self):
        assert stored_status(dict(BASE_BOOKING, status="reserved")) == "reserved"

    def test_other_statuses_pass_through(self):
        assert stored_status(dict(BASE_BOOKING, status="released")) == "released"


class TestAdminBlockStatus:
    """Admins block resources for weeks (e.g. Room 236 as election office,
    May-Sep 2026). Stored as 'blocked' so every status='reserved' query
    leaves them out of utilisation statistics, while the rows remain."""

    def test_long_admin_booking_is_stored_as_blocked(self):
        booking = dict(BASE_BOOKING, status="obsolete", admin=True,
                       start="2026-05-19T07:40:00.000Z", end="2026-09-30T15:00:00.000Z")
        assert stored_status(booking) == "blocked"

    def test_short_admin_booking_counts_as_normal(self):
        """Admins also book ordinary meetings on someone's behalf."""
        booking = dict(BASE_BOOKING, status="reserved", admin=True)
        assert stored_status(booking) == "reserved"

    def test_long_non_admin_booking_counts_as_normal(self):
        """Lockers and building passes are legitimately booked for months."""
        booking = dict(BASE_BOOKING, status="reserved", admin=False,
                       start="2025-06-01T06:00:00.000Z", end="2027-06-01T06:00:00.000Z")
        assert stored_status(booking) == "reserved"

    def test_admin_booking_of_exactly_twelve_hours_counts_as_normal(self):
        booking = dict(BASE_BOOKING, status="reserved", admin=True,
                       start="2026-06-01T06:00:00.000Z", end="2026-06-01T18:00:00.000Z")
        assert stored_status(booking) == "reserved"
