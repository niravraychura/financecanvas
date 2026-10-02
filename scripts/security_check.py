#!/usr/bin/env python3
"""FinanceCanvas repository security gate.

Run after every change. This is intentionally conservative because the repository
is public and the project handles financial data.
"""
from __future__ import annotations

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

REQUIRED_FILES = {
    "README.md",
    "SKILL.md",
    "SECURITY.md",
    "SECURITY_CHECKLIST.md",
    "COMPLIANCE.md",
    "PRIVACY.md",
    "THREAT_MODEL.md",
    "DATA_RETENTION.md",
    "INCIDENT_RESPONSE.md",
    "RELEASE_CHECKLIST.md",
    "CONTRIBUTING.md",
    "AGENTS.md",
    "ROADMAP.md",
    "package.json",
    "skills.sh.json",
    "bin/install.mjs",
    "LICENSE",
    "NOTICE",
    "CITATION.cff",
    "THIRD_PARTY.md",
    "REPOSITORY_METADATA.md",
    "ADVANCED_SETUP.md",
    "INSTALL.md",
    "QUICKSTART.md",
    "ACCEPTANCE_TEST.md",
    "scripts/generate_api_key.py",
    "scripts/acceptance_test.py",
    "scripts/package_skill.py",
    ".github/workflows/acceptance.yml",
    ".github/workflows/skill-install.yml",
    "references/CALCULATION_RULES.md",
    "references/CATEGORIZATION_RULES.md",
    "references/IMPORT_RULES.md",
    "references/API_OPERATIONS.md",
    "references/DATA_MODEL.md",
    "references/WATCH_RULES.md",
    "references/HISTORY_AND_EVIDENCE.md",
    "references/MEMORY_AND_RECOMMENDATIONS.md",
    "references/FINANCIAL_HEALTH_RULES.md",
    "references/SCENARIO_RULES.md",
    "references/CONNECTOR_MODE.md",
    "supabase/functions/financecanvas-api/index.ts",
    "supabase/migrations/20261002063000_financecanvas_v01_connector_bootstrap.sql",
}

FORBIDDEN_SUFFIXES = {
    ".pdf", ".jpg", ".jpeg", ".png", ".heic",
    ".xls", ".xlsx", ".sqlite", ".sqlite3", ".db",
    ".pem", ".p12", ".pfx",
}

FORBIDDEN_BASENAMES = {
    ".env",
    "credentials.json",
    "service-account.json",
}

HARDCODED_SUPABASE_PROJECT_URL = re.compile(
    r"https://(?!YOUR_PROJECT_REF|your-project-ref)[a-z0-9]{20}\.supabase\.co",
    re.IGNORECASE,
)

SECRET_PATTERNS = [
    ("Supabase secret key", re.compile(r"sb_secret_[A-Za-z0-9._-]{16,}")),
    ("FinanceCanvas runtime key", re.compile(r"fc_[A-Za-z0-9_-]{24,}")),
    ("private key block", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("non-empty FinanceCanvas key assignment", re.compile(r"FINANCECANVAS_API_KEY\s*=\s*[^\s#]{20,}")),
    ("non-empty Supabase server-key assignment", re.compile(r"SUPABASE_SERVICE_ROLE_KEY\s*=\s*[^\s#]{20,}")),
]

CANONICAL_INSTALL = "npx --yes github:niravraychura/financecanvas"

REQUIRED_SKILL_PHRASES = [
    "Exact duplicates must never be silently inserted",
    "permanent deletions",
    "critical secrets",
    "controlled FinanceCanvas API",
    "BYO Supabase",
    "financecanvas_private.initialize_workspace",
    "Sensitive-data warning",
]

REQUIRED_API_MARKERS = [
    "requiredScope",
    "CRITICAL_SECRET_DETECTED",
    "HIGH_RISK_IDENTIFIER_DETECTED",
    "request_workspace_erasure",
    "confirm_workspace_erasure",
    "export_workspace_csv",
    "base_fingerprint",
    "assertIdsInWorkspace",
    "CROSS_WORKSPACE_REFERENCE",
    "SENSITIVE_FIELD_NOT_ALLOWED",
    "financecanvas_commit_transaction_batch",
    "check_import_hash",
    "DUPLICATE_SOURCE_DOCUMENT",
    "get_historical_balance",
    "balance_after",
    "source_sequence",
    "detect_recurring_patterns",
    "get_financial_timeline",
    "get_ownership_graph",
    "get_evidence_bundle",
    "upsert_financial_preference",
    "record_recommendation",
    "subscription_change",
    "spending_anomaly",
    "loan_emi_change",
    "annual_fee_watch",
    "reconciliation_watch",
    "allocation_drift",
]

def tracked_files() -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "ls-files"], cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        )
        return [line.strip() for line in out.splitlines() if line.strip()]
    except Exception:
        return [
            str(p.relative_to(ROOT))
            for p in ROOT.rglob("*")
            if p.is_file() and ".git" not in p.parts
        ]

