#!/usr/bin/env python3
"""
Fetch entities from Awaio API and import directly to PostgreSQL.
Authenticates using client_id and client_secret, then fetches entities for a community.
"""

import os
import sys
import json
import requests
from datetime import datetime
from typing import List, Dict, Any, Optional
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# API Configuration
AUTH_URL = os.getenv('AWAIO_AUTH_URL', 'https://api.awaio.com/auth/token')
API_BASE_URL = os.getenv('AWAIO_API_BASE_URL', 'https://api.awaio.com/v1.0.0')
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


class AwaioAPIClient:
    """Client for interacting with Awaio API."""

    def __init__(self, client_id: str, client_secret: str, auth_url: str, api_base_url: str):
        """Initialize the API client."""
        self.client_id = client_id
        self.client_secret = client_secret
        self.auth_url = auth_url
        self.api_base_url = api_base_url
        self.access_token = None

    def authenticate(self) -> bool:
        """
        Authenticate with the API and get an access token.
        Returns True if successful, False otherwise.
        """
        print(f"Authenticating with {self.auth_url}...")

        try:
            response = requests.post(
                self.auth_url,
                json={
                    'client_id': self.client_id,
                    'client_secret': self.client_secret,
                    'grant_type': 'client_credentials'
                },
                headers={'Content-Type': 'application/json'},
                timeout=30
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

        except (requests.exceptions.RequestException, ValueError) as e:
            print(f"✗ Authentication error: {e}")
            return False

    def get_entities(self, community_id: str) -> list:
        """
        Fetch entities for a specific community.
        Returns list of entities or empty list on error.
        """
        if not self.access_token:
            print("✗ Not authenticated. Call authenticate() first.")
            return []

        url = f"{self.api_base_url}/communities/{community_id}/entities"
        print(f"\nFetching entities from {url}...")

        try:
            response = requests.get(
                url,
                headers={
                    'Authorization': f'Bearer {self.access_token}',
                    'Content-Type': 'application/json'
                },
                timeout=30
            )

            if response.status_code == 200:
                entities = response.json()
                entity_count = len(entities) if isinstance(entities, list) else 1
                print(f"✓ Successfully fetched {entity_count} entities")
                return entities if isinstance(entities, list) else [entities]
            else:
                print(f"✗ Failed to fetch entities. Status: {response.status_code}")
                print(f"Response: {response.text}")
                return []

        except requests.exceptions.RequestException as e:
            print(f"✗ Error fetching entities: {e}")
            return []

    def save_to_json(self, data: list, filename: str = None) -> str:
        """
        Save entities data to a JSON file.
        Returns the filename.
        """
        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"json/entities_{timestamp}.json"

        # Ensure json directory exists
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"✓ Saved {len(data)} entities to {filename}")
        return filename


