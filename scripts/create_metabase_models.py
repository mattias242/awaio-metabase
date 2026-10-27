#!/usr/bin/env python3
"""
Create/update Awaio Metabase models from SQL files in metabase/models/.

Reads each .sql file, finds (or creates) an `Awaio Models` collection, then
POSTs (or PUTs) a card with type='model' per file. Idempotent: re-running
updates existing models instead of duplicating them.

Required env:
    METABASE_URL       default http://localhost:3000
    METABASE_API_KEY   create via Admin → Authentication → API Keys
    METABASE_DB_NAME   default 'Awaio' (case-insensitive match against the
                       'Name' field of the registered database)
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv


SEMANTIC_TYPES = {
    # timestamps
    "start_time": "type/CreationTimestamp",
    "end_time": "type/CancelationTimestamp",
    "created_at": "type/CreationTimestamp",
    "updated_at": "type/UpdatedTimestamp",
    "booking_date": "type/CreationDate",
    "week_start": "type/CreationDate",
    "first_booking_at": "type/CreationTimestamp",
    "last_booking_at": "type/CancelationTimestamp",
    # duration
    "duration_hours": "type/Duration",
    "total_hours": "type/Duration",
    "avg_duration_hours": "type/Duration",
    # categoricals
    "weekday_name": "type/Category",
    "weekday_num": "type/Category",
    "entity_group_tag": "type/Category",
    "entity_main_tag": "type/Category",
    "booking_group_tag": "type/Category",
    "booking_main_tag": "type/Category",
    "group_tag": "type/Category",
    "main_tag": "type/Category",
    "floor_name": "type/Category",
    "area_name": "type/Category",
    "status": "type/Category",
    "category": "type/Category",
    # ids
    "booking_id": "type/PK",
    "entity_id": "type/FK",
    "owner_id": "type/FK",
    "community_id": "type/FK",
    "floor_id": "type/FK",
    "area_id": "type/FK",
    "building_id": "type/FK",
    # share / ratio
    "top_user_share": "type/Percentage",
}


MODEL_REF_RE = re.compile(r"\{\{@model:([a-z0-9_]+)\}\}")


def slug_from_filename(filename: str) -> str:
    """02_bookings_enriched.sql -> bookings_enriched"""
    stem = Path(filename).stem
    return re.sub(r"^\d+_", "", stem)


def human_name(filename: str) -> str:
    return slug_from_filename(filename).replace("_", " ").title()


def resolve_model_refs(sql: str, models_by_slug: dict) -> str:
    """Replace {{@model:<slug>}} placeholders with Metabase {{#<id>-<slug>}} refs."""
    def _sub(m):
        slug = m.group(1)
        if slug not in models_by_slug:
            raise SystemExit(f"✗ SQL references unknown model '{slug}'. Known: {list(models_by_slug)}")
        card_id = models_by_slug[slug]
        return "{{#" + f"{card_id}-{slug.replace('_', '-')}" + "}}"
    return MODEL_REF_RE.sub(_sub, sql)


def mb_request(session: requests.Session, base: str, method: str, path: str, **kw):
    resp = session.request(method, base + path, **kw)
    if not resp.ok:
        print(f"✗ {method} {path} → {resp.status_code}: {resp.text[:300]}")
        resp.raise_for_status()
    return resp.json() if resp.text else None


def find_database_id(session, base, name_wanted: str) -> int:
    data = mb_request(session, base, "GET", "/api/database")
    dbs = data.get("data", data) if isinstance(data, dict) else data
    for db in dbs:
        if db.get("name", "").lower() == name_wanted.lower():
            return db["id"]
    raise SystemExit(
        f"✗ No database named '{name_wanted}' in Metabase. "
        f"Available: {[db.get('name') for db in dbs]}"
    )


def find_or_create_collection(session, base, name: str) -> int:
    collections = mb_request(session, base, "GET", "/api/collection")
    for c in collections:
        if c.get("name") == name:
            return c["id"]
    created = mb_request(
        session, base, "POST", "/api/collection",
        json={"name": name, "description": "Awaio semantic data models backing dashboard questions."},
    )
    print(f"→ Created collection '{name}' (id={created['id']})")
    return created["id"]


def find_model_by_name(session, base, collection_id: int, name: str):
    items = mb_request(
        session, base, "GET", f"/api/collection/{collection_id}/items",
        params={"models": "dataset"},
    )
    data = items.get("data", items) if isinstance(items, dict) else items
    for item in data:
        if item.get("name") == name and item.get("model") in ("dataset", "card"):
            return item.get("id")
    return None


def apply_semantic_metadata(session, base, card_id: int):
    """Refetch card to pick up result_metadata, then PUT it back with semantic types."""
    card = mb_request(session, base, "GET", f"/api/card/{card_id}")
    metadata = card.get("result_metadata") or []
    if not metadata:
        print(f"  (no result_metadata yet for card {card_id}; run the card once in UI to populate)")
        return
    for col in metadata:
        sem = SEMANTIC_TYPES.get(col.get("name"))
        if sem:
            col["semantic_type"] = sem
    mb_request(
        session, base, "PUT", f"/api/card/{card_id}",
        json={"result_metadata": metadata},
    )


def upsert_model(session, base, database_id: int, collection_id: int, sql_path: Path,
                 models_by_slug: dict):
    name = human_name(sql_path.name)
    slug = slug_from_filename(sql_path.name)
    raw_sql = sql_path.read_text(encoding="utf-8")
    sql = resolve_model_refs(raw_sql, models_by_slug)

    # Referenced models appear as template tags in Metabase
    template_tags = {}
    for ref_slug in set(MODEL_REF_RE.findall(raw_sql)):
        ref_id = models_by_slug[ref_slug]
        tag_name = f"#{ref_id}-{ref_slug.replace('_', '-')}"
        template_tags[tag_name] = {
            "id": tag_name,
            "name": tag_name,
            "display-name": tag_name,
            "type": "card",
            "card-id": ref_id,
        }

    payload = {
        "name": name,
        "type": "model",
        "dataset_query": {
            "type": "native",
            "native": {"query": sql, "template-tags": template_tags},
            "database": database_id,
        },
        "display": "table",
        "visualization_settings": {},
        "collection_id": collection_id,
    }

    existing_id = find_model_by_name(session, base, collection_id, name)
    if existing_id:
        mb_request(session, base, "PUT", f"/api/card/{existing_id}", json=payload)
        print(f"✓ Updated '{name}' (id={existing_id})")
        card_id = existing_id
    else:
        created = mb_request(session, base, "POST", "/api/card", json=payload)
        card_id = created["id"]
        print(f"✓ Created '{name}' (id={card_id})")

    apply_semantic_metadata(session, base, card_id)
    models_by_slug[slug] = card_id
    return card_id


def main():
    load_dotenv()
    base = os.getenv("METABASE_URL", "http://localhost:3000").rstrip("/")
    api_key = os.getenv("METABASE_API_KEY")
    db_name = os.getenv("METABASE_DB_NAME", "Awaio")

    if not api_key:
        print("✗ METABASE_API_KEY is not set.")
        print("  Create one in Metabase: Admin settings → Authentication → API Keys.")
        print("  Then add it to .env (or export it) and re-run.")
        sys.exit(1)

    session = requests.Session()
    session.headers["X-API-Key"] = api_key
    session.headers["Content-Type"] = "application/json"

    print(f"→ Metabase: {base}")
    db_id = find_database_id(session, base, db_name)
    print(f"→ Database '{db_name}' has id={db_id}")

    collection_id = find_or_create_collection(session, base, "Awaio Models")
    print(f"→ Collection 'Awaio Models' has id={collection_id}")

    models_dir = Path(__file__).resolve().parent.parent / "metabase" / "models"
    sql_files = sorted(models_dir.glob("*.sql"))
    if not sql_files:
        print(f"✗ No SQL files in {models_dir}")
        sys.exit(1)

    print(f"→ Applying {len(sql_files)} model(s) from {models_dir}...")
    models_by_slug: dict = {}
    for sql_path in sql_files:
        upsert_model(session, base, db_id, collection_id, sql_path, models_by_slug)

    print("✓ Done.")


if __name__ == "__main__":
    main()
