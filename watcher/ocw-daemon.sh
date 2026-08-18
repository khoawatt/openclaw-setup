#!/usr/bin/env bash
# ocw-daemon.sh — OpenCode tmux watcher daemon (zero-LLM, pure shell)
# Monitors aliased OpenCode panes in tmux, classifies state transitions,
# and pushes Telegram notifications directly via Bot API.
set -u

# shellcheck disable=SC1091
. "$(dirname "$0")/ocw-lib.sh"

export PATH="/usr/bin:/bin:$PATH"

mkdir -p "$PER_PANE_DIR" "$LOG_DIR"
echo $$ > "$PID_FILE"
log DAEMON "daemon started pid=$$ mode=$(mode_get)"

# init per-pane state files so `status` works even before first poll
while read -r alias target _path; do
  [ -z "$alias" ] && continue
  f="$(state_file "$alias")"
  [ -f "$f" ] || {
    printf 'state=UNKNOWN\nlast_hash=\nlast_content_hash=\nlast_state_change=%s\nprev_state=UNKNOWN\nnotified=none\n' "$(now)" > "$f"
  }
done < <(aliases_list)

# seed activity timer: poll fast briefly on start to establish a baseline
state_set _global last_activity "$(now)"

loop_sleep=5   # start with a modest first check
prev_loop_sleep=""

