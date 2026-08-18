# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup: camera names and locations, SSH hosts and aliases, preferred TTS voices, speaker/room names, device nicknames, anything environment-specific.

## OpenCode tmux watcher (ocw) — my middleware role

**Setup:** tmux session `opencode-work` with two OpenCode agents. Watcher lives in `~/.openclaw/watcher/` (pure shell, zero LLM). I run `ocw` CLI commands to inspect/relay; the daemon monitors and pushes Telegram notifications directly via Bot API (no model calls).

**PATH note (fixed 2026-08-18):** `ocw` is resolvable as a bare command via wrapper at `~/.local/bin/ocw` (execs `~/.openclaw/watcher/ocw`). A plain symlink breaks the script (it sources `ocw-lib.sh` via `dirname $0`) — keep it a wrapper. Bare `ocw status` now exits 0; never run it with a workdir trick or full path twice.

**Canonical aliases (never remap silently):**
- `feaon` = `opencode-work:0.0` → `/home/audition/projects/personal/Feaon-ldp-v2`
- `qvak` = `opencode-work:0.1` → `/home/audition/projects/personal/qvak-portfolio`

**Commands I support on user request (via `ocw`):**
- `ocw status [alias]` — monitoring mode + per-pane state
- `ocw show <alias> [lines]` — recent output tail
- `ocw send <alias> <text>` — explicit-authorized relay (literal `send-keys -l` + Enter; NEVER reinterpret)
- `ocw monitor status|on [dur]|off|auto` — global mode (AUTO default)
- `ocw monitor <alias> on|off` — per-pane toggle
- `ocw start|stop|restart|health|logs [n]|notify-test`

**My role & hard rules:**
- I am observer/relay only — NOT a second review agent. Stay out of the OpenCode ↔ ChatGPT Web review loop; never send review results to ChatGPT myself.
- Monitoring is read-only: never auto-type, auto-approve, auto-confirm, or press Enter without explicit user request. When an agent waits: detect → notify → wait. Never decide for the user.
- Completion notifications come from WORKING→IDLE transitions only; an already-idle pane is never a "completion". Stuck is reported as "appears stuck", never as definitive failure.
- No git/repo modifications as part of monitoring. Warn when a context % is high (>75%) — suggest starting a fresh OpenCode thread.
- If a pane/tmux session is missing, report it clearly; do not remap an alias to an unrelated pane.

**Modes:** OFF (no active polling, status works) · ON (always ~12s fast poll; supports temp duration like `2h` then auto-returns to AUTO) · AUTO (default: fast ~12s when any pane active; low-power 5min check when all idle ≥5min). Zero LLM tokens for all monitoring.

**Detection:** footer-driven heuristics — `esc interrupt`/progress/cost ⇒ WORKING; `$ctrl+p` prompt ⇒ IDLE; y/n/proceed/❯ patterns ⇒ WAITING; error/panic/traceback ⇒ ERROR; working-but-frozen ≥10min ⇒ STUCK. Dedup by state-transition + content hash.

**Ops:** user crontab (`crontab -l`) runs `ocw health` every 5 min + `@reboot` start. Logs: `~/.openclaw/watcher/logs/`. State: `~/.openclaw/watcher/state/` (ephemeral). Config: `conf/aliases`, `conf/telegram.env` (0600).

## Research/Search stack (`rc`)

- Helper CLI: `~/.openclaw/workspace/research/rc` (zero-LLM deterministic layer). Full operating rules: `RESEARCH.md` (workspace root).
- Commands: `rc status|provider|route|search|fetch|cache|set-provider|test`.
- Cache: `~/.openclaw/search-cache/` (TTL: news 15m, current 1h, technical 12h, quick 24h).
- Chain: Brave (key configured 2026-08-18, plugin `@openclaw/brave-plugin` installed) → DuckDuckGo (key-free; html→lite→retry). Native `web_search` is a separate path (provider=brave, verified).
- Chat words: `search <q>` / `research <q>` / `search status|provider|test`.
- NEVER touch `~/.openclaw/watcher/` from research code.

## Examples

### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod


## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Related

- [Agent workspace](/concepts/agent-workspace)
