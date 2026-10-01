#!/usr/bin/env python3
"""Build a portable FinanceCanvas Agent Skill bundle for upload-based hosts.

Output: dist/financecanvas.zip
The archive contains exactly one root skill directory named "financecanvas".
"""
from __future__ import annotations

from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist" / "financecanvas.zip"

ROOT_FILES = {
    "SKILL.md",
    "LICENSE",
    "NOTICE",
    "README.md",
    "SECURITY.md",
    "COMPLIANCE.md",
    "PRIVACY.md",
    "DATA_RETENTION.md",
    "THREAT_MODEL.md",
    "INCIDENT_RESPONSE.md",
    "ADVANCED_SETUP.md",
}
ROOT_DIRS = {"references", "scripts", "supabase"}
EXCLUDE_NAMES = {"__pycache__", ".DS_Store"}
EXCLUDE_FILES = {"scripts/package_skill.py"}

def include(path: Path) -> bool:
    rel = path.relative_to(ROOT).as_posix()
    if rel in ROOT_FILES:
        return True
    if rel in EXCLUDE_FILES:
        return False
    parts = path.relative_to(ROOT).parts
    if not parts or parts[0] not in ROOT_DIRS:
        return False
    if any(p in EXCLUDE_NAMES for p in parts):
        return False
    if path.suffix in {".pyc", ".pyo"}:
        return False
    return True

def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in ROOT.rglob("*") if p.is_file() and include(p))
    if not (ROOT / "SKILL.md").exists():
        raise SystemExit("SKILL.md not found")
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in files:
            rel = path.relative_to(ROOT)
            zf.write(path, Path("financecanvas") / rel)
    print(OUT)
    print(f"files={len(files)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
