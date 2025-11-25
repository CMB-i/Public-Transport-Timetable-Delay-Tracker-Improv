#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config.sh"

mkdir -p "$PROCESSED_DIR" "$LOG_DIR"

# Find latest live delay CSV
LATEST_DELAY_CSV="$(ls -1t "$LIVE_DIR"/delays_*.csv | head -n 1 || true)"

if [[ -z "${LATEST_DELAY_CSV:-}" || ! -f "$LATEST_DELAY_CSV" ]]; then
  echo "$(date '+%F %T') [WARN] No delay CSV found" >> "$LOG_FILE"
  exit 0
fi

OUTPUT_DAILY="$PROCESSED_DIR/delays_${DATE_TODAY}.csv"

# If file doesn't exist, create header
if [[ ! -f "$OUTPUT_DAILY" ]]; then
  echo "date,route_id,vehicle_id,stop_id,scheduled_arrival,actual_arrival,delay_minutes,is_heavily_delayed" > "$OUTPUT_DAILY"
fi

TMP_TIMETABLE=$(mktemp)
TMP_DELAYS=$(mktemp)

# Sort both by route,vehicle,stop
tail -n +2 "$TIMETABLE_CSV" | sort -t',' -k1,1 -k2,2 -k3,3 > "$TMP_TIMETABLE"
tail -n +2 "$LATEST_DELAY_CSV" | sort -t',' -k1,1 -k2,2 -k3,3 > "$TMP_DELAYS"

awk -F',' -v OFS=',' -v threshold="$DELAY_THRESHOLD_ALERT" -v date_today="$DATE_TODAY" '
  FNR==NR {
    # delays: route,vehicle,stop,actual_arrival,delay_minutes (we’ll recompute anyway)
    key = $1 "|" $2 "|" $3
    actual[key] = $4
    next
  }
  {
    # timetable: route,vehicle,stop,stop_name,scheduled_arrival
    route = $1; veh = $2; stop = $3; stop_name = $4; sched = $5
    key = route "|" veh "|" stop
    if (key in actual) {
      act = actual[key]

      # Extract HH:MM from "YYYY-MM-DD HH:MM" and "YYYY-MM-DDTHH:MM:SS"
      # sched: last field is HH:MM
      split(sched, a, " ")
      split(a[2], sh, ":")
      shh = sh[1] + 0
      smm = sh[2] + 0

      # act: after "T", we get HH:MM:SS
      split(act, b, "T")
      split(b[2], ah, ":")
      ahh = ah[1] + 0
      amm = ah[2] + 0

      sched_min = shh*60 + smm
      actual_min = ahh*60 + amm
      delay = actual_min - sched_min

      is_heavy = (delay > threshold) ? 1 : 0

      print date_today, route, veh, stop, sched, act, delay, is_heavy
    }
  }
' "$TMP_DELAYS" "$TMP_TIMETABLE" >> "$OUTPUT_DAILY"

rm -f "$TMP_TIMETABLE" "$TMP_DELAYS"

echo "$(date '+%F %T') [INFO] Computed delays into $OUTPUT_DAILY from $LATEST_DELAY_CSV" >> "$LOG_FILE"
