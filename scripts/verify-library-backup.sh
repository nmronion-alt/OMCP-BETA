#!/usr/bin/env bash
set -Eeuo pipefail

ARCHIVE="${1:-backups/OMCP-PANEL-main.zip}"
EXPECTED_ROOT="OMCP-PANEL-main"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "ERROR: Backup archive not found: $ARCHIVE" >&2
  exit 2
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip is required. Install it with: sudo apt-get install -y unzip" >&2
  exit 2
fi

echo "== ZIP integrity =="
unzip -t "$ARCHIVE"

echo
echo "== Required backup files =="
required=(
  "$EXPECTED_ROOT/README.md"
  "$EXPECTED_ROOT/index.html"
  "$EXPECTED_ROOT/install-omcp.sh"
  "$EXPECTED_ROOT/agent/omcp_agent.py"
  "$EXPECTED_ROOT/docs/ARCHITECTURE.md"
  "$EXPECTED_ROOT/DEPLOYMENT-ARCHITECTURE.md"
)
listing="$(unzip -Z1 "$ARCHIVE")"
for item in "${required[@]}"; do
  if ! grep -Fxq "$item" <<<"$listing"; then
    echo "ERROR: Missing from archive: $item" >&2
    exit 1
  fi
  echo "OK  $item"
done

echo
echo "== Archive summary =="
unzip -Z1 "$ARCHIVE" | sed -n '1,80p'
echo
echo "PASS: OMCP backup ZIP is present and its required files are readable."
