#!/usr/bin/env bash
# setup.sh — bootstrap OpenClaw agent config on a NEW machine from templates.
# Usage: ./setup.sh            (interactive: prompts for each secret)
#        SECRETS_FILE=env ./setup.sh   (read secrets from a local env file)
#
# This script NEVER contains secrets and NEVER writes them to git.
# It copies templates into ~/.openclaw and fills placeholders from
# your input (or a local env file you keep OUT of the repo).
set -u

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
OCW_HOME="${OCW_HOME:-$HOME/.openclaw}"
USER_NAME="${USER:-$(id -un)}"

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }

# ---- secret sources -------------------------------------------------------
# 1) SECRETS_FILE env pointing to a local file with KEY=VALUE lines
# 2) interactive prompts (default)
get_secret() { # $1=name $2=prompt
  local name="$1" prompt="$2" val=""
  if [ -n "${SECRETS_FILE:-}" ] && [ -f "$SECRETS_FILE" ]; then
    val=$(awk -F= -v k="$name" '$1==k {sub(/^[^=]*=/,""); print}' "$SECRETS_FILE" | head -1)
  fi
  if [ -z "$val" ]; then
    read -r -p "$prompt: " val
  fi
  printf '%s' "$val"
}

# ---- steps ----------------------------------------------------------------
step_openclaw_json() {
  local src="$REPO_DIR/openclaw.json.example" dst="$OCW_HOME/openclaw.json"
  if [ -f "$dst" ] && [ -z "${FORCE:-}" ]; then
    warn "skip: $dst exists (use FORCE=1 to overwrite)"
    return
  fi
  say "Generate $dst"
  mkdir -p "$OCW_HOME"
  local tok tbot brave owner iso
  tok=$(get_secret GATEWAY_TOKEN "Gateway auth token (openssl rand -hex 24)")
  tbot=$(get_secret TELEGRAM_BOT_TOKEN "Telegram bot token (from @BotFather)")
  brave=$(get_secret BRAVE_API_KEY "Brave Search API key (https://brave.com/search/api/)")
  owner=$(get_secret OWNER_TELEGRAM_ID "Owner Telegram numeric ID")
  iso=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
  sed -e "s/__GATEWAY_TOKEN__/${tok}/g" \
      -e "s/__TELEGRAM_BOT_TOKEN__/${tbot}/g" \
      -e "s/__BRAVE_API_KEY__/${brave}/g" \
      -e "s/__OWNER_TELEGRAM_ID__/${owner}/g" \
      -e "s|__USER__|${USER_NAME}|g" \
      -e "s/__ISO_DATE__/${iso}/g" \
      "$src" > "$dst"
  chmod 600 "$dst"
  say "openclaw.json written (0600). Verify: openclaw config get tools.web.search.provider"
}

step_watcher() {
  say "Install watcher scripts -> $OCW_HOME/watcher"
  mkdir -p "$OCW_HOME/watcher/conf" "$OCW_HOME/watcher/logs" "$OCW_HOME/watcher/state"
  cp "$REPO_DIR/watcher/ocw" "$REPO_DIR/watcher/ocw-lib.sh" "$REPO_DIR/watcher/ocw-daemon.sh" "$OCW_HOME/watcher/"
  chmod +x "$OCW_HOME/watcher/ocw" "$OCW_HOME/watcher/ocw-lib.sh" "$OCW_HOME/watcher/ocw-daemon.sh"
  cp -r "$REPO_DIR/watcher/tests" "$OCW_HOME/watcher/" 2>/dev/null

  # aliases: substitute user home
  sed "s|__USER__|${USER_NAME}|g" "$REPO_DIR/watcher/conf/aliases.example" > "$OCW_HOME/watcher/conf/aliases"

  # telegram.env from secrets (never from repo)
  if [ ! -f "$OCW_HOME/watcher/conf/telegram.env" ] || [ -n "${FORCE:-}" ]; then
    local tbot tchat
    tbot=$(get_secret TELEGRAM_BOT_TOKEN "Telegram bot token")
    tchat=$(get_secret TELEGRAM_CHAT_ID "Telegram chat id (owner)")
    cat > "$OCW_HOME/watcher/conf/telegram.env" <<EOF
TELEGRAM_BOT_TOKEN=${tbot}
TELEGRAM_CHAT_ID=${tchat}
EOF
    chmod 600 "$OCW_HOME/watcher/conf/telegram.env"
  fi
  say "watcher installed. Add cron (see README):  */5 * * * * ocw health + @reboot ocw start"
}

step_research() {
  say "Install research stack -> $OCW_HOME/workspace/research"
  mkdir -p "$OCW_HOME/workspace/research"
  cp "$REPO_DIR/research/rc" "$OCW_HOME/workspace/research/"
  cp "$REPO_DIR/research/RESEARCH.md" "$OCW_HOME/workspace/"
  chmod +x "$OCW_HOME/workspace/research/rc"
  say "research stack installed. Test: rc status"
}

step_browser_check() {
  say "Browser check (optional): openclaw browser status"
  echo "  If missing WSL libs: sudo apt-get install -y libnspr4 libnss3 libasound2"
}

# ---- main -----------------------------------------------------------------
main() {
  say "OpenClaw setup bootstrap (repo: $REPO_DIR)"
  step_openclaw_json
  step_watcher
  step_research
  step_browser_check
  say "Done. Next: run 'openclaw gateway restart' if the gateway already exists."
}

main "$@"