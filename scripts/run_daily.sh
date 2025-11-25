#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/config.sh"

# 1. Rotate logs at start of day
"$BASE_DIR/scripts/rotate_logs.sh"

# 2. Generate daily summary and reports
"$BASE_DIR/scripts/generate_reports.sh"

# 3. Send alerts one final time (optional if you also have a more frequent alert cron)
"$BASE_DIR/scripts/send_alerts.sh"

echo "$(date '+%F %T') [INFO] Completed daily run" >> "$LOG_FILE"
