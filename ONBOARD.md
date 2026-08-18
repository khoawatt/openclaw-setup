# ONBOARD.md — Machine Briefing (read this FIRST on a fresh install)

> Purpose: a reinstalled/repurposed OpenClaw instance reads this file and
> immediately understands what this workstation is, what it runs, where
> things live, and how to help the operator. This is the "make me smart
> again" document.

## What this machine is

- **Host:** LAPTOP-G9ND0UM1 — WSL2 Ubuntu (user `audition`), Windows 11 host.
- **Role:** personal OpenClaw agent + OpenCode agent orchestrator.
- **Two independent subsystems:**
  1. **OpenCode tmux watcher (`ocw`)** — monitors feaon/qvak OpenCode agents.
  2. **Research/Search stack (`rc`)** — web search with provider chain + cache.
- Gateway: OpenClaw, systemd **user** service `openclaw-gateway.service`,
  port 18789, loopback bind. (WSL note: closing the last terminal stops the
  VM by default; reopening a terminal restores everything.)

## Projects (aliases are canonical — never remap)

| Alias | tmux target | Project | Purpose |
|---|---|---|---|
| `feaon` | `opencode-work:0.0` | `~/projects/personal/Feaon-ldp-v2` | main app (Supabase/Postgres backend) |
| `qvak` | `opencode-work:0.1` | `~/projects/personal/qvak-portfolio` | portfolio site (Next.js + i18n, CI, content workflows) |

Other dirs: `ai-os-v1.6`, `opencode-workflow`, `workflow-playbooks`.

## How to help / commands

- User chat words: `search <q>` (lightweight), `research <q>` (deep), `show <alias>`, `send <alias> <text>`.
- Watcher: `ocw status|show|send|monitor|start|stop|restart|health|logs`.
- Research: `rc status|provider|route|search|fetch|cache|set-provider|test`.
- qvak merges are **human-only**: `.opencode/scripts/merge-approved-pr.sh <PR>`.

## Operating rules (hard boundaries)

- **NEVER modify `~/.openclaw/watcher/` outside explicit user request** — it is
  a separate, safety-critial subsystem. Observer/relay only: no auto-typing,
  no auto-approving, no deciding for the user. `ocw send` requires explicit
  authorization and is sent literally (never reinterpreted).
- Don't touch other people's stuff via any agent without instruction;
  assistant is an observer in the OpenCode↔chat review loop.
- No sudo / no system package installs / no Windows Chrome CDP changes
  without explicit user approval.
- Secrets live only in `~/.openclaw/openclaw.json` (0600) and
  `~/.openclaw/watcher/conf/telegram.env` (0600). Never log/print them.
- Browser automation is currently UNAVAILABLE (missing WSL libs) and is NOT
  required for normal research — do not try to fix without approval.

## Layer summary (what each file does)

- `AGENTS.md` — workspace operating rules (this repo installs it).
- `SOUL.md` — persona. `IDENTITY.md` — name/avatar. `USER.md` — about the human.
- `TOOLS.md` — local notes: watcher aliases, rc stack, PATH quirks.
- `RESEARCH.md` — research/search stack operating rules (repo: `research/`).
- `memory/` + `MEMORY.md` — actual memories (chat logs, decisions). NOT in
  this repo — restore from your own private backup (see `scripts/backup-memory.sh`).

## Recovery checklist (OpenClaw broken → reinstall)

See `docs/recovery.md` for the full runbook. Short version:

1. Reinstall OpenClaw (or point it at this workspace copy).
2. `setup.sh` → regenerates `openclaw.json` (prompts secrets), installs
   watcher + research stack, installs this workspace pack.
3. Restore memory: run/point at your private memory backup.
4. Verify: `rc status`, `ocw status`, `openclaw config get tools.web.search.provider`.
5. Start tmux `opencode-work` session + `ocw start`; agents resume.

## Notes

- Timezone: Asia/Bangkok. Operator writes Vietnamese, casual ("m/tao").
- Current pending work lives in `memory/` + project repos/issues (qvak #17/#49 etc.) —
  do not guess; read before acting.