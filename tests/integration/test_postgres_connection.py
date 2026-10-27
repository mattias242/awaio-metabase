"""Smoke test for the postgres service spun up by CI.

The Integration Tests job in `.github/workflows/ci.yml` brings up a
postgres:16-alpine service container with empty schema. This test verifies
that the connection works end-to-end with the env vars CI sets.
"""

import os

import psycopg2
import pytest


@pytest.mark.integration
def test_postgres_is_reachable():
    conn = psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        port=int(os.environ["POSTGRES_PORT"]),
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            assert cur.fetchone() == (1,)
    finally:
        conn.close()
