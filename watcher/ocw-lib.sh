#!/usr/bin/env bash
# ocw-lib.sh — shared library for the OpenCode tmux watcher (zero-LLM monitoring)
# This is pure shell: tmux inspection, process checks, hashing, state files.
# No LLM, no model inference. Deterministic.
set -u

OCW_DIR="${OCW_DIR:-$HOME/.openclaw/watcher}"
CONF_DIR="$OCW_DIR/conf"
STATE_DIR="$OCW_DIR/state"
PER_PANE_DIR="$STATE_DIR/per-pane"
LOG_DIR="$OCW_DIR/logs"
FIXTURE_DIR="$OCW_DIR/fixtures"

ALIASES_FILE="$CONF_DIR/aliases"
TELEGRAM_ENV="$CONF_DIR/telegram.env"
MODE_FILE="$STATE_DIR/mode"
MODE_UNTIL_FILE="$STATE_DIR/mode_until"
PID_FILE="$STATE_DIR/daemon.pid"
HEARTBEAT_FILE="$STATE_DIR/heartbeat"
LOG_FILE="$LOG_DIR/watcher.log"
DAEMON_LOG="$LOG_DIR/daemon.log"
RESTART_COUNT_FILE="$STATE_DIR/restart_count"
RESTART_WINDOW_FILE="$STATE_DIR/restart_window"

export LC_ALL="${OCW_LOCALE:-C.UTF-8}"

# ---- timing knobs (seconds) -------------------------------------------
FAST_INTERVAL="${OCW_FAST_INTERVAL:-12}"     # active monitoring cadence
SLOW_INTERVAL="${OCW_SLOW_INTERVAL:-300}"    # low-power AUTO cadence
IDLE_WINDOW="${OCW_IDLE_WINDOW:-300}"        # all panes idle this long -> low power
STUCK_AFTER="${OCW_STUCK_AFTER:-600}"        # working but output frozen this long -> STUCK
GRACE="${OCW_GRACE:-20}"                     # debounce before declaring completion
HEARTBEAT_STALE="${OCW_HEARTBEAT_STALE:-900}"  # health check threshold
OFF_SLEEP="${OCW_OFF_SLEEP:-120}"            # OFF-mode poll interval (mode file only)

# ---- detection patterns --------------------------------------------------
# WAITING: prompts requiring user input (scanned in last 12 lines)
WAIT_PAT='(Proceed\?|Continue\?|Are you sure|\([Yy]es/[Nn]o\)|\([Yy]/[Nn]\)|Please (choose|select|confirm|enter)|Select (an option|one)|Choose (an option|one)|Do you (want|wish)|Would you like|Press (Enter|any key)|Allow\?|Approve\?|Permission|confirm(ed)?\?|type your|Enter your)'

# ERROR: obvious failures (last 15 lines). Intentionally conservative —
# ordinary warnings do NOT match these.
ERR_PAT='((^|[^A-Za-z])(error|Error|ERROR|Fatal|fatal|FATAL|panic|Panic)|Traceback|Exception|✖|❌|exit code [1-9]|[Ee]xit code [1-9]|Process exited|command failed|failed to (run|execute|start|build|install|parse)|npm error|fatal:|Thread .* panicked)'

# WORKING: activity markers (last 8 lines). Spinners, progress blocks,
# task banners, tool calls, status rows that only render while running.
# NOTE: use literal char lists, not ranges — glibc grep/sed reject
# multibyte ranges like [⠁-⣿] under C.UTF-8 ("Invalid collation character").
WORK_PAT='(esc interrupt|Task —|Task -|subagents|Bash [a-z]|Thinking|Analyzing|Planning|Reasoning|Working|[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏⠻⠽⠾⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠍⠎⠓⠕⠖⠛⠜⠝⠞⠢⠣⠥⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠵⠶⠷⠺]|[⬝⬞]|[▁▂▃▄▅▆▇▉▊▋▌▍▎▏▐░▒▓▔▕▖▗▘▙▚▛▜▝▞▟█])'

# IDLE: mode-selector line only rendered when OpenCode is at a prompt.
# Working footers also show ctrl+p / ╹ borders, so do NOT use those.
IDLE_PAT='(Build (auto|manual|normal|insert))'

# Chars to strip for content-hashing (spinner/progress animation jitter)
STRIP_SPIN='[⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿⬝⬞▁▂▃▄▅▆▇█▉▊▋▌▍▎▏▐░▒▓▔▕▖▗▘▙▚▛▜▝▞▟]'

# ---- time helpers --------------------------------------------------------
now()  { date +%s; }
ts()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "$(ts) [$1] $2" >> "$LOG_FILE"; }