def text_of(path: pathlib.Path) -> str:
    try:
        if path.stat().st_size > 2_000_000:
            return ""
        return path.read_text("utf-8")
    except (UnicodeDecodeError, OSError):
        return ""

def main() -> int:
    errors: list[str] = []
    files = tracked_files()
    file_set = set(files)

    for required in sorted(REQUIRED_FILES):
        if required not in file_set and not (ROOT / required).exists():
            errors.append(f"Missing required security/governance file: {required}")

    for rel in files:
        p = pathlib.Path(rel)
        name = p.name.lower()
        suffix = p.suffix.lower()
        if name in FORBIDDEN_BASENAMES:
            errors.append(f"Forbidden tracked secret file: {rel}")
        if suffix in FORBIDDEN_SUFFIXES:
            errors.append(f"Forbidden tracked sensitive/binary file type: {rel}")

        content = text_of(ROOT / rel)
        if not content:
            continue
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(content):
                errors.append(f"Potential {label} found in tracked file: {rel}")
        if HARDCODED_SUPABASE_PROJECT_URL.search(content):
            errors.append(f"Hardcoded real-looking Supabase project URL found in tracked file: {rel}")

    readme = text_of(ROOT / "README.md")
    install_doc = text_of(ROOT / "INSTALL.md")
    license_text = text_of(ROOT / "LICENSE")

    if CANONICAL_INSTALL not in readme or CANONICAL_INSTALL not in install_doc:
        errors.append("README.md and INSTALL.md must contain the canonical one-command installer")
    if "Apache License" not in license_text or "Version 2.0" not in license_text:
        errors.append("LICENSE must contain Apache License 2.0")
    skills_manifest = text_of(ROOT / "skills.sh.json")
    if '"financecanvas"' not in skills_manifest or 'skills.sh.schema.json' not in skills_manifest:
        errors.append("skills.sh manifest must reference the financecanvas skill and published schema")

    package_json = text_of(ROOT / "package.json")
    if '"license": "Apache-2.0"' not in package_json:
        errors.append("package.json must declare Apache-2.0")
    installer = text_of(ROOT / "bin/install.mjs")
    for marker in [".agents", ".claude", ".cursor", ".codex", ".gemini", "No Supabase/admin secret"]:
        if marker not in installer:
            errors.append(f"Installer missing required portability/security marker: {marker}")

    skill = text_of(ROOT / "SKILL.md")
    if "license: Apache-2.0" not in skill:
        errors.append("SKILL.md must declare Apache-2.0 in Agent Skills frontmatter")

    for phrase in REQUIRED_SKILL_PHRASES:
        if phrase.lower() not in skill.lower():
            errors.append(f"SKILL.md missing required guardrail phrase: {phrase}")

    connector_mode = text_of(ROOT / "references/CONNECTOR_MODE.md")
    for marker in ["bring-your-own-Supabase", "financecanvas_private.connector_status", "financecanvas_private.initialize_workspace", "Never hardcode"]:
        if marker.lower() not in connector_mode.lower():
            errors.append(f"CONNECTOR_MODE.md missing required portability marker: {marker}")

    connector_bootstrap = text_of(ROOT / "supabase/migrations/20261002063000_financecanvas_v01_connector_bootstrap.sql")
    for marker in ["create schema if not exists financecanvas_private", "security invoker", "connector_status", "initialize_workspace", "revoke all on function"]:
        if marker.lower() not in connector_bootstrap.lower():
            errors.append(f"Connector bootstrap migration missing security marker: {marker}")

    api = text_of(ROOT / "supabase/functions/financecanvas-api/index.ts")
    for marker in REQUIRED_API_MARKERS:
        if marker not in api:
            errors.append(f"FinanceCanvas API missing required security marker: {marker}")
    if 'npm:@supabase/supabase-js@2"' in api:
        errors.append("FinanceCanvas API uses a floating Supabase JS major version instead of an exact reviewed version")

    for rel in files:
        if not rel.startswith("supabase/migrations/") or not rel.endswith(".sql"):
            continue
        content = text_of(ROOT / rel)
        if re.search(r"\bgrant\b[\s\S]{0,200}\bto\s+(?:anon|authenticated)\b", content, re.I):
            errors.append(f"Migration appears to grant direct client access: {rel}")

    if errors:
        print("FinanceCanvas security gate: FAILED", file=sys.stderr)
        for e in errors:
            print(f" - {e}", file=sys.stderr)
        return 1

    print("FinanceCanvas security gate: PASS")
    print(f"Checked {len(files)} tracked files and required runtime guardrails.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
