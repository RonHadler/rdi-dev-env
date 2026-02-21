#!/bin/bash
#
# rdi-dev-env — Generic Quality Gate (Continuous Development Watch)
#
# Auto-detects project type (Node.js, Python, Go) and runs tiered checks:
#   Tier 1: Security pattern scan (instant, grep-based)
#   Tier 2: Type/lint checks (tsc, mypy, go vet)
#   Tier 3: Related tests (jest, pytest, go test)
#
# Usage:
#   cd /path/to/project
#   bash /path/to/quality-gate.sh
#
# Options:
#   --no-test    Skip test tier (faster feedback)
#   --once       Run checks once and exit (no watch loop)
#
# Recommended: Run in dedicated tmux pane (Pane 2)
#

set -uo pipefail

# ── Options ──────────────────────────────────────────────────
SKIP_TESTS=false
RUN_ONCE=false

for arg in "$@"; do
  case $arg in
    --no-test)  SKIP_TESTS=true ;;
    --once)     RUN_ONCE=true ;;
    *)          echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Project Detection ────────────────────────────────────────
PROJECT_ROOT="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
PROJECT_TYPE="unknown"

if [ -f "package.json" ] && [ -d "src" -o -d "app" -o -d "lib" ]; then
  PROJECT_TYPE="node"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
  PROJECT_TYPE="python"
elif [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
elif [ -f "Makefile" ] && grep -q 'go ' Makefile 2>/dev/null; then
  PROJECT_TYPE="go"
fi

# ── Watch directories based on project type ──────────────────
case $PROJECT_TYPE in
  node)
    WATCH_DIRS=()
    [ -d "src" ] && WATCH_DIRS+=("src/")
    [ -d "app" ] && WATCH_DIRS+=("app/")
    [ -d "lib" ] && WATCH_DIRS+=("lib/")
    WATCH_EXTS="-name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx'"
    ;;
  python)
    WATCH_DIRS=()
    # Find Python source directories
    for d in src/ app/ lib/ $(find . -maxdepth 1 -name '*.py' -printf '%h/' 2>/dev/null | sort -u); do
      [ -d "$d" ] && WATCH_DIRS+=("$d")
    done
    [ ${#WATCH_DIRS[@]} -eq 0 ] && WATCH_DIRS=(".")
    WATCH_EXTS="-name '*.py'"
    ;;
  go)
    WATCH_DIRS=(".")
    WATCH_EXTS="-name '*.go'"
    ;;
  *)
    echo -e "${RED}Error: Cannot detect project type in $(pwd)${NC}"
    echo "Supported: Node.js (package.json), Python (pyproject.toml), Go (go.mod)"
    exit 1
    ;;
esac

# ── Paths ────────────────────────────────────────────────────
MARKER_FILE="/tmp/.qg-${PROJECT_NAME}-marker"
LOCK_FILE="/tmp/.qg-${PROJECT_NAME}-lock"
RUN_COUNT=0

# ── Cleanup on exit ──────────────────────────────────────────
cleanup() {
  rm -f "$LOCK_FILE" "$MARKER_FILE"
  echo -e "\n${DIM}Quality gate stopped.${NC}"
  exit 0
}
trap cleanup SIGINT SIGTERM

# ── Helpers ──────────────────────────────────────────────────
timestamp() {
  date '+%H:%M:%S'
}

separator() {
  local cols=${COLUMNS:-80}
  printf '%*s\n' "$cols" '' | tr ' ' '─'
}