# ---- telegram (direct Bot API, no LLM) ----------------------------------
tel_send() {
  # usage: tel_send "<html-text>"
  [ -f "$TELEGRAM_ENV" ] || { log NOTIFY "telegram env missing ($TELEGRAM_ENV)"; return 1; }
  # shellcheck disable=SC1090
  . "$TELEGRAM_ENV"
  local text="$1" out rc
  out=$(curl -s -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${text}" 2>/dev/null)
  rc=$?
  if [ $rc -ne 0 ] || printf '%s' "$out" | grep -q '"ok":false'; then
    log NOTIFY "telegram send failed (rc=$rc)"
    return 1
  fi
  log NOTIFY "telegram sent (msg ${#text} chars)"
  return 0
}

html_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# ---- aliases ---------------------------------------------------------------
aliases_list() {
  awk '!/^[[:space:]]*#/ && NF>=2 {print $1, $2, $3}' "$ALIASES_FILE"
}
alias_target() {
  # echoes tmux target for alias, empty if unknown alias
  awk -v a="$1" '$1==a {print $2; found=1} END {exit found?0:1}' "$ALIASES_FILE"
}
alias_path() {
  awk -v a="$1" '$1==a {print $3}' "$ALIASES_FILE"
}
alias_exists() { alias_target "$1" >/dev/null 2>&1; }

# ---- tmux / process inspection --------------------------------------------
pane_exists() {
  # $1 = tmux target like opencode-work:0.0
  tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1
}
session_exists() {
  tmux has-session -t "${1%%:*}" >/dev/null 2>&1
}
capture_tail() {
  # $1 = tmux target, $2 = max lines (scrollback + screen)
  tmux capture-pane -p -t "$1" -S "-$2" 2>/dev/null
}
pane_cmd() {
  tmux display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null
}
pane_pid() {
  tmux display-message -p -t "$1" '#{pane_pid}' 2>/dev/null
}

h() { sha256sum | cut -c1-16; }
content_hash() {
  # stdin: tail text. Strip animation jitter + footer rows, then hash.
  # => stable hash while a spinner just keeps spinning.
  sed "s/$STRIP_SPIN//g" | head -n -4 | h
}

# ---- classification ----------------------------------------------------------
classify() {
  # stdin: tail text. Echoes one of: WAITING|WORKING|IDLE|ERROR|UNKNOWN
  # Priority: WAITING > WORKING(footer) > IDLE(footer) > ERROR > IDLE(mode) > UNKNOWN.
  # The live footer (last 2 lines) is authoritative for WORKING vs IDLE:
  #   - 'esc interrupt' / progress bar / cost => task running
  #   - '$ctrl'+p prompt => idle, ready for input
  # ERROR is only reached when OpenCode is neither actively working nor at
  # an idle prompt — i.e. the pane shows error output with no live footer.
  # Transient compiler/test errors while the footer is still active are
  # WORKING, never ERROR. Stale error lines still visible in the tail are
  # filtered by the daemon via fresh_error_lines (new-output evidence).
  local text t2 t4 t12 t15
  text=$(cat)
  [ -z "$text" ] && { echo UNKNOWN; return; }
  t2=$(printf '%s\n' "$text" | tail -n 2)
  t4=$(printf '%s\n' "$text" | tail -n 4)
  t12=$(printf '%s\n' "$text" | tail -n 12)
  t15=$(printf '%s\n' "$text" | tail -n 15)
  if printf '%s\n' "$t12" | grep -qE "$WAIT_PAT"; then echo WAITING; return; fi
  # footer says task is actively running (must beat ERROR: transient errors
  # while the agent is still working remain WORKING)
  if printf '%s\n' "$t2" | grep -qE 'esc interrupt|[⬝■]|[$][0-9]+[.][0-9]+'; then echo WORKING; return; fi
  # footer says input-ready prompt (agent finished; stale errors ignored)
  if printf '%s\n' "$t2" | grep -qE '\$ctrl|commands'; then echo IDLE; return; fi
  # candidate ERROR: error text visible and no working/idle footer
  if printf '%s\n' "$t15" | grep -qE "$ERR_PAT"; then echo ERROR; return; fi
  # fallback: mode-selector line visible and no running footer
  if printf '%s\n' "$t4" | grep -qE "$IDLE_PAT" && ! printf '%s\n' "$t4" | grep -qE 'esc interrupt'; then echo IDLE; return; fi
  echo UNKNOWN
}

# ---- fresh error evidence --------------------------------------------------
# fresh_error_lines: stdin = current tail, $1 = previous poll's tail snapshot
# (baseline). Echoes only ERR_PAT lines that are NEW since the baseline, i.e.
# error output that appeared after the last observation. If the baseline file
# does not exist yet (first poll after daemon start), nothing is echoed: the
# first poll only establishes the baseline, so a stale error screen already
# on the pane at startup can never trigger an immediate false ERROR.
fresh_error_lines() {
  local base="$1" cur
  cur=$(cat)
  if [ -z "$cur" ]; then return 0; fi
  if [ ! -f "$base" ] || [ ! -s "$base" ]; then
    return 0
  fi
  # lines present now but absent in the baseline
  comm -13 <(sort -u "$base") <(printf '%s\n' "$cur" | sort -u) | grep -E "$ERR_PAT" || true
}

# ---- per-pane state ----------------------------------------------------------
state_file()   { echo "$PER_PANE_DIR/$1.state"; }
enabled_file() { echo "$PER_PANE_DIR/$1.enabled"; }

state_get() {
  # $1=alias, $2=key, $3=default
  local f; f="$(state_file "$1")"
  if [ -f "$f" ]; then
    awk -F= -v k="$2" '$1==k {print $2; found=1} END {if(!found) print "'"$3"'"}' "$f"
  else
    echo "$3"
  fi
}
state_set() {
  # $1=alias, $2=key, $3=value  (creates/replaces key in state file atomically)
  local f; f="$(state_file "$1")"
  touch "$f" 2>/dev/null
  if grep -q "^$2=" "$f" 2>/dev/null; then
    sed -i "s/^$2=.*/$2=$3/" "$f"
  else
    printf '%s=%s\n' "$2" "$3" >> "$f"
  fi
}
enabled_get() { [ -f "$(enabled_file "$1")" ] && cat "$(enabled_file "$1")" || echo 1; }
enabled_set() { printf '%s' "$2" > "$(enabled_file "$1")"; }

# ---- mode ---------------------------------------------------------------------
mode_get() {
  [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo auto
}
mode_set() {
  printf '%s\n' "$1" > "$MODE_FILE"
  log MODE "global mode -> $1"
}
mode_until_get() { [ -f "$MODE_UNTIL_FILE" ] && cat "$MODE_UNTIL_FILE" || echo 0; }

# ---- notification builders ------------------------------------------------------
notify_completed() {
  local alias="$1" tail="$2" t
  t=$(printf '%s\n' "$tail" | tail -n 3 | html_escape | sed 's/^/  /')
  tel_send "<b>✅ ${alias} — completed</b>

Task appears finished and OpenCode is idle.

Last output:
<code>${t}</code>

Action: none."
}
notify_waiting() {
  local alias="$1" tail="$2" t
  t=$(printf '%s\n' "$tail" | tail -n 6 | html_escape | sed 's/^/  /')
  tel_send "<b>⚠️ ${alias} — waiting for input</b>

OpenCode is asking for confirmation/input.

Prompt:
<code>${t}</code>

Action required: reply with your decision (tell me: <i>send ${alias} ...</i>)."
}
notify_error() {
  # $1=alias $2=tail $3=fresh error evidence lines (optional)
  local alias="$1" tail="$2" ev="${3:-}" t e
  t=$(printf '%s\n' "$tail" | tail -n 6 | html_escape | sed 's/^/  /')
  if [ -n "$ev" ]; then
    e=$(printf '%s\n' "$ev" | head -n 4 | html_escape | sed 's/^/  /')
    tel_send "<b>❌ ${alias} — apparent error</b>

Error evidence:
<code>${e}</code>

Recent output:
<code>${t}</code>

Action: inspect ${alias}."
  else
    tel_send "<b>❌ ${alias} — apparent error</b>

Relevant output:
<code>${t}</code>

Action: inspect ${alias}."
  fi
}
notify_stuck() {
  local alias="$1" tail="$2" mins="$3" t
  t=$(printf '%s\n' "$tail" | tail -n 4 | html_escape | sed 's/^/  /')
  tel_send "<b>⏳ ${alias} — appears stuck</b>

No meaningful output change for ~${mins} min while OpenCode still appears busy.

Last output:
<code>${t}</code>

Action: inspect if necessary."
}
notify_missing() {
  local alias="$1" t
  t=$(ts)
  tel_send "<b>🚫 ${alias} — pane/session unavailable</b>

The configured pane for ${alias} cannot be found (tmux session or pane missing).
Alias mapping is unchanged — nothing was remapped.

Action: check tmux. Time: ${t}"
}
notify_restored() {
  local alias="$1"
  tel_send "<b>🔁 ${alias} — pane available again</b>

The configured pane for ${alias} is back. Monitoring resumed.

Action: none."
}
notify_mode() {
  local text="$1"
  tel_send "<b>⚙️ Monitor</b> — ${text}"
}