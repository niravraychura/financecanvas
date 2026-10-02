#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const home = homedir();

const args = new Set(process.argv.slice(2));
const uninstall = args.has("--uninstall");
const dryRun = args.has("--dry-run");

const claudeHome = process.env.CLAUDE_CONFIG_DIR?.trim() || join(home, ".claude");
const codexHome = process.env.CODEX_HOME?.trim() || join(home, ".codex");

const targets = [
  ["Agent Skills", join(home, ".agents", "skills", "financecanvas")],
  ["Claude Code", join(claudeHome, "skills", "financecanvas")],
  ["Cursor", join(home, ".cursor", "skills", "financecanvas")],
  ["OpenAI Codex", join(codexHome, "skills", "financecanvas")],
  ["Gemini CLI", join(home, ".gemini", "skills", "financecanvas")]
];

const rootFiles = [
  "SKILL.md",
  "LICENSE",
  "NOTICE",
  "README.md",
  "SECURITY.md",
  "SECURITY_CHECKLIST.md",
  "COMPLIANCE.md",
  "PRIVACY.md",
  "DATA_RETENTION.md",
  "THREAT_MODEL.md",
  "INCIDENT_RESPONSE.md",
  "ADVANCED_SETUP.md"
];

const rootDirs = ["references", "scripts", "supabase"];

function copySkill(target) {
  if (dryRun) return;
  rmSync(target, { recursive: true, force: true });
  mkdirSync(target, { recursive: true });
  for (const file of rootFiles) {
    const src = join(root, file);
    if (existsSync(src)) cpSync(src, join(target, file));
  }
  for (const dir of rootDirs) {
    const src = join(root, dir);
    if (existsSync(src)) cpSync(src, join(target, dir), { recursive: true });
  }
}

function removeSkill(target) {
  if (!dryRun) rmSync(target, { recursive: true, force: true });
}

console.log(uninstall ? "Removing FinanceCanvas skill..." : "Installing FinanceCanvas skill...");

for (const [name, target] of targets) {
  if (uninstall) removeSkill(target);
  else copySkill(target);
  console.log(`  ${dryRun ? "[dry-run] " : ""}${name}: ${target}`);
}

if (!uninstall) {
  console.log("");
  console.log("FinanceCanvas installed.");
  console.log('Open your agent and say: "Initialize FinanceCanvas."');
  console.log("");
  console.log("ChatGPT web uses its Skills upload UI rather than local skill folders.");
  console.log("To build an upload bundle from a clone of this repository, run:");
  console.log("  python scripts/package_skill.py");
}

console.log("");
console.log("No Supabase/admin secret was created or stored by this installer.");
