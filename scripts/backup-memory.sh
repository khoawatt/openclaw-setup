#!/usr/bin/env bash
# backup-memory.sh — back up the PERSONAL memory layer of an OpenClaw agent.
#
# This creates a standalone tar.gz so a fresh install can restore continuity
# (chat logs, decisions, identity/user notes). The archive is NEVER committed
# to the repo — keep it somewhere private (local disk, personal drive).
#
# Usage:
#   ./scripts/backup-memory.sh                  # -> ~/openclaw-memory-YYYYMMDD-HHMMSS.tar.gz
#   ./scripts/backup-memory.sh /path/out.tar.gz # custom destination
set -u

WORKSPACE="${OCW_HOME:-$HOME/.openclaw}/workspace"
OUT="${1:-$HOME/openclaw-memory-$(date +%Y%m%d-%H%M%S).tar.gz}"

[ -d "$WORKSPACE" ] || { echo "!! workspace not found: $WORKSPACE" >&2; exit 1; }

echo "==> Backing up memory layer from $WORKSPACE"
echo "    -> $OUT"

tar -czf "$OUT" \
  -C "$WORKSPACE" \
  memory/ \
  MEMORY.md \
  USER.md \
  IDENTITY.md \
  openclaw-workspace-state.json \
  2>/dev/null

chmod 600 "$OUT"
echo "==> Done: $(ls -lh "$OUT" | awk '{print $5}')  $OUT"
echo "    Restore on new machine:  MEMORY_BACKUP=$OUT ./setup.sh"
echo "    (or: tar -xzf $OUT -C ~/.openclaw/workspace/)"