# ══════════════════════════════════════════════════════════════
# Security Scan (shared across all project types)
# ══════════════════════════════════════════════════════════════
security_scan() {
  local critical=0
  local warnings=0

  # File extensions to scan based on project type
  local include_flags=""
  case $PROJECT_TYPE in
    node)   include_flags="--include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx'" ;;
    python) include_flags="--include='*.py'" ;;
    go)     include_flags="--include='*.go'" ;;
  esac

  # ── Critical: Hardcoded API keys ──
  local keys
  keys=$(eval grep -rnE $include_flags \
    "'(sk-[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9_-]{35}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36})'" \
    "${WATCH_DIRS[@]}" 2>/dev/null \
    | grep -v node_modules | grep -v '.next' | grep -v __pycache__ \
    | grep -v '\.test\.' | grep -v '__tests__' | grep -v '_test\.' \
    | grep -v 'quality-gate' || true)

  if [ -n "$keys" ]; then
    echo -e "  ${RED}CRITICAL: Possible hardcoded API key${NC}"
    echo "$keys" | head -5 | while IFS= read -r line; do
      echo -e "    ${DIM}$line${NC}"
    done
    ((critical++))
  fi

  # ── Critical: eval() / exec() usage ──
  local evals
  case $PROJECT_TYPE in
    node)
      evals=$(eval grep -rnE $include_flags "'\beval\s*\('" \
        "${WATCH_DIRS[@]}" 2>/dev/null \
        | grep -v node_modules | grep -v '.next' \
        | grep -v '\.test\.' | grep -v '__tests__' || true)
      ;;
    python)
      evals=$(eval grep -rnE $include_flags "'\b(eval|exec)\s*\('" \
        "${WATCH_DIRS[@]}" 2>/dev/null \
        | grep -v __pycache__ | grep -v '\.test' | grep -v 'test_' || true)
      ;;
    go)
      evals=""  # Go doesn't have eval
      ;;
  esac

  if [ -n "$evals" ]; then
    echo -e "  ${RED}CRITICAL: eval()/exec() usage${NC}"
    echo "$evals" | head -5 | while IFS= read -r line; do
      echo -e "    ${DIM}$line${NC}"
    done
    ((critical++))
  fi

  # ── Node.js specific: dangerouslySetInnerHTML ──
  if [ "$PROJECT_TYPE" = "node" ]; then
    local dangerous
    dangerous=$(grep -rnE --include='*.ts' --include='*.tsx' \
      'dangerouslySetInnerHTML' \
      "${WATCH_DIRS[@]}" 2>/dev/null \
      | grep -v node_modules | grep -v '.next' \
      | grep -v '\.test\.' | grep -v '__tests__' || true)

    if [ -n "$dangerous" ]; then
      echo -e "  ${YELLOW}WARNING: dangerouslySetInnerHTML usage${NC}"
      echo "$dangerous" | head -3 | while IFS= read -r line; do
        echo -e "    ${DIM}$line${NC}"
      done
      ((warnings++))
    fi
  fi

  # ── Python specific: subprocess with shell=True ──
  if [ "$PROJECT_TYPE" = "python" ]; then
    local shell_true
    shell_true=$(grep -rnE --include='*.py' \
      'subprocess\.\w+\(.*shell\s*=\s*True' \
      "${WATCH_DIRS[@]}" 2>/dev/null \
      | grep -v __pycache__ | grep -v '\.test' | grep -v 'test_' || true)

    if [ -n "$shell_true" ]; then
      echo -e "  ${YELLOW}WARNING: subprocess with shell=True${NC}"
      echo "$shell_true" | head -3 | while IFS= read -r line; do
        echo -e "    ${DIM}$line${NC}"
      done
      ((warnings++))
    fi
  fi

  # ── Summary line ──
  if [ $critical -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "  ${GREEN}No issues found${NC}"
  elif [ $critical -eq 0 ]; then
    echo -e "  ${YELLOW}$warnings warning(s)${NC}"
  fi

  return $critical
}

# ══════════════════════════════════════════════════════════════
# Type/Lint Check (project-specific)
# ══════════════════════════════════════════════════════════════
run_type_check() {
  local exit_code=0

  case $PROJECT_TYPE in
    node)
      echo -e "${BOLD}> Type Check${NC} ${DIM}(tsc --noEmit)${NC}"
      local tsc_output
      tsc_output=$(npx tsc --noEmit 2>&1) || true

      if echo "$tsc_output" | grep -qE 'error TS[0-9]+'; then
        exit_code=1
        local error_count
        error_count=$(echo "$tsc_output" | grep -cE 'error TS[0-9]+' || echo 0)
        echo -e "  ${RED}$error_count error(s)${NC}"
        echo "$tsc_output" | grep -E 'error TS[0-9]+' | head -10 | while IFS= read -r line; do
          echo -e "  ${DIM}$line${NC}"
        done
        [ "$error_count" -gt 10 ] && echo -e "  ${DIM}... and $((error_count - 10)) more${NC}"
      else
        echo -e "  ${GREEN}No errors${NC}"
      fi
      ;;

    python)
      echo -e "${BOLD}> Type Check${NC} ${DIM}(mypy)${NC}"
      if command -v mypy &>/dev/null; then
        local mypy_output
        mypy_output=$(mypy . --ignore-missing-imports 2>&1) || true

        if echo "$mypy_output" | grep -qE ': error:'; then
          exit_code=1
          local error_count
          error_count=$(echo "$mypy_output" | grep -cE ': error:' || echo 0)
          echo -e "  ${RED}$error_count error(s)${NC}"
          echo "$mypy_output" | grep -E ': error:' | head -10 | while IFS= read -r line; do
            echo -e "  ${DIM}$line${NC}"
          done
        else
          echo -e "  ${GREEN}No errors${NC}"
        fi
      else
        echo -e "  ${DIM}mypy not installed (skipping)${NC}"
      fi
      ;;

    go)
      echo -e "${BOLD}> Vet${NC} ${DIM}(go vet ./...)${NC}"
      local vet_output
      vet_output=$(go vet ./... 2>&1) || true

      if [ -n "$vet_output" ]; then
        exit_code=1
        echo -e "  ${RED}Issues found${NC}"
        echo "$vet_output" | head -10 | while IFS= read -r line; do
          echo -e "  ${DIM}$line${NC}"
        done
      else
        echo -e "  ${GREEN}No issues${NC}"
      fi
      ;;
  esac

  return $exit_code
}

