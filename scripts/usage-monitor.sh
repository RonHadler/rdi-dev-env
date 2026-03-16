#!/bin/bash
#
# rdi-dev-env — Usage Monitor
#
# Tracks Claude Max subscription message usage within the 5-hour
# rolling window. Counts assistant messages across all project
# conversation JSONLs.
#
# Usage:
#   usage-monitor.sh status          # Dashboard with progress bar
#   usage-monitor.sh check           # Exit 0=ok, 1=low, 2=critical
#   usage-monitor.sh can-afford N    # Can we afford N more messages?
#   usage-monitor.sh json            # Machine-readable output
#
# Exit codes (check/can-afford):
#   0 = OK (>25% of effective limit remaining)
#   1 = LOW (10-25% remaining)
#   2 = CRITICAL (<10% remaining)
#
# Config (env vars):
#   USAGE_PLAN        max_5x | max_20x (default: max_5x)
#   USAGE_5H_LIMIT    messages per 5-hour window (default: 225)
#   USAGE_SAFETY_PCT  % reserved for interactive use (default: 20)
#   CLAUDE_DIR        Claude config directory (default: ~/.claude)
#

set -uo pipefail

# ── Config ────────────────────────────────────────────────────
USAGE_PLAN="${USAGE_PLAN:-max_5x}"
USAGE_SAFETY_PCT="${USAGE_SAFETY_PCT:-20}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

# Set default limit based on plan
case "$USAGE_PLAN" in
  max_20x) DEFAULT_LIMIT=900 ;;
  max_5x|*) DEFAULT_LIMIT=225 ;;
esac
USAGE_5H_LIMIT="${USAGE_5H_LIMIT:-$DEFAULT_LIMIT}"

WINDOW_MINUTES=300  # 5 hours

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Core: count messages in window ────────────────────────────
count_messages_in_window() {
  local window_minutes="$1"
  local cutoff_iso
  cutoff_iso=$(date -u -d "-${window_minutes} minutes" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null) || \
  cutoff_iso=$(date -u -v-"${window_minutes}M" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null) || {
    echo "0"
    return
  }

  local count=0
  # Only scan files modified within the window (fast filter)
  while IFS= read -r f; do
    local c
    c=$(grep '"role":"assistant"' "$f" 2>/dev/null | \
        grep -o '"timestamp":"[^"]*"' | \
        awk -F'"' -v cutoff="$cutoff_iso" '$4 >= cutoff {n++} END {print n+0}')
    count=$((count + c))
  done < <(find "$CLAUDE_DIR/projects" -name '*.jsonl' -mmin "-${window_minutes}" 2>/dev/null)

  echo "$count"
}

# ── Compute budget stats ─────────────────────────────────────
compute_stats() {
  local used
  used=$(count_messages_in_window "$WINDOW_MINUTES")

  local effective_limit
  effective_limit=$(( USAGE_5H_LIMIT - (USAGE_5H_LIMIT * USAGE_SAFETY_PCT / 100) ))

  local remaining
  remaining=$(( effective_limit - used ))
  [ "$remaining" -lt 0 ] && remaining=0

  local pct_used=0
  if [ "$USAGE_5H_LIMIT" -gt 0 ]; then
    pct_used=$(( used * 100 / USAGE_5H_LIMIT ))
  fi

  local pct_of_effective=0
  if [ "$effective_limit" -gt 0 ]; then
    pct_of_effective=$(( (effective_limit - remaining) * 100 / effective_limit ))
  fi

  local remaining_pct=0
  if [ "$effective_limit" -gt 0 ]; then
    remaining_pct=$(( remaining * 100 / effective_limit ))
  fi

  # Determine status
  local status="OK"
  local exit_code=0
  if [ "$remaining_pct" -lt 10 ]; then
    status="CRITICAL"
    exit_code=2
  elif [ "$remaining_pct" -lt 25 ]; then
    status="LOW"
    exit_code=1
  fi

  # Export for callers
  STAT_USED="$used"
  STAT_LIMIT="$USAGE_5H_LIMIT"
  STAT_EFFECTIVE="$effective_limit"
  STAT_REMAINING="$remaining"
  STAT_PCT_USED="$pct_used"
  STAT_PCT_EFFECTIVE="$pct_of_effective"
  STAT_REMAINING_PCT="$remaining_pct"
  STAT_STATUS="$status"
  STAT_EXIT_CODE="$exit_code"
}

