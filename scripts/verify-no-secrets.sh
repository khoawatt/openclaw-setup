#!/usr/bin/env bash
# Safety check: make sure no real secrets leaked into this repo before push.
# Scans template/config files and shell scripts for credential-shaped values.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== placeholder tokens present (expected: >0) ==="
PH=$(grep -rhoE "__[A-Z_]+__" --include="*.example" --include="*.sh" . 2>/dev/null | sort -u | wc -l)
echo "$PH unique placeholders"

echo "=== assignment-shape secrets scan (must be ZERO real values) ==="
# Only look at lines shaped like KEY=value or JSON "key": "value".
# Skip: our own script (contains the pattern), comment lines, placeholder values.
BAD=$(grep -rnE '(=|: ?")[A-Za-z0-9_\-]{20,}' --include="*.example" --include="*.sh" \
  --include="*.env.example" --exclude-dir=.git . 2>/dev/null \
  | grep -v "verify-no-secrets.sh" \
  | grep -vE "__[A-Z_]+__|#[[:space:]]|openssl rand|chmod 600|placeholder" || true)
if [ -n "$BAD" ]; then
  echo "❌ Possible secret leak:"
  echo "$BAD"
  exit 1
fi
echo "✅ no assignment-shaped secrets found"

echo "=== known real secret values (Brave key prefix) — must be ZERO ==="
grep -rn "BSAmJl" --include="*.example" --include="*.sh" --include="*.md" --exclude-dir=.git . 2>/dev/null \
  | grep -v "verify-no-secrets.sh" \
  && { echo "❌ LEAK"; exit 1; } || echo "✅ clean"

echo "=== ignored real-config paths ==="
for f in openclaw.json watcher/conf/telegram.env; do
  git check-ignore "$f" >/dev/null 2>&1 && echo "✅ $f ignored" || echo "⚠️ $f NOT ignored"
done
exit 0