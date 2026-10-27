#!/usr/bin/env python3
"""Hourly Awaio fetch loop.

Runs inside the Awaio fetcher Docker image. Once per top-of-hour between
07:00 and 19:00 Europe/Stockholm:
  1. fetch_entities.py
  2. fetch_bookings.py  (rolling date window from logs/last_fetch.state)
  3. REFRESH MATERIALIZED VIEW bi.v_hour_slots

The state file is updated only when all three steps succeed.
"""

from __future__ import annotations

import logging
import os
import signal
import subprocess
import sys
import threading
from datetime import date, datetime, timedelta
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path
from zoneinfo import ZoneInfo

import psycopg2

STOCKHOLM = ZoneInfo("Europe/Stockholm")
WINDOW_START_HOUR = 7
WINDOW_END_HOUR = 19  # inclusive — last iteration starts 19:00

APP_DIR = Path(os.getenv("AWAIO_APP_DIR", "/app"))
LOG_DIR = APP_DIR / "logs"
STATE_FILE = LOG_DIR / "last_fetch.state"

# Event.wait() uses the monotonic clock, which stops while the host sleeps;
# wait in short chunks and re-check the wall clock so a suspend can't
# postpone the next run by hours.
MAX_WAIT_CHUNK_S = 60.0

_stop = threading.Event()


def setup_logging() -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("scheduler")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    if logger.handlers:
        return logger

    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")

    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    fh = TimedRotatingFileHandler(
        LOG_DIR / "scheduler.log", when="midnight", backupCount=14, encoding="utf-8"
    )
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    return logger


log = setup_logging()


def now_stockholm() -> datetime:
    return datetime.now(STOCKHOLM)


def in_window(dt: datetime) -> bool:
    return WINDOW_START_HOUR <= dt.hour <= WINDOW_END_HOUR


def next_run_time(dt: datetime) -> datetime:
    next_hour = dt.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
    if WINDOW_START_HOUR <= next_hour.hour <= WINDOW_END_HOUR:
        return next_hour
    target = dt.replace(hour=WINDOW_START_HOUR, minute=0, second=0, microsecond=0)
    if target <= dt:
        target = target + timedelta(days=1)
    return target


def sleep_until(target: datetime, now_fn=now_stockholm, stop=_stop) -> bool:
    """Wait until wall-clock time reaches target. Returns True if stopped."""
    while True:
        remaining = (target - now_fn()).total_seconds()
        if remaining <= 0:
            return False
        if stop.wait(min(remaining, MAX_WAIT_CHUNK_S)):
            return True


def read_last_fetch_date() -> date | None:
    if not STATE_FILE.exists():
        return None
    raw = STATE_FILE.read_text(encoding="utf-8").strip()
    try:
        return datetime.strptime(raw, "%Y-%m-%d").date()
    except ValueError:
        log.warning("Cannot parse %r in %s — treating as no prior fetch", raw, STATE_FILE)
        return None


def write_last_fetch_date(d: date) -> None:
    STATE_FILE.write_text(d.isoformat(), encoding="utf-8")


def compute_window(today: date, last_fetch: date | None) -> tuple[str, int]:
    """Mirror task_fetch_bookings_windows.ps1: start = last_fetch - 1 day,
    days = (today - start).days + 1. First-ever run uses today - 2 days."""
    if last_fetch is None:
        last_fetch = today - timedelta(days=2)
    start = last_fetch - timedelta(days=1)
    days = max(1, (today - start).days + 1)
    return start.isoformat(), days


def run_subprocess(cmd: list[str], label: str) -> int:
    log.info("[%s] running: %s", label, " ".join(cmd))
    try:
        result = subprocess.run(
            cmd,
            cwd=str(APP_DIR),
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError as e:
        log.error("[%s] cannot launch: %s", label, e)
        return 127

    for line in result.stdout.splitlines():
        log.info("[%s] %s", label, line)
    for line in result.stderr.splitlines():
        log.warning("[%s] %s", label, line)
    log.info("[%s] exit=%d", label, result.returncode)
    return result.returncode


def fetch_bookings(start_date_str: str, days: int) -> int:
    return run_subprocess(
        [
            sys.executable,
            "fetch_bookings.py",
            "--date", start_date_str,
            "--days", str(days),
            "--stats",
        ],
        "fetch_bookings",
    )


def fetch_entities() -> int:
    return run_subprocess(
        [sys.executable, "fetch_entities.py", "--stats"],
        "fetch_entities",
    )


def refresh_hour_slots() -> int:
    log.info("[refresh_bi] REFRESH MATERIALIZED VIEW bi.v_hour_slots")
    try:
        conn = psycopg2.connect(
            host=os.environ["POSTGRES_HOST"],
            port=int(os.environ.get("POSTGRES_PORT", "5432")),
            dbname=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
        )
        conn.autocommit = True
        try:
            with conn.cursor() as cur:
                cur.execute("REFRESH MATERIALIZED VIEW bi.v_hour_slots")
        finally:
            conn.close()
        log.info("[refresh_bi] done")
        return 0
    except Exception as e:
        log.error("[refresh_bi] failed: %s", e)
        return 1


def run_iteration() -> bool:
    started = now_stockholm()
    log.info("=" * 60)
    log.info("Iteration started at %s", started.isoformat(timespec="seconds"))

    today = started.date()
    last_fetch = read_last_fetch_date()
    start_date_str, days = compute_window(today, last_fetch)
    log.info(
        "Last fetch: %s — fetching --date %s --days %d",
        last_fetch.isoformat() if last_fetch else "(never)",
        start_date_str,
        days,
    )

    # Entities first, so bookings on newly added resources join in this run.
    rc_entities = fetch_entities()
    rc_bookings = fetch_bookings(start_date_str, days)
    rc_refresh = refresh_hour_slots()

    duration = (now_stockholm() - started).total_seconds()
    success = rc_bookings == 0 and rc_entities == 0 and rc_refresh == 0

    if success:
        write_last_fetch_date(today)
        log.info("Iteration succeeded in %.1fs — state updated to %s", duration, today.isoformat())
    else:
        log.error(
            "Iteration failed (entities=%d, bookings=%d, refresh=%d) in %.1fs — state NOT updated",
            rc_entities, rc_bookings, rc_refresh, duration,
        )

    if duration > 50 * 60:
        log.warning("Iteration took %.1f minutes — exceeds soft 50-minute budget", duration / 60)

    return success


def _handle_signal(signum, _frame):
    log.info("Received signal %d — shutting down gracefully", signum)
    _stop.set()


def main_loop() -> None:
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    log.info(
        "Awaio scheduler started — window %02d:00–%02d:00 Europe/Stockholm",
        WINDOW_START_HOUR, WINDOW_END_HOUR,
    )

    now = now_stockholm()
    if in_window(now):
        log.info("Currently in window (%s) — running immediately", now.isoformat(timespec="seconds"))
        try:
            run_iteration()
        except Exception:
            log.exception("Unexpected error in initial iteration")
    else:
        log.info("Currently outside window (%s) — waiting", now.isoformat(timespec="seconds"))

    while not _stop.is_set():
        now = now_stockholm()
        nxt = next_run_time(now)
        wait_s = max(1.0, (nxt - now).total_seconds())
        log.info("Sleeping %.0fs until %s", wait_s, nxt.isoformat(timespec="seconds"))
        if sleep_until(nxt):
            break
        try:
            run_iteration()
        except Exception:
            log.exception("Unexpected error in iteration")

    log.info("Scheduler exited cleanly")


if __name__ == "__main__":
    main_loop()
