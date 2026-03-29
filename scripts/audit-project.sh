#!/bin/bash
#
# rdi-audit — RDI Standards Compliance Auditor
#
# Reads standards.json and checks any project for compliance.
# Supports Python, Go, Rust, Node, and base-only projects via auto-detection.
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

# ── Locate standards.json and template-utils ────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ENV_DIR="$(dirname "$SCRIPT_DIR")"
STANDARDS_FILE="$DEV_ENV_DIR/standards.json"
TEMPLATES_DIR="$DEV_ENV_DIR/templates"

if [ ! -f "$STANDARDS_FILE" ]; then
  echo -e "${RED}Error:${NC} standards.json not found at $STANDARDS_FILE" >&2
  exit 1
fi

# Source shared template utilities
source "$SCRIPT_DIR/lib/template-utils.sh"

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
# Pre-parsed check arrays (populated by load_standards)
STD_VERSION=""
STD_COUNT=0
declare -a STD_IDS=()
declare -a STD_NAMES=()
declare -a STD_SEVERITIES=()
declare -a STD_CATEGORIES=()
declare -a STD_TYPES=()
declare -a STD_PATHS=()
declare -a STD_PATTERNS=()
declare -a STD_REMEDIATIONS=()
declare -a STD_STACKS=()

# Compat aliases: old v1 check ID → new v2 check ID
declare -a COMPAT_OLD_IDS=()
declare -a COMPAT_NEW_IDS=()

# Parse standards.json v2 into bash arrays.
# Loads ALL checks from ALL stacks (filtering happens at audit time).
load_standards() {
  local delim=$'\x1f'
  local raw

  raw=$(node -e "
    const fs = require('fs'), path = require('path');
    const d = JSON.parse(fs.readFileSync(path.resolve(process.argv[1]), 'utf8'));
    const sep = '\x1f';
    process.stdout.write('VERSION' + sep + d.version + '\n');

    // v2 stacks-based format
    if (d.stacks) {
      for (const [stackName, stack] of Object.entries(d.stacks)) {
        for (const c of (stack.checks || [])) {
          const fields = [c.id, c.name, c.severity, c.category, c.type, c.path, c.pattern || '', c.remediation || '', stackName];
          process.stdout.write(fields.join(sep) + '\n');
        }
      }
      // Compat aliases
      if (d.compat_aliases) {
        for (const [oldId, newId] of Object.entries(d.compat_aliases)) {
          process.stdout.write('ALIAS' + sep + oldId + sep + newId + '\n');
        }
      }
    }
    // v1 flat format (backwards compat)
    else if (d.checks) {
      for (const c of d.checks) {
        const fields = [c.id, c.name, c.severity, c.category, c.type, c.path, c.pattern || '', c.remediation || '', 'all'];
        process.stdout.write(fields.join(sep) + '\n');
      }
    }
  " -- "$STANDARDS_FILE")

  STD_VERSION=$(printf '%s\n' "$raw" | head -1 | cut -d "$delim" -f2)
  STD_COUNT=0

  while IFS="$delim" read -r first rest; do
    case "$first" in
      VERSION) continue ;;
      ALIAS)
        local old_id new_id
        old_id=$(printf '%s' "$rest" | cut -d "$delim" -f1)
        new_id=$(printf '%s' "$rest" | cut -d "$delim" -f2)
        COMPAT_OLD_IDS+=("$old_id")
        COMPAT_NEW_IDS+=("$new_id")
        ;;
      *)
        # Regular check line: id, name, severity, category, type, path, pattern, remediation, stack
        local id="$first"
        local name severity category type ckpath pattern remediation stack_name
        IFS="$delim" read -r name severity category type ckpath pattern remediation stack_name <<< "$rest"
        STD_IDS+=("$id")
        STD_NAMES+=("$name")
        STD_SEVERITIES+=("$severity")
        STD_CATEGORIES+=("$category")
        STD_TYPES+=("$type")
        STD_PATHS+=("$ckpath")
        STD_PATTERNS+=("$pattern")
        STD_REMEDIATIONS+=("$remediation")
        STD_STACKS+=("$stack_name")
        ((STD_COUNT++)) || true
        ;;
    esac
  done <<< "$raw"
}