# ══════════════════════════════════════════════════════════════
# Test Runner (project-specific)
# ══════════════════════════════════════════════════════════════
run_tests() {
  local changed_files="$1"
  local exit_code=0

  case $PROJECT_TYPE in
    node)
      echo -e "${BOLD}> Tests${NC} ${DIM}(jest --findRelatedTests)${NC}"
      local files_list
      files_list=$(echo "$changed_files" | tr '\n' ' ')
      local test_output
      test_output=$(npx jest --findRelatedTests $files_list --no-coverage --colors 2>&1) || true
      exit_code=$?

      if [ $exit_code -eq 0 ]; then
        echo "$test_output" | grep -E '(Tests:|Test Suites:|Passed|passed)' | tail -3 | while IFS= read -r line; do
          echo -e "  $line"
        done
        if ! echo "$test_output" | grep -qE '(Tests:|Test Suites:)'; then
          echo -e "  ${GREEN}All related tests passed${NC}"
        fi
      else
        echo "$test_output" | grep -E '(FAIL|PASS|Tests:|●|✕|✓)' | head -15 | while IFS= read -r line; do
          echo -e "  $line"
        done
      fi
      ;;

    python)
      echo -e "${BOLD}> Tests${NC} ${DIM}(pytest)${NC}"
      local test_output
      if command -v pytest &>/dev/null; then
        test_output=$(pytest --tb=short -q 2>&1) || true
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
          echo "$test_output" | tail -3 | while IFS= read -r line; do
            echo -e "  $line"
          done
        else
          echo "$test_output" | grep -E '(FAILED|ERROR|PASSED|::)' | head -15 | while IFS= read -r line; do
            echo -e "  $line"
          done
        fi
      else
        echo -e "  ${DIM}pytest not installed (skipping)${NC}"
      fi
      ;;

    go)
      echo -e "${BOLD}> Tests${NC} ${DIM}(go test ./...)${NC}"
      local test_output
      test_output=$(go test ./... -count=1 -short 2>&1) || true
      exit_code=$?

      if [ $exit_code -eq 0 ]; then
        echo "$test_output" | grep -E '(ok|PASS)' | tail -5 | while IFS= read -r line; do
          echo -e "  ${GREEN}$line${NC}"
        done
      else
        echo "$test_output" | grep -E '(FAIL|---)|Error' | head -15 | while IFS= read -r line; do
          echo -e "  ${RED}$line${NC}"
        done
      fi
      ;;
  esac

  return $exit_code
}

