#!/bin/bash
# Creates the metabase_app database when PostgreSQL initialises
psql -U "$POSTGRES_USER" -c "CREATE DATABASE metabase_app OWNER $POSTGRES_USER;" 2>/dev/null || true