# Check if a given check index applies to the detected stack chain.
# Usage: check_applies_to_chain <index> <space-separated-chain>
check_applies_to_chain() {
  local index="$1"
  local chain="$2"
  local check_stack="${STD_STACKS[$index]}"

  # v1 compat: "all" matches everything
  if [ "$check_stack" = "all" ]; then
    return 0
  fi

  # Check if the check's stack is in the resolved chain
  for s in $chain; do
    if [ "$s" = "$check_stack" ]; then
      return 0
    fi
  done
  return 1
}

# Load once at startup
load_standards

# ── Known RDI projects ──────────────────────────────────────
# Stack is auto-detected at audit time from manifest files.
RDI_PROJECTS=(
  "rdi-datagov-mcp"
  "rdi-google-ads-mcp"
  "rdi-google-ga4-mcp"
  "rdi-marketmirror-mcp"
  "rdi-documents-mcp"
  "rdi-poe-mcp"
  "rdi-domo-mcp"
  "rdi-domo-api-reference-mcp"
  "rdi-argus-mcp"
)

# ── Check if a check ID is suppressed in .rdi-baseline ──────
# Supports both new v2 IDs and old v1 IDs via compat_aliases.
is_suppressed() {
  local project_dir="$1"
  local check_id="$2"
  local baseline_file="$project_dir/.rdi-baseline"

  if [ ! -f "$baseline_file" ]; then
    return 1  # Not suppressed (no baseline file)
  fi

  # Build list of IDs to check: the new ID plus any old aliases that map to it
  local ids_to_check="$check_id"
  for i in "${!COMPAT_NEW_IDS[@]}"; do
    if [ "${COMPAT_NEW_IDS[$i]}" = "$check_id" ]; then
      ids_to_check="$ids_to_check ${COMPAT_OLD_IDS[$i]}"
    fi
  done

  # Also check if the check_id itself is an old alias
  for i in "${!COMPAT_OLD_IDS[@]}"; do
    if [ "${COMPAT_OLD_IDS[$i]}" = "$check_id" ]; then
      ids_to_check="$ids_to_check ${COMPAT_NEW_IDS[$i]}"
    fi
  done

  node -e "
    const fs = require('fs'), path = require('path');
    const fp = path.resolve(process.argv[1]);
    const d = JSON.parse(fs.readFileSync(fp, 'utf8'));
    const idsToCheck = process.argv[2].split(' ');
    const found = (d.suppress || []).some(s => idsToCheck.includes(s.id));
    process.exit(found ? 0 : 1);
  " -- "$baseline_file" "$ids_to_check" 2>/dev/null
}