# ══════════════════════════════════════════════════════════════
# Run All Checks
# ══════════════════════════════════════════════════════════════
run_checks() {
  local changed_files="$1"
  local start_time
  start_time=$(date +%s)
  local file_count
  file_count=$(echo "$changed_files" | grep -c '.' || echo 0)

  ((RUN_COUNT++))

  # Header
  clear
  echo -e "${CYAN}${BOLD}+==================================================+${NC}"
  echo -e "${CYAN}${BOLD}|        Quality Gate  v2.0  (${PROJECT_TYPE})              |${NC}"
  echo -e "${CYAN}${BOLD}|        ${PROJECT_NAME}${NC}"
  echo -e "${CYAN}${BOLD}+==================================================+${NC}"
  echo ""
  echo -e "${DIM}Run #${RUN_COUNT} -- $(timestamp) -- ${file_count} file(s) changed${NC}"
  echo ""

  # Show changed files (abbreviated)
  echo "$changed_files" | head -5 | while IFS= read -r f; do
    echo -e "  ${DIM}~ $f${NC}"
  done
  [ "$file_count" -gt 5 ] && echo -e "  ${DIM}... and $((file_count - 5)) more${NC}"
  echo ""

  # ── Tier 1: Security ──
  separator
  echo -e "${BOLD}> Security Scan${NC}"
  local sec_result=0
  security_scan || sec_result=$?
  echo ""

  # ── Tier 2: Type/Lint ──
  separator
  local type_result=0
  run_type_check || type_result=$?
  echo ""

  # ── Tier 3: Tests ──
  local test_result=0
  if [ "$SKIP_TESTS" = false ]; then
    separator
    run_tests "$changed_files" || test_result=$?
    echo ""
  fi

  # ── Summary Dashboard ──
  local elapsed=$(( $(date +%s) - start_time ))
  separator
  echo ""
  echo -e "${BOLD}  Summary${NC} ${DIM}(${elapsed}s)${NC}"
  echo ""

  if [ $sec_result -eq 0 ]; then
    echo -e "    ${GREEN}+${NC} Security"
  else
    echo -e "    ${RED}x${NC} Security ${RED}($sec_result critical)${NC}"
  fi

  if [ $type_result -eq 0 ]; then
    echo -e "    ${GREEN}+${NC} Types"
  else
    echo -e "    ${RED}x${NC} Types"
  fi

  if [ "$SKIP_TESTS" = false ]; then
    if [ $test_result -eq 0 ]; then
      echo -e "    ${GREEN}+${NC} Tests"
    else
      echo -e "    ${RED}x${NC} Tests"
    fi
  else
    echo -e "    ${DIM}-${NC} Tests ${DIM}(skipped)${NC}"
  fi

  echo ""
  echo -e "${DIM}  Watching for changes...${NC}"

  if [ $sec_result -gt 0 ] || [ $type_result -ne 0 ] || [ $test_result -ne 0 ]; then
    return 1
  fi
  return 0
}

# ══════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════

# Startup banner
echo -e "${CYAN}${BOLD}+==================================================+${NC}"
echo -e "${CYAN}${BOLD}|        Quality Gate  v2.0  (${PROJECT_TYPE})              |${NC}"
echo -e "${CYAN}${BOLD}|        ${PROJECT_NAME}${NC}"
echo -e "${CYAN}${BOLD}|        Watching for changes                      |${NC}"
echo -e "${CYAN}${BOLD}+==================================================+${NC}"
echo ""

# Run initial security scan
echo -e "${BOLD}> Initial Security Scan${NC}"
security_scan || true
echo ""

if [ "$RUN_ONCE" = true ]; then
  echo ""
  run_type_check || true
  echo ""
  if [ "$SKIP_TESTS" = false ]; then
    run_tests "." || true
  fi
  exit 0
fi

# Initialize marker
touch "$MARKER_FILE"
rm -f "$LOCK_FILE"

echo -e "${DIM}Polling every 2s. Press Ctrl+C to stop.${NC}"
echo ""

# ── Watch Loop ───────────────────────────────────────────────
while true; do
  sleep 2

  # Build find command for project type
  CHANGED=""
  for dir in "${WATCH_DIRS[@]}"; do
    dir_changed=$(eval find "$dir" \
      \\\( $WATCH_EXTS \\\) \
      -newer "$MARKER_FILE" \
      ! -path "'*/node_modules/*'" \
      ! -path "'*/.next/*'" \
      ! -path "'*/__pycache__/*'" \
      ! -path "'*/vendor/*'" \
      2>/dev/null || true)
    [ -n "$dir_changed" ] && CHANGED="${CHANGED}${dir_changed}"$'\n'
  done

  # Trim trailing newline
  CHANGED=$(echo "$CHANGED" | sed '/^$/d' | sort)

  if [ -n "$CHANGED" ]; then
    touch "$MARKER_FILE"

    if [ -f "$LOCK_FILE" ]; then
      continue
    fi

    touch "$LOCK_FILE"
    run_checks "$CHANGED" || true
    rm -f "$LOCK_FILE"

    # Check for changes during run
    POST_CHANGED=""
    for dir in "${WATCH_DIRS[@]}"; do
      dir_changed=$(eval find "$dir" \
        \\\( $WATCH_EXTS \\\) \
        -newer "$MARKER_FILE" \
        ! -path "'*/node_modules/*'" \
        ! -path "'*/.next/*'" \
        ! -path "'*/__pycache__/*'" \
        ! -path "'*/vendor/*'" \
        2>/dev/null || true)
      [ -n "$dir_changed" ] && POST_CHANGED="${POST_CHANGED}${dir_changed}"$'\n'
    done
    POST_CHANGED=$(echo "$POST_CHANGED" | sed '/^$/d' | sort)

    if [ -n "$POST_CHANGED" ]; then
      touch "$MARKER_FILE"
      touch "$LOCK_FILE"
      run_checks "$POST_CHANGED" || true
      rm -f "$LOCK_FILE"
    fi
  fi
done