# ── Progress bar ──────────────────────────────────────────────
progress_bar() {
  local pct="$1"
  local width=20
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled="$width"
  local empty=$(( width - filled ))

  local bar=""
  local color="$GREEN"
  [ "$pct" -ge 60 ] && color="$YELLOW"
  [ "$pct" -ge 85 ] && color="$RED"

  local i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done

  echo -e "${color}${bar}${NC}"
}

# ── Commands ──────────────────────────────────────────────────

cmd_status() {
  compute_stats

  local bar
  bar=$(progress_bar "$STAT_PCT_USED")

  local status_color="$GREEN"
  [ "$STAT_STATUS" = "LOW" ] && status_color="$YELLOW"
  [ "$STAT_STATUS" = "CRITICAL" ] && status_color="$RED"

  echo -e "${BOLD}Claude Max Usage Monitor (${USAGE_PLAN})${NC}"
  echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "5-hour window:   ${bar}  ${STAT_USED}/${STAT_LIMIT} messages (${STAT_PCT_USED}%)"
  echo -e "Effective limit: ${STAT_EFFECTIVE} (${USAGE_SAFETY_PCT}% reserved for interactive use)"
  echo -e "Remaining:       ${STAT_REMAINING} messages"
  echo -e "Status:          ${status_color}${BOLD}${STAT_STATUS}${NC}"
}

cmd_check() {
  compute_stats
  return "$STAT_EXIT_CODE"
}

cmd_can_afford() {
  local requested="${1:-1}"
  compute_stats

  if [ "$STAT_REMAINING" -ge "$requested" ]; then
    # Still check status thresholds
    return "$STAT_EXIT_CODE"
  else
    # Can't afford it
    return 2
  fi
}

cmd_json() {
  compute_stats
  cat <<EOF
{
  "plan": "$USAGE_PLAN",
  "window_minutes": $WINDOW_MINUTES,
  "used": $STAT_USED,
  "limit": $STAT_LIMIT,
  "effective_limit": $STAT_EFFECTIVE,
  "remaining": $STAT_REMAINING,
  "pct_used": $STAT_PCT_USED,
  "remaining_pct": $STAT_REMAINING_PCT,
  "status": "$STAT_STATUS",
  "safety_pct": $USAGE_SAFETY_PCT
}
EOF
}

# ── Main ──────────────────────────────────────────────────────
case "${1:-status}" in
  status)     cmd_status ;;
  check)      cmd_check; exit $? ;;
  can-afford) cmd_can_afford "${2:-1}"; exit $? ;;
  json)       cmd_json ;;
  -h|--help)
    echo "Usage: $(basename "$0") {status|check|can-afford N|json}"
    echo ""
    echo "Commands:"
    echo "  status       Dashboard with progress bar (default)"
    echo "  check        Exit 0=ok, 1=low, 2=critical"
    echo "  can-afford N Can we afford N more messages?"
    echo "  json         Machine-readable output"
    echo ""
    echo "Config (env vars):"
    echo "  USAGE_PLAN=$USAGE_PLAN  USAGE_5H_LIMIT=$USAGE_5H_LIMIT"
    echo "  USAGE_SAFETY_PCT=$USAGE_SAFETY_PCT  CLAUDE_DIR=$CLAUDE_DIR"
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Usage: $(basename "$0") {status|check|can-afford N|json}" >&2
    exit 1
    ;;
esac