# ── Run a single check against a project ────────────────────
run_check() {
  local project_dir="$1"
  local index="$2"

  local check_id="${STD_IDS[$index]}"
  local check_type="${STD_TYPES[$index]}"
  local check_path="${STD_PATHS[$index]}"
  local check_pattern="${STD_PATTERNS[$index]}"

  # Check suppression
  if is_suppressed "$project_dir" "$check_id"; then
    echo "suppressed"
    return 0
  fi

  case "$check_type" in
    file_exists)
      # NOTE: does not support globs — check_path must be a literal path
      if [ -e "$project_dir/$check_path" ]; then
        echo "pass"
      else
        echo "fail"
      fi
      ;;

    file_contains)
      # Handle glob patterns in path
      # Supports: **/*.py, **/*.{py,go,rs}, **/config.py
      local target_files=()
      if [[ "$check_path" == *"*"* ]]; then
        local find_pattern
        find_pattern=$(basename "$check_path")
        local find_args=("$project_dir" -path "*/.venv" -prune -o -path "*/.git" -prune -o -path "*/node_modules" -prune -o -path "*/target" -prune)

        # Handle brace expansion: *.{py,go,rs} → multiple -name args
        if [[ "$find_pattern" == *"{"*"}"* ]]; then
          local prefix="${find_pattern%%\{*}"
          local remainder="${find_pattern#*\{}"
          local exts="${remainder%%\}*}"
          local suffix="${remainder#*\}}"
          local first=true
          find_args+=(-o \()
          IFS=',' read -ra ext_arr <<< "$exts"
          for ext in "${ext_arr[@]}"; do
            if $first; then first=false; else find_args+=(-o); fi
            find_args+=(-name "${prefix}${ext}${suffix}")
          done
          find_args+=(\) -print0)
        else
          find_args+=(-o -name "$find_pattern" -print0)
        fi

        while IFS= read -r -d '' f; do
          target_files+=("$f")
        done < <(find "${find_args[@]}" 2>/dev/null)
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
        if grep -qEi -- "$check_pattern" "$f" 2>/dev/null; then
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
        local find_pattern
        find_pattern=$(basename "$check_path")
        local find_args=("$project_dir" -path "*/.venv" -prune -o -path "*/.git" -prune -o -path "*/node_modules" -prune -o -path "*/target" -prune)

        if [[ "$find_pattern" == *"{"*"}"* ]]; then
          local prefix="${find_pattern%%\{*}"
          local remainder="${find_pattern#*\{}"
          local exts="${remainder%%\}*}"
          local suffix="${remainder#*\}}"
          local first=true
          find_args+=(-o \()
          IFS=',' read -ra ext_arr <<< "$exts"
          for ext in "${ext_arr[@]}"; do
            if $first; then first=false; else find_args+=(-o); fi
            find_args+=(-name "${prefix}${ext}${suffix}")
          done
          find_args+=(\) -print0)
        else
          find_args+=(-o -name "$find_pattern" -print0)
        fi

        while IFS= read -r -d '' f; do
          target_files+=("$f")
        done < <(find "${find_args[@]}" 2>/dev/null)
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
        if grep -qEi -- "$check_pattern" "$f" 2>/dev/null; then
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
    stages=$(grep -c "^FROM " "$project_dir/Dockerfile" 2>/dev/null || true)
    [ -z "$stages" ] && stages=0
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
    fixture_count=$(grep -c "@pytest.fixture" "$project_dir/tests/conftest.py" 2>/dev/null || true)
    [ -z "$fixture_count" ] && fixture_count=0
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

  # Auto-detect project stack
  detect_stack "$project_dir"
  local detected="$DETECTED_STACK"
  if [ -z "$detected" ]; then
    echo -e "${YELLOW}Warning:${NC} Could not detect stack for $project_name (no pyproject.toml, go.mod, Cargo.toml, or package.json)" >&2
    detected="base"
  fi

  # Resolve template chain for detected stack
  resolve_chain "$detected"
  local chain_str="${TEMPLATE_CHAIN[*]}"

  local check_count=$STD_COUNT

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
    # Skip checks that don't apply to this project's stack
    if ! check_applies_to_chain "$i" "$chain_str"; then
      continue
    fi

    local result
    result=$(run_check "$project_dir" "$i")

    result_ids+=("${STD_IDS[$i]}")
    result_names+=("${STD_NAMES[$i]}")
    result_severities+=("${STD_SEVERITIES[$i]}")
    result_statuses+=("$result")
    result_remediations+=("${STD_REMEDIATIONS[$i]}")

    case "$result" in
      pass) ((pass_count++)) || true ;;
      fail)
        ((fail_count++)) || true
        case "${STD_SEVERITIES[$i]}" in
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
      safe_candidate=$(printf '%s' "${UPSTREAM_CANDIDATES[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
      upstream_json+="\"$safe_candidate\""
    done
    upstream_json+="]"

    local safe_project_name safe_project_dir
    safe_project_name=$(printf '%s' "$project_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    safe_project_dir=$(printf '%s' "$project_dir" | sed 's/\\/\\\\/g; s/"/\\"/g')

    cat <<EOF
{
  "project": "$safe_project_name",
  "path": "$safe_project_dir",
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
    local tasks_json
    local safe_name
    local safe_dir
    safe_name=$(printf '%s' "$project_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    safe_dir=$(printf '%s' "$project_dir" | sed 's/\\/\\\\/g; s/"/\\"/g')
    tasks_json="{\"version\":\"1.0\",\"project\":\"$safe_name\",\"generated_by\":\"rdi-audit\",\"generated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"tasks\":["
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
        if [[ "${result_ids[$i]}" == *-CI-* ]] || [[ "${result_ids[$i]}" == CI-* ]]; then commit_type="ci"; fi
        if [[ "${result_ids[$i]}" == *-CON-* ]] || [[ "${result_ids[$i]}" == CON-* ]]; then commit_type="docs"; fi

        # Escape remediation for JSON
        local safe_remediation
        safe_remediation=$(printf '%s' "${result_remediations[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')

        tasks_json+="{\"id\":\"TASK-$(printf '%03d' $task_num)\",\"status\":\"pending\",\"priority\":$priority,\"title\":\"${result_ids[$i]}: ${result_names[$i]}\",\"description\":\"$safe_remediation\",\"blocked_by\":[],\"verification\":{\"test_command\":\"rdi-audit \\\"$safe_dir\\\" --json\",\"check_patterns\":[\"${result_ids[$i]}\"]},\"commit_type\":\"$commit_type\",\"attempts\":0,\"max_attempts\":3}"
        ((task_num++)) || true
      fi
    done

    tasks_json+="]}"
    echo "$tasks_json" | $PYTHON_CMD -m json.tool 2>/dev/null || echo "$tasks_json"
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
  echo -e "${DIM}Standards version: $STD_VERSION | $(date +%Y-%m-%d)${NC}"
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

    local score pass fail skip critical_fails upstream status_icon
    if [ "$JSON_TOOL" = "jq" ]; then
      read -r score pass fail skip critical_fails upstream <<< "$(echo "$json_result" | jq -r '[.score, .pass, .fail, .skip, .critical_failures, .upstream_candidates] | @tsv')"
    else
      local parsed
      parsed=$(node -e "
        const d = JSON.parse(process.argv[1]);
        console.log([d.score, d.pass, d.fail, d.skip, d.critical_failures, d.upstream_candidates].join(' '));
      " -- "$json_result")
      read -r score pass fail skip critical_fails upstream <<< "$parsed"
    fi

    # Guard against empty/non-integer values from failed parsing
    score=${score:-0}; pass=${pass:-0}; fail=${fail:-0}
    skip=${skip:-0}; critical_fails=${critical_fails:-0}; upstream=${upstream:-0}

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

    local upstream_val="${upstream:-0}"
    local upstream_display
    if [ "$upstream_val" -gt 0 ] 2>/dev/null; then
      # Pad to 4 chars visible width (ANSI codes don't count for width)
      upstream_display="${CYAN}$(printf '%-4s' "$upstream_val")${NC}"
    else
      upstream_display="$(printf '%-4s' "$upstream_val")"
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
  $STD_COUNT checks across 6 stacks (base, python, python-fastmcp, go, rust, node)
  Auto-detects project stack from manifest files
  Version: $STD_VERSION
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

  # Parse arguments — flags and path can appear in any order
  local project_dir=""
  local mode="text"
  local reverse_only=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --json) mode="json" ;;
      --generate-tasks) mode="tasks" ;;
      --reverse) reverse_only=true ;;
      --help|-h) usage; exit 0 ;;
      -*)
        echo -e "${RED}Unknown option:${NC} $1" >&2; exit 1 ;;
      *)
        if [ -z "$project_dir" ]; then
          project_dir="$1"
        else
          echo -e "${RED}Unexpected argument:${NC} $1" >&2; exit 1
        fi
        ;;
    esac
    shift
  done

  if [ -z "$project_dir" ]; then
    echo -e "${RED}Error:${NC} No project path specified" >&2
    usage
    exit 1
  fi

  # Resolve relative paths
  if [[ ! "$project_dir" = /* ]]; then
    project_dir="$(pwd)/$project_dir"
  fi

  # Strip trailing slash (guard against bare /)
  project_dir="${project_dir%/}"
  [ -z "$project_dir" ] && project_dir="/"

  if $reverse_only; then
    reverse_audit "$project_dir"
    exit 0
  fi

  audit_project "$project_dir" "$mode"
}

main "$@"
