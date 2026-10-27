#!/usr/bin/env python3
"""
Fetch bookings from Awaio API and import directly to PostgreSQL.
Authenticates using client_id and client_secret, then fetches bookings for a community.
"""

import os
import sys
import json
import requests
import subprocess
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional, Set
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv
from anonymize import DatabaseAnonymizer, generate_swedish_display_name, hash_user_id, should_anonymize

# Load environment variables
load_dotenv()

# API Configuration
AUTH_URL = os.getenv('AWAIO_AUTH_URL', 'https://api.awaio.com/auth/token')
API_BASE_URL = os.getenv('AWAIO_API_BASE_URL', 'https://api.awaio.com/v1.1.0')
CLIENT_ID = os.getenv('AWAIO_CLIENT_ID')
CLIENT_SECRET = os.getenv('AWAIO_CLIENT_SECRET')

# Database Configuration
DB_CONFIG = {
    'host': os.getenv('POSTGRES_HOST', 'localhost'),
    'port': int(os.getenv('POSTGRES_PORT', 5432)),
    'database': os.getenv('POSTGRES_DB', 'awaio_db'),
    'user': os.getenv('POSTGRES_USER', 'awaio_user'),
    'password': os.getenv('POSTGRES_PASSWORD', 'change_me')
}


def _truncate(text: str, limit: int = 2000) -> str:
    """Shorten a response body for logging, noting how much was cut."""
    text = '' if text is None else str(text)
    if len(text) <= limit:
        return text
    return f"{text[:limit]}... [{len(text) - limit} more chars truncated]"


def _redact_headers(headers: Dict[str, str]) -> Dict[str, str]:
    """Return headers with credential values replaced by a placeholder, so a
    verbose log can be shared with Awaio support without leaking secrets."""
    redacted = {}
    for name, value in headers.items():
        if name.lower() == 'authorization':
            scheme = str(value).split(' ', 1)[0] if value else ''
            redacted[name] = f"{scheme} <redacted>".strip()
        else:
            redacted[name] = value
    return redacted


ISO_FORMAT = '%Y-%m-%dT%H:%M:%S.%fZ'
# Awaio rejects includeObsolete windows longer than 92 days; keep a margin.
MAX_WINDOW_DAYS = 90
# Users can book at most 9 h; admin bookings longer than this are blocks.
ADMIN_BLOCK_MIN_DURATION = timedelta(hours=12)


def _split_window(start_date: str, end_date: str, max_days: int = MAX_WINDOW_DAYS) -> List[tuple]:
    """Split an ISO date range into consecutive (start, end) ISO windows of at
    most max_days each, covering the range exactly."""
    start = datetime.strptime(start_date, ISO_FORMAT)
    end = datetime.strptime(end_date, ISO_FORMAT)
    windows = []
    while True:
        window_end = min(start + timedelta(days=max_days), end)
        windows.append((start, window_end))
        if window_end >= end:
            break
        start = window_end
    return [(_to_iso_millis(s), _to_iso_millis(e)) for s, e in windows]


def _to_iso_millis(dt: datetime) -> str:
    """Format like the API expects: 2026-06-01T00:00:00.000Z."""
    return dt.strftime(ISO_FORMAT)[:-4] + 'Z'


