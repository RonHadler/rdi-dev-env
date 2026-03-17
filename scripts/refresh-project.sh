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
  # Review standards
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

  # Extract project name (e.g. "rdi-datagov-mcp")
  PROJECT_NAME=$(grep -E '^name\s*=' "$pyproject" | head -1 | sed 's/.*=\s*"\(.*\)"/\1/')

  # Derive package name: rdi-datagov-mcp -> rdi_datagov_mcp
  PACKAGE_NAME=$(echo "$PROJECT_NAME" | tr '-' '_')

  # Derive upper package name: RDI_DATAGOV_MCP
  UPPER_PACKAGE_NAME=$(echo "$PACKAGE_NAME" | tr '[:lower:]' '[:upper:]')

  # Derive display name: rdi-datagov-mcp -> RDI Datagov MCP
  DISPLAY_NAME=$(echo "$PROJECT_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

  # Extract description
  DESCRIPTION=$(grep -E '^description\s*=' "$pyproject" | head -1 | sed 's/.*=\s*"\(.*\)"/\1/' || echo "")

  if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error:${NC} Could not extract project name from $pyproject" >&2
    return 1
  fi
}

# ── Apply substitutions to a template ─────────────────────────
apply_substitutions() {
  local content="$1"
  echo "$content" \
    | sed "s|<!-- CUSTOMIZE: Project Name -->|$DISPLAY_NAME|g" \
    | sed "s|<!-- CUSTOMIZE: project-name -->|$PROJECT_NAME|g" \
    | sed "s|<!-- CUSTOMIZE: package_name -->|$PACKAGE_NAME|g" \
    | sed "s|<!-- CUSTOMIZE: PACKAGE_NAME -->|$UPPER_PACKAGE_NAME|g" \
    | sed "s|<!-- CUSTOMIZE: description -->|$DESCRIPTION|g" \
    | sed "s|<!-- CUSTOMIZE: date -->|$(date +%Y-%m-%d)|g" \
    | sed "s|# CUSTOMIZE:.*||g"
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

  # Read template and apply substitutions
  local content
  content=$(cat "$template_path")
  local processed
  processed=$(apply_substitutions "$content")

  # Check if destination exists and compare
  if [ -f "$dest_path" ]; then
    local existing
    existing=$(cat "$dest_path")
    if [ "$processed" = "$existing" ]; then
      echo -e "  ${DIM}-${NC} $dest_rel — already up to date"
      return 0
    fi

    if [ "$apply" = "true" ]; then
      mkdir -p "$(dirname "$dest_path")"
      echo "$processed" > "$dest_path"
      echo -e "  ${GREEN}↻${NC} $dest_rel — updated"
      ((UPDATED++)) || true
    else
      echo -e "  ${YELLOW}~${NC} $dest_rel — would update (differs from template)"
      ((WOULD_UPDATE++)) || true
    fi
  else
    if [ "$apply" = "true" ]; then
      mkdir -p "$(dirname "$dest_path")"
      echo "$processed" > "$dest_path"
      echo -e "  ${GREEN}+${NC} $dest_rel — created"
      ((CREATED++)) || true
    else
      echo -e "  ${YELLOW}+${NC} $dest_rel — would create (missing)"
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
  echo -e "${DIM}Project: $PROJECT_NAME | Package: $PACKAGE_NAME${NC}"
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

  echo -e "${BOLD}Managed Files${NC}"
  for entry in "${MANAGED_FILES[@]}"; do
    local template_rel="${entry%%:*}"
    local dest_rel="${entry##*:}"
    process_file "$template_rel" "$dest_rel" "$project_dir" "$apply" || true
  done

  echo ""

  # Summary
  if $apply; then
    echo -e "${BOLD}Summary:${NC} ${GREEN}$CREATED created${NC}, ${GREEN}$UPDATED updated${NC}"
  else
    local total=$((WOULD_CREATE + WOULD_UPDATE))
    if [ "$total" -eq 0 ]; then
      echo -e "${GREEN}All managed files are up to date.${NC}"
    else
      echo -e "${BOLD}Summary:${NC} ${YELLOW}$WOULD_CREATE to create${NC}, ${YELLOW}$WOULD_UPDATE to update${NC}"
      echo -e "${DIM}Run with --apply to write changes.${NC}"
    fi
  fi

  # Generate tasks for remaining gaps
  if $apply && $generate_tasks; then
    echo ""
    echo -e "${BOLD}Generating tasks for remaining gaps...${NC}"
    local audit_script="$DEV_ENV_DIR/scripts/audit-project.sh"
    if [ -f "$audit_script" ]; then
      bash "$audit_script" "$project_dir" --generate-tasks > "$project_dir/tasks.json"
      local task_count
      if command -v jq &>/dev/null; then
        task_count=$(jq '.tasks | length' "$project_dir/tasks.json")
      else
        task_count=$(node -e "
          const fs = require('fs'), path = require('path');
          const d = JSON.parse(fs.readFileSync(path.resolve(process.argv[1]), 'utf8'));
          console.log(d.tasks.length);
        " -- "$project_dir/tasks.json")
      fi
      if [ "$task_count" -gt 0 ]; then
        echo -e "  ${GREEN}+${NC} tasks.json — $task_count remaining task(s) for project agent"
      else
        echo -e "  ${DIM}-${NC} tasks.json — no remaining tasks (fully compliant!)"
        rm -f "$project_dir/tasks.json"
      fi
    else
      echo -e "  ${YELLOW}~${NC} Audit script not found — skipping task generation"
    fi
  fi

  echo ""
}

main "$@"
