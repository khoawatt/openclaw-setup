# openclaw-setup

Portable, **secrets-free** bootstrap templates for an OpenClaw agent workstation:
gateway config, OpenCode tmux watcher (ocw), and the research/search stack.

> ⚠️ This repo intentionally contains **zero real credentials**. Live config files
> (`openclaw.json`, `telegram.env`) are templates with `__PLACEHOLDER__` tokens and
> are filled in on each machine by `setup.sh` (prompts or a local env file kept
> **out** of the repo).

## Contents

```
openclaw-setup/
├── openclaw.json.example       # gateway config template (placeholders for secrets)
├── setup.sh                    # bootstrap a new machine (interactive or env-file)
├── README.md
├── watcher/                    # OpenCode tmux watcher (zero-LLM monitoring)
│   ├── ocw                     # CLI: status/show/send/monitor/start/stop/health/logs
│   ├── ocw-lib.sh              # classification, notifications, helpers
│   ├── ocw-daemon.sh           # poll loop daemon
│   ├── conf/
│   │   ├── aliases.example     # feaon/qvak -> tmux targets -> project paths
│   │   └── telegram.env.example # bot token + chat id (FILL LOCALLY, 0600)
│   └── tests/                  # regression fixtures (fixes for ERROR false-positives)
└── research/                    # search stack operating rules + rc helper
    ├── rc                      # zero-LLM: status/provider/route/search/fetch/cache
    └── RESEARCH.md             # operating rules (providers, TTLs, security)
```

## Quick start (new machine)

```bash
git clone <repo> ~/openclaw-setup && cd ~/openclaw-setup
./setup.sh                      # interactive prompts for each secret
# or: SECRETS_FILE=~/.secrets/local.env ./setup.sh

# verify
openclaw config get tools.web.search.provider   # -> brave
~/.openclaw/workspace/research/rc status
~/.openclaw/watcher/ocw status

# keep the watcher alive (user crontab)
crontab -e
# */5 * * * * /home/<user>/.openclaw/watcher/ocw health
# @reboot sleep 15 && /home/<user>/.openclaw/watcher/ocw start
```

## Secrets policy (why this is safe to share)

| Item | In repo? | Notes |
|---|---|---|
| gateway auth token | ❌ `__GATEWAY_TOKEN__` | regenerate per machine: `openssl rand -hex 24` |
| Telegram bot token | ❌ `__TELEGRAM_BOT_TOKEN__` | from @BotFather; per-bot |
| Telegram chat id | ❌ `__OWNER_TELEGRAM_ID__` | numeric owner id |
| Brave Search API key | ❌ `__BRAVE_API_KEY__` | https://brave.com/search/api/ |
| watcher telegram.env | ❌ (only `.example`) | chmod 600 after fill |
| openclaw.json / logs / memory/ | ❌ gitignored | personal + ephemeral |

`setup.sh` replaces placeholders at install time and `chmod 600`s every file
that can hold secrets. Nothing in this repo can leak a credential.

## Watcher notes

- Detection heuristics (footer-driven): WAITING > WORKING > IDLE > ERROR.
  ERROR requires **fresh** error lines (delta vs previous poll snapshot) and
  no active working/idle footer — transient compiler/test errors while an
  agent is still working are **not** notified as errors.
- Regression suite: `watcher/tests/run-tests.sh` (18 checks, fixture-only,
  no real panes / no Telegram).
- Safety: `ocw send` is explicit-authorized only; monitoring is read-only;
  aliases are canonical and never remapped.

## Research/search stack notes

- Primary provider: Brave (key configured via template). Fallback: DuckDuckGo
  (key-free). Chain rule: `brave -> duckduckgo`; never remove DDG.
- Cache: `~/.openclaw/search-cache/` (news 15m / current 1h / technical 12h / quick 24h).
- Full operating rules: `research/RESEARCH.md`.