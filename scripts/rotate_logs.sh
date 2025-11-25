#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/config.sh"

LOG_DIR="$(dirname "$LOG_FILE")"
mkdir -p "$LOG_DIR"

# If current log exists, rotate it
if [[ -f "$LOG_FILE" ]]; then
  ARCHIVE="$LOG_DIR/app_$(date +%Y-%m-%d).log"
  mv "$LOG_FILE" "$ARCHIVE"
  gzip -f "$ARCHIVE"
  echo "$(date '+%F %T') [INFO] [rotate_logs] Rotated log to $ARCHIVE.gz" >> "$LOG_FILE" 2>/dev/null || true
fi

# Start a fresh log file
touch "$LOG_FILE"

# Optional: keep only last 7 archives
ls -1t "$LOG_DIR"/app_*.log.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