class EntityImporter:
    """Import entities to PostgreSQL database."""

    def __init__(self, db_config: Dict[str, Any], verbose: bool = False):
        """Initialize database connection. verbose=True logs every entity;
        otherwise only summaries and errors are printed."""
        self.db_config = db_config
        self.verbose = verbose
        self.conn = None
        self.cursor = None

    def _detail(self, message: str):
        """Print per-object progress, only with --verbose."""
        if self.verbose:
            print(message)

    def connect(self):
        """Connect to PostgreSQL database."""
        try:
            self.conn = psycopg2.connect(**self.db_config)
            self.cursor = self.conn.cursor()
            print(f"✓ Connected to database: {self.db_config['database']}")
        except psycopg2.Error as e:
            print(f"✗ Database connection error: {e}")
            sys.exit(1)

    def disconnect(self):
        """Close database connection."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("✓ Database connection closed")

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

    def entity_exists(self, entity_id: str) -> bool:
        """Check if entity already exists in database."""
        sql = "SELECT id FROM entities WHERE id = %s"
        try:
            self.cursor.execute(sql, (entity_id,))
            return self.cursor.fetchone() is not None
        except psycopg2.Error:
            return False

    def insert_entity(self, entity: Dict[str, Any]) -> tuple:
        """
        Insert or update entity.
        Returns tuple (success: bool, action: str) where action is 'inserted', 'updated', or 'failed'.
        """
        entity_id = entity.get('id')
        existed = self.entity_exists(entity_id)

        sql = """
            INSERT INTO entities (
                id, name, parent_id, community_id, main_tag, group_tag,
                capacity_normal, capacity_max,
                address_street, address_city, address_postal_code, address_country,
                geo_latitude, geo_longitude, device_id
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                parent_id = EXCLUDED.parent_id,
                community_id = EXCLUDED.community_id,
                main_tag = EXCLUDED.main_tag,
                group_tag = EXCLUDED.group_tag,
                capacity_normal = EXCLUDED.capacity_normal,
                capacity_max = EXCLUDED.capacity_max,
                address_street = EXCLUDED.address_street,
                address_city = EXCLUDED.address_city,
                address_postal_code = EXCLUDED.address_postal_code,
                address_country = EXCLUDED.address_country,
                geo_latitude = EXCLUDED.geo_latitude,
                geo_longitude = EXCLUDED.geo_longitude,
                device_id = EXCLUDED.device_id,
                updated_at = CURRENT_TIMESTAMP
        """

        # Extract nested data
        capacity = entity.get('capacity', {})
        address = entity.get('address', {})
        geo_data = entity.get('geoData', {})
        device = entity.get('device', {})

        values = (
            entity_id,
            entity.get('name'),
            entity.get('parent'),
            entity.get('community'),
            entity.get('mainTag'),
            entity.get('groupTag'),
            capacity.get('normal') if isinstance(capacity, dict) else None,
            capacity.get('max') if isinstance(capacity, dict) else None,
            address.get('street') if isinstance(address, dict) else None,
            address.get('city') if isinstance(address, dict) else None,
            address.get('postalCode') if isinstance(address, dict) else None,
            address.get('country') if isinstance(address, dict) else None,
            geo_data.get('latitude') if isinstance(geo_data, dict) else None,
            geo_data.get('longitude') if isinstance(geo_data, dict) else None,
            device.get('id') if isinstance(device, dict) else None
        )

        try:
            self.cursor.execute(sql, values)
            action = 'updated' if existed else 'inserted'
            return (True, action)
        except psycopg2.Error as e:
            print(f"✗ Error inserting entity {entity_id} ({entity.get('name')}): {e}")
            return (False, 'failed')

    def insert_entity_attributes(self, entity_id: str, attributes: List[str]):
        """Insert entity attributes (tags) using UPSERT to avoid duplicates."""
        if not attributes:
            return

        # First, delete attributes that are no longer in the list
        if attributes:
            placeholders = ','.join(['%s'] * len(attributes))
            delete_sql = f"""
                DELETE FROM entity_attributes
                WHERE entity_id = %s
                AND attribute_tag NOT IN ({placeholders})
            """
            try:
                self.cursor.execute(delete_sql, (entity_id, *attributes))
            except psycopg2.Error as e:
                print(f"✗ Error cleaning old attributes for entity {entity_id}: {e}")

        # Insert new attributes using UPSERT
        sql = """
            INSERT INTO entity_attributes (entity_id, attribute_tag)
            VALUES (%s, %s)
            ON CONFLICT (entity_id, attribute_tag) DO NOTHING
        """
        try:
            values = [(entity_id, attr) for attr in attributes]
            execute_batch(self.cursor, sql, values)
        except psycopg2.Error as e:
            print(f"✗ Error inserting attributes for entity {entity_id}: {e}")

    def insert_entity_equipment(self, entity_id: str, equipment: List[str]):
        """Insert entity equipment using UPSERT to avoid duplicates."""
        if not equipment:
            return

        # First, delete equipment that is no longer in the list
        if equipment:
            placeholders = ','.join(['%s'] * len(equipment))
            delete_sql = f"""
                DELETE FROM entity_equipment
                WHERE entity_id = %s
                AND equipment NOT IN ({placeholders})
            """
            try:
                self.cursor.execute(delete_sql, (entity_id, *equipment))
            except psycopg2.Error as e:
                print(f"✗ Error cleaning old equipment for entity {entity_id}: {e}")

        # Insert new equipment using UPSERT
        sql = """
            INSERT INTO entity_equipment (entity_id, equipment)
            VALUES (%s, %s)
            ON CONFLICT (entity_id, equipment) DO NOTHING
        """
        try:
            values = [(entity_id, equip) for equip in equipment]
            execute_batch(self.cursor, sql, values)
        except psycopg2.Error as e:
            print(f"✗ Error inserting equipment for entity {entity_id}: {e}")

    def insert_entity_photos(self, entity_id: str, photos: List[str]):
        """Insert entity photos."""
        if not photos:
            return

        # First, delete existing photos for this entity
        delete_sql = "DELETE FROM entity_photos WHERE entity_id = %s"
        try:
            self.cursor.execute(delete_sql, (entity_id,))
        except psycopg2.Error as e:
            print(f"✗ Error deleting old photos for entity {entity_id}: {e}")

        # Insert new photos
        sql = """
            INSERT INTO entity_photos (entity_id, photo_url, display_order)
            VALUES (%s, %s, %s)
        """
        try:
            values = [(entity_id, photo, idx) for idx, photo in enumerate(photos)]
            execute_batch(self.cursor, sql, values)
        except psycopg2.Error as e:
            print(f"✗ Error inserting photos for entity {entity_id}: {e}")

    def insert_entity_qr_codes(self, entity_id: str, qr_codes: List[str]):
        """Insert entity QR codes using UPSERT to avoid duplicates."""
        if not qr_codes:
            return

        # First, delete QR codes that are no longer in the list
        if qr_codes:
            placeholders = ','.join(['%s'] * len(qr_codes))
            delete_sql = f"""
                DELETE FROM entity_qr_codes
                WHERE entity_id = %s
                AND qr_code NOT IN ({placeholders})
            """
            try:
                self.cursor.execute(delete_sql, (entity_id, *qr_codes))
            except psycopg2.Error as e:
                print(f"✗ Error cleaning old QR codes for entity {entity_id}: {e}")

        # Insert new QR codes using UPSERT
        sql = """
            INSERT INTO entity_qr_codes (entity_id, qr_code)
            VALUES (%s, %s)
            ON CONFLICT (entity_id, qr_code) DO NOTHING
        """
        try:
            values = [(entity_id, qr) for qr in qr_codes]
            execute_batch(self.cursor, sql, values)
        except psycopg2.Error as e:
            print(f"✗ Error inserting QR codes for entity {entity_id}: {e}")

    def _get_hierarchy_level(self, entity: Dict[str, Any], all_entities: List[Dict[str, Any]]) -> int:
        """Get the hierarchy level of an entity (0 = root, 1 = child of root, etc.)."""
        if not entity.get('parent'):
            return 0

        # Find parent and recursively get its level
        parent_id = entity.get('parent')
        parent = next((e for e in all_entities if e.get('id') == parent_id), None)

        if parent:
            return 1 + self._get_hierarchy_level(parent, all_entities)
        else:
            # Parent not found, treat as root level
            return 0

    def _topological_sort(self, entities: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Sort entities in topological order so parents are imported before children.
        Uses a simple algorithm: repeatedly find entities whose parents have been processed.
        """
        # Create a map of entity ID to entity
        entity_map = {e.get('id'): e for e in entities}

        # Track which entities have been processed
        processed = set()
        result = []

        # Keep iterating until all entities are processed
        max_iterations = len(entities) + 1
        iteration = 0

        while len(result) < len(entities) and iteration < max_iterations:
            iteration += 1
            added_this_round = False

            for entity in entities:
                entity_id = entity.get('id')

                # Skip if already processed
                if entity_id in processed:
                    continue

                parent_id = entity.get('parent')

                # Add if no parent, or if parent is already processed
                if not parent_id or parent_id in processed or parent_id not in entity_map:
                    result.append(entity)
                    processed.add(entity_id)
                    added_this_round = True

            # If nothing was added this round, we might have circular dependencies
            if not added_this_round:
                # Add remaining entities anyway to avoid infinite loop
                for entity in entities:
                    if entity.get('id') not in processed:
                        result.append(entity)
                        processed.add(entity.get('id'))
                break

        return result

    def import_entities(self, entities: List[Dict[str, Any]], community_id: str):
        """Import list of entities with all related data."""
        total = len(entities)
        print(f"\n{'='*80}")
        print(f"Importing {total} entities to database...")
        print(f"{'='*80}")

        # Insert community first
        print(f"\n→ Ensuring community '{community_id}' exists...")
        self.insert_community(community_id)
        print(f"  ✓ Community ready")

        # Sort entities in topological order (parents before children)
        print(f"\n→ Sorting entities in hierarchical order...")
        all_entities_ordered = self._topological_sort(entities)

        # Count hierarchy levels
        levels = {}
        for entity in all_entities_ordered:
            level = self._get_hierarchy_level(entity, entities)
            levels[level] = levels.get(level, 0) + 1

        print(f"\n→ Hierarchy structure:")
        for level in sorted(levels.keys()):
            print(f"  Level {level}: {levels[level]} entities")

        inserted = 0
        updated = 0
        failed = 0

        for idx, entity in enumerate(all_entities_ordered, 1):
            entity_id = entity.get('id')
            entity_name = entity.get('name', 'Unnamed')
            entity_type = entity.get('groupTag', 'unknown')
            parent_id = entity.get('parent')
            level = self._get_hierarchy_level(entity, entities)

            level_indent = "  " * level
            parent_info = f" [parent: {parent_id[:8]}...]" if parent_id else " [ROOT]"
            self._detail(f"\n[{idx}/{total}] {level_indent}Processing: {entity_name} ({entity_type}){parent_info}")
            self._detail(f"  {level_indent}ID: {entity_id}")

            # Insert entity
            success, action = self.insert_entity(entity)
            if success:
                if action == 'inserted':
                    self._detail(f"  {level_indent}✓ Entity inserted (NEW)")
                    inserted += 1
                elif action == 'updated':
                    self._detail(f"  {level_indent}✓ Entity updated (EXISTING)")
                    updated += 1

                # Count related data
                attrs_count = len(entity.get('attributeTags', []))
                equip_count = len(entity.get('equipment', []))
                qr_count = len(entity.get('qrCodes', []))

                # Insert related data
                if attrs_count > 0:
                    self.insert_entity_attributes(entity_id, entity.get('attributeTags', []))
                    self._detail(f"  {level_indent}✓ {attrs_count} attribute(s) saved")

                if equip_count > 0:
                    self.insert_entity_equipment(entity_id, entity.get('equipment', []))
                    self._detail(f"  {level_indent}✓ {equip_count} equipment item(s) saved")

                if qr_count > 0:
                    self.insert_entity_qr_codes(entity_id, entity.get('qrCodes', []))
                    self._detail(f"  {level_indent}✓ {qr_count} QR code(s) saved")

                if attrs_count == 0 and equip_count == 0 and qr_count == 0:
                    self._detail(f"  {level_indent}ℹ No additional data")
            else:
                failed += 1
                print(f"  {level_indent}✗ Failed to save entity {entity_name} ({entity_id})")
                # Rollback and continue with next entity
                self.conn.rollback()

        self.conn.commit()

        print(f"\n{'='*80}")
        print(f"IMPORT COMPLETE")
        print(f"{'='*80}")
        print(f"  Total entities processed: {total}")
        print(f"  New entities inserted: {inserted}")
        print(f"  Existing entities updated: {updated}")
        print(f"  Failed: {failed}")
        print(f"  Success rate: {((inserted + updated) / total * 100):.1f}%")
        print(f"{'='*80}")

    def get_stats(self):
        """Get and display database statistics."""
        stats = {}

        tables = ['communities', 'entities', 'entity_attributes',
                  'entity_equipment', 'entity_photos', 'entity_qr_codes']

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
    """Main function to fetch entities and import to database."""
    import argparse

    parser = argparse.ArgumentParser(description='Fetch entities from Awaio API and import to PostgreSQL')
    parser.add_argument(
        '--community-id',
        default='OlnrwKaefGc2C2Z9Znzv',
        help='Community ID to fetch entities for (default: OlnrwKaefGc2C2Z9Znzv)'
    )
    parser.add_argument(
        '--save-json',
        action='store_true',
        help='Also save entities to JSON file'
    )
    parser.add_argument(
        '--output',
        help='Output JSON filename (only used with --save-json)'
    )
    parser.add_argument(
        '--print',
        action='store_true',
        help='Print entities to console'
    )
    parser.add_argument(
        '--stats',
        action='store_true',
        help='Show database statistics after import'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Log every entity imported. Default: summaries and errors only'
    )

    args = parser.parse_args()

    print("="*80)
    print("AWAIO ENTITIES IMPORTER")
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

    # Create API client
    print("→ Creating API client...")
    api_client = AwaioAPIClient(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        auth_url=AUTH_URL,
        api_base_url=API_BASE_URL
    )

    # Authenticate
    print("→ Authenticating with Awaio API...")
    if not api_client.authenticate():
        print("\n✗ Authentication failed. Please check your credentials.")
        sys.exit(1)

    # Fetch entities
    print(f"→ Fetching entities for community {args.community_id}...")
    entities = api_client.get_entities(args.community_id)

    if not entities:
        print("\n✗ No entities found or error occurred.")
        sys.exit(1)

    # Print to console if requested
    if args.print:
        print("\n" + "="*80)
        print("ENTITIES DATA:")
        print("="*80)
        print(json.dumps(entities, indent=2, ensure_ascii=False))
        print("="*80)

    # Save to JSON file if requested
    if args.save_json:
        print("\n→ Saving to JSON file...")
        filename = api_client.save_to_json(entities, args.output)
        print(f"  ✓ JSON file saved: {filename}")

    # Import to database
    print(f"\n→ Connecting to database...")
    db_importer = EntityImporter(DB_CONFIG, verbose=args.verbose)

    try:
        db_importer.connect()
        db_importer.import_entities(entities, args.community_id)

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
    print(f"  Entities fetched from API: {len(entities)}")
    print(f"  Entities imported to database: {len(entities)}")
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
