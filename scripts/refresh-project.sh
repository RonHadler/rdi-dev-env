#!/bin/bash
#
# rdi-refresh — Refresh managed files from rdi-dev-env templates
#
# Copies "managed" files (CI workflows, review standards, dependabot)
# from the template chain into a target project, applying project-specific
# substitutions automatically from manifest metadata.
#
# Supports Python, Go, Node, Rust, and FastMCP projects via auto-detection.
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
# shellcheck disable=SC2034  # Used by sourced template-utils.sh
TEMPLATES_DIR="$DEV_ENV_DIR/templates"

# Source shared template utilities (provides PYTHON_CMD, detect_stack,
# resolve_chain, collect_managed_files, collect_seeded_files,
# extract_metadata, resolve_workflow_source, substitute_markers)
source "$SCRIPT_DIR/lib/template-utils.sh"

# ── Cleanup temp files on exit ───────────────────────────────
TMPFILES=()
cleanup() { [ ${#TMPFILES[@]} -gt 0 ] && rm -f "${TMPFILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# ── Process a single managed file ─────────────────────────────
# Args: <source_abs_path> <dest_rel> <project_dir> <apply>
process_managed_file() {
  local source_path="$1"
  local dest_rel="$2"
  local project_dir="$3"
  local apply="$4"

  local dest_path="$project_dir/$dest_rel"

  if [ ! -f "$source_path" ]; then
    echo -e "  ${RED}x${NC} $dest_rel — template not found: $source_path"
    return 1
  fi

  # Copy template to temp file and apply substitutions in-place
  local tmpfile
  tmpfile=$(mktemp)
  TMPFILES+=("$tmpfile")
  cp "$source_path" "$tmpfile"
  substitute_markers "$tmpfile"

  # Compare with destination
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

${BOLD}Stacks:${NC}
  Auto-detected from manifest files (pyproject.toml, go.mod, Cargo.toml, package.json).
  Managed and seeded file lists are resolved from the template chain.

${BOLD}Managed files${NC} (owned by rdi-dev-env, safe to overwrite):
  CI workflows, security scanning, code review, dependabot config

${BOLD}Seeded files${NC} (created once if missing, then project-owned):
  CLAUDE.md, AGENTS.md, GEMINI.md, docs scaffolding

${BOLD}Not managed${NC} (project-owned, use rdi-audit to check):
  Dockerfile, Makefile, conftest.py, config.py, pyproject.toml
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

  # ── Auto-detect stack ──
  detect_stack "$project_dir"
  local detected="${DETECTED_STACK:-base}"
  if [ "$detected" = "base" ] && [ -z "$DETECTED_STACK" ]; then
    echo -e "${YELLOW}Warning:${NC} Could not detect stack (no manifest file found), falling back to base" >&2
  fi

  # ── Resolve template chain ──
  if ! resolve_chain "$detected"; then
    echo -e "${RED}Error:${NC} Failed to resolve template chain for '$detected'" >&2
    exit 1
  fi
  local chain_display="${TEMPLATE_CHAIN[*]}"

  # ── Extract project metadata (polymorphic) ──
  extract_metadata "$project_dir"
  if [ -z "$META_PROJECT_NAME" ]; then
    echo -e "${YELLOW}Warning:${NC} Could not extract project name from manifest — substitutions may be incomplete" >&2
  fi

  # ── Collect file lists from template chain ──
  collect_managed_files
  collect_seeded_files

  local project_basename
  project_basename=$(basename "$project_dir")

  echo -e "${BOLD}rdi-refresh: ${CYAN}$project_basename${NC}"
  echo -e "${DIM}Stack: $detected ($chain_display) | Project: ${META_PROJECT_NAME:-unknown} | Branch: ${META_DEFAULT_BRANCH:-main}${NC}"
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

  # ── Process managed files ──
  local stack dest_rel source_path j try_stack
  echo -e "${BOLD}Managed Files${NC} ${DIM}(owned by rdi-dev-env — safe to overwrite)${NC}"

  if [ ${#MANAGED_FILES[@]} -eq 0 ]; then
    echo -e "  ${DIM}(no managed files in template chain)${NC}"
  fi

  for entry in "${MANAGED_FILES[@]}"; do
    stack="${entry%%:*}"
    dest_rel="${entry#*:}"

    # Resolve the source template file.
    # Try the declaring stack first, then walk chain backwards (most specific → base)
    # to find the actual template source.
    source_path=""
    source_path=$(resolve_workflow_source "$stack" "$dest_rel")
    if [ -z "$source_path" ] || [ ! -f "$source_path" ]; then
      # Walk chain in reverse to find the source
      j=${#TEMPLATE_CHAIN[@]}
      while [ $j -gt 0 ]; do
        ((j--)) || true
        try_stack="${TEMPLATE_CHAIN[$j]}"
        source_path=$(resolve_workflow_source "$try_stack" "$dest_rel")
        if [ -n "$source_path" ] && [ -f "$source_path" ]; then
          break
        fi
        source_path=""
      done
    fi

    if [ -z "$source_path" ]; then
      echo -e "  ${RED}x${NC} $dest_rel — template source not found in any stack"
      continue
    fi

    process_managed_file "$source_path" "$dest_rel" "$project_dir" "$apply" || true
  done

  # ── Process seeded files ──
  local dest_path actual_skeleton sk tmpfile
  local seeded_len=${#SEEDED_MAP_KEYS[@]}
  echo ""
  echo -e "${BOLD}Seeded Files${NC} ${DIM}(created once, then project-owned)${NC}"

  if [ ${#SEEDED_MAP_KEYS[@]} -eq 0 ]; then
    echo -e "  ${DIM}(no seeded files in template chain)${NC}"
  fi

  for ((i=0; i<seeded_len; i++)); do
    dest_rel="${SEEDED_MAP_KEYS[$i]}"
    stack="${SEEDED_MAP_VALUES[$i]}"
    dest_path="$project_dir/$dest_rel"

    if [ -e "$dest_path" ]; then
      echo -e "  ${DIM}-${NC} $dest_rel — already exists (project-owned, skipping)"
      continue
    fi

    # Find the seeded source file in the stack's template directory
    source_path="$TEMPLATES_DIR/$stack/$dest_rel"

    # Walk chain for skeleton — use the most specific layer that has one
    actual_skeleton=""
    for s in "${TEMPLATE_CHAIN[@]}"; do
      sk="$TEMPLATES_DIR/$s/skeletons/${dest_rel}.skeleton"
      if [ -f "$sk" ]; then
        actual_skeleton="$sk"
      fi
    done

    if [ -n "$actual_skeleton" ]; then
      # Assemble from skeleton + fragments
      if $apply; then
        tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        assemble_file "$actual_skeleton" "$tmpfile"
        substitute_markers "$tmpfile"
        mkdir -p "$(dirname "$dest_path")"
        cat "$tmpfile" > "$dest_path" && rm -f "$tmpfile"
        echo -e "  ${GREEN}+${NC} $dest_rel — created (assembled from skeleton + fragments)"
        ((SEEDED_CREATED++)) || true
      else
        echo -e "  ${YELLOW}+${NC} $dest_rel — would create (assembled from skeleton + fragments)"
        ((SEEDED_WOULD_CREATE++)) || true
      fi
    elif [ -f "$source_path" ]; then
      # Direct copy from template
      if $apply; then
        tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        cp "$source_path" "$tmpfile"
        substitute_markers "$tmpfile"
        mkdir -p "$(dirname "$dest_path")"
        cat "$tmpfile" > "$dest_path" && rm -f "$tmpfile"
        echo -e "  ${GREEN}+${NC} $dest_rel — created"
        ((SEEDED_CREATED++)) || true
      else
        echo -e "  ${YELLOW}+${NC} $dest_rel — would create"
        ((SEEDED_WOULD_CREATE++)) || true
      fi
    else
      echo -e "  ${DIM}-${NC} $dest_rel — template source not found in $stack/ (skipping)"
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
