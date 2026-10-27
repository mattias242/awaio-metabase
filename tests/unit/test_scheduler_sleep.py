"""
Unit tests for the scheduler's wait between iterations.

Event.wait() runs on the monotonic clock, which stands still while the host
(laptop / Docker VM) is suspended. A single wait of ~1 h therefore overslept
by a whole night (2026-10-26 17:00 -> no runs until well after wake-up).
The scheduler must wait in short chunks and re-check the wall clock.
"""

import os
import sys
from datetime import datetime, timedelta
from unittest.mock import Mock

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))


@pytest.fixture
def scheduler(tmp_path, monkeypatch):
    monkeypatch.setenv('AWAIO_APP_DIR', str(tmp_path))
    sys.modules.pop('scheduler_loop', None)
    import scheduler_loop
    return scheduler_loop


def clock(*times):
    values = iter(times)
    return lambda: next(values)


T0 = datetime(2026, 10, 26, 17, 0, 51)
TARGET = datetime(2026, 10, 26, 18, 0, 0)


def test_waits_in_short_chunks(scheduler):
    stop = Mock()
    stop.wait.return_value = False

    scheduler.sleep_until(TARGET, now_fn=clock(T0, TARGET), stop=stop)

    assert all(call.args[0] <= 60 for call in stop.wait.call_args_list)


def test_wakes_up_after_host_suspend(scheduler):
    """After resume the wall clock is far past the target: run right away."""
    stop = Mock()
    stop.wait.return_value = False
    after_resume = datetime(2026, 10, 27, 8, 53, 26)

    stopped = scheduler.sleep_until(TARGET, now_fn=clock(T0, after_resume), stop=stop)

    assert stopped is False
    assert stop.wait.call_count == 1


def test_returns_true_when_stopped(scheduler):
    stop = Mock()
    stop.wait.return_value = True

    assert scheduler.sleep_until(TARGET, now_fn=clock(T0), stop=stop) is True


def test_target_in_the_past_returns_immediately(scheduler):
    stop = Mock()

    assert scheduler.sleep_until(TARGET, now_fn=clock(TARGET + timedelta(seconds=1)),
                                 stop=stop) is False
    stop.wait.assert_not_called()


def test_entities_are_fetched_before_bookings(scheduler, monkeypatch):
    """Bookings on a newly added resource should join to it in the same run."""
    calls = []
    monkeypatch.setattr(scheduler, 'fetch_entities', lambda: calls.append('entities') or 0)
    monkeypatch.setattr(scheduler, 'fetch_bookings', lambda *a: calls.append('bookings') or 0)
    monkeypatch.setattr(scheduler, 'refresh_hour_slots', lambda: calls.append('refresh') or 0)

    assert scheduler.run_iteration() is True
    assert calls == ['entities', 'bookings', 'refresh']
