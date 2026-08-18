#!/usr/bin/env bash
# Regression tests: watcher ERROR false-positive fix (fixtures/simulation only)
# - Never touches real tmux panes (feaon/qvak) or sends keys.
# - Never sends Telegram: tel_send is stubbed.
# - Uses a temp sandbox for OCW_DIR so no real state/logs are touched.
set -u

TESTDIR="$(mktemp -d)"
trap 'rm -rf "$TESTDIR"' EXIT

# ---- sandbox: point lib globals at temp dirs ---------------------------
export OCW_DIR="$TESTDIR/watcher"
mkdir -p "$OCW_DIR/conf" "$OCW_DIR/state/per-pane" "$OCW_DIR/logs"
# shellcheck disable=SC1091
. "$(dirname "$0")/../ocw-lib.sh"

# ---- stub telegram -----------------------------------------------------
SENT=""
tel_send() { SENT="$1"; }

# ---- harness -----------------------------------------------------------
pass=0; fail=0
check() { # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; pass=$((pass+1));
  else echo "FAIL: $1 (expected=$2 got=$3)"; fail=$((fail+1)); fi
}

# =========================================================================
# Fixtures (realistic OpenCode TUI captures, shapes match real panes)
# =========================================================================

# F1: transient TypeScript error WHILE agent is actively working
F_TS="$(mktemp "$TESTDIR/ts.XXXX")"
cat > "$F_TS" <<'EOF'
  ┃  ✓ Types generated successfully
  ┃  src/content/content.test.ts(85,28): error TS18048: 'organization' is
  ┃  possibly 'undefined'.
  ┃  ℹ tests 87
  ┃  ℹ pass 87
  ┃  ℹ fail 0
  ┃
     Type narrowing vẫn không hoạt động vì filter với optional chain. Dùng
     cách khác — lọc bằng helper explicit
     → Read src/content/content.test.ts [limit=30, offset=75]
     + Thought: 1.5s
     Type predicate phải narrow xuống non-undefined type
  ┃  ← Edit src/content/content.test.ts
  ▣  Build · DeepSeek V4 Flash Free
  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
  ⬝⬝⬝⬝⬝⬝⬝⬝  esc interrupt151.9K (76%) · $0.81  ctrl+p commands
EOF

# F2: failing test output while still working (agent fixing it)
F_FAIL="$(mktemp "$TESTDIR/fail.XXXX")"
cat > "$F_FAIL" <<'EOF'
  ┃  ❌ content.test.ts > published resume (87 tests)
  ┃  AssertionError: expected 'private' to equal 'visible'
  ┃
     Fixing the assertion — resume default is private now
     → Edit src/content/content.test.ts
  ┃  ← Edit src/content/content.test.ts
  ▣  Build · DeepSeek V4 Flash Free
  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
  ⬝⬝⬝⬝⬝⬝⬝⬝  esc interrupt130.2K (65%) · $0.82  ctrl+p commands
EOF

# F3: agent fixed test → all pass → idle prompt (feaon-idle shape: $ctrl+p, no cost)
F_PASS="$(mktemp "$TESTDIR/pass.XXXX")"
cat > "$F_PASS" <<'EOF'
  ┃  ℹ tests 93
  ┃  ℹ pass 93
  ┃  ℹ fail 0
  ┃
     All green — done with the resume-lock feature.
  ┃
  ┃  Build auto · DeepSeek V4 Flash Free OpenCode Zen
  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
  /home/audition/projects/personal/133.0K (66%) · $ctrl+p
  qvak-portfolio                                          commands
EOF

# F4: actual unrecovered failure — fatal text, no live working footer
F_UNC="$(mktemp "$TESTDIR/unc.XXXX")"
cat > "$F_UNC" <<'EOF'
  ┃  npm error code ERESOLVE
  ┃  npm error Could not resolve dependency tree
  ┃  ✖ Task failed: install dependencies
  ┃  Process exited with code 1
  ┃  fatal: unable to access 'https://github.com/'
  ┃
  ┃  Build auto · DeepSeek V4 Flash Free OpenCode Zen
EOF

# F5: stale error lines remain in pane history while agent is working
F_STALE="$(mktemp "$TESTDIR/stale.XXXX")"
cat > "$F_STALE" <<'EOF'
  ┃  jQuery is not defined
  ┃  Uncaught TypeError: Cannot read properties of undefined
  ┃
     (old error from previous task — still in scrollback)
     Continuing with the new task, everything is fine
     → Run npm test
  ▣  Build · DeepSeek V4 Flash Free
  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
  ⬝⬝⬝⬝⬝⬝  esc interrupt98.2K (49%) · $0.77  ctrl+p commands
EOF

# F6: ERROR-candidate screen (fatal text, no footer) — for stale-evidence gate
F_ERRCAND="$(mktemp "$TESTDIR/errcand.XXXX")"
cat > "$F_ERRCAND" <<'EOF'
  ┃  npm error code ERESOLVE
  ┃  ✖ Task failed: install dependencies
  ┃  Process exited with code 1
  ┃
  ┃  Build auto · DeepSeek V4 Flash Free OpenCode Zen
