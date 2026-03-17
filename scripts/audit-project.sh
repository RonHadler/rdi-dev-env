#!/bin/bash
#
# rdi-audit — RDI Standards Compliance Auditor
#
# Reads standards.json and checks any Python/FastMCP project for compliance.
#
# Usage:
#   rdi-audit status                  # Dashboard of all known RDI projects
#   rdi-audit /path/to/project        # Audit a single project
#   rdi-audit /path/to/project --json # Machine-readable output
#   rdi-audit /path/to/project --generate-tasks  # Ralph Loop tasks.json
#   rdi-audit /path/to/project --reverse          # Find project innovations not in template
#
# Exit codes:
#   0 = all checks pass (or only low/medium failures)
#   1 = high-severity failures
#   2 = critical-severity failures

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Locate standards.json ───────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ENV_DIR="$(dirname "$SCRIPT_DIR")"
STANDARDS_FILE="$DEV_ENV_DIR/standards.json"

if [ ! -f "$STANDARDS_FILE" ]; then
  echo -e "${RED}Error:${NC} standards.json not found at $STANDARDS_FILE" >&2
  exit 1
fi

# ── Dependencies check ──────────────────────────────────────
# We need jq or node for JSON parsing
if command -v jq &>/dev/null; then
  JSON_TOOL="jq"
elif command -v node &>/dev/null; then
  JSON_TOOL="node"
else
  echo -e "${RED}Error:${NC} Either jq or node is required" >&2
  exit 1
fi

# ── JSON helpers ─────────────────────────────────────────────
# Read a JSON file safely with node (handles Windows/Git Bash paths)
node_json() {
  local file="$1"
  shift
  node -e "
    const fs = require('fs'), path = require('path');
    const fp = path.resolve(process.argv[1]);
    const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
    const args = process.argv.slice(2);
    ${1}
  " -- "$file" "${@:2}" 2>/dev/null
}

# Extract a field from JSON using jq or node
json_query() {
  local file="$1"
  local query="$2"

  if [ "$JSON_TOOL" = "jq" ]; then
    jq -r "$query" "$file" 2>/dev/null
  else
    node -e "
      const fs = require('fs'), path = require('path');
      const fp = path.resolve(process.argv[1]);
      const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
      const result = data[process.argv[2]];
      if (Array.isArray(result)) { result.forEach(r => console.log(typeof r === 'object' ? JSON.stringify(r) : r)); }
      else { console.log(typeof result === 'object' ? JSON.stringify(result) : result); }
    " -- "$file" "$query" 2>/dev/null
  fi
}

# Get check count
get_check_count() {
  if [ "$JSON_TOOL" = "jq" ]; then
    jq '.checks | length' "$STANDARDS_FILE"
  else
    node -e "
      const fs = require('fs'), path = require('path');
      const fp = path.resolve(process.argv[1]);
      const d = JSON.parse(fs.readFileSync(fp, 'utf8'));
      console.log(d.checks.length);
    " -- "$STANDARDS_FILE"
  fi
}

# Get check field by index
get_check_field() {
  local index="$1"
  local field="$2"

  if [ "$JSON_TOOL" = "jq" ]; then
    jq -r ".checks[$index].$field" "$STANDARDS_FILE"
  else
    node -e "
      const fs = require('fs'), path = require('path');
      const fp = path.resolve(process.argv[1]);
      const d = JSON.parse(fs.readFileSync(fp, 'utf8'));
      console.log(d.checks[parseInt(process.argv[2])][process.argv[3]] || '');
    " -- "$STANDARDS_FILE" "$index" "$field"
  fi
}

# ── Known RDI Python projects ───────────────────────────────
RDI_PROJECTS=(
  "rdi-datagov-mcp"
  "rdi-google-ads-mcp"
  "rdi-google-ga4-mcp"
  "rdi-marketmirror-mcp"
  "rdi-documents-mcp"
  "rdi-poe-mcp"
  "rdi-domo-mcp"
  "rdi-domo-api-reference-mcp"
)

