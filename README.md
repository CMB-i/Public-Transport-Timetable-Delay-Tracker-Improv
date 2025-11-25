# Public-Transport-Timetable-Delay-Tracker-Improv

Shell-based mini-pipeline to process bus/train timetables and live delay data, compute punctuality metrics, and generate daily HTML reports with charts.

> **Assignment mapping**
> - Ingest timetable data (CSV) 
> - Ingest live delay feed (JSON, simulated via local file + `jq`) 
> - Compare scheduled vs actual arrival → delay minutes 
> - Flag vehicles delayed beyond threshold (e.g., > 15 min) 
> - Generate daily summary report (CSV + HTML with chart) 
> - Email alerts for heavily delayed routes  
> - Maintain logs + can be wired to `cron` for automation 

---

# 1. Tech Stack

- **Shell**: `bash`
- **Data wrangling**: `awk`, `jq`
- **Charts**: `gnuplot` (PNG bar chart)
- **Scheduling** (optional): `cron`
- **Email** (optional): `mail` / `mailx` (depends on system)

Tested on:

- macOS (zsh + Homebrew)
- Linux (bash)

---

# 2. Repository Structure

```text
train-timetable-tracker/
├── config.sh
├── scripts/
│   ├── fetch_delays.sh        # JSON → CSV from seed delays (simulated API)
│   ├── compute_delays.sh      # join timetable + live delays, compute delay minutes
│   ├── generate_reports.sh    # summary CSVs + charts + rich HTML report
│   ├── send_alerts.sh         # email heavily delayed trips (optional)
│   ├── rotate_logs.sh         # (optional) rotate logs
│   ├── run_daily.sh           # daily pipeline (for cron)
│   └── reset_and_run.sh       # clean + run full pipeline (one command)
├── data/
│   ├── timetable.csv          # INPUT: scheduled timetable (you edit this)
│   ├── live/
│   │   └── delays_seed.json   # INPUT: base JSON delays (simulated API feed)
│   └── processed/
│       └── delays_<DATE>.csv  # OUTPUT: merged + computed delays
├── reports/
│   ├── csv/
│   │   ├── summary_<DATE>.csv       # OUTPUT: global stats
│   │   ├── route_stats_<DATE>.csv   # OUTPUT: per-route stats
│   │   └── heavy_delays_<DATE>.csv  # OUTPUT: heavily delayed trips
│   ├── charts/
│   │   ├── chart_<DATE>.dat         # OUTPUT: gnuplot data
│   │   └── chart_<DATE>.png         # OUTPUT: chart image (avg delay / route)
│   └── html/
│       └── report_<DATE>.html       # OUTPUT: main daily report
├── logs/
│   └── app.log                # pipeline logs
└── cron/
    └── crontab.example        # sample cron entries
```
---

# 3. Input Data

## 3.1 Timetable (data/timetable.csv)

Schedule for each vehicle and stop:

```text
route_id,vehicle_id,stop_id,stop_name,scheduled_arrival
B10,BUS100,ST01,Central Station,2025-11-15 08:00
B10,BUS100,ST02,Park Lane,2025-11-15 08:15
...
T1,TRAIN02,ST52,Industrial Zone,2025-11-15 10:50
```

You can edit this file to add more routes / vehicles / stops.

## 3.2 Delay Feed (data/live/delays_seed.json)

Simulated “live” delay feed (replaces real API). Example:

```text
[
  {
    "route_id": "B10",
    "vehicle_id": "BUS100",
    "stop_id": "ST01",
    "actual_arrival": "2025-11-15T08:02:00",
    "delay_minutes": 2
  },
  {
    "route_id": "B10",
    "vehicle_id": "BUS100",
    "stop_id": "ST02",
    "actual_arrival": "2025-11-15T08:17:00",
    "delay_minutes": 2
  }
  // ...
]
```

Note: In a “real” deployment, fetch_delays.sh would call an external API with curl. For this assignment we simulate the API by copying this local seed JSON and converting it to CSV via jq.


---

# 4. Setup

## 4.1 Clone and enter the repo

```text
git clone <your-repo-url>.git
cd train-timetable-tracker
```

## 4.2 Install dependencies

macOS (Homebrew)
```text
brew install jq gnuplot
# For email alerts (optional)
brew install mailutils   # or configure a mailer that provides `mail`/`mailx`
```

Ubuntu / Debian
```text
sudo apt-get update
sudo apt-get install -y jq gnuplot mailutils
```

## 4.3 Configure config.sh

Open config.sh and update BASE_DIR to your local clone path:

```text
BASE_DIR="/absolute/path/to/train-timetable-tracker"
```

Other important config values:

```text
TIMETABLE_CSV="$DATA_DIR/timetable.csv"     # timetable input
DELAY_SEED_JSON="$LIVE_DIR/delays_seed.json"  # simulated API JSON

DELAY_THRESHOLD_ALERT=15                   # minutes; heavy delay threshold

ALERT_RECIPIENTS="ops-team@example.com"   # for send_alerts.sh (optional)
MAIL_SUBJECT_PREFIX="[Delay Alert]"
```

