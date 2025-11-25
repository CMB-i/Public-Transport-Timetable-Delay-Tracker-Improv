#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config.sh"

TARGET_DATE="${1:-$DATE_TODAY}"

mkdir -p "$REPORT_CSV_DIR" "$REPORT_HTML_DIR" "$REPORT_CHART_DIR" "$LOG_DIR"

DAILY_FILE="$PROCESSED_DIR/delays_${TARGET_DATE}.csv"
if [[ ! -f "$DAILY_FILE" ]]; then
  echo "$(date '+%F %T') [WARN] No processed delay file for $TARGET_DATE" >> "$LOG_FILE"
  exit 0
fi

SUMMARY_CSV="$REPORT_CSV_DIR/summary_${TARGET_DATE}.csv"
ROUTE_STATS_CSV="$REPORT_CSV_DIR/route_stats_${TARGET_DATE}.csv"
HEAVY_CSV="$REPORT_CSV_DIR/heavy_delays_${TARGET_DATE}.csv"

CHART_DATA="$REPORT_CHART_DIR/chart_${TARGET_DATE}.dat"
CHART_IMG="$REPORT_CHART_DIR/chart_${TARGET_DATE}.png"
HTML_REPORT="$REPORT_HTML_DIR/report_${TARGET_DATE}.html"

################################
# 1) Overall summary (CSV)     #
################################
TARGET_DATE="$TARGET_DATE" awk -F',' '
  NR==1 { next }
  {
    total++;
    d = $7 + 0;
    sum += d;

    if (d <= 0) ontime++; else delayed++;

    if (d > 0) {
      sum_delayed += d;
      delayed_only++;
    }
  }
  END {
    if (total == 0) exit;
    ontime_pct   = (ontime * 100.0) / total;
    avg_all      = sum / total;
    avg_delayed  = (delayed_only > 0) ? (sum_delayed / delayed_only) : 0;

    print "date,total_trips,on_time_trips,delayed_trips,on_time_percent,avg_delay_minutes,avg_delay_delayed_only";
    printf "%s,%d,%d,%d,%.2f,%.2f,%.2f\n",
           ENVIRON["TARGET_DATE"], total, ontime, delayed, ontime_pct, avg_all, avg_delayed;
  }
' "$DAILY_FILE" > "$SUMMARY_CSV"

echo "$(date '+%F %T') [INFO] Wrote summary CSV $SUMMARY_CSV" >> "$LOG_FILE"

###########################################
# 2) Per-route stats + chart data (CSV)   #
###########################################

# 2a) Per-route average delay (for gnuplot)
awk -F',' '
  NR==1 { next }
  {
    r = $2;
    d = $7 + 0;
    c[r]++; s[r] += d;
  }
  END {
    for (r in c) {
      printf "%s %f\n", r, s[r]/c[r];
    }
  }
' "$DAILY_FILE" > "$CHART_DATA"

if [[ ! -s "$CHART_DATA" ]]; then
  echo "$(date '+%F %T') [WARN] No chart data for $TARGET_DATE" >> "$LOG_FILE"
  exit 0
fi

# 2b) Rich per-route stats table (CSV)
awk -F',' '
  NR==1 { next }
  {
    route = $2;
    delay = $7 + 0;
    trips[route]++;
    sum_delay[route] += delay;

    if (delay <= 0) ontime[route]++; else delayed[route]++;

    if ($8 + 0 == 1) heavy[route]++;
  }
  END {
    print "route_id,total_trips,on_time_trips,delayed_trips,heavy_delays,avg_delay";
    for (r in trips) {
      avg = (trips[r] > 0) ? (sum_delay[r] / trips[r]) : 0;
      printf "%s,%d,%d,%d,%d,%.2f\n",
             r, trips[r], (ontime[r] + 0), (delayed[r] + 0), (heavy[r] + 0), avg;
    }
  }
' "$DAILY_FILE" > "$ROUTE_STATS_CSV"

# 2c) Heavy-delay trips table (CSV)
awk -F',' '
  NR==1 { next }
  $8 + 0 == 1 {
    # date,route_id,vehicle_id,stop_id,scheduled_arrival,actual_arrival,delay_minutes,is_heavily_delayed
    printf "%s,%s,%s,%s,%s,%s,%s\n", $1, $2, $3, $4, $5, $6, $7;
  }
' "$DAILY_FILE" > "$HEAVY_CSV"

################################
# 3) gnuplot chart (PNG)       #
################################

gnuplot <<EOF
set terminal png size 800,600
set output "$CHART_IMG"
set title "Average Delay per Route ($TARGET_DATE)"
set xlabel "Route ID"
set ylabel "Average Delay (minutes)"
set style data histograms
set style fill solid
set boxwidth 0.9
plot "$CHART_DATA" using 2:xtic(1) title "Avg Delay"
EOF

echo "$(date '+%F %T') [INFO] Generated chart $CHART_IMG" >> "$LOG_FILE"

################################
# 4) HTML report (rich)        #
################################

