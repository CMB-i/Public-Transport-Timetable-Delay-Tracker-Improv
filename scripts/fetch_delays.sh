#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config.sh"

mkdir -p "$LIVE_DIR" "$LOG_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RAW_JSON="$LIVE_DIR/delays_${TIMESTAMP}.json"
NORM_CSV="$LIVE_DIR/delays_${TIMESTAMP}.csv"

# 1) Copy seed JSON (simulating "API fetch")
cp "$DELAY_SEED_JSON" "$RAW_JSON"

# (Optional) simple randomization of delay_minutes per run
# This keeps things interesting but avoids crazy date logic.
# We keep actual_arrival fixed; this is enough for the assignment.
tmp_rand=$(mktemp)
jq '
  map(
    .delay_minutes = (.delay_minutes + ([-3,-2,-1,0,1,2,3][] | . * (now|floor|.[0:1]? // 1)%2 | .))
  )
' "$RAW_JSON" > "$tmp_rand" || cp "$RAW_JSON" "$tmp_rand"
mv "$tmp_rand" "$RAW_JSON"

# 2) Normalize JSON to CSV (UNQUOTED, so awk joins cleanly)
jq -r '
  "route_id,vehicle_id,stop_id,actual_arrival,delay_minutes",
  (.[] | "\(.route_id),\(.vehicle_id),\(.stop_id),\(.actual_arrival),\(.delay_minutes)")
' "$RAW_JSON" > "$NORM_CSV"

echo "$(date '+%F %T') [INFO] Fetched (from seed) -> $RAW_JSON, normalized -> $NORM_CSV" >> "$LOG_FILE"