while true; do
  t0=$(now)
  printf '%s\n' "$t0" > "$HEARTBEAT_FILE"

  mode=$(mode_get)

  # temporary activation expiry (monitor on 2h)
  until_ts=$(mode_until_get)
  if [ "$mode" = "on" ] && [ "$until_ts" -gt 0 ] && [ "$t0" -ge "$until_ts" ]; then
    log MODE "temporary ON window expired, returning to AUTO"
    rm -f "$MODE_UNTIL_FILE"
    mode_set auto
    mode=auto
    notify_mode "temporary active window expired — back to AUTO."
  fi

  if [ "$mode" = "off" ]; then
    # OFF: no pane inspection. Only keep service heartbeat alive so
    # `monitor status` / health / re-enable still work.
    sleep "$OFF_SLEEP"
    continue
  fi

  # ---- poll all enabled panes -------------------------------------------
  any_active=0
  while read -r alias target _path; do
    [ -z "$alias" ] && continue
    [ "$(enabled_get "$alias")" = "1" ] || continue

    prev_state=$(state_get "$alias" state UNKNOWN)
    if ! session_exists "$target"; then
      # session gone -> report missing, no remapping
      if [ "$prev_state" != "MISSING" ]; then
        log PANE "$alias target=$target => MISSING (session gone)"
        notify_missing "$alias"
        state_set "$alias" state MISSING
        state_set "$alias" prev_state "$prev_state"
        state_set "$alias" notified missing
      fi
      continue
    fi
    if ! pane_exists "$target"; then
      if [ "$prev_state" != "MISSING" ]; then
        log PANE "$alias target=$target => MISSING (pane gone)"
        notify_missing "$alias"
        state_set "$alias" state MISSING
        state_set "$alias" prev_state "$prev_state"
        state_set "$alias" notified missing
      fi
      continue
    fi

    tail_out=$(capture_tail "$target" 40)
    hash=$(printf '%s\n' "$tail_out" | h)
    chash=$(printf '%s\n' "$tail_out" | content_hash)
    cls=$(printf '%s\n' "$tail_out" | classify)
    now_ts=$(now)

    if [ "$prev_state" = "MISSING" ] && [ "$cls" != "UNKNOWN" ]; then
      log PANE "$alias restored (was MISSING)"
      notify_restored "$alias"
      state_set "$alias" state "$cls"
      state_set "$alias" prev_state MISSING
      state_set "$alias" last_hash "$hash"
      state_set "$alias" last_content_hash "$chash"
      state_set "$alias" last_state_change "$now_ts"
      state_set "$alias" notified none
      prev_state="$cls"
    fi

    # ---- state machine --------------------------------------------------
    case "$cls" in
      WORKING)
        any_active=1
        if [ "$prev_state" != "WORKING" ] && [ "$prev_state" != "STUCK" ]; then
          log PANE "$alias WORKING (from $prev_state)"
          state_set "$alias" state WORKING
          state_set "$alias" prev_state "$prev_state"
          state_set "$alias" last_state_change "$now_ts"
          state_set "$alias" notified none
          prev_state=WORKING
        fi
        # STUCK detection: still "working" but content hash frozen
        if [ "$prev_state" = "WORKING" ]; then
          prev_chash=$(state_get "$alias" last_content_hash "")
          if [ -n "$prev_chash" ] && [ "$prev_chash" = "$chash" ] && [ "$(state_get "$alias" notified)" != "stuck" ]; then
            last_change=$(state_get "$alias" last_state_change "$now_ts")
            if [ $(( now_ts - last_change )) -ge "$STUCK_AFTER" ]; then
              mins=$(( STUCK_AFTER / 60 ))
              log PANE "$alias STUCK (no change ~${mins}min)"
              notify_stuck "$alias" "$tail_out" "$mins"
              state_set "$alias" state STUCK
              state_set "$alias" notified stuck
            fi
          fi
        fi
        # transition STUCK -> WORKING again (progress resumed)
        if [ "$prev_state" = "STUCK" ] && [ "$chash" != "$(state_get "$alias" last_content_hash "")" ]; then
          log PANE "$alias WORKING again (was STUCK)"
          state_set "$alias" state WORKING
          state_set "$alias" prev_state STUCK
          state_set "$alias" last_state_change "$now_ts"
          state_set "$alias" notified none
        fi
        ;;
      WAITING)
        any_active=1
        if [ "$prev_state" != "WAITING" ]; then
          log PANE "$alias WAITING (from $prev_state)"
          notify_waiting "$alias" "$tail_out"
          state_set "$alias" state WAITING
          state_set "$alias" prev_state "$prev_state"
          state_set "$alias" last_state_change "$now_ts"
          state_set "$alias" notified "waiting_$hash"
        fi
        ;;
      ERROR)
        any_active=1
        # ERROR requires FRESH evidence: error lines that are new since the
        # last poll. A stale error line still visible in pane history while
        # the agent is working (or recovered) must not flip state to ERROR.
        snap="$PER_PANE_DIR/$alias.tail"
        fresh=$(printf '%s\n' "$tail_out" | fresh_error_lines "$snap")
        if [ -n "$fresh" ] && [ "$prev_state" != "ERROR" ]; then
          log PANE "$alias ERROR (from $prev_state)"
          notify_error "$alias" "$tail_out" "$fresh"
          state_set "$alias" state ERROR
          state_set "$alias" prev_state "$prev_state"
          state_set "$alias" last_state_change "$now_ts"
          state_set "$alias" notified "error_$hash"
        elif [ -z "$fresh" ]; then
          log PANE "$alias error-signal stale (no fresh evidence) — staying $prev_state"
        fi
        ;;
      IDLE|UNKNOWN)
        # completion: WORKING/STUCK -> IDLE only (dedup: transition-based)
        if [ "$prev_state" = "WORKING" ] || [ "$prev_state" = "STUCK" ]; then
          n=$(state_get "$alias" notified none)
          if [ "$n" != "completed_$chash" ]; then
            log PANE "$alias COMPLETED ($prev_state -> IDLE)"
            notify_completed "$alias" "$tail_out"
            state_set "$alias" notified "completed_$chash"
          fi
        fi
        if [ "$prev_state" != "IDLE" ] && [ "$cls" = "IDLE" ]; then
          log PANE "$alias IDLE (from $prev_state)"
        fi
        state_set "$alias" state IDLE
        state_set "$alias" prev_state "$prev_state"
        state_set "$alias" last_state_change "$now_ts"
        ;;
    esac

    state_set "$alias" last_hash "$hash"
    state_set "$alias" last_content_hash "$chash"
    # per-pane tail snapshot (baseline for fresh-error detection next poll)
    printf '%s\n' "$tail_out" > "$PER_PANE_DIR/$alias.tail"
  done < <(aliases_list)

  # ---- cadence -----------------------------------------------------------
  if [ "$mode" = "on" ]; then
    loop_sleep=$FAST_INTERVAL
  else
    # AUTO: all idle for >= IDLE_WINDOW -> low power; else fast
    last_any_change=$(state_get _global last_activity 0)
    if [ $(( t0 - last_any_change )) -ge "$IDLE_WINDOW" ] && [ "$any_active" = "0" ]; then
      loop_sleep=$SLOW_INTERVAL
    else
      loop_sleep=$FAST_INTERVAL
    fi
  fi
  [ "$any_active" = "1" ] && state_set _global last_activity "$t0"

  if [ "$loop_sleep" != "$prev_loop_sleep" ]; then
    log CADENCE "${loop_sleep}s per poll (mode=$mode active=$any_active)"
    prev_loop_sleep="$loop_sleep"
  fi

  sleep "$loop_sleep"
done