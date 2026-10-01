# Install FinanceCanvas

## One command

Install FinanceCanvas globally into all Agent-Skills-compatible local agents detected on your machine:

```bash
npx skills add niravraychura/financecanvas --all -g
```

That is the recommended install command.

It works with Agent Skills hosts supported by the `skills` CLI, including Claude Code, Cursor, Codex and many others.

After installation, start your AI agent and say:

```text
Initialize FinanceCanvas.
```

FinanceCanvas will detect the available environment and guide the first-time data-layer setup only if you want persistent finance storage.

## ChatGPT web

ChatGPT's current Skills experience installs skills through the ChatGPT UI rather than a local shell command.

Create an upload-ready FinanceCanvas bundle with:

```bash
python scripts/package_skill.py
```

Then in ChatGPT:

```text
Plugins → Skills → Create → Upload
```

Upload:

```text
dist/financecanvas.zip
```

## Update

```bash
npx skills update -g
```

## Remove

```bash
npx skills remove financecanvas -g
```

## Advanced/self-hosted setup

You normally do not need to clone the repository just to install the Skill.

For Supabase CLI deployment, external API clients, acceptance testing, or contributor setup, see [ADVANCED_SETUP.md](ADVANCED_SETUP.md).
