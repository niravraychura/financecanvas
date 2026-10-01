#!/usr/bin/env python3
"""Minimal FinanceCanvas HTTP client using Python's standard library."""
from __future__ import annotations
import json, os, urllib.error, urllib.request
from typing import Any

class FinanceCanvasClient:
    def __init__(self, api_url: str | None = None, api_key: str | None = None):
        self.api_url = (api_url or os.environ.get("FINANCECANVAS_API_URL", "")).rstrip("/")
        self.api_key = api_key or os.environ.get("FINANCECANVAS_API_KEY", "")
        if not self.api_url or not self.api_key:
            raise RuntimeError("Set FINANCECANVAS_API_URL and FINANCECANVAS_API_KEY outside the repository.")

    def call(self, operation: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        body = json.dumps({"operation": operation, "payload": payload or {}}).encode()
        req = urllib.request.Request(self.api_url, data=body, method="POST", headers={
            "content-type": "application/json",
            "authorization": f"Bearer {self.api_key}",
        })
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")
            raise RuntimeError(f"FinanceCanvas API error {exc.code}: {detail}") from exc

if __name__ == "__main__":
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument("operation")
    parser.add_argument("payload", nargs="?", default="{}")
    args=parser.parse_args()
    print(json.dumps(FinanceCanvasClient().call(args.operation,json.loads(args.payload)),indent=2,sort_keys=True))
