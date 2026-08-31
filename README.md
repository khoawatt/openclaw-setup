# openclaw-setup

Portable, **secrets-free** bootstrap + **machine-understanding pack** for an
OpenClaw agent workstation: gateway config, OpenCode tmux watcher (ocw), and
the research/search stack.

> Purpose (per owner): *"repo này để hiểu những config và công việc hiện tại —
> research web, watch tmux opencode… — nếu OpenClaw hỏng thì cài lại vẫn hiểu
> và nhớ."*

Two layers live in this repo:

1. **Config layer** — templates + installer (`setup.sh`), zero real credentials.
2. **Instruct layer** — `ONBOARD.md` + `workspace/` pack so a reinstalled
   agent reads and instantly understands this machine and its workflows.

Memory (chat logs, decisions) is **personal and never committed** — it is
backed up separately with `scripts/backup-memory.sh` and restored via
`MEMORY_BACKUP=<archive> ./setup.sh`.

## Contents

```
openclaw-setup/
├── ONBOARD.md                   # MACHINE BRIEFING — read first on fresh install
├── openclaw.json.example        # gateway config template (placeholders for secrets)
├── setup.sh                     # bootstrap: config + watcher + research + workspace + memory
├── README.md
├── workspace/                   # instruct pack (installed to ~/.openclaw/workspace)
│   ├── AGENTS.md                # operating rules
│   ├── SOUL.md                  # persona
│   ├── TOOLS.md                 # local notes: watcher aliases, rc stack, PATH quirks
│   ├── HEARTBEAT.md             # heartbeat template
│   ├── RESEARCH.md              # search stack operating rules
│   ├── USER.md.example          # about-the-human template (fill locally)
│   └── IDENTITY.md.example      # name/avatar template (fill locally)
├── watcher/                     # OpenCode tmux watcher (zero-LLM monitoring)
│   ├── ocw                      # CLI: status/show/send/monitor/start/stop/health/logs
│   ├── ocw-lib.sh               # classification, notifications, helpers
│   ├── ocw-daemon.sh            # poll loop daemon
│   ├── conf/
│   │   ├── aliases.example      # feaon/qvak -> tmux targets -> project paths
│   │   └── telegram.env.example # bot token + chat id (FILL LOCALLY, 0600)
│   └── tests/                   # regression fixtures (ERROR false-positive fix)
├── research/                    # search stack
│   ├── rc                       # zero-LLM: status/provider/route/search/fetch/cache
│   └── RESEARCH.md              # operating rules (providers, TTLs, security)
├── docs/recovery.md             # FULL RUNBOOK: broken OpenClaw -> reinstall -> working
└── scripts/
    ├── verify-no-secrets.sh     # pre-push leak guard
    └── backup-memory.sh         # private memory archive (NEVER committed)
```

## Quick start (new machine)

```bash
git clone <repo> ~/openclaw-setup && cd ~/openclaw-setup
./setup.sh                      # interactive prompts for each secret
# or: SECRETS_FILE=~/.secrets/local.env ./setup.sh
# or (recovery): MEMORY_BACKUP=~/openclaw-memory-*.tar.gz ./setup.sh

# verify
openclaw config get tools.web.search.provider   # -> brave
~/.openclaw/workspace/research/rc status        # provider chain
~/.openclaw/watcher/ocw status                  # watcher + pane states

# keep the watcher alive (user crontab)
crontab -e
# */5 * * * * /home/<user>/.openclaw/watcher/ocw health
# @reboot sleep 15 && /home/<user>/.openclaw/watcher/ocw start
```

## Recovering a broken OpenClaw

Full runbook: **`docs/recovery.md`**. Short version:

1. `git clone <repo>` + `./setup.sh` → regenerates config (prompts secrets),
   installs watcher/research/workspace pack.
2. Restore memory: `MEMORY_BACKUP=<archive> ./setup.sh` (or `tar -xzf` into
   `~/.openclaw/workspace/`).
3. `openclaw gateway restart`, then verify with `rc status` + `ocw status`.
4. Ask the agent: *"Read ONBOARD.md and tell me what this machine runs."*
   → it should describe ocw (feaon/qvak), rc (Brave→DDG), gateway facts.

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
Run `bash scripts/verify-no-secrets.sh` before any push.

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

---

## Đóng góp (Contributing)

Mọi đóng góp đều được hoan nghênh. Vui lòng xem [CONTRIBUTING.md](CONTRIBUTING.md) và [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---

## Tác giả & Contributors

* **Quách Võ Anh Khoa** ([@khoawatt](https://github.com/khoawatt)) — Author & Maintainer

---

## Giấy phép (License)

Dự án được phân phối dưới giấy phép **MIT License**. Xem [LICENSE](LICENSE).

---

## Bảo mật (Security)

Xem [SECURITY.md](SECURITY.md) để báo cáo lỗ hổng. Không mở issue công khai cho vấn đề bảo mật.