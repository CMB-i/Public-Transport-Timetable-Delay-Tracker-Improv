#!/usr/bin/env bash

# ---- BASE PATHS ----
BASE_DIR="/Users/devbayana/Desktop/train-timetable-tracker"  # <- change on other machines

DATA_DIR="$BASE_DIR/data"
LIVE_DIR="$DATA_DIR/live"
PROCESSED_DIR="$DATA_DIR/processed"

REPORT_DIR="$BASE_DIR/reports"
REPORT_CSV_DIR="$REPORT_DIR/csv"
REPORT_HTML_DIR="$REPORT_DIR/html"
REPORT_CHART_DIR="$REPORT_DIR/charts"

LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/app.log"

TIMETABLE_CSV="$DATA_DIR/timetable.csv"

# ---- INPUT DELAY JSON (no real API, just local file) ----
# This is your "seed" JSON we copy & randomize from.
DELAY_SEED_JSON="$LIVE_DIR/delays_seed.json"

# Delay threshold (minutes)
DELAY_THRESHOLD_ALERT=15

# Email settings (can be dummy for demo)
ALERT_RECIPIENTS="ops-team@example.com"
MAIL_SUBJECT_PREFIX="[Delay Alert]"

# Today’s date in a portable way (works on mac + linux)
DATE_TODAY="$(date +%Y-%m-%d)"