# ── Check if a check ID is suppressed in .rdi-baseline ──────
is_suppressed() {
  local project_dir="$1"
  local check_id="$2"
  local baseline_file="$project_dir/.rdi-baseline"

  if [ ! -f "$baseline_file" ]; then
    return 1  # Not suppressed (no baseline file)
  fi

  if [ "$JSON_TOOL" = "jq" ]; then
    local found
    found=$(jq -r --arg id "$check_id" '.suppress[]? | select(.id == $id) | .id' "$baseline_file" 2>/dev/null)
    [ -n "$found" ]
  else
    node -e "
      const fs = require('fs'), path = require('path');
      const fp = path.resolve(process.argv[1]);
      const d = JSON.parse(fs.readFileSync(fp, 'utf8'));
      const found = (d.suppress || []).some(s => s.id === process.argv[2]);
      process.exit(found ? 0 : 1);
    " -- "$baseline_file" "$check_id" 2>/dev/null
  fi
}

# ── Run a single check against a project ────────────────────
run_check() {
  local project_dir="$1"
  local index="$2"

  local check_id check_type check_path check_pattern severity
  check_id=$(get_check_field "$index" "id")
  check_type=$(get_check_field "$index" "type")
  check_path=$(get_check_field "$index" "path")
  check_pattern=$(get_check_field "$index" "pattern")
  severity=$(get_check_field "$index" "severity")

  # Check suppression
  if is_suppressed "$project_dir" "$check_id"; then
    echo "suppressed"
    return 0
  fi

  case "$check_type" in
    file_exists)
      if [ -e "$project_dir/$check_path" ]; then
        echo "pass"
      else
        echo "fail"
      fi
      ;;

    file_contains)
      # Handle glob patterns in path
      local target_files=()
      if [[ "$check_path" == *"*"* ]]; then
        # Glob pattern — find matching files
        while IFS= read -r -d '' f; do
          target_files+=("$f")
        done < <(find "$project_dir" -path "$project_dir/.venv" -prune -o -path "$project_dir/.git" -prune -o -path "$project_dir/node_modules" -prune -o -path "$project_dir/$check_path" -print0 2>/dev/null)

        # If glob didn't work with find -path, try a simpler approach
        if [ ${#target_files[@]} -eq 0 ]; then
          # Convert glob to find-compatible pattern
          local find_name
          find_name=$(basename "$check_path")
          while IFS= read -r -d '' f; do
            target_files+=("$f")
          done < <(find "$project_dir" -path "$project_dir/.venv" -prune -o -path "$project_dir/.git" -prune -o -name "$find_name" -print0 2>/dev/null)
        fi
      else
        if [ -f "$project_dir/$check_path" ]; then
          target_files=("$project_dir/$check_path")
        fi
      fi

      if [ ${#target_files[@]} -eq 0 ]; then
        echo "skip"  # File doesn't exist — not applicable
        return 0
      fi

      local found=false
      for f in "${target_files[@]}"; do
        if grep -qEi "$check_pattern" "$f" 2>/dev/null; then
          found=true
          break
        fi
      done

      if $found; then
        echo "pass"
      else
        echo "fail"
      fi
      ;;

    file_not_contains)
      local target_files=()
      if [[ "$check_path" == *"*"* ]]; then
        local find_name
        find_name=$(basename "$check_path")
        while IFS= read -r -d '' f; do
          target_files+=("$f")
        done < <(find "$project_dir" -path "$project_dir/.venv" -prune -o -path "$project_dir/.git" -prune -o -name "$find_name" -print0 2>/dev/null)
      else
        if [ -f "$project_dir/$check_path" ]; then
          target_files=("$project_dir/$check_path")
        fi
      fi

      if [ ${#target_files[@]} -eq 0 ]; then
        echo "pass"  # No files to check = no violations
        return 0
      fi

      local violation=false
      for f in "${target_files[@]}"; do
        if grep -qEi "$check_pattern" "$f" 2>/dev/null; then
          violation=true
          break
        fi
      done

      if $violation; then
        echo "fail"
      else
        echo "pass"
      fi
      ;;

    *)
      echo "skip"
      ;;
  esac
}

# ── Reverse audit: find project patterns not in template ────
# Populates UPSTREAM_CANDIDATES array with descriptions
UPSTREAM_CANDIDATES=()

collect_upstream_candidates() {
  local project_dir="$1"
  UPSTREAM_CANDIDATES=()

  # Check for multi-stage Docker build
  if [ -f "$project_dir/Dockerfile" ]; then
    local stages
    stages=$(grep -c "^FROM " "$project_dir/Dockerfile" 2>/dev/null || echo "0")
    if [ "$stages" -gt 1 ]; then
      UPSTREAM_CANDIDATES+=("Multi-stage Dockerfile ($stages stages)")
    fi

    # Check for HEALTHCHECK
    if grep -q "^HEALTHCHECK" "$project_dir/Dockerfile" 2>/dev/null; then
      UPSTREAM_CANDIDATES+=("HEALTHCHECK instruction in Dockerfile")
    fi

    # Check for entrypoint script
    if grep -q "ENTRYPOINT" "$project_dir/Dockerfile" 2>/dev/null; then
      UPSTREAM_CANDIDATES+=("Custom ENTRYPOINT script")
    fi
  fi

  # Check for domain-specific test fixtures beyond the template
  if [ -f "$project_dir/tests/conftest.py" ]; then
    local fixture_count
    fixture_count=$(grep -c "@pytest.fixture" "$project_dir/tests/conftest.py" 2>/dev/null || echo "0")
    if [ "$fixture_count" -gt 2 ]; then
      UPSTREAM_CANDIDATES+=("Rich test fixtures ($fixture_count fixtures in conftest.py)")
    fi
  fi

  # Check for test_config.py
  if [ -f "$project_dir/tests/test_config.py" ]; then
    UPSTREAM_CANDIDATES+=("Dedicated config test file (tests/test_config.py)")
  fi

  # Check for Alembic migrations
  if [ -d "$project_dir/alembic" ]; then
    UPSTREAM_CANDIDATES+=("Alembic database migrations")
  fi

  # Check for custom middleware
  if find "$project_dir" -name "middleware.py" -not -path "*/.venv/*" -not -path "*/.git/*" 2>/dev/null | grep -q .; then
    UPSTREAM_CANDIDATES+=("Custom middleware module")
  fi

  # Check for noxfile
  if [ -f "$project_dir/noxfile.py" ]; then
    UPSTREAM_CANDIDATES+=("noxfile.py (Nox test runner)")
  fi
}

# Print reverse audit as standalone output (--reverse mode)
reverse_audit() {
  local project_dir="$1"
  local project_name
  project_name=$(basename "$project_dir")

  collect_upstream_candidates "$project_dir"

  echo -e "${BOLD}Reverse Audit: ${CYAN}$project_name${NC}"
  echo -e "${DIM}Patterns in project that may be worth upstreaming to templates${NC}"
  echo ""

  if [ ${#UPSTREAM_CANDIDATES[@]} -eq 0 ]; then
    echo -e "  ${DIM}No upstream candidates found${NC}"
  else
    for candidate in "${UPSTREAM_CANDIDATES[@]}"; do
      echo -e "  ${CYAN}+${NC} $candidate"
    done
    echo ""
    echo -e "  ${BOLD}${#UPSTREAM_CANDIDATES[@]}${NC} potential upstream candidate(s)"
  fi
}

# ── Audit a single project ──────────────────────────────────
audit_project() {
  local project_dir="$1"
  local output_mode="${2:-text}"  # text, json, tasks

  local project_name
  project_name=$(basename "$project_dir")

  if [ ! -d "$project_dir" ]; then
    echo -e "${RED}Error:${NC} Directory not found: $project_dir" >&2
    return 1
  fi

  # Check if it looks like a Python project
  if [ ! -f "$project_dir/pyproject.toml" ] && [ ! -f "$project_dir/setup.py" ] && [ ! -f "$project_dir/requirements.txt" ]; then
    echo -e "${YELLOW}Warning:${NC} $project_name does not appear to be a Python project" >&2
  fi

  local check_count
  check_count=$(get_check_count)

  local pass_count=0
  local fail_count=0
  local skip_count=0
  local suppress_count=0
  local critical_fails=0
  local high_fails=0

  # Arrays for results
  declare -a result_ids=()
  declare -a result_names=()
  declare -a result_severities=()
  declare -a result_statuses=()
  declare -a result_remediations=()

  for ((i=0; i<check_count; i++)); do
    local check_id check_name severity result remediation
    check_id=$(get_check_field "$i" "id")
    check_name=$(get_check_field "$i" "name")
    severity=$(get_check_field "$i" "severity")
    remediation=$(get_check_field "$i" "remediation")

    result=$(run_check "$project_dir" "$i")

    result_ids+=("$check_id")
    result_names+=("$check_name")
    result_severities+=("$severity")
    result_statuses+=("$result")
    result_remediations+=("$remediation")

    case "$result" in
      pass) ((pass_count++)) || true ;;
      fail)
        ((fail_count++)) || true
        case "$severity" in
          critical) ((critical_fails++)) || true ;;
          high) ((high_fails++)) || true ;;
        esac
        ;;
      skip) ((skip_count++)) || true ;;
      suppressed) ((suppress_count++)) || true ;;
    esac
  done

  local total=$((pass_count + fail_count))
  local score=0
  if [ "$total" -gt 0 ]; then
    score=$(( (pass_count * 100) / total ))
  fi

  # ── Collect upstream candidates (reverse audit) ──
  collect_upstream_candidates "$project_dir"
  local upstream_count=${#UPSTREAM_CANDIDATES[@]}

  # ── JSON output ──
  if [ "$output_mode" = "json" ]; then
    local checks_json="["
    for ((i=0; i<${#result_ids[@]}; i++)); do
      [ "$i" -gt 0 ] && checks_json+=","
      checks_json+="{\"id\":\"${result_ids[$i]}\",\"name\":\"${result_names[$i]}\",\"severity\":\"${result_severities[$i]}\",\"status\":\"${result_statuses[$i]}\"}"
    done
    checks_json+="]"

    local upstream_json="["
    for ((i=0; i<upstream_count; i++)); do
      [ "$i" -gt 0 ] && upstream_json+=","
      # Escape quotes in candidate descriptions
      local safe_candidate
      safe_candidate=$(echo "${UPSTREAM_CANDIDATES[$i]}" | sed 's/"/\\"/g')
      upstream_json+="\"$safe_candidate\""
    done
    upstream_json+="]"

    cat <<EOF
{
  "project": "$project_name",
  "path": "$project_dir",
  "score": $score,
  "pass": $pass_count,
  "fail": $fail_count,
  "skip": $skip_count,
  "suppressed": $suppress_count,
  "critical_failures": $critical_fails,
  "high_failures": $high_fails,
  "upstream_candidates": $upstream_count,
  "checks": $checks_json,
  "upstream": $upstream_json
}
EOF
    # Exit code based on severity
    if [ "$critical_fails" -gt 0 ]; then return 2; fi
    if [ "$high_fails" -gt 0 ]; then return 1; fi
    return 0
  fi

  # ── Generate tasks output ──
  if [ "$output_mode" = "tasks" ]; then
    local task_num=1
    local tasks_json="{\"version\":\"1.0\",\"project\":\"$project_name\",\"generated_by\":\"rdi-audit\",\"generated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"tasks\":["
    local first_task=true

    for ((i=0; i<${#result_ids[@]}; i++)); do
      if [ "${result_statuses[$i]}" = "fail" ]; then
        [ "$first_task" = "false" ] && tasks_json+=","
        first_task=false

        local priority
        case "${result_severities[$i]}" in
          critical) priority=1 ;;
          high) priority=2 ;;
          medium) priority=3 ;;
          low) priority=4 ;;
          *) priority=5 ;;
        esac

        local commit_type="fix"
        if [[ "${result_ids[$i]}" == CI-* ]]; then commit_type="ci"; fi
        if [[ "${result_ids[$i]}" == CON-* ]]; then commit_type="docs"; fi

        # Escape remediation for JSON
        local safe_remediation
        safe_remediation=$(echo "${result_remediations[$i]}" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

        tasks_json+="{\"id\":\"TASK-$(printf '%03d' $task_num)\",\"status\":\"pending\",\"priority\":$priority,\"title\":\"${result_ids[$i]}: ${result_names[$i]}\",\"description\":\"$safe_remediation\",\"blocked_by\":[],\"verification\":{\"test_command\":\"rdi-audit $project_dir --json\",\"check_patterns\":[\"${result_ids[$i]}\"]},\"commit_type\":\"$commit_type\",\"attempts\":0,\"max_attempts\":3}"
        ((task_num++)) || true
      fi
    done

    tasks_json+="]}"
    echo "$tasks_json" | python3 -m json.tool 2>/dev/null || echo "$tasks_json"
    return 0
  fi

  # ── Text output (default) ──
  echo -e "${BOLD}Audit: ${CYAN}$project_name${NC}  ${DIM}($project_dir)${NC}"
  echo ""

  # Group by severity for display
  local severities=("critical" "high" "medium" "low")
  local severity_colors=("$RED" "$YELLOW" "$YELLOW" "$DIM")
  local severity_labels=("CRITICAL" "HIGH" "MEDIUM" "LOW")

  for s_idx in "${!severities[@]}"; do
    local sev="${severities[$s_idx]}"
    local color="${severity_colors[$s_idx]}"
    local label="${severity_labels[$s_idx]}"
    local has_items=false

    for ((i=0; i<${#result_ids[@]}; i++)); do
      if [ "${result_severities[$i]}" = "$sev" ]; then
        if ! $has_items; then
          echo -e "  ${color}${BOLD}$label${NC}"
          has_items=true
        fi

        local status_icon
        case "${result_statuses[$i]}" in
          pass) status_icon="${GREEN}✓${NC}" ;;
          fail) status_icon="${RED}✗${NC}" ;;
          skip) status_icon="${DIM}○${NC}" ;;
          suppressed) status_icon="${DIM}⊘${NC}" ;;
        esac

        echo -e "    $status_icon ${result_ids[$i]}: ${result_names[$i]}"

        # Show remediation for failures
        if [ "${result_statuses[$i]}" = "fail" ]; then
          echo -e "      ${DIM}→ ${result_remediations[$i]}${NC}"
        fi
      fi
    done

    if $has_items; then
      echo ""
    fi
  done

  # Score bar
  local bar_width=30
  local filled=$(( (score * bar_width) / 100 ))
  local empty=$(( bar_width - filled ))
  local bar=""
  for ((j=0; j<filled; j++)); do bar+="█"; done
  for ((j=0; j<empty; j++)); do bar+="░"; done

  local score_color="$RED"
  if [ "$score" -ge 80 ]; then score_color="$GREEN"
  elif [ "$score" -ge 60 ]; then score_color="$YELLOW"
  fi

  echo -e "  ${BOLD}Score:${NC} ${score_color}${bar} ${score}%${NC}  (${pass_count}/${total} checks pass, ${skip_count} skipped, ${suppress_count} suppressed)"

  if [ "$critical_fails" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}⚠ $critical_fails critical failure(s)${NC}"
  fi
  if [ "$high_fails" -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}⚠ $high_fails high-severity failure(s)${NC}"
  fi

  # Upstream candidates (reverse audit)
  if [ "$upstream_count" -gt 0 ]; then
    echo ""
    echo -e "  ${CYAN}${BOLD}Upstream Candidates${NC}"
    for candidate in "${UPSTREAM_CANDIDATES[@]}"; do
      echo -e "    ${CYAN}+${NC} $candidate"
    done
  fi

  echo ""

  # Exit code based on severity
  if [ "$critical_fails" -gt 0 ]; then return 2; fi
  if [ "$high_fails" -gt 0 ]; then return 1; fi
  return 0
}

# ── Dashboard: status of all known projects ─────────────────
show_dashboard() {
  echo -e "${CYAN}${BOLD}RDI Standards Compliance Dashboard${NC}"
  local standards_version
  if [ "$JSON_TOOL" = "jq" ]; then
    standards_version=$(jq -r '.version' "$STANDARDS_FILE")
  else
    standards_version=$(node -e "
      const fs = require('fs'), path = require('path');
      const d = JSON.parse(fs.readFileSync(path.resolve(process.argv[1]), 'utf8'));
      console.log(d.version);
    " -- "$STANDARDS_FILE")
  fi
  echo -e "${DIM}Standards version: $standards_version | $(date +%Y-%m-%d)${NC}"
  echo ""

  local dev_root
  dev_root=$(dirname "$DEV_ENV_DIR")

  # Table header
  printf "  ${BOLD}%-30s  %-7s  %-6s  %-5s  %-5s  %-4s  %-8s${NC}\n" "PROJECT" "SCORE" "PASS" "FAIL" "SKIP" "UP" "STATUS"
  printf "  ${DIM}%-30s  %-7s  %-6s  %-5s  %-5s  %-4s  %-8s${NC}\n" "──────────────────────────────" "───────" "──────" "─────" "─────" "────" "────────"

  local total_projects=0
  local compliant_projects=0

  for project in "${RDI_PROJECTS[@]}"; do
    local project_dir="$dev_root/$project"

    if [ ! -d "$project_dir" ]; then
      printf "  ${DIM}%-30s  %-7s${NC}\n" "$project" "NOT FOUND"
      continue
    fi

    ((total_projects++)) || true

    # Run audit silently and capture JSON
    local json_result
    json_result=$(audit_project "$project_dir" "json" 2>/dev/null) || true

    if [ -z "$json_result" ]; then
      printf "  ${DIM}%-30s  %-7s${NC}\n" "$project" "ERROR"
      continue
    fi

    local score pass fail skip critical_fails upstream status_icon status_color
    if [ "$JSON_TOOL" = "jq" ]; then
      score=$(echo "$json_result" | jq -r '.score')
      pass=$(echo "$json_result" | jq -r '.pass')
      fail=$(echo "$json_result" | jq -r '.fail')
      skip=$(echo "$json_result" | jq -r '.skip')
      critical_fails=$(echo "$json_result" | jq -r '.critical_failures')
      upstream=$(echo "$json_result" | jq -r '.upstream_candidates')
    else
      # Parse all fields in a single node call for efficiency
      local parsed
      parsed=$(node -e "
        const d = JSON.parse(process.argv[1]);
        console.log([d.score, d.pass, d.fail, d.skip, d.critical_failures, d.upstream_candidates].join(' '));
      " -- "$json_result")
      read -r score pass fail skip critical_fails upstream <<< "$parsed"
    fi

    if [ "$score" -eq 100 ]; then
      status_icon="${GREEN}✓ COMPLIANT${NC}"
      ((compliant_projects++)) || true
    elif [ "${critical_fails:-0}" -gt 0 ]; then
      status_icon="${RED}✗ CRITICAL${NC}"
    elif [ "$score" -ge 70 ]; then
      status_icon="${YELLOW}~ PARTIAL${NC}"
    else
      status_icon="${RED}✗ LOW${NC}"
    fi

    local score_color="$RED"
    if [ "$score" -ge 80 ]; then score_color="$GREEN"
    elif [ "$score" -ge 60 ]; then score_color="$YELLOW"
    fi

    local upstream_display="${upstream:-0}"
    if [ "$upstream_display" -gt 0 ] 2>/dev/null; then
      upstream_display="${CYAN}${upstream_display}${NC}"
    fi

    printf "  %-30s  ${score_color}%-7s${NC}  %-6s  %-5s  %-5s  %b  %b\n" \
      "$project" "${score}%" "$pass" "$fail" "$skip" "$upstream_display" "$status_icon"
  done

  echo ""
  echo -e "  ${BOLD}Fleet:${NC} $compliant_projects/$total_projects projects fully compliant"
  echo ""
}

# ── Usage ────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}rdi-audit${NC} — RDI Standards Compliance Auditor

${BOLD}Usage:${NC}
  rdi-audit status                          Dashboard of all RDI projects
  rdi-audit <path>                          Audit a single project
  rdi-audit <path> --json                   Machine-readable JSON output
  rdi-audit <path> --generate-tasks         Generate Ralph Loop tasks.json
  rdi-audit <path> --reverse                Find project innovations not in template

${BOLD}Exit codes:${NC}
  0  All checks pass (or only low/medium failures)
  1  High-severity failures
  2  Critical-severity failures

${BOLD}Standards:${NC}
  $(get_check_count) checks across 4 severity levels (critical, high, medium, low)
  Version: $(json_query "$STANDARDS_FILE" "version")
EOF
}

# ── Main ─────────────────────────────────────────────────────
main() {
  if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
  fi

  if [ "$1" = "status" ]; then
    show_dashboard
    exit 0
  fi

  local project_dir="$1"
  local mode="text"

  # Resolve relative paths
  if [[ ! "$project_dir" = /* ]]; then
    project_dir="$(pwd)/$project_dir"
  fi

  # Strip trailing slash
  project_dir="${project_dir%/}"

  shift || true

  while [ $# -gt 0 ]; do
    case "$1" in
      --json) mode="json" ;;
      --generate-tasks) mode="tasks" ;;
      --reverse)
        reverse_audit "$project_dir"
        exit 0
        ;;
      *) echo -e "${RED}Unknown option:${NC} $1" >&2; exit 1 ;;
    esac
    shift
  done

  audit_project "$project_dir" "$mode"
}

main "$@"
