#!/usr/bin/env python3
"""FinanceCanvas HTTP acceptance test using synthetic data only.

Required environment:
  FINANCECANVAS_API_URL
  FINANCECANVAS_BOOTSTRAP_API_KEY

The bootstrap key needs admin permission. The script creates a temporary
workspace-scoped key, exercises the controlled API, and erases the synthetic
workspace at the end.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
import uuid

API_URL = os.environ.get("FINANCECANVAS_API_URL", "").rstrip("/")
BOOTSTRAP_KEY = os.environ.get("FINANCECANVAS_BOOTSTRAP_API_KEY", "")

class ApiError(RuntimeError):
    pass

def call(key: str, operation: str, payload: dict | None = None, expected=(200,)) -> dict:
    body = json.dumps({"operation": operation, "payload": payload or {}}).encode()
    req = urllib.request.Request(
        API_URL,
        data=body,
        method="POST",
        headers={
            "content-type": "application/json",
            "authorization": f"Bearer {key}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            data = json.loads(response.read().decode())
            if response.status not in expected:
                raise ApiError(f"{operation}: unexpected HTTP {response.status}: {data}")
            return data
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")
        try:
            data = json.loads(raw)
        except Exception:
            data = {"raw": raw}
        if exc.code in expected:
            return data
        raise ApiError(f"{operation}: HTTP {exc.code}: {data}") from exc

def require(condition: bool, message: str) -> None:
    if not condition:
        raise ApiError(message)

def main() -> int:
    if not API_URL or not BOOTSTRAP_KEY:
        print(
            "Set FINANCECANVAS_API_URL and FINANCECANVAS_BOOTSTRAP_API_KEY.",
            file=sys.stderr,
        )
        return 2

    suffix = uuid.uuid4().hex[:10]
    workspace_id = None
    runtime_key = None

    try:
        init = call(
            BOOTSTRAP_KEY,
            "initialize_workspace",
            {
                "name": f"__FinanceCanvas Acceptance {suffix}__",
                "base_currency": "INR",
                "first_profile_name": "Synthetic User",
                "use_default": False,
            },
        )
        workspace_id = init["workspace"]["id"]
        profile_id = init["profile"]["id"]

        generated = call(
            BOOTSTRAP_KEY,
            "create_api_key",
            {
                "workspace_id": workspace_id,
                "label": f"acceptance-{suffix}",
                "scopes": ["read", "write", "watch", "export"],
            },
        )
        runtime_key = generated["api_key"]

        account = call(
            runtime_key,
            "create_account",
            {
                "workspace_id": workspace_id,
                "name": "Synthetic XYZ Bank",
                "account_type": "bank",
                "currency": "INR",
                "identifier_last4": "0001",
                "current_balance": 850,
                "balance_as_of": "2026-03-20",
            },
        )["account"]
        account_id = account["id"]

        call(
            runtime_key,
            "create_record",
            {
                "workspace_id": workspace_id,
                "table": "account_owners",
                "record": {
                    "account_id": account_id,
                    "profile_id": profile_id,
                    "ownership_percent": 100,
                    "is_primary": True,
                },
            },
        )

        source_hash = ("a" * 54) + suffix[:10]
        source_hash = source_hash[:64].ljust(64, "a")

        imp = call(
            runtime_key,
            "create_record",
            {
                "workspace_id": workspace_id,
                "table": "imports",
                "record": {
                    "profile_id": profile_id,
                    "account_id": account_id,
                    "source_type": "synthetic",
                    "original_filename": "synthetic-march-2026.txt",
                    "source_hash": source_hash,
                    "statement_start": "2026-03-01",
                    "statement_end": "2026-03-31",
                    "status": "confirmed",
                    "reconciliation_status": "passed",
                    "reconciliation_difference": 0,
                },
            },
        )["record"]
        import_id = imp["id"]

        call(
            runtime_key,
            "create_record",
            {
                "workspace_id": workspace_id,
                "table": "account_balances",
                "record": {
                    "account_id": account_id,
                    "import_id": import_id,
                    "balance_date": "2026-03-01",
                    "balance": 1000,
                    "currency": "INR",
                    "balance_type": "opening",
                    "confirmed": True,
                },
            },
        )

        transactions = [
            {
                "client_id": "t1",
                "profile_id": profile_id,
                "account_id": account_id,
                "import_id": import_id,
                "posted_date": "2026-03-05",
                "amount": 100,
                "currency": "INR",
                "direction": "debit",
                "raw_description": "SYNTHETIC GROCER",
                "merchant_normalized": "Synthetic Grocer",
                "category": "Groceries",
                "balance_after": 900,
                "source_sequence": 1,
            },
            {
                "client_id": "t2",
                "profile_id": profile_id,
                "account_id": account_id,
                "import_id": import_id,
                "posted_date": "2026-03-10",
                "amount": 500,
                "currency": "INR",
                "direction": "credit",
                "raw_description": "SYNTHETIC SALARY",
                "merchant_normalized": "Synthetic Employer",
                "category": "Salary/Professional Income",
                "balance_after": 1400,
                "source_sequence": 2,
            },
            {
                "client_id": "t3",
                "profile_id": profile_id,
                "account_id": account_id,
                "import_id": import_id,
                "posted_date": "2026-03-15",
                "amount": 200,
                "currency": "INR",
                "direction": "debit",
                "raw_description": "SYNTHETIC RENT",
                "merchant_normalized": "Synthetic Rent",
                "category": "Housing",
                "balance_after": 1200,
                "source_sequence": 3,
            },
            {
                "client_id": "t4",
                "profile_id": profile_id,
                "account_id": account_id,
                "import_id": import_id,
                "posted_date": "2026-03-15",
                "amount": 50,
                "currency": "INR",
                "direction": "debit",
                "raw_description": "SYNTHETIC CAFE",
                "merchant_normalized": "Synthetic Cafe",
                "category": "Dining",
                "balance_after": 1150,
                "source_sequence": 4,
            },
            {
                "client_id": "t5",
                "profile_id": profile_id,
                "account_id": account_id,
                "import_id": import_id,
                "posted_date": "2026-03-20",
                "amount": 300,
                "currency": "INR",
                "direction": "debit",
                "raw_description": "SYNTHETIC UTILITIES",
                "merchant_normalized": "Synthetic Utilities",
                "category": "Utilities",
                "balance_after": 850,
                "source_sequence": 5,
            },
        ]

        preview = call(
            runtime_key,
            "preview_transaction_import",
            {"workspace_id": workspace_id, "transactions": transactions},
        )
        require(all(x["status"] == "ready" for x in preview["results"]), "Initial preview was not fully ready")

        committed = call(
            runtime_key,
            "commit_transactions",
            {
                "workspace_id": workspace_id,
                "transactions": transactions,
                "final_confirmation": True,
                "duplicate_resolutions": [],
            },
        )
        require(committed.get("atomic_commit") is True, "Commit did not report atomic_commit=true")
        require(len(committed.get("inserted", [])) == 5, "Expected 5 inserted transactions")

        balance = call(
            runtime_key,
            "get_historical_balance",
            {"workspace_id": workspace_id, "account_id": account_id, "date": "2026-03-15"},
        )
        require(float(balance["balance"]) == 1150.0, f"Unexpected historical balance: {balance}")
        require(balance["method"] == "statement_running_balance", f"Unexpected balance method: {balance}")

        duplicate_preview = call(
            runtime_key,
            "preview_transaction_import",
            {"workspace_id": workspace_id, "transactions": [transactions[0]]},
        )
        require(duplicate_preview["results"][0]["status"] == "exact_duplicate", "Exact duplicate was not detected")

        hash_check = call(
            runtime_key,
            "check_import_hash",
            {"workspace_id": workspace_id, "source_hash": source_hash},
        )
        require(hash_check["duplicate_found"] is True, "Source-document hash duplicate was not found")

        call(
            runtime_key,
            "upsert_financial_preference",
            {
                "workspace_id": workspace_id,
                "profile_id": profile_id,
                "preference_key": "emergency_fund_months",
                "preference_group": "planning",
                "preference_value": 6,
            },
        )
        call(
            runtime_key,
            "record_recommendation",
            {
                "workspace_id": workspace_id,
                "profile_id": profile_id,
                "recommendation_type": "synthetic_test",
                "title": "Synthetic recommendation",
                "summary": "Synthetic acceptance-test recommendation.",
                "evidence": {"synthetic": True},
                "assumptions": {"synthetic": True},
                "confidence": 0.9,
            },
        )

        watch = call(
            runtime_key,
            "create_watch_rule",
            {
                "workspace_id": workspace_id,
                "profile_id": profile_id,
                "name": "Synthetic high-value check",
                "rule_type": "high_value",
                "severity": "warning",
                "configuration": {"threshold_amount": 150},
            },
        )
        require(bool(watch["watch_rule"]["id"]), "Watch rule was not created")

        watch_result = call(
            runtime_key,
            "run_watch_checks",
            {"workspace_id": workspace_id, "lookback_days": 365},
        )
        require(watch_result["findings_generated"] >= 1, "Watch produced no findings")

        evidence = call(
            runtime_key,
            "get_evidence_bundle",
            {
                "workspace_id": workspace_id,
                "account_id": account_id,
                "from_date": "2026-03-01",
                "to_date": "2026-03-31",
            },
        )
        require(evidence["included"]["transaction_count"] == 5, "Evidence bundle did not include all 5 transactions")

        timeline = call(
            runtime_key,
            "get_financial_timeline",
            {
                "workspace_id": workspace_id,
                "from_date": "2026-03-01",
                "to_date": "2026-03-31",
            },
        )
        require(len(timeline["events"]) >= 5, "Timeline did not include expected events")

        graph = call(runtime_key, "get_ownership_graph", {"workspace_id": workspace_id})
        require(any(e["type"] == "owns_account" for e in graph["edges"]), "Ownership graph missing account edge")

        pending = call(
            runtime_key,
            "request_edit",
            {
                "workspace_id": workspace_id,
                "table": "accounts",
                "record_id": account_id,
                "patch": {"name": "Synthetic XYZ Bank Edited"},
                "reason": "Acceptance test",
            },
        )
        op_id = pending["pending_operation"]["id"]
        edited = call(
            runtime_key,
            "confirm_pending_operation",
            {"workspace_id": workspace_id, "operation_id": op_id, "confirmed": True},
        )
        require(edited["record"]["name"] == "Synthetic XYZ Bank Edited", "Two-step edit did not apply")

        exported_json = call(runtime_key, "export_workspace_json", {"workspace_id": workspace_id})
        require(exported_json["workspace_id"] == workspace_id, "JSON export failed")

        exported_csv = call(runtime_key, "export_workspace_csv", {"workspace_id": workspace_id})
        require("transactions.csv" in exported_csv["files"], "CSV export missing transactions.csv")

        erasure = call(
            runtime_key,
            "request_workspace_erasure",
            {
                "workspace_id": workspace_id,
                "reason": "Synthetic acceptance test cleanup",
            },
        )
        erase_id = erasure["pending_operation"]["id"]
        result = call(
            runtime_key,
            "confirm_workspace_erasure",
            {
                "workspace_id": workspace_id,
                "operation_id": erase_id,
                "confirmed": True,
            },
        )
        require(result.get("erased") is True, "Workspace erasure did not complete")
        workspace_id = None

        print("FinanceCanvas HTTP acceptance test: PASS")
        print("Verified atomic import, historical balance, duplicate detection, hash protection,")
        print("memory/recommendation persistence, Watch, evidence, timeline, ownership, edit, export and erasure.")
        return 0

    finally:
        if workspace_id:
            try:
                erasure = call(
                    runtime_key or BOOTSTRAP_KEY,
                    "request_workspace_erasure",
                    {
                        "workspace_id": workspace_id,
                        "reason": "Acceptance test emergency cleanup",
                    },
                )
                call(
                    runtime_key or BOOTSTRAP_KEY,
                    "confirm_workspace_erasure",
                    {
                        "workspace_id": workspace_id,
                        "operation_id": erasure["pending_operation"]["id"],
                        "confirmed": True,
                    },
                )
            except Exception as exc:
                print(f"WARNING: automatic cleanup failed: {exc}", file=sys.stderr)
                print(f"Delete synthetic workspace manually: {workspace_id}", file=sys.stderr)

if __name__ == "__main__":
    raise SystemExit(main())
