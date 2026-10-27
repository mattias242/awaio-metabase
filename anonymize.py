"""
User-ID anonymization for Awaio booking system.

Pseudonymizes Awaio user_ids with HMAC-SHA256 keyed by a secret salt.
The same awaio_user_id always maps to the same anonymous id (longitudinal
analysis works), but recovering the awaio_user_id from the stored hash is
computationally infeasible without knowing the salt.

No mapping table is persisted: hashing is stateless and deterministic.
"""

import hashlib
import hmac
import json
import os
from typing import Optional, Tuple


ANON_ID_LENGTH = 24  # hex chars → 96 bits of entropy; collision-safe for millions of users


def hash_user_id(awaio_user_id: str, salt: str) -> str:
    """
    Return a deterministic pseudonym for an Awaio user_id using HMAC-SHA256.

    Args:
        awaio_user_id: The original user_id as returned by the Awaio API.
        salt: A secret, high-entropy string. Must be non-empty.

    Returns:
        First 24 hex chars of HMAC-SHA256(salt, awaio_user_id).

    Raises:
        ValueError: If awaio_user_id or salt is empty.
    """
    if not awaio_user_id:
        raise ValueError("awaio_user_id must be non-empty")
    if not salt:
        raise ValueError("salt must be non-empty")
    mac = hmac.new(salt.encode("utf-8"), awaio_user_id.encode("utf-8"), hashlib.sha256)
    return mac.hexdigest()[:ANON_ID_LENGTH]


def should_anonymize() -> bool:
    """True when ANONYMIZE_USERS env var is truthy."""
    return os.getenv("ANONYMIZE_USERS", "false").lower() in ("true", "1", "yes")


def load_swedish_names() -> dict:
    names_file = os.path.join(os.path.dirname(__file__), "swedish_names.json")
    try:
        with open(names_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"male_names": [], "female_names": [], "surnames": []}


def generate_swedish_display_name(anon_id: str) -> str:
    """
    Derive a stable Swedish display name from an already-hashed anonymous id.

    The input must be the hashed id (not the raw Awaio user_id), so the display
    name leaks no information about the original identity.
    """
    names = load_swedish_names()
    # Re-hash the anon_id to get name-selection bits independent of the id hash
    digest = hashlib.sha256(anon_id.encode("utf-8")).hexdigest()
    n = int(digest[:16], 16)

    is_male = n % 2 == 0
    first_names = names["male_names"] if is_male else names["female_names"]
    first_name = first_names[(n >> 8) % len(first_names)] if first_names else "Person"

    surnames = names["surnames"]
    surname = surnames[(n >> 16) % len(surnames)] if surnames else f"User{anon_id[:6].upper()}"

    return f"{first_name} {surname}"


class DatabaseAnonymizer:
    """
    Stateless pseudonymizer for users.id and FK references.

    The class name is kept for backwards compatibility with the previous
    implementation, but there is no longer any mapping table — the `cursor`
    parameter is unused and kept only so callers don't need to change.
    """

    def __init__(self, cursor, salt: str, prefix: str = "user"):
        if not salt:
            raise ValueError(
                "ANONYMIZE_SALT is required when anonymization is enabled. "
                "Generate one with: openssl rand -hex 32"
            )
        self.cursor = cursor  # unused, retained for API compat
        self.salt = salt
        self.prefix = prefix

    def anonymize_id(self, awaio_user_id: str) -> str:
        return hash_user_id(awaio_user_id, self.salt)

    def identity_for(self, awaio_user_id: str) -> Tuple[str, str, str]:
        """
        Return (anon_id, anon_email, display_name) for an Awaio user_id.

        anon_email and display_name are derived from the *hashed* id so they
        cannot be used to recover the original.
        """
        anon_id = self.anonymize_id(awaio_user_id)
        anon_email = f"{self.prefix}_{anon_id[:12]}@anonymous.local"
        display_name = generate_swedish_display_name(anon_id)
        return anon_id, anon_email, display_name
