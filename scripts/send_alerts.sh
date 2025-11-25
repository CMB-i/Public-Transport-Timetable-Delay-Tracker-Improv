#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/config.sh"

DAILY_FILE="$PROCESSED_DIR/delays_${DATE_TODAY}.csv"
if [[ ! -f "$DAILY_FILE" ]]; then
  echo "$(date '+%F %T') [WARN] No processed delay file for alerts on $DATE_TODAY" >> "$LOG_FILE"
  exit 0
fi

TMP_ALERT=$(mktemp)

awk -F',' -v threshold="$DELAY_THRESHOLD_ALERT" '
  NR==1 { next }
  {
    delay = $7 + 0;
    is_heavy = $8 + 0;
    if (is_heavy == 1) {
      print $0;
    }
  }
' "$DAILY_FILE" > "$TMP_ALERT"

if [[ ! -s "$TMP_ALERT" ]]; then
  echo "$(date '+%F %T') [INFO] No heavily delayed routes today" >> "$LOG_FILE"
  rm -f "$TMP_ALERT"
  exit 0
fi

# Build email body nicely
BODY=$(awk -F',' '
  NR==1 { next }
  {
    printf("Route: %s | Vehicle: %s | Stop: %s | Scheduled: %s | Actual: %s | Delay: %s min\n",
           $2, $3, $4, $5, $6, $7);
  }
' "$TMP_ALERT")

echo "$BODY" | mail -s "$MAIL_SUBJECT_PREFIX Heavy delays detected on $DATE_TODAY" "$ALERT_RECIPIENTS"

echo "$(date '+%F %T') [INFO] Sent delay alerts" >> "$LOG_FILE"

rm -f "$TMP_ALERT"
