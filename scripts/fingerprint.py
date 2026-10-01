#!/usr/bin/env python3
"""Deterministic transaction fingerprints used for client-side validation/tests."""
from __future__ import annotations
import hashlib, json, re
from decimal import Decimal
from typing import Any, Mapping

def _norm_text(value: Any) -> str:
    text = "" if value is None else str(value)
    return re.sub(r"\s+", " ", text.strip().lower())

def _norm_amount(value: Any) -> str:
    return format(Decimal(str(value)).quantize(Decimal("0.01")), "f")

def transaction_fingerprint(record: Mapping[str, Any]) -> str:
    canonical = {
        "workspace_id": _norm_text(record.get("workspace_id")),
        "account_id": _norm_text(record.get("account_id")),
        "posted_date": _norm_text(record.get("posted_date")),
        "amount": _norm_amount(record.get("amount", "0")),
        "currency": _norm_text(record.get("currency") or "INR").upper(),
        "direction": _norm_text(record.get("direction")),
        "reference": _norm_text(record.get("reference")),
        "raw_description": _norm_text(record.get("raw_description")),
    }
    payload = json.dumps(canonical, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()

if __name__ == "__main__":
    import sys
    print(transaction_fingerprint(json.load(sys.stdin)))
