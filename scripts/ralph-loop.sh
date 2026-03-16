#!/bin/bash
#
# rdi-dev-env — Ralph Loop (Autonomous Task Execution)
#
# Picks tasks from tasks.json, sends them to Claude CLI for implementation,
# runs tests, commits on pass, and creates PRs.
#
# Usage:
#   ralph-loop.sh [options] [tasks.json]
#
# Options:
#   --dry-run           Show what would happen without executing
#   --once              Execute one task and exit
#   --max-iterations N  Maximum loop iterations (default: 10)
#   --no-pr             Skip PR creation at the end
#   --branch NAME       Use specific branch name (default: auto-generated)
#   -h, --help          Show this help message
#
# Safety:
#   - Stop file: touch /tmp/.ralph-stop-<project> to pause at next iteration
#   - Max 3 attempts per task (configurable in tasks.json)
#   - Failed tasks revert all uncommitted changes
#   - Ctrl+C writes clean summary before exiting
#
# Dependencies: claude, git, gh, jq, sed
#

set -uo pipefail

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Defaults ─────────────────────────────────────────────────
DRY_RUN=false
RUN_ONCE=false
MAX_ITERATIONS=10
CREATE_PR=true
USAGE_CHECK=true
BRANCH_NAME=""
TASKS_FILE=""
PROGRESS_LOG=""
PROJECT_NAME=""
PROJECT_TYPE=""
STOP_FILE=""
ITERATION=0
COMPLETED=0
FAILED=0

# ── Usage ────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [tasks.json]

Autonomous task execution loop — picks tasks, implements via Claude CLI,
runs tests, commits on pass, creates PR.

Options:
  --dry-run           Show what would happen without executing
  --once              Execute one task and exit
  --max-iterations N  Maximum loop iterations (default: 10)
  --no-pr             Skip PR creation at the end
  --usage-check       Enable pre-flight usage budget check (default)
  --no-usage-check    Disable usage budget check
  --branch NAME       Use specific branch name (default: auto-generated)
  -h, --help          Show this help message

Safety:
  Stop file:  touch /tmp/.ralph-stop-<project>
  Ctrl+C:     Writes summary before exiting
EOF
  exit 0
}

# ── Argument Parsing ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)       DRY_RUN=true; shift ;;
    --once)          RUN_ONCE=true; shift ;;
    --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --no-pr)         CREATE_PR=false; shift ;;
    --usage-check)   USAGE_CHECK=true; shift ;;
    --no-usage-check) USAGE_CHECK=false; shift ;;
    --branch)        BRANCH_NAME="$2"; shift 2 ;;
    -h|--help)       usage ;;
    -*)              echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    *)               TASKS_FILE="$1"; shift ;;
  esac
done

# ── Logging ──────────────────────────────────────────────────
log() {
  local level="$1"
  shift
  local msg="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  local color=""
  case $level in
    INFO)  color="$CYAN" ;;
    OK)    color="$GREEN" ;;
    WARN)  color="$YELLOW" ;;
    ERROR) color="$RED" ;;
    *)     color="$DIM" ;;
  esac
  echo -e "${color}[$ts] [$level] $msg${NC}"
  if [ -n "$PROGRESS_LOG" ]; then
    echo "[$ts] [$level] $msg" >> "$PROGRESS_LOG"
  fi
}

# ── Dependency Check ─────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in claude git jq; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}Missing required dependencies: ${missing[*]}${NC}"
    echo "Install them and try again."
    exit 1
  fi
  # gh is optional (only needed for PR creation)
  if [ "$CREATE_PR" = true ] && ! command -v gh &>/dev/null; then
    log WARN "gh CLI not found — PR creation will be skipped"
    CREATE_PR=false
  fi
}