EOF

echo "== [1/5] classification: transient error while working -> WORKING =="
check "transient TS error while working" WORKING "$(classify < "$F_TS")"
check "failing test while fixing"        WORKING "$(classify < "$F_FAIL")"
check "stale error while working"        WORKING "$(classify < "$F_STALE")"

echo "== [2/5] classification: recovery flow, no ERROR =="
check "tests pass + idle -> IDLE" IDLE "$(classify < "$F_PASS")"

echo "== [3/5] classification: real unrecovered failure -> ERROR =="
check "unrecovered failure -> ERROR" ERROR "$(classify < "$F_UNC")"
check "ERROR candidate (no footer) -> ERROR" ERROR "$(classify < "$F_ERRCAND")"

echo "== [4/5] fresh_error_lines unit tests (evidence gating) =="
BASE="$(mktemp "$TESTDIR/base.XXXX")"
CUR="$(mktemp "$TESTDIR/cur.XXXX")"
printf 'clean line 1\nclean line 2\n' > "$BASE"
printf 'clean line 1\nclean line 2\nnpm error code ERESOLVE\n' > "$CUR"
fresh=$(fresh_error_lines < "$CUR" "$BASE")
check "new error line in delta -> detected" "npm error code ERESOLVE" "$fresh"
fresh2=$(fresh_error_lines < "$BASE" "$BASE")
check "no new lines -> no fresh error" "" "$fresh2"
# first poll (no baseline) must never fire: baseline is established silently
fresh3=$(fresh_error_lines < "$F_UNC" "$TESTDIR/nonexistent.baseline")
check "first poll (no baseline) -> no fresh error" "" "$fresh3"

echo "== [5/5] daemon flow simulation (transition + notify gating) =="
SIM_FRESH_EV=""
sim() { # $1=tailfile -> prints "STATE|FRESH|EVIDENCE" (parsed by caller)
  local tf="$1" snap st ev
  snap="$PER_PANE_DIR/qvak.tail"
  cls=$(classify < "$tf")
  st="$cls"
  if [ "$cls" = "ERROR" ]; then
    ev=$(fresh_error_lines < "$tf" "$snap")
    if [ -z "$ev" ]; then
      st="HELD"            # stale error evidence -> hold previous state, no notify
      printf '%s|0|\n' "$st"
    else
      printf '%s|1|%s\n' "$st" "$ev"
    fi
  else
    printf '%s|0|\n' "$st"
  fi
  printf '%s\n' "$(cat "$tf")" > "$snap"   # persist snapshot like daemon does
}

# a) transient TS error appears then agent fixes -> WORKING -> IDLE, never ERROR
IFS='|' read -r s1 f1 e1 <<< "$(sim "$F_TS")"
check "flow: TS error (working) -> WORKING" WORKING "$s1"
IFS='|' read -r s2 f2 e2 <<< "$(sim "$F_PASS")"
check "flow: fixed -> IDLE, never ERROR" IDLE "$s2"

# b) unrecovered failure arrives fresh (baseline exists, error is NEW) -> ERROR
sim "$F_PASS" >/dev/null
IFS='|' read -r s3 f3 e3 <<< "$(sim "$F_UNC")"
check "flow: fresh unrecovered failure -> ERROR" ERROR "$s3"
check "flow: fresh error evidence captured" "1" "$f3"
printf '%s' "$e3" | grep -q "npm error\|Process exited" \
  && { echo "PASS: flow: evidence lines are real error text"; pass=$((pass+1)); } \
  || { echo "FAIL: flow: evidence lines missing ($e3)"; fail=$((fail+1)); }

# c) stale error screen (no footer) with identical snapshot -> held, no ERROR
printf '%s\n' "$(cat "$F_ERRCAND")" > "$PER_PANE_DIR/qvak.tail"
IFS='|' read -r s4 f4 e4 <<< "$(sim "$F_ERRCAND")"
check "flow: stale error screen -> HELD (prev state kept)" "HELD" "$s4"
check "flow: stale error -> no fresh evidence" "0" "$f4"

# d) stale error while working (footer active) -> WORKING (never ERROR)
printf '%s\n' "$(cat "$F_STALE")" > "$PER_PANE_DIR/qvak.tail"
IFS='|' read -r s5 f5 e5 <<< "$(sim "$F_STALE")"
check "flow: stale error while working -> WORKING" "WORKING" "$s5"

echo "== notify_error evidence (requirement: notification includes proof) =="
SENT=""
notify_error qvak "$(cat "$F_UNC")" "npm error code ERESOLVE
Process exited with code 1"
printf '%s' "$SENT" | grep -q "Error evidence" && printf '%s' "$SENT" | grep -q "ERESOLVE" \
  && { echo "PASS: notification contains actual error evidence"; pass=$((pass+1)); } \
  || { echo "FAIL: notification missing evidence (SENT=$SENT)"; fail=$((fail+1)); }

echo
echo "===== $pass passed, $fail failed ====="
[ "$fail" -eq 0 ]