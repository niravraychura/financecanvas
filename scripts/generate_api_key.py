#!/usr/bin/env python3
"""Generate a FinanceCanvas API key locally.

The plaintext token is printed once for the operator to place in a client secret store.
Only the SHA-256 hash belongs in Supabase.
"""
from __future__ import annotations

import argparse
import hashlib
import secrets

VALID_SCOPES = {"read", "write", "watch", "export", "admin"}

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", default="financecanvas-runtime")
    parser.add_argument("--workspace-id", default=None)
    parser.add_argument("--scopes", default="read,write,watch,export")
    args = parser.parse_args()

    scopes = [s.strip() for s in args.scopes.split(",") if s.strip()]
    bad = [s for s in scopes if s not in VALID_SCOPES]
    if bad:
        raise SystemExit(f"Invalid scopes: {', '.join(bad)}")

    token = "fc_" + secrets.token_urlsafe(36)
    digest = hashlib.sha256(token.encode()).hexdigest()
    workspace_sql = "null" if not args.workspace_id else "'" + args.workspace_id.replace("'", "''") + "'::uuid"
    scopes_sql = "array[" + ",".join("'" + s + "'" for s in scopes) + "]::text[]"
    label = args.label.replace("'", "''")

    print("FinanceCanvas plaintext key (store securely; shown once):")
    print(token)
    print()
    print("SHA-256 hash:")
    print(digest)
    print()
    print("Run this SQL through the trusted owner/admin Supabase connection:")
    print(
        "insert into public.financecanvas_api_keys"
        "(label,key_hash,workspace_id,scopes,active) values("
        f"'{label}','{digest}',{workspace_sql},{scopes_sql},true);"
    )
    print()
    print("Never commit the plaintext key or paste it into repository files.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