# ── Project Detection ────────────────────────────────────────
detect_project_type() {
  if [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
  elif [ -f "package.json" ]; then
    PROJECT_TYPE="node"
  elif [ -f "go.mod" ]; then
    PROJECT_TYPE="go"
  else
    PROJECT_TYPE="unknown"
  fi
}

# ── Task Management (jq-based) ──────────────────────────────

# Get the next pending task with all dependencies resolved
pick_next_task() {
  jq -r '
    .tasks
    | map(select(.status == "completed")) | map(.id) as $completed
    | input.tasks
    | map(select(
        .status == "pending"
        and .attempts < .max_attempts
        and ((.blocked_by // []) - $completed | length) == 0
      ))
    | sort_by(.priority)
    | first
    | .id // empty
  ' "$TASKS_FILE" "$TASKS_FILE" 2>/dev/null
}

# Get a field from a task by ID
get_task_field() {
  local task_id="$1"
  local field="$2"
  jq -r --arg id "$task_id" --arg f "$field" \
    '.tasks[] | select(.id == $id) | .[$f] // empty' "$TASKS_FILE"
}

# Get nested verification field
get_verification_field() {
  local task_id="$1"
  local field="$2"
  jq -r --arg id "$task_id" --arg f "$field" \
    '.tasks[] | select(.id == $id) | .verification[$f] // empty' "$TASKS_FILE"
}

# Update task status and fields
update_task_status() {
  local task_id="$1"
  local status="$2"
  local extra_updates="${3:-}"

  local tmp
  tmp=$(mktemp)

  local jq_filter
  jq_filter='(.tasks[] | select(.id == $id)).status = $status'

  if [ -n "$extra_updates" ]; then
    jq_filter="$jq_filter | $extra_updates"
  fi

  jq --arg id "$task_id" --arg status "$status" "$jq_filter" "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
}

# Increment attempts counter
increment_attempts() {
  local task_id="$1"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" \
    '(.tasks[] | select(.id == $id)).attempts += 1' \
    "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
}

# Store last error
store_last_error() {
  local task_id="$1"
  local error_text="$2"
  # Truncate to ~500 chars to keep tasks.json manageable
  local truncated
  truncated=$(echo "$error_text" | tail -20 | head -c 500)
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" --arg err "$truncated" \
    '(.tasks[] | select(.id == $id)).last_error = $err' \
    "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
}

# Mark task completed with timestamp
mark_completed() {
  local task_id="$1"
  local ts
  ts=$(date -Iseconds)
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" --arg ts "$ts" \
    '(.tasks[] | select(.id == $id)).status = "completed" |
     (.tasks[] | select(.id == $id)).completed_at = $ts' \
    "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
}

# Mark task failed
mark_failed() {
  local task_id="$1"
  local tmp
  tmp=$(mktemp)
  jq --arg id "$task_id" \
    '(.tasks[] | select(.id == $id)).status = "failed"' \
    "$TASKS_FILE" > "$tmp" && mv "$tmp" "$TASKS_FILE"
}

# ── Usage Budget Check ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

preflight_usage_check() {
  local estimated_msgs="${1:-12}"  # avg messages per task
  local monitor="${SCRIPT_DIR}/usage-monitor.sh"

  [ "$USAGE_CHECK" != true ] && return 0
  [ ! -x "$monitor" ] && { log WARN "Usage monitor not found at $monitor"; return 0; }

  "$monitor" can-afford "$estimated_msgs"
  local rc=$?

  case $rc in
    0) log OK "Budget OK — proceeding" ;;
    1)
      log WARN "Budget LOW — pausing 5 min then rechecking..."
      local waited=0
      while [ $waited -lt 3600 ]; do
        sleep 300; waited=$((waited + 300))
        "$monitor" can-afford "$estimated_msgs" && return 0
      done
      log ERROR "Budget did not recover after 1 hour"
      return 1
      ;;
    2) log ERROR "Budget CRITICAL — stopping"; return 1 ;;
  esac
}

