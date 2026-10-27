"""
Unit tests for import log verbosity.

The hourly scheduler logged ~2 800 lines per run, nearly all of them one
block per booking/entity. By default the importers print only summaries
(and errors); --verbose restores the per-object detail.
"""

import os
import sys
from unittest.mock import Mock

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from fetch_bookings import BookingImporter
from fetch_entities import EntityImporter


BOOKINGS = [
    {"id": f"b{i}", "community": "C1", "entity": "E1", "owner": None,
     "start": "2026-10-27T07:00:00.000Z", "end": "2026-10-27T08:00:00.000Z",
     "status": "reserved", "cancelled": False, "organizers": ["u1"]}
    for i in range(3)
]

ENTITIES = [
    {"id": "E1", "name": "Plan 2", "groupTag": "location", "parent": None},
    {"id": "E2", "name": "Desk 12", "groupTag": "desk", "parent": "E1",
     "equipment": ["screen"], "qrCodes": ["q1"]},
]


def booking_importer(**kwargs):
    importer = BookingImporter(db_config={}, **kwargs)
    importer.cursor = Mock()
    importer.cursor.fetchone.return_value = ("E1",)
    importer.conn = Mock()
    importer.insert_booking = Mock(return_value=(True, 'updated'))
    importer.insert_booking_organizers = Mock()
    importer.insert_user = Mock()
    importer.insert_community = Mock()
    return importer


def entity_importer(**kwargs):
    importer = EntityImporter(db_config={}, **kwargs)
    importer.cursor = Mock()
    importer.conn = Mock()
    importer.insert_community = Mock()
    importer.insert_entity = Mock(return_value=(True, 'updated'))
    importer.insert_entity_equipment = Mock()
    importer.insert_entity_qr_codes = Mock()
    return importer


class TestBookingImportVerbosity:

    def test_default_prints_summary_only(self, capsys):
        booking_importer().import_bookings(BOOKINGS)

        out = capsys.readouterr().out
        assert "Processing booking:" not in out
        assert "Booking updated" not in out
        assert "Existing bookings updated: 3" in out

    def test_verbose_prints_every_booking(self, capsys):
        booking_importer(verbose=True).import_bookings(BOOKINGS)

        out = capsys.readouterr().out
        assert out.count("Processing booking:") == 3

    def test_failure_is_reported_with_booking_id_by_default(self, capsys):
        importer = booking_importer()
        importer.insert_booking = Mock(return_value=(False, None))

        importer.import_bookings(BOOKINGS[:1])

        assert "Failed to save booking b0" in capsys.readouterr().out


class TestEntityImportVerbosity:

    def test_default_prints_summary_only(self, capsys):
        entity_importer().import_entities(ENTITIES, "C1")

        out = capsys.readouterr().out
        assert "Processing:" not in out
        assert "Entity updated" not in out
        assert "Existing entities updated: 2" in out

    def test_verbose_prints_every_entity(self, capsys):
        entity_importer(verbose=True).import_entities(ENTITIES, "C1")

        assert capsys.readouterr().out.count("Processing:") == 2

    def test_failure_is_reported_with_entity_name_by_default(self, capsys):
        importer = entity_importer()
        importer.insert_entity = Mock(return_value=(False, None))

        importer.import_entities(ENTITIES[:1], "C1")

        assert "Failed to save entity Plan 2" in capsys.readouterr().out
