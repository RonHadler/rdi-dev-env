#!/bin/bash
#
# rdi-refresh — Refresh managed files from rdi-dev-env templates
#
# Copies "managed" files (CI workflows, review standards, dependabot)
# from templates into a target project, applying project-specific
# substitutions automatically from pyproject.toml metadata.
#
# Does NOT touch "seeded" files (Makefile, conftest, config, Dockerfile)
# that the project owns. Use rdi-audit for those.
#
# Usage:
#   rdi-refresh /path/to/project              # Dry run (show what would change)
#   rdi-refresh /path/to/project --apply      # Apply changes
#   rdi-refresh /path/to/project --apply --tasks  # Apply + generate tasks.json for remaining gaps
#
# Exit codes:
#   0 = success
#   1 = error

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Paths ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ENV_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$DEV_ENV_DIR/templates"

# ── Python command (python3 or python) ───────────────────────
PYTHON_CMD="python3"
if ! python3 --version &>/dev/null; then
  PYTHON_CMD="python"
fi
if ! command -v "$PYTHON_CMD" &>/dev/null; then
  echo -e "${RED}Error:${NC} Python not found (need python3 or python)" >&2
  exit 1
fi

# ── Cleanup temp files on exit ───────────────────────────────
TMPFILES=()
cleanup() { [ ${#TMPFILES[@]} -gt 0 ] && rm -f "${TMPFILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# ── Managed file manifest ────────────────────────────────────
# Format: "template_source:project_destination"
# These files are owned by rdi-dev-env and can be overwritten safely.
MANAGED_FILES=(
  # CI workflows (need substitutions)
  "github-workflows/ci-python.yml:.github/workflows/ci.yml"
  "github-workflows/security-python.yml:.github/workflows/security.yml"
  "github-workflows/gemini-code-review.yml:.github/workflows/gemini-code-review.yml"
  # CI workflows (no substitutions needed)
  "github-workflows/stale.yml:.github/workflows/stale.yml"
  "github-workflows/dependabot.yml:.github/dependabot.yml"
)

# Seeded files — created once if missing, never overwritten.
# Project owns these after initial creation.
SEEDED_FILES=(
  "GEMINI.md:GEMINI.md"
)

# ── Extract project metadata from pyproject.toml ─────────────
extract_metadata() {
  local project_dir="$1"
  local pyproject="$project_dir/pyproject.toml"

  if [ ! -f "$pyproject" ]; then
    echo -e "${RED}Error:${NC} No pyproject.toml found in $project_dir" >&2
    return 1
  fi

  # Output TSV directly from Python — no jq/node dependency needed
  local py_script
  py_script=$(cat <<'PYEOF'
import sys
try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        sys.exit(1)
with open(sys.argv[1], "rb") as f:
    p = tomllib.load(f).get("project", {})
name = p.get("name", "")
desc = p.get("description", "").replace("\n", " ").replace("\t", " ").strip()
pkg = name.replace("-", "_")
print(f"{name}\t{pkg}\t{pkg.upper()}\t{name.replace('-', ' ').title()}\t{desc}")
PYEOF
)
  local metadata
  if ! metadata=$("$PYTHON_CMD" -c "$py_script" "$pyproject" 2>/dev/null); then
    echo -e "${RED}Error:${NC} Could not parse pyproject.toml (file may be malformed, or requires Python 3.11+ / 'tomli')" >&2
    return 1
  fi

  IFS=$'\t' read -r PROJECT_NAME PACKAGE_NAME UPPER_PACKAGE_NAME DISPLAY_NAME DESCRIPTION <<< "$metadata"

  if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error:${NC} Could not extract project name from $pyproject" >&2
    return 1
  fi

  # Detect default branch from git
  DEFAULT_BRANCH="main"
  if [ -d "$project_dir/.git" ]; then
    # Try HEAD reference first, then fall back to common names
    local head_ref
    head_ref=$(git -C "$project_dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
    if [ -n "$head_ref" ]; then
      DEFAULT_BRANCH="$head_ref"
    elif git -C "$project_dir" rev-parse --verify refs/heads/master &>/dev/null; then
      DEFAULT_BRANCH="master"
    fi
  fi
}

# ── Escape a string for use in sed replacement ────────────────
sed_escape() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

# ── Apply substitutions to a template file (reads from stdin) ─
apply_substitutions() {
  local safe_display safe_name safe_pkg safe_upper safe_desc safe_date safe_branch
  safe_display=$(sed_escape "$DISPLAY_NAME")
  safe_name=$(sed_escape "$PROJECT_NAME")
  safe_pkg=$(sed_escape "$PACKAGE_NAME")
  safe_upper=$(sed_escape "$UPPER_PACKAGE_NAME")
  safe_desc=$(sed_escape "$DESCRIPTION")
  safe_branch=$(sed_escape "$DEFAULT_BRANCH")
  safe_date=$(date +%Y-%m-%d)

  sed \
    -e "s|<!-- CUSTOMIZE: Project Name -->|$safe_display|g" \
    -e "s|<!-- CUSTOMIZE: project-name -->|$safe_name|g" \
    -e "s|<!-- CUSTOMIZE: package_name -->|$safe_pkg|g" \
    -e "s|<!-- CUSTOMIZE: PACKAGE_NAME -->|$safe_upper|g" \
    -e "s|<!-- CUSTOMIZE: description -->|$safe_desc|g" \
    -e "s|<!-- CUSTOMIZE: default_branch -->|$safe_branch|g" \
    -e "s|<!-- CUSTOMIZE: date -->|$safe_date|g" \
    -e "s|# CUSTOMIZE:.*||g"
}

# ── Process a single managed file ─────────────────────────────
process_file() {
  local template_rel="$1"
  local dest_rel="$2"
  local project_dir="$3"
  local apply="$4"

  local template_path="$TEMPLATES_DIR/$template_rel"
  local dest_path="$project_dir/$dest_rel"

  if [ ! -f "$template_path" ]; then
    echo -e "  ${RED}x${NC} $dest_rel — template not found: $template_rel"
    return 1
  fi

  # Generate processed content into a temp file (avoids variable truncation)
  local tmpfile
  tmpfile=$(mktemp)
  TMPFILES+=("$tmpfile")
  apply_substitutions < "$template_path" > "$tmpfile"

  # Check if destination exists and compare
  if [ -f "$dest_path" ]; then
    if cmp -s "$tmpfile" "$dest_path"; then
      echo -e "  ${DIM}-${NC} $dest_rel — already up to date"
      rm -f "$tmpfile"
      return 0
    fi

    if [ "$apply" = "true" ]; then
      mkdir -p "$(dirname "$dest_path")"
      cat "$tmpfile" > "$dest_path" && rm -f "$tmpfile"
      echo -e "  ${GREEN}↻${NC} $dest_rel — updated"
      ((UPDATED++)) || true
    else
      echo -e "  ${YELLOW}~${NC} $dest_rel — would update (differs from template)"
      rm -f "$tmpfile"
      ((WOULD_UPDATE++)) || true
    fi
  else
    if [ "$apply" = "true" ]; then
      mkdir -p "$(dirname "$dest_path")"
      cat "$tmpfile" > "$dest_path" && rm -f "$tmpfile"
      echo -e "  ${GREEN}+${NC} $dest_rel — created"
      ((CREATED++)) || true
    else
      echo -e "  ${YELLOW}+${NC} $dest_rel — would create (missing)"
      rm -f "$tmpfile"
      ((WOULD_CREATE++)) || true
    fi
  fi
}

# ── Usage ────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}rdi-refresh${NC} — Refresh managed files from rdi-dev-env templates

${BOLD}Usage:${NC}
  rdi-refresh <path>                     Dry run (show what would change)
  rdi-refresh <path> --apply             Apply managed file updates
  rdi-refresh <path> --apply --tasks     Apply + generate tasks.json for remaining gaps

${BOLD}Managed files${NC} (owned by rdi-dev-env, safe to overwrite):
  .github/workflows/ci.yml              CI lint/test pipeline
  .github/workflows/security.yml        Security scanning
  .github/workflows/gemini-code-review.yml  AI code review
  .github/workflows/stale.yml           Stale PR/issue cleanup
  .github/dependabot.yml                Dependency updates
  GEMINI.md                             Code review standards

${BOLD}Not managed${NC} (project-owned, use rdi-audit to check):
  Dockerfile, Makefile, conftest.py, config.py, pyproject.toml,
  CLAUDE.md, AGENTS.md
EOF
}

# ── Main ─────────────────────────────────────────────────────
main() {
  if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
  fi

  local project_dir=""
  local apply=false
  local generate_tasks=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --apply) apply=true ;;
      --tasks) generate_tasks=true ;;
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
  project_dir="${project_dir%/}"
  [ -z "$project_dir" ] && project_dir="/"

  if [ ! -d "$project_dir" ]; then
    echo -e "${RED}Error:${NC} Directory not found: $project_dir" >&2
    exit 1
  fi

  # Extract project metadata
  extract_metadata "$project_dir" || exit 1

  local project_basename
  project_basename=$(basename "$project_dir")

  echo -e "${BOLD}rdi-refresh: ${CYAN}$project_basename${NC}"
  echo -e "${DIM}Project: $PROJECT_NAME | Package: $PACKAGE_NAME | Branch: $DEFAULT_BRANCH${NC}"
  if $apply; then
    echo -e "${DIM}Mode: apply${NC}"
  else
    echo -e "${DIM}Mode: dry run (use --apply to write changes)${NC}"
  fi
  echo ""

  # Counters
  UPDATED=0
  CREATED=0
  WOULD_UPDATE=0
  WOULD_CREATE=0

  local SEEDED_CREATED=0
  local SEEDED_WOULD_CREATE=0

  echo -e "${BOLD}Managed Files${NC} ${DIM}(owned by rdi-dev-env — safe to overwrite)${NC}"
  for entry in "${MANAGED_FILES[@]}"; do
    local template_rel="${entry%%:*}"
    local dest_rel="${entry##*:}"
    process_file "$template_rel" "$dest_rel" "$project_dir" "$apply" || true
  done

  echo ""
  echo -e "${BOLD}Seeded Files${NC} ${DIM}(created once, then project-owned)${NC}"
  for entry in "${SEEDED_FILES[@]}"; do
    local template_rel="${entry%%:*}"
    local dest_rel="${entry##*:}"
    local dest_path="$project_dir/$dest_rel"

    if [ -e "$dest_path" ]; then
      echo -e "  ${DIM}-${NC} $dest_rel — already exists (project-owned, skipping)"
    elif $apply; then
      local tmpfile
      tmpfile=$(mktemp)
      TMPFILES+=("$tmpfile")
      apply_substitutions < "$TEMPLATES_DIR/$template_rel" > "$tmpfile"
      mkdir -p "$(dirname "$dest_path")"
      cat "$tmpfile" > "$dest_path" && rm -f "$tmpfile"
      echo -e "  ${GREEN}+${NC} $dest_rel — created (customize <!-- CUSTOMIZE --> markers)"
      ((SEEDED_CREATED++)) || true
    else
      echo -e "  ${YELLOW}+${NC} $dest_rel — would create"
      ((SEEDED_WOULD_CREATE++)) || true
    fi
  done

  echo ""

  # Summary
  local total_created=$((CREATED + SEEDED_CREATED))
  local total_would=$((WOULD_CREATE + WOULD_UPDATE + SEEDED_WOULD_CREATE))
  if $apply; then
    echo -e "${BOLD}Summary:${NC} ${GREEN}$total_created created${NC}, ${GREEN}$UPDATED updated${NC}"
  else
    if [ "$total_would" -eq 0 ]; then
      echo -e "${GREEN}All files are up to date.${NC}"
    else
      echo -e "${BOLD}Summary:${NC} ${YELLOW}$((WOULD_CREATE + SEEDED_WOULD_CREATE)) to create${NC}, ${YELLOW}$WOULD_UPDATE to update${NC}"
      echo -e "${DIM}Run with --apply to write changes.${NC}"
    fi
  fi

  # Generate tasks for remaining gaps
  if $apply && $generate_tasks; then
    echo ""
    echo -e "${BOLD}Generating tasks for remaining gaps...${NC}"
    local audit_script="$DEV_ENV_DIR/scripts/audit-project.sh"
    if [ -f "$audit_script" ]; then
      TMPFILES+=("$project_dir/tasks.json.tmp")
      bash "$audit_script" "$project_dir" --generate-tasks > "$project_dir/tasks.json.tmp" 2>/dev/null || true
      if [ -s "$project_dir/tasks.json.tmp" ]; then
        mv "$project_dir/tasks.json.tmp" "$project_dir/tasks.json"
      else
        rm -f "$project_dir/tasks.json.tmp"
        echo -e "  ${RED}x${NC} Audit failed — no tasks generated"
        return 0
      fi
      local task_count
      task_count=$("$PYTHON_CMD" -c "
import json, sys
with open(sys.argv[1]) as f:
    print(len(json.load(f).get('tasks', [])))
" "$project_dir/tasks.json" 2>/dev/null) || task_count=-1

      if [ "$task_count" -gt 0 ]; then
        echo -e "  ${GREEN}+${NC} tasks.json — $task_count remaining task(s) for project agent"
      elif [ "$task_count" -eq 0 ]; then
        echo -e "  ${DIM}-${NC} tasks.json — no remaining tasks (fully compliant!)"
        rm -f "$project_dir/tasks.json"
      else
        echo -e "  ${GREEN}+${NC} tasks.json — created (could not count tasks)"
      fi
    else
      echo -e "  ${YELLOW}~${NC} Audit script not found — skipping task generation"
    fi
  fi

  echo ""
}

main "$@"