# 4a) Header + styles
cat > "$HTML_REPORT" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Daily Punctuality Report - $TARGET_DATE</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.5; }
    h1 { margin-bottom: 0.2rem; }
    h2 { margin-top: 1.5rem; margin-bottom: 0.5rem; }
    p.note { font-size: 0.9rem; color: #555; margin-top: 0; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 1.5rem; }
    th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: center; font-size: 0.9rem; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) td { background-color: #fafafa; }
    img { max-width: 100%; height: auto; border: 1px solid #ddd; padding: 4px; background: #fff; }
    .chips { margin-bottom: 1rem; }
    .chip {
      display: inline-block;
      padding: 4px 10px;
      margin: 2px 4px;
      border-radius: 999px;
      background-color: #f0f0f0;
      font-size: 0.8rem;
    }
  </style>
</head>
<body>
  <h1>Daily Punctuality Report – $TARGET_DATE</h1>
EOF

################################
# 4b) Overall summary section  #
################################

# summary chips (quick stats)
read _summary_header _summary_line < <(printf "%s\n%s\n" "$(head -n1 "$SUMMARY_CSV")" "$(tail -n1 "$SUMMARY_CSV")")
IFS=',' read -r _d _total _ontime _delayed _pct _avg_all _avg_delayed <<< "$_summary_line"

cat >> "$HTML_REPORT" <<EOF
  <div class="chips">
    <span class="chip">Total trips: $_total</span>
    <span class="chip">On-time: $_ontime</span>
    <span class="chip">Delayed: $_delayed</span>
    <span class="chip">On-time %: $_pct%</span>
    <span class="chip">Avg delay (all): $_avg_all min</span>
    <span class="chip">Avg delay (delayed only): $_avg_delayed min</span>
  </div>

  <h2>1. Overall Summary</h2>
  <p class="note">System-wide punctuality metrics calculated across all trips on $TARGET_DATE.</p>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Total Trips</th>
        <th>On-time Trips</th>
        <th>Delayed Trips</th>
        <th>On-time %</th>
        <th>Avg Delay (min)</th>
        <th>Avg Delay (Delayed only)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>$_d</td>
        <td>$_total</td>
        <td>$_ontime</td>
        <td>$_delayed</td>
        <td>$_pct</td>
        <td>$_avg_all</td>
        <td>$_avg_delayed</td>
      </tr>
    </tbody>
  </table>
EOF

################################
# 4c) Chart section            #
################################

cat >> "$HTML_REPORT" <<EOF
  <h2>2. Average Delay per Route</h2>
  <p class="note">Each bar shows the mean delay (in minutes) across all trips on that route.</p>
  <img src="../charts/$(basename "$CHART_IMG")" alt="Average Delay per Route chart">
EOF

################################
# 4d) Per-route stats table    #
################################

cat >> "$HTML_REPORT" <<EOF
  <h2>3. Route-level Performance</h2>
  <p class="note">Breakdown of punctuality by route: on-time vs delayed counts, heavy delays, and average delay.</p>
  <table>
    <thead>
      <tr>
        <th>Route ID</th>
        <th>Total Trips</th>
        <th>On-time Trips</th>
        <th>Delayed Trips</th>
        <th>Heavily Delayed (&gt;$DELAY_THRESHOLD_ALERT min)</th>
        <th>Avg Delay (min)</th>
      </tr>
    </thead>
    <tbody>
EOF

tail -n +2 "$ROUTE_STATS_CSV" | while IFS=',' read -r route total ontime delayed heavy avg; do
  [ -z "$route" ] && continue
  cat >> "$HTML_REPORT" <<ROW
      <tr>
        <td>$route</td>
        <td>$total</td>
        <td>$ontime</td>
        <td>$delayed</td>
        <td>$heavy</td>
        <td>$avg</td>
      </tr>
ROW
done

cat >> "$HTML_REPORT" <<EOF
    </tbody>
  </table>
EOF

################################
# 4e) Heavy delays table       #
################################

if [[ -s "$HEAVY_CSV" ]]; then
  cat >> "$HTML_REPORT" <<EOF
  <h2>4. Heavily Delayed Trips (&gt;$DELAY_THRESHOLD_ALERT minutes)</h2>
  <p class="note">Trips where the delay exceeded the configured alert threshold of $DELAY_THRESHOLD_ALERT minutes.</p>
  <table>
    <thead>
      <tr>
        <th>Date</th>
        <th>Route</th>
        <th>Vehicle</th>
        <th>Stop</th>
        <th>Scheduled Arrival</th>
        <th>Actual Arrival</th>
        <th>Delay (min)</th>
      </tr>
    </thead>
    <tbody>
EOF

  tail -n +1 "$HEAVY_CSV" | while IFS=',' read -r d route veh stop sched act delay; do
    cat >> "$HTML_REPORT" <<ROW
      <tr>
        <td>$d</td>
        <td>$route</td>
        <td>$veh</td>
        <td>$stop</td>
        <td>$sched</td>
        <td>$act</td>
        <td>$delay</td>
      </tr>
ROW
  done

  cat >> "$HTML_REPORT" <<EOF
    </tbody>
  </table>
EOF
fi

################################
# 4f) Footer                   #
################################

cat >> "$HTML_REPORT" <<EOF
</body>
</html>
EOF

echo "$(date '+%F %T') [INFO] Generated HTML report $HTML_REPORT" >> "$LOG_FILE"
