# Recovery Runbook — OpenClaw broken → reinstall → working again

Goal: get from "OpenClaw is broken on this machine" back to a working agent
that **understands this machine and remembers what happened before**, with
minimum fuss.

## 1. Quick assessment (5 min)

- `openclaw status` — is the gateway up? What broke (crash loop / config error / data loss)?
- `systemctl --user status openclaw-gateway` — service state + last logs.
- Check last good state: did `setup.sh` ever run? Does `~/.openclaw/` still exist?
- If only the config is broken: back it up, then regenerate:
  ```
  cp ~/.openclaw/openclaw.json ~/openclaw.json.bak-$(date +%F)
  ```
- If the whole `~/.openclaw` is lost: full reinstall path below.

## 2. Full reinstall (config + workspace recreated from repo)

1. Reinstall OpenClaw (per official docs), then:
   ```
   git clone <your openclaw-setup repo> ~/openclaw-setup
   cd ~/openclaw-setup
   ./setup.sh
   ```
   It regenerates `~/.openclaw/openclaw.json` (prompts each secret),
   installs the watcher + research stack + workspace instruct pack.
2. Restore memory (your chat history / decisions) from your private backup:
   ```
   MEMORY_BACKUP=~/openclaw-memory-2026-08-18-*.tar.gz ./setup.sh
   # or manually:
   tar -xzf ~/openclaw-memory-2026-08-18-*.tar.gz -C ~/.openclaw/workspace/
   ```
3. Restart the gateway: `openclaw gateway restart` (or `systemctl --user restart openclaw-gateway`).

## 3. Verify it understands the machine

Ask the agent: *"Read ONBOARD.md and tell me what this machine runs."*
Expected answers:
- OpenCode tmux watcher (`ocw`) — aliases feaon (0.0) + qvak (0.1), commands `ocw status/show/send`.
- Research stack (`rc`) — Brave primary, DDG fallback; `rc status` shows provider.
- Gateway config facts (port 18789, systemd user service, loopback).
- It should NOT know your memory yet if the backup wasn't restored — that's expected.

Command checks:
```
rc status                              # provider=brave, fallback ddg
ocw status                             # watcher + pane states (or "not started")
openclaw config get tools.web.search.provider   # -> brave
openclaw plugins list                  # brave plugin enabled
```

## 4. Restart the tmux agents (if this machine drives feaon/qvak)

```
tmux new-session -d -s opencode-work   # recreate if the session is gone
# re-attach the two panes + launch opencode in each (see watcher/conf/aliases.example)
# then:
ocw start                              # watcher daemon
crontab -e                             # re-add: */5 * * * * ocw health ; @reboot ocw start
```

## 5. Post-recovery hygiene

- Run `bash scripts/verify-no-secrets.sh` before any push (should be green).
- If you rotated any secret (token/key) while recovering, update this repo's
  templates ONLY if the template structure changed — never values.
- Make a fresh memory backup after a few days of normal use:
  `./scripts/backup-memory.sh`.

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| gateway crash-loop after setup | bad token/host value in openclaw.json | `openclaw config set gateway.auth.token ...` then restart |
| `rc status` shows ddg only | brave key missing/expired | re-run setup with valid `BRAVE_API_KEY` |
| watcher "alias missing" | tmux session not running | start `opencode-work` session, then `ocw restart` |
| agent doesn't remember | memory/ not restored | restore from backup archive (step 2) |
| browser broken | WSL missing libs (known issue) | not required for normal use; needs sudo to fix |