# ── Prompt Builder ───────────────────────────────────────────
build_prompt() {
  local task_id="$1"
  local title
  title=$(get_task_field "$task_id" "title")
  local description
  description=$(get_task_field "$task_id" "description")
  local last_error
  last_error=$(get_task_field "$task_id" "last_error")
  local attempts
  attempts=$(get_task_field "$task_id" "attempts")

  local prompt=""

  # Add project context files
  if [ -f "CLAUDE.md" ]; then
    prompt+="## Project Context (CLAUDE.md)
$(cat CLAUDE.md)

"
  fi
  if [ -f "AGENTS.md" ]; then
    prompt+="## Shared Agent Context (AGENTS.md)
$(cat AGENTS.md)

"
  fi

  # Add task
  prompt+="## Current Task: $task_id — $title

$description

## Instructions
1. Implement the task described above following TDD (write tests first, then implementation).
2. Run the test command to verify your changes pass.
3. Do NOT commit — the Ralph Loop will handle committing after tests pass.
4. Make only the changes required for this task. Do not modify unrelated files.
"

  # Add retry context if this is a retry
  if [ -n "$last_error" ] && [ "$last_error" != "null" ] && [ "$last_error" != "" ]; then
    prompt+="
## Previous Attempt Failed (attempt $attempts)
The previous attempt failed with this error output:
\`\`\`
$last_error
\`\`\`
Analyze the error and fix the issue. Do not repeat the same mistake.
"
  fi

  echo "$prompt"
}

# ── Test Runner ──────────────────────────────────────────────
run_tests() {
  local task_id="$1"
  local test_cmd
  test_cmd=$(get_verification_field "$task_id" "test_command")

  # Fall back to auto-detected test command
  if [ -z "$test_cmd" ] || [ "$test_cmd" = "null" ]; then
    case $PROJECT_TYPE in
      python) test_cmd="uv run pytest tests/ -v" ;;
      node)   test_cmd="npm test" ;;
      go)     test_cmd="go test ./..." ;;
      *)      test_cmd="echo 'No test command configured'"; return 1 ;;
    esac
  fi

  log INFO "Running tests: $test_cmd"
  local output
  output=$(bash -c "$test_cmd" 2>&1)
  local exit_code=$?

  if [ $exit_code -eq 0 ]; then
    log OK "Tests passed"
  else
    log ERROR "Tests failed (exit code $exit_code)"
    echo "$output"  # Print full output for debugging
  fi

  # Store output for potential error reporting
  TEST_OUTPUT="$output"
  return $exit_code
}

# ── Git Operations ───────────────────────────────────────────
revert_changes() {
  log WARN "Reverting uncommitted changes..."
  git checkout -- . 2>/dev/null || true
  git clean -fd 2>/dev/null || true
}

commit_task() {
  local task_id="$1"
  local title
  title=$(get_task_field "$task_id" "title")
  local commit_type
  commit_type=$(get_task_field "$task_id" "commit_type")
  commit_type="${commit_type:-feat}"

  # Stage all changes
  git add -A

  # Check if there are changes to commit
  if git diff --cached --quiet; then
    log WARN "No changes to commit for $task_id"
    return 0
  fi

  local commit_msg="${commit_type}: ${title}

Task: ${task_id}
Automated by Ralph Loop

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

  git commit -m "$commit_msg"
  log OK "Committed: ${commit_type}: ${title}"
}

# ── PR Creation ──────────────────────────────────────────────
maybe_create_pr() {
  if [ "$CREATE_PR" = false ]; then
    return 0
  fi

  # Check if we have a remote
  if ! git remote get-url origin &>/dev/null; then
    log WARN "No git remote — skipping PR creation"
    return 0
  fi

  # Check if we have commits ahead of develop/main
  local base_branch="develop"
  if ! git rev-parse --verify "$base_branch" &>/dev/null; then
    base_branch="main"
  fi
  if ! git rev-parse --verify "$base_branch" &>/dev/null; then
    base_branch="master"
  fi

  local current_branch
  current_branch=$(git branch --show-current)

  if [ "$current_branch" = "$base_branch" ]; then
    log WARN "On $base_branch — skipping PR creation"
    return 0
  fi

  # Build PR body from completed tasks
  local completed_tasks
  completed_tasks=$(jq -r '.tasks[] | select(.status == "completed") | "- [x] \(.id): \(.title)"' "$TASKS_FILE")
  local failed_tasks
  failed_tasks=$(jq -r '.tasks[] | select(.status == "failed") | "- [ ] \(.id): \(.title) (failed)"' "$TASKS_FILE")
  local pending_tasks
  pending_tasks=$(jq -r '.tasks[] | select(.status == "pending") | "- [ ] \(.id): \(.title)"' "$TASKS_FILE")

  local pr_body="## Summary
Automated implementation via Ralph Loop.

## Tasks Completed
${completed_tasks:-None}

## Tasks Failed
${failed_tasks:-None}

## Tasks Remaining
${pending_tasks:-None}

---
Generated by Ralph Loop (rdi-dev-env)"

  log INFO "Pushing branch and creating PR..."
  git push -u origin "$current_branch" 2>/dev/null || {
    log ERROR "Failed to push branch"
    return 1
  }

  gh pr create \
    --title "Ralph Loop: automated implementation" \
    --body "$pr_body" \
    --base "$base_branch" 2>/dev/null || {
    log WARN "PR creation failed (may already exist)"
  }
}

# ── Summary ──────────────────────────────────────────────────
print_summary() {
  local total_tasks
  total_tasks=$(jq '.tasks | length' "$TASKS_FILE")
  local completed_total
  completed_total=$(jq '[.tasks[] | select(.status == "completed")] | length' "$TASKS_FILE")
  local failed_total
  failed_total=$(jq '[.tasks[] | select(.status == "failed")] | length' "$TASKS_FILE")
  local pending_total
  pending_total=$(jq '[.tasks[] | select(.status == "pending")] | length' "$TASKS_FILE")

  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Ralph Loop Summary${NC}"
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  Iterations:  $ITERATION"
  echo -e "  ${GREEN}Completed:${NC}   $COMPLETED (this run) / $completed_total (total)"
  echo -e "  ${RED}Failed:${NC}      $FAILED (this run) / $failed_total (total)"
  echo -e "  ${DIM}Pending:${NC}     $pending_total"
  echo -e "  ${DIM}Total:${NC}       $total_tasks"
  echo ""

  if [ -n "$PROGRESS_LOG" ] && [ -f "$PROGRESS_LOG" ]; then
    echo -e "${DIM}Progress log: $PROGRESS_LOG${NC}"
  fi
}

# ── Cleanup & Signal Handling ────────────────────────────────
cleanup() {
  print_summary
  rm -f "$STOP_FILE"
  echo -e "${DIM}Ralph Loop stopped.${NC}"
  exit 0
}
trap cleanup SIGINT SIGTERM

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

# ── Setup ────────────────────────────────────────────────────
check_deps

# Find tasks.json
if [ -z "$TASKS_FILE" ]; then
  if [ -f "tasks.json" ]; then
    TASKS_FILE="tasks.json"
  else
    echo -e "${RED}Error: tasks.json not found${NC}"
    echo "Usage: $(basename "$0") [options] [tasks.json]"
    exit 1
  fi
fi

if [ ! -f "$TASKS_FILE" ]; then
  echo -e "${RED}Error: $TASKS_FILE does not exist${NC}"
  exit 1
fi

# Validate tasks.json
if ! jq empty "$TASKS_FILE" 2>/dev/null; then
  echo -e "${RED}Error: $TASKS_FILE is not valid JSON${NC}"
  exit 1
fi

# Project setup
PROJECT_NAME=$(jq -r '.project // empty' "$TASKS_FILE")
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$(pwd)")
fi

detect_project_type
STOP_FILE="/tmp/.ralph-stop-${PROJECT_NAME}"
PROGRESS_LOG="progress.log"

# Branch setup
if [ -z "$BRANCH_NAME" ]; then
  BRANCH_NAME="ralph/$(date +%m%d)"
fi

# Ensure we're on the right branch (skip if dry-run)
if [ "$DRY_RUN" = false ]; then
  current_branch=$(git branch --show-current 2>/dev/null || echo "")
  if [ "$current_branch" != "$BRANCH_NAME" ]; then
    # Create branch if it doesn't exist, or switch to it
    if git rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
      git checkout "$BRANCH_NAME"
    else
      git checkout -b "$BRANCH_NAME"
    fi
    log INFO "On branch: $BRANCH_NAME"
  fi
fi

# ── Banner ───────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Ralph Loop v1.0${NC}"
echo -e "${CYAN}${BOLD}  Project: $PROJECT_NAME ($PROJECT_TYPE)${NC}"
echo -e "${CYAN}${BOLD}  Tasks:   $TASKS_FILE${NC}"
echo -e "${CYAN}${BOLD}  Branch:  $BRANCH_NAME${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}${BOLD}  Mode:    DRY RUN${NC}"
fi
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""

# Remove stale stop file
rm -f "$STOP_FILE"

# ── Main Loop ────────────────────────────────────────────────
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ((ITERATION++))

  # Check stop file
  if [ -f "$STOP_FILE" ]; then
    log WARN "Stop file detected: $STOP_FILE"
    log WARN "Stopping Ralph Loop gracefully."
    break
  fi

  # Pick next task
  TASK_ID=$(pick_next_task)

  if [ -z "$TASK_ID" ]; then
    log INFO "No more eligible tasks. All done or all blocked."
    break
  fi

  TASK_TITLE=$(get_task_field "$TASK_ID" "title")
  TASK_ATTEMPTS=$(get_task_field "$TASK_ID" "attempts")
  TASK_ATTEMPTS="${TASK_ATTEMPTS:-0}"
  TASK_MAX=$(get_task_field "$TASK_ID" "max_attempts")
  TASK_MAX="${TASK_MAX:-3}"

  echo ""
  log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log INFO "Iteration $ITERATION/$MAX_ITERATIONS — $TASK_ID: $TASK_TITLE"
  log INFO "Attempt $((TASK_ATTEMPTS + 1))/$TASK_MAX"
  log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Dry run — just log
  if [ "$DRY_RUN" = true ]; then
    log INFO "[DRY RUN] Would execute task: $TASK_ID — $TASK_TITLE"
    log INFO "[DRY RUN] Test command: $(get_verification_field "$TASK_ID" "test_command")"
    continue
  fi

  # Mark in_progress and increment attempts
  update_task_status "$TASK_ID" "in_progress"
  increment_attempts "$TASK_ID"

  # Build prompt
  PROMPT=$(build_prompt "$TASK_ID")

  # Pre-flight usage budget check
  if ! preflight_usage_check 12; then
    log ERROR "Insufficient message budget — stopping loop"
    update_task_status "$TASK_ID" "pending"
    break
  fi

  # Execute via Claude CLI
  log INFO "Sending task to Claude CLI..."
  echo "$PROMPT" | claude -p 2>&1 || true
  log INFO "Claude CLI completed"

  # Run tests
  TEST_OUTPUT=""
  if run_tests "$TASK_ID"; then
    # Tests passed — commit and mark completed
    commit_task "$TASK_ID"
    mark_completed "$TASK_ID"
    ((COMPLETED++))
    log OK "Task $TASK_ID completed successfully"
  else
    # Tests failed
    store_last_error "$TASK_ID" "$TEST_OUTPUT"
    revert_changes

    # Check if max attempts reached
    current_attempts=$(get_task_field "$TASK_ID" "attempts")
    max_attempts=$(get_task_field "$TASK_ID" "max_attempts")
    if [ "$current_attempts" -ge "$max_attempts" ]; then
      mark_failed "$TASK_ID"
      ((FAILED++))
      log ERROR "Task $TASK_ID failed after $max_attempts attempts"
    else
      update_task_status "$TASK_ID" "pending"
      log WARN "Task $TASK_ID failed (attempt $current_attempts/$max_attempts) — will retry"
    fi
  fi

  # --once mode
  if [ "$RUN_ONCE" = true ]; then
    log INFO "Single task mode (--once) — stopping"
    break
  fi
done

# ── Post-Loop ────────────────────────────────────────────────
if [ "$DRY_RUN" = false ] && [ $COMPLETED -gt 0 ]; then
  maybe_create_pr
fi

print_summary
rm -f "$STOP_FILE"
