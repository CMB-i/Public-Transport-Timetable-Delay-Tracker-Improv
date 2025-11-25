#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config.sh"

echo "=========================="
echo "   RESET + FULL RUN"
echo "=========================="

echo "[1] Cleaning old outputs..."

# DO NOT delete delays_seed.json
find "$LIVE_DIR" -maxdepth 1 -type f -name "delays_*.json" ! -name "delays_seed.json" -delete
find "$LIVE_DIR" -maxdepth 1 -type f -name "delays_*.csv" -delete

rm -f "$PROCESSED_DIR"/delays_*.csv || true
rm -f "$REPORT_CSV_DIR"/summary_*.csv || true
rm -f "$REPORT_CHART_DIR"/chart_*.dat || true
rm -f "$REPORT_CHART_DIR"/chart_*.png || true
rm -f "$REPORT_HTML_DIR"/report_*.html || true

echo "[OK] All old generated files removed — seed JSON preserved."

echo
echo "[2] Fetching delays from seed JSON..."
"$BASE_DIR/scripts/fetch_delays.sh"
echo "[OK] Live delays CSV & JSON generated."

echo
echo "[3] Computing delays..."
"$BASE_DIR/scripts/compute_delays.sh"
echo "[OK] Processed delays created under $PROCESSED_DIR"

echo
echo "[4] Generating reports..."
"$BASE_DIR/scripts/generate_reports.sh" "$DATE_TODAY"
echo "[OK] Reports generated."

echo
echo "=========================="
echo "ALL DONE!"
echo "Your files are here:"
echo "  Processed CSV:  $PROCESSED_DIR/delays_${DATE_TODAY}.csv"
echo "  Summary CSV:    $REPORT_CSV_DIR/summary_${DATE_TODAY}.csv"
echo "  Chart PNG:      $REPORT_CHART_DIR/chart_${DATE_TODAY}.png"
echo "  HTML Report:    $REPORT_HTML_DIR/report_${DATE_TODAY}.html"
echo "=========================="
