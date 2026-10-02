# Install FinanceCanvas

## One command

Install FinanceCanvas globally into all Agent-Skills-compatible local agents detected on your machine:

```bash
npx --yes github:niravraychura/financecanvas
```

That is the recommended install command.

It installs FinanceCanvas into:
- the universal Agent Skills directory;
- Claude Code;
- Cursor;
- OpenAI Codex;
- Gemini CLI.

Alternative using the open Agent Skills CLI:

```bash
npx skills add niravraychura/financecanvas --all -g -y
```

After installation, start your AI agent and say:

```text
Initialize FinanceCanvas.
```

FinanceCanvas will detect the available environment and guide the first-time data-layer setup only if you want persistent finance storage.

### Persistent storage: each user brings their own Supabase

The installer does **not** connect users to the author's Supabase project.

If your AI host already has an authorized Supabase connector:

1. FinanceCanvas lists the projects available to **that user**.
2. If there is one suitable project, it uses it; if there are several, it asks which one should store FinanceCanvas data.
3. It checks whether FinanceCanvas is installed in that selected project.
4. With confirmation, it can install/upgrade the bundled FinanceCanvas schema there.
5. It initializes the user's workspace through the private connector bootstrap routine.

No Supabase admin `.env` or copied service key is needed when the connector is already authorized.

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

Run the same install command again:

```bash
npx --yes github:niravraychura/financecanvas
```

## Remove

```bash
npx --yes github:niravraychura/financecanvas --uninstall
```

## Advanced/self-hosted setup

You normally do not need to clone the repository just to install the Skill.

For Supabase CLI deployment, external API clients, acceptance testing, or contributor setup, see [ADVANCED_SETUP.md](ADVANCED_SETUP.md).

## Reinstalling the updated Skill

```bash
npx --yes --prefer-online github:niravraychura/financecanvas#main
```

Use your existing project/workspace during initialization. Follow [references/UPGRADING.md](references/UPGRADING.md) for missing database migrations; reinstalling the Skill does not erase or migrate data.