class AwaioAPIClient:
    """Client for interacting with Awaio API."""

    def __init__(self, client_id: str, client_secret: str, auth_url: str, api_base_url: str,
                 verbose: bool = False):
        """Initialize the API client. verbose=True logs every HTTP request and
        response in full (credentials redacted) for support/debugging."""
        self.client_id = client_id
        self.client_secret = client_secret
        self.auth_url = auth_url
        self.api_base_url = api_base_url
        self.access_token = None
        self.verbose = verbose

    def _log_exchange(self, method: str, url: str, response,
                      headers: Dict[str, str] = None, body: Dict[str, Any] = None,
                      log_response_headers: bool = False,
                      log_body: bool = False) -> None:
        """Print one request/response pair in a form that can be forwarded to
        Awaio support. Credentials are redacted by the callers' inputs."""
        now = datetime.now(timezone.utc).isoformat(timespec='milliseconds')
        print(f"  [verbose] {now} {method} {url}")
        for name, value in _redact_headers(headers or {}).items():
            print(f"  [verbose]   {name}: {value}")
        if body is not None:
            print(f"  [verbose] body: {json.dumps(body)}")
        print(f"  [verbose] <- HTTP {response.status_code}")
        if log_response_headers:
            for name, value in dict(response.headers).items():
                print(f"  [verbose]   {name}: {value}")
        if log_body:
            print(f"  [verbose] body: {_truncate(response.text)}")

    def authenticate(self) -> bool:
        """
        Authenticate with the API and get an access token.
        Returns True if successful, False otherwise.
        """
        print(f"Authenticating with {self.auth_url}...")

        body = {
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'grant_type': 'client_credentials'
        }

        try:
            response = requests.post(
                self.auth_url,
                json=body,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )

            if self.verbose:
                self._log_exchange(
                    'POST', self.auth_url, response,
                    body=dict(body, client_secret='<redacted>')
                )

            if response.status_code == 200:
                token_data = response.json()
                self.access_token = token_data.get('access_token')

                if self.access_token:
                    print(f"✓ Authentication successful")
                    return True
                else:
                    print(f"✗ No access_token in response")
                    print(f"Response: {json.dumps(token_data, indent=2)}")
                    return False
            else:
                print(f"✗ Authentication failed with status {response.status_code}")
                print(f"Response: {response.text}")
                return False

        except requests.exceptions.RequestException as e:
            print(f"✗ Authentication error: {e}")
            return False

    def get_bookings(self, community_id: str, start_date: str = None, end_date: str = None):
        """
        Fetch bookings for a specific community with optional date filtering.
        Returns list of bookings (may be empty), or None on error.
        """
        if not self.access_token:
            print("✗ Not authenticated. Call authenticate() first.")
            return None

        url = f"{self.api_base_url}/communities/{community_id}/bookings"

        if not (start_date and end_date):
            # includeObsolete is rejected without a time window, so an
            # unfiltered fetch only sees bookings that ended in the last week.
            print(f"\nFetching all bookings from {url}...")
            return self._fetch_bookings_page(url, {})

        print(f"\nFetching bookings from {url}")
        print(f"  Date range (OData filter): {start_date} to {end_date}")

        bookings = {}
        for window_start, window_end in _split_window(start_date, end_date):
            # Without includeObsolete Awaio hides bookings that ended more than
            # ~7 days ago (Awaio support, 2026-10-22). Overlap rather than
            # containment, so long-running locker bookings are included.
            params = {
                'includeObsolete': 'true',
                '$filter': f"end ge '{window_start}' and start le '{window_end}'",
            }
            print(f"  Filter: {params['$filter']}")
            page = self._fetch_bookings_page(url, params)
            if page is None:
                return None
            for booking in page:
                bookings.setdefault(booking.get('id'), booking)

        print(f"✓ Fetched {len(bookings)} unique bookings in total")
        return list(bookings.values())

    def _fetch_bookings_page(self, url: str, params: Dict[str, str]):
        """One GET against the bookings endpoint. Returns a list, or None on error."""
        headers = {
            'Authorization': f'Bearer {self.access_token}',
            'Content-Type': 'application/json'
        }

        try:
            response = requests.get(url, params=params, headers=headers, timeout=60)

            if self.verbose:
                self._log_exchange(
                    'GET', response.request.url, response,
                    headers=headers,
                    log_response_headers=True,
                    log_body=True
                )

            if response.status_code == 200:
                bookings = response.json()
                booking_count = len(bookings) if isinstance(bookings, list) else 1
                print(f"✓ Successfully fetched {booking_count} bookings")
                return bookings if isinstance(bookings, list) else [bookings]
            else:
                print(f"✗ Failed to fetch bookings. Status: {response.status_code}")
                print(f"Response: {response.text}")
                return None

        except requests.exceptions.RequestException as e:
            print(f"✗ Error fetching bookings: {e}")
            return None

    def save_to_json(self, data: list, filename: str = None) -> str:
        """Save bookings data to a JSON file. Returns the filename."""
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"json/bookings_{timestamp}.json"

        os.makedirs(os.path.dirname(filename), exist_ok=True)

        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"✓ Saved {len(data)} bookings to {filename}")
        return filename