DATE_TODAY is automatically set from the system date:
```text
DATE_TODAY="$(date +%Y-%m-%d)"
```

You usually don’t need to touch this unless you want to regenerate reports for a past date.

## 4.4 Make scripts executable

```text
chmod +x scripts/*.sh
```

---

# 5. Quick Start: One-Command Run

From the repo root:
```text
./scripts/reset_and_run.sh
```

This script will:
1. Clean old outputs (but keep data/live/delays_seed.json)
2. Fetch delays from the seed JSON and generate a timestamped CSV
3. Compute delays into data/processed/delays_<DATE>.csv
4. Generate reports:
  - CSV summaries under reports/csv/
  - chart PNG under reports/charts/
  - HTML report under reports/html/

You’ll see something like:
```text
ALL DONE!
Your files are here:
  Processed CSV:  data/processed/delays_2025-11-25.csv
  Summary CSV:    reports/csv/summary_2025-11-25.csv
  Chart PNG:      reports/charts/chart_2025-11-25.png
  HTML Report:    reports/html/report_2025-11-25.html
```

Open the report in a browser:
```text
open reports/html/report_2025-11-25.html     # macOS
# or
xdg-open reports/html/report_2025-11-25.html # Linux
```
---

# 6. What the Pipeline Produces
## 6.1 Processed delays (data/processed/delays_<DATE>.csv)

Merged from timetable + live delays:
```text
date,route_id,vehicle_id,stop_id,scheduled_arrival,actual_arrival,delay_minutes,is_heavily_delayed
2025-11-25,B10,BUS101,ST01,2025-11-25 09:00,2025-11-25T09:12:00,12,0
...
```

delay_minutes = “actual − scheduled” in minutes (can be negative for early)

is_heavily_delayed = 1 if delay > DELAY_THRESHOLD_ALERT

## 6.2 Summary stats (reports/csv/summary_<DATE>.csv)
```text
date,total_trips,on_time_trips,delayed_trips,on_time_percent,avg_delay_minutes,avg_delay_delayed_only
2025-11-25,9,2,7,22.22,7.11,9.43
```
## 6.3 Per-route stats (reports/csv/route_stats_<DATE>.csv)
```text
route_id,total_trips,on_time_trips,delayed_trips,heavy_delays,avg_delay
B10,3,1,2,1,8.17
B20,3,0,3,2,17.50
T1,3,1,2,1,8.00
```
## 6.4 Heavy-delay trips (reports/csv/heavy_delays_<DATE>.csv)
```text
2025-11-25,B20,BUS201,ST12,2025-11-25 09:45,2025-11-25T10:20:00,35
...
```
##6.5 Chart (reports/charts/chart_<DATE>.png)

Bar chart: average delay per route for the day.

## 6.6 HTML report (reports/html/report_<DATE>.html)

Sections:
1. Header + quick summary chips (total trips, on-time %, avg delay, etc.)
2. Overall summary table
3. Average delay per route (with embedded PNG chart)
4. Route-level performance table (per-route totals, heavy delays, avg delay)
5. Heavily delayed trips table (only if any exist)
---

# 7. Manual Step-by-Step Run (if you don’t want reset script)

From repo root:
```text
# 1) Generate live delays (from seed JSON)
./scripts/fetch_delays.sh

# 2) Compute delays (creates data/processed/delays_<DATE>.csv)
./scripts/compute_delays.sh

# 3) Generate reports for a specific date
./scripts/generate_reports.sh 2025-11-25
# or just:
./scripts/generate_reports.sh
# which uses DATE_TODAY from config.sh
```
---

#8. Cron Automation (Optional)

Example cron/crontab.example (Linux style):
```text
# Every 5 minutes: fetch delays, compute delays, send alerts
*/5 * * * * /bin/bash /path/to/train-timetable-tracker/scripts/fetch_delays.sh      >/dev/null 2>&1
*/5 * * * * /bin/bash /path/to/train-timetable-tracker/scripts/compute_delays.sh    >/dev/null 2>&1
*/5 * * * * /bin/bash /path/to/train-timetable-tracker/scripts/send_alerts.sh       >/dev/null 2>&1

# Once a day at 23:55: rotate logs and generate daily reports
55 23 * * * /bin/bash /path/to/train-timetable-tracker/scripts/rotate_logs.sh       >/dev/null 2>&1
56 23 * * * /bin/bash /path/to/train-timetable-tracker/scripts/generate_reports.sh  >/dev/null 2>&1

```
To install:
```text
crontab cron/crontab.example
```

Note: Update /path/to/train-timetable-tracker to your actual absolute path.

------

# 9. Troubleshooting

1. HTML report is empty / blank
  - Check that data/processed/delays_<DATE>.csv has more than just the header.
  - If not: run ./scripts/fetch_delays.sh and ./scripts/compute_delays.sh again.
2. gnuplot: command not found
  - Install it (brew install gnuplot or sudo apt-get install gnuplot).
3. jq: command not found
  - Install it (brew install jq or sudo apt-get install jq).
4. No heavy-delay section in HTML
  - That just means no trips exceeded DELAY_THRESHOLD_ALERT.

---