class BookingImporter:
    """Import bookings to PostgreSQL database."""

    def __init__(self, db_config: Dict[str, Any], anonymize: bool = False, salt: str = "",
                 verbose: bool = False):
        """Initialize database connection. verbose=True logs every booking;
        otherwise only summaries and errors are printed."""
        self.db_config = db_config
        self.verbose = verbose
        self.conn = None
        self.cursor = None
        self.anonymize = anonymize
        self.salt = salt
        self.anonymizer = None  # Will be initialized after database connection
        self.missing_entities: Set[str] = set()  # Track missing entities

    def _detail(self, message: str):
        """Print per-object progress, only with --verbose."""
        if self.verbose:
            print(message)

    def connect(self):
        """Connect to PostgreSQL database."""
        try:
            self.conn = psycopg2.connect(**self.db_config)
            self.cursor = self.conn.cursor()
            if self.anonymize:
                self.anonymizer = DatabaseAnonymizer(self.cursor, self.salt)
            print(f"✓ Connected to database: {self.db_config['database']}")
        except psycopg2.Error as e:
            print(f"✗ Database connection error: {e}")
            sys.exit(1)

    def _anon_id(self, raw_user_id: Optional[str]) -> Optional[str]:
        """Return hashed id when anonymization is on, otherwise the raw id (or None)."""
        if not raw_user_id:
            return None
        if self.anonymize:
            return hash_user_id(raw_user_id, self.salt)
        return raw_user_id

    def disconnect(self):
        """Close database connection."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("✓ Database connection closed")

    def parse_datetime(self, dt_str: Optional[str]) -> Optional[datetime]:
        """Parse ISO datetime string."""
        if not dt_str:
            return None
        try:
            if dt_str.endswith('Z'):
                dt_str = dt_str[:-1] + '+00:00'
            return datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            return None

    def insert_community(self, community_id: str, name: str = None):
        """Insert or update community."""
        if not name:
            name = f"Community {community_id}"

        sql = """
            INSERT INTO communities (id, name)
            VALUES (%s, %s)
            ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        """
        try:
            self.cursor.execute(sql, (community_id, name))
        except psycopg2.Error as e:
            print(f"✗ Error inserting community {community_id}: {e}")

    def insert_user(self, user_id: str, email: str = None, name: str = None):
        """Insert or update user. Hashes user_id when anonymization is enabled."""
        if self.anonymize:
            stored_id, stored_email, display_name = self.anonymizer.identity_for(user_id)
            stored_name = display_name  # legacy `name` column mirrors display_name under anonymization
        else:
            stored_id = user_id
            stored_email = email
            stored_name = name
            display_name = generate_swedish_display_name(user_id)

        sql = """
            INSERT INTO users (id, email, name, display_name)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE SET
                email = EXCLUDED.email,
                name = EXCLUDED.name,
                display_name = EXCLUDED.display_name
        """
        try:
            self.cursor.execute(sql, (stored_id, stored_email, stored_name, display_name))
        except psycopg2.Error as e:
            print(f"✗ Error inserting user: {e}")

    def insert_calendar_event(self, event_id: str):
        """Insert calendar event id. Title/description intentionally not stored (privacy)."""
        sql = """
            INSERT INTO calendar_events (id)
            VALUES (%s)
            ON CONFLICT (id) DO NOTHING
        """
        try:
            self.cursor.execute(sql, (event_id,))
        except psycopg2.Error as e:
            print(f"✗ Error inserting calendar event {event_id}: {e}")

    def booking_exists(self, booking_id: str) -> bool:
        """Check if booking already exists in database."""
        sql = "SELECT id FROM bookings WHERE id = %s"
        try:
            self.cursor.execute(sql, (booking_id,))
            return self.cursor.fetchone() is not None
        except psycopg2.Error:
            return False

    def normalize_status(self, booking: Dict[str, Any]) -> str:
        """Status to store for a booking.

        Long admin bookings are blocks (e.g. Room 236 as election office,
        May-Sep 2026), not usage: 'blocked' keeps them out of every
        status='reserved' query. Awaio marks ended bookings 'obsolete';
        cancellation is a separate flag, so those are stored as 'reserved',
        matching how import/import_awaio_export.py stores historical bookings."""
        status = booking.get('status', 'reserved')
        if booking.get('admin'):
            start = self.parse_datetime(booking.get('start'))
            end = self.parse_datetime(booking.get('end'))
            if start and end and end - start > ADMIN_BLOCK_MIN_DURATION:
                return 'blocked'
        return 'reserved' if status == 'obsolete' else status

    def insert_booking(self, booking: Dict[str, Any]) -> tuple:
        """
        Insert or update booking.
        Returns tuple (success: bool, action: str) where action is 'inserted', 'updated', or 'failed'.
        """
        booking_id = booking.get('id')
        existed = self.booking_exists(booking_id)

        sql = """
            INSERT INTO bookings (
                id, calendar_event_id, owner_id, community_id, entity_id,
                category, status, start_time, end_time, cancelled, ended_early,
                is_admin, group_tag, main_tag, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (id) DO UPDATE SET
                calendar_event_id = EXCLUDED.calendar_event_id,
                status = EXCLUDED.status,
                start_time = EXCLUDED.start_time,
                end_time = EXCLUDED.end_time,
                cancelled = EXCLUDED.cancelled,
                ended_early = EXCLUDED.ended_early,
                updated_at = EXCLUDED.updated_at
        """

        values = (
            booking_id,
            booking.get('calendarEvent'),
            self._anon_id(booking.get('owner')),
            booking.get('community'),
            booking.get('entity'),
            booking.get('category'),
            self.normalize_status(booking),
            self.parse_datetime(booking.get('start')),
            self.parse_datetime(booking.get('end')),
            booking.get('cancelled', False),
            booking.get('endedEarly', False),
            booking.get('admin', False),
            booking.get('groupTag'),
            booking.get('mainTag'),
            self.parse_datetime(booking.get('created')),
            self.parse_datetime(booking.get('updated'))
        )

        try:
            self.cursor.execute(sql, values)
            action = 'updated' if existed else 'inserted'
            return (True, action)
        except psycopg2.Error as e:
            print(f"✗ Error inserting booking {booking_id}: {e}")
            return (False, 'failed')

    def insert_booking_organizers(self, booking_id: str, organizers: List[str]):
        """Insert booking organizers using UPSERT to avoid duplicates."""
        if not organizers:
            return

        anon_ids = [self._anon_id(o) for o in organizers if o]

        placeholders = ','.join(['%s'] * len(anon_ids))
        delete_sql = f"""
            DELETE FROM booking_organizers
            WHERE booking_id = %s
            AND user_id NOT IN ({placeholders})
        """
        try:
            self.cursor.execute(delete_sql, (booking_id, *anon_ids))
        except psycopg2.Error as e:
            print(f"✗ Error cleaning organizers for booking {booking_id}: {e}")

        sql = """
            INSERT INTO booking_organizers (booking_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT (booking_id, user_id) DO NOTHING
        """

        try:
            execute_batch(self.cursor, sql, [(booking_id, uid) for uid in anon_ids])
        except psycopg2.Error as e:
            print(f"✗ Error inserting organizers for booking {booking_id}: {e}")

    def insert_booking_participants(self, booking_id: str, participants: List[str]):
        """Insert booking participants using UPSERT to avoid duplicates."""
        if not participants:
            return

        anon_ids = [self._anon_id(p) for p in participants if p]

        placeholders = ','.join(['%s'] * len(anon_ids))
        delete_sql = f"""
            DELETE FROM booking_participants
            WHERE booking_id = %s
            AND user_id NOT IN ({placeholders})
        """
        try:
            self.cursor.execute(delete_sql, (booking_id, *anon_ids))
        except psycopg2.Error as e:
            print(f"✗ Error cleaning participants for booking {booking_id}: {e}")

        sql = """
            INSERT INTO booking_participants (booking_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT (booking_id, user_id) DO NOTHING
        """

        try:
            execute_batch(self.cursor, sql, [(booking_id, uid) for uid in anon_ids])
        except psycopg2.Error as e:
            print(f"✗ Error inserting participants for booking {booking_id}: {e}")

    def fetch_missing_entities(self) -> bool:
        """
        Fetch missing entities by calling fetch_entities.py script.
        Returns True if successful, False otherwise.
        """
        if not self.missing_entities:
            return True

        print(f"\n{'='*80}")
        print(f"⚠ Found {len(self.missing_entities)} missing entities")
        print(f"{'='*80}")
        print(f"Missing entity IDs: {', '.join(list(self.missing_entities)[:5])}" +
              (f"... and {len(self.missing_entities) - 5} more" if len(self.missing_entities) > 5 else ""))
        print(f"\n→ Fetching entities from Awaio API...")

        # Get path to fetch_entities.py script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        fetch_entities_script = os.path.join(script_dir, 'fetch_entities.py')

        if not os.path.exists(fetch_entities_script):
            print(f"✗ Error: fetch_entities.py not found at {fetch_entities_script}")
            return False

        try:
            # Run fetch_entities.py
            result = subprocess.run(
                [sys.executable, fetch_entities_script],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode == 0:
                print(f"✓ Successfully fetched entities")
                print(f"→ Verifying entities are now in database...")

                # Verify the missing entities are now present
                still_missing = []
                for entity_id in self.missing_entities:
                    self.cursor.execute("SELECT id FROM entities WHERE id = %s", (entity_id,))
                    if not self.cursor.fetchone():
                        still_missing.append(entity_id)

                if still_missing:
                    print(f"⚠ Warning: {len(still_missing)} entities still missing after fetch")
                    print(f"  Missing: {', '.join(still_missing[:5])}" +
                          (f"... and {len(still_missing) - 5} more" if len(still_missing) > 5 else ""))
                    return False
                else:
                    print(f"✓ All {len(self.missing_entities)} entities now available in database")
                    self.missing_entities.clear()
                    return True
            else:
                print(f"✗ Error running fetch_entities.py (exit code {result.returncode})")
                if result.stderr:
                    print(f"  Error output: {result.stderr[:500]}")
                return False

        except subprocess.TimeoutExpired:
            print(f"✗ Error: fetch_entities.py timed out after 5 minutes")
            return False
        except Exception as e:
            print(f"✗ Error running fetch_entities.py: {e}")
            return False

    def import_bookings(self, bookings: List[Dict[str, Any]]):
        """Import list of bookings with all related data."""
        total = len(bookings)
        print(f"\n{'='*80}")
        print(f"Importing {total} bookings to database...")
        print(f"{'='*80}")

        # First pass: Check for missing entities
        print(f"\n→ Checking for missing entities...")
        self.missing_entities.clear()

        for booking in bookings:
            entity_id = booking.get('entity')
            if entity_id:
                try:
                    self.cursor.execute("SELECT id FROM entities WHERE id = %s", (entity_id,))
                    if not self.cursor.fetchone():
                        self.missing_entities.add(entity_id)
                except psycopg2.Error as e:
                    print(f"  ✗ Error checking entity {entity_id}: {e}")

        # If we have missing entities, try to fetch them
        if self.missing_entities:
            if not self.fetch_missing_entities():
                print(f"\n⚠ Warning: Could not fetch all missing entities. Some bookings will be skipped.")
        else:
            print(f"✓ All entities exist in database")

        # Second pass: Import bookings
        print(f"\n{'='*80}")
        print(f"Processing bookings...")
        print(f"{'='*80}")

        inserted = 0
        updated = 0
        failed = 0
        skipped = 0

        for idx, booking in enumerate(bookings, 1):
            booking_id = booking.get('id')
            entity_name = booking.get('entity', 'Unknown')[:20]
            start_time = booking.get('start', '')[:16] if booking.get('start') else 'N/A'
            status = booking.get('status', 'unknown')

            self._detail(f"\n[{idx}/{total}] Processing booking: {entity_name}... @ {start_time}")
            self._detail(f"  ID: {booking_id}")
            self._detail(f"  Status: {status}")

            # Check if entity exists
            entity_id = booking.get('entity')
            if entity_id:
                try:
                    self.cursor.execute("SELECT id FROM entities WHERE id = %s", (entity_id,))
                    if not self.cursor.fetchone():
                        print(f"  ⚠ Warning: Entity {entity_id} not found, skipping booking {booking_id}")
                        skipped += 1
                        continue
                except psycopg2.Error as e:
                    print(f"  ✗ Error checking entity {entity_id} for booking {booking_id}: {e}")
                    failed += 1
                    continue

            # Insert related data first
            if booking.get('community'):
                self.insert_community(booking['community'])

            if booking.get('owner'):
                self.insert_user(booking['owner'])

            if booking.get('calendarEvent'):
                self.insert_calendar_event(booking['calendarEvent'])

            # Insert organizers and participants as users
            for org_id in booking.get('organizers', []):
                self.insert_user(org_id)

            for part_id in booking.get('participants', []):
                self.insert_user(part_id)

            # Insert booking
            success, action = self.insert_booking(booking)
            if success:
                if action == 'inserted':
                    self._detail(f"  ✓ Booking inserted (NEW)")
                    inserted += 1
                elif action == 'updated':
                    self._detail(f"  ✓ Booking updated (EXISTING)")
                    updated += 1

                # Insert organizers and participants relationships
                organizers = booking.get('organizers', [])
                participants = booking.get('participants', [])

                if organizers:
                    self.insert_booking_organizers(booking_id, organizers)
                    self._detail(f"  ✓ {len(organizers)} organizer(s) saved")

                if participants:
                    self.insert_booking_participants(booking_id, participants)
                    self._detail(f"  ✓ {len(participants)} participant(s) saved")

                if not organizers and not participants:
                    self._detail(f"  ℹ No organizers or participants")
            else:
                failed += 1
                print(f"  ✗ Failed to save booking {booking_id}")
                self.conn.rollback()

        self.conn.commit()

        print(f"\n{'='*80}")
        print(f"IMPORT COMPLETE")
        print(f"{'='*80}")
        print(f"  Total bookings processed: {total}")
        print(f"  New bookings inserted: {inserted}")
        print(f"  Existing bookings updated: {updated}")
        print(f"  Skipped (missing entity): {skipped}")
        print(f"  Failed: {failed}")
        if total > 0:
            print(f"  Success rate: {((inserted + updated) / total * 100):.1f}%")
        print(f"{'='*80}")

    def get_stats(self):
        """Get and display database statistics."""
        stats = {}

        tables = ['communities', 'users', 'entities', 'bookings',
                  'booking_organizers', 'booking_participants', 'calendar_events']

        for table in tables:
            self.cursor.execute(f"SELECT COUNT(*) FROM {table}")
            stats[table] = self.cursor.fetchone()[0]

        print("\n" + "="*50)
        print("Database Statistics:")
        print("="*50)
        for table, count in stats.items():
            print(f"  {table:25} {count:>10} records")
        print("="*50)


def main():
    """Main function to fetch bookings and import to database."""
    import argparse

    parser = argparse.ArgumentParser(description='Fetch bookings from Awaio API and import to PostgreSQL')
    parser.add_argument(
        '--community-id',
        default='OlnrwKaefGc2C2Z9Znzv',
        help='Community ID to fetch bookings for (default: OlnrwKaefGc2C2Z9Znzv)'
    )
    parser.add_argument(
        '--date',
        help='Fetch bookings for specific date (YYYY-MM-DD), defaults to today'
    )
    parser.add_argument(
        '--days',
        type=int,
        default=1,
        help='Number of days to fetch (default: 1, only today)'
    )
    parser.add_argument(
        '--save-json',
        action='store_true',
        help='Also save bookings to JSON file'
    )
    parser.add_argument(
        '--output',
        help='Output JSON filename (only used with --save-json)'
    )
    parser.add_argument(
        '--stats',
        action='store_true',
        help='Show database statistics after import'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Log every booking imported, and every HTTP request and response in full '
             '(credentials redacted) so the output can be sent to Awaio support. '
             'Default: summaries and errors only'
    )

    args = parser.parse_args()

    print("="*80)
    print("AWAIO BOOKINGS IMPORTER")
    print("="*80)
    print(f"Community ID: {args.community_id}")
    print(f"Database: {DB_CONFIG['database']} @ {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print("="*80)

    # Validate credentials
    if not CLIENT_ID or CLIENT_ID == 'your_client_id':
        print("\n✗ Error: AWAIO_CLIENT_ID not set in .env file")
        print("Please update .env with your actual client_id")
        sys.exit(1)

    if not CLIENT_SECRET or CLIENT_SECRET == 'your_client_secret':
        print("\n✗ Error: AWAIO_CLIENT_SECRET not set in .env file")
        print("Please update .env with your actual client_secret")
        sys.exit(1)

    print("\n→ Credentials validated")

    anonymize = should_anonymize()
    salt = os.getenv('ANONYMIZE_SALT', '')
    if anonymize and not salt:
        print("\n✗ Error: ANONYMIZE_USERS=true but ANONYMIZE_SALT is empty.")
        print("  Generate one with:  openssl rand -hex 32")
        print("  Then set ANONYMIZE_SALT in .env (and store a copy in Bitwarden).")
        print("  Losing the salt means losing longitudinal correlation — it cannot be recovered.")
        sys.exit(1)
    print(f"→ Anonymization: {'ON (HMAC-SHA256 keyed)' if anonymize else 'OFF'}")

    # Calculate date range
    if args.date:
        start_date = datetime.strptime(args.date, '%Y-%m-%d')
    else:
        start_date = datetime.now()

    end_date = start_date + timedelta(days=args.days)

    # Format dates for API (ISO 8601)
    start_date_str = start_date.strftime('%Y-%m-%dT00:00:00.000Z')
    end_date_str = end_date.strftime('%Y-%m-%dT23:59:59.999Z')

    print(f"→ Date range: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")

    # Create API client
    print("→ Creating API client...")
    api_client = AwaioAPIClient(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        auth_url=AUTH_URL,
        api_base_url=API_BASE_URL,
        verbose=args.verbose
    )

    # Authenticate
    print("→ Authenticating with Awaio API...")
    if not api_client.authenticate():
        print("\n✗ Authentication failed. Please check your credentials.")
        sys.exit(1)

    # Fetch bookings
    print(f"→ Fetching bookings for community {args.community_id}...")
    bookings = api_client.get_bookings(args.community_id, start_date_str, end_date_str)

    if bookings is None:
        print("\n✗ Failed to fetch bookings. Check credentials and network.")
        sys.exit(1)

    if len(bookings) == 0:
        print("\n✓ No bookings in date range — nothing to import.")
        sys.exit(0)

    # Save to JSON file if requested
    if args.save_json:
        print("\n→ Saving to JSON file...")
        filename = api_client.save_to_json(bookings, args.output)
        print(f"  ✓ JSON file saved: {filename}")

    # Import to database
    print(f"\n→ Connecting to database...")
    db_importer = BookingImporter(DB_CONFIG, anonymize=anonymize, salt=salt,
                                  verbose=args.verbose)

    try:
        db_importer.connect()
        db_importer.import_bookings(bookings)

        # Show statistics if requested
        if args.stats:
            db_importer.get_stats()

    except KeyboardInterrupt:
        print("\n\n✗ Import interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        db_importer.disconnect()

    # Summary
    print("\n" + "="*80)
    print("✓ ALL OPERATIONS COMPLETED SUCCESSFULLY")
    print("="*80)
    print(f"  Community ID: {args.community_id}")
    print(f"  Date range: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
    print(f"  Bookings fetched from API: {len(bookings)}")
    if args.save_json:
        print(f"  JSON file saved: Yes")
    print("="*80)
    print("\nYou can now view the data in:")
    print(f"  - Metabase: http://localhost:3000")
    print(f"  - pgAdmin: http://localhost:5050")
    print(f"  - PostgreSQL: psql -h localhost -U {DB_CONFIG['user']} -d {DB_CONFIG['database']}")
    print("="*80)


if __name__ == '__main__':
    main()
