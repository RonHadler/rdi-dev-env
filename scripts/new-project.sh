#!/bin/bash
#
# rdi-dev-env — Smart Project Scaffolder
#
# Interactive script to create new projects from templates.
# Supports all stacks defined in templates/*/template.json:
#   python, python-fastmcp, go, node, rust
#
# File lists, directories, and inheritance are driven by template.json
# definitions — the same source of truth used by rdi-refresh and rdi-audit.
#
# Usage:
#   new-project.sh
#
# Dependencies: git, python3 (or python), stack-specific tools (uv, npm, go, cargo)
#

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

# Source shared template utilities (provides resolve_chain, detect_stack,
# collect_managed_files, collect_seeded_files, assemble_file, copy_gitignore,
# substitute_markers, resolve_workflow_source, json_extract_*, PYTHON_CMD)
source "$SCRIPT_DIR/lib/template-utils.sh"

# ── Helpers ──────────────────────────────────────────────────
prompt_text() {
  local question="$1"
  local default="${2:-}"
  local result=""

  if [ -n "$default" ]; then
    echo -ne "${BOLD}$question${NC} ${DIM}[$default]${NC}: "
  else
    echo -ne "${BOLD}$question${NC}: "
  fi
  read -r result
  echo "${result:-$default}"
}

prompt_choice() {
  local question="$1"
  shift
  local options=("$@")

  echo -e "${BOLD}$question${NC}"
  for i in "${!options[@]}"; do
    echo -e "  ${CYAN}[$((i+1))]${NC} ${options[$i]}"
  done
  echo -ne "${BOLD}Choice${NC}: "
  read -r choice
  echo "$choice"
}

prompt_yn() {
  local question="$1"
  local default="${2:-y}"

  if [ "$default" = "y" ]; then
    echo -ne "${BOLD}$question${NC} ${DIM}[Y/n]${NC}: "
  else
    echo -ne "${BOLD}$question${NC} ${DIM}[y/N]${NC}: "
  fi
  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy] ]]
}

# ── Dependency Check ─────────────────────────────────────────
# Note: Python is validated by template-utils.sh on source (exits if missing).
check_deps() {
  if ! command -v git &>/dev/null; then
    echo -e "${RED}Missing required dependency: git${NC}"
    exit 1
  fi
}

# ── Stack Helpers ────────────────────────────────────────────

# Check if the template chain includes a Python stack.
is_python_stack() {
  for s in "${TEMPLATE_CHAIN[@]}"; do
    [ "$s" = "python" ] && return 0
  done
  return 1
}

# Check if a scaffold entry is a known project-root directory.
is_project_root_entry() {
  case "$1" in
    tests|tests/*|docs|docs/*|.github|.github/*|scripts|scripts/*|bin|bin/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve scaffold destination path.
# For Python stacks, bare names (not project-root dirs) go into the package dir.
resolve_scaffold_dest() {
  local entry="$1" target="$2"
  if is_python_stack && ! is_project_root_entry "$entry"; then
    echo "$target/$META_PACKAGE_NAME/$entry"
  else
    echo "$target/$entry"
  fi
}

# Extract scaffold.files from template.json as tab-separated dest\tsource pairs.
extract_scaffold_files() {
  local file="$1"
  $PYTHON_CMD -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
scaffold = data.get('scaffold') or {}
files = scaffold.get('files') or {}
for dest, src in files.items():
    print(dest + '\t' + src)
" "$file" 2>/dev/null | tr -d '\r' || true
}

# Apply all substitutions including GCP markers.
apply_all_substitutions() {
  local file="$1"
  if [ -n "$GCP_PROJECT_ID" ]; then
    substitute_markers "$file" "GCP project ID=$GCP_PROJECT_ID" "GCP region=$GCP_REGION"
  else
    substitute_markers "$file"
  fi
}

# ── Build Stack Menu ─────────────────────────────────────────
# Scan templates/*/template.json, skip base, sort by layer+name.
build_stack_menu() {
  STACK_NAMES=()
  STACK_LABELS=()

  local entries=()
  for tjson in "$TEMPLATES_DIR"/*/template.json; do
    [ -f "$tjson" ] || continue
    local name desc layer
    name=$(json_extract_field "$tjson" "name")
    [ "$name" = "base" ] && continue
    layer=$(json_extract_field "$tjson" "layer")
    desc=$(json_extract_field "$tjson" "description")
    entries+=("${layer:-0}"$'\t'"$name"$'\t'"$desc")
  done

  local sorted
  sorted=$(printf '%s\n' "${entries[@]}" | sort -t$'\t' -k1n -k2)

  while IFS=$'\t' read -r _layer name desc; do
    [ -z "$name" ] && continue
    STACK_NAMES+=("$name")
    STACK_LABELS+=("$name — $desc")
  done <<< "$sorted"
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
main() {
  check_deps

  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}  RDI Project Scaffolder${NC}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""

  # ── 1. Project Name ────────────────────────────────────────
  local project_name
  project_name=$(prompt_text "Project name (e.g., rdi-my-mcp)")
  if [ -z "$project_name" ]; then
    echo -e "${RED}Project name is required${NC}"
    exit 1
  fi
  echo ""

  # ── 2. Stack Type ──────────────────────────────────────────
  build_stack_menu
  if [ ${#STACK_NAMES[@]} -eq 0 ]; then
    echo -e "${RED}No stack templates found in $TEMPLATES_DIR${NC}"
    exit 1
  fi

  local stack_choice
  stack_choice=$(prompt_choice "Stack type:" "${STACK_LABELS[@]}")

  if [ -z "$stack_choice" ] || ! [[ "$stack_choice" =~ ^[0-9]+$ ]] || \
     [ "$stack_choice" -lt 1 ] || [ "$stack_choice" -gt ${#STACK_NAMES[@]} ]; then
    echo -e "${RED}Invalid choice${NC}"
    exit 1
  fi
  local selected_stack="${STACK_NAMES[$((stack_choice-1))]}"

  if ! resolve_chain "$selected_stack"; then
    echo -e "${RED}Error: Failed to resolve template chain for '$selected_stack'${NC}"
    exit 1
  fi
  echo -e "${DIM}Chain: ${TEMPLATE_CHAIN[*]}${NC}"
  echo ""

  # ── Set META_* locals (inherited by called functions) ───────
  # shellcheck disable=SC2034  # META_* consumed by substitute_markers() in template-utils.sh
  local META_PROJECT_NAME="$project_name"
  local META_PACKAGE_NAME="${project_name//[- ]/_}"
  local META_DISPLAY_NAME
  META_DISPLAY_NAME=$($PYTHON_CMD -c "import sys; print(sys.argv[1].replace('-', ' ').title())" "$project_name" 2>/dev/null) || true
  META_DISPLAY_NAME="${META_DISPLAY_NAME//$'\r'/}"
  # shellcheck disable=SC2034  # Consumed by substitute_markers()
  local META_DEFAULT_BRANCH="develop"
  local META_DESCRIPTION

  # ── 3. Description ─────────────────────────────────────────
  META_DESCRIPTION=$(prompt_text "Brief project description" "")
  echo ""

  # ── 4. GitHub Remote ───────────────────────────────────────
  local github_remote="" create_remote=false
  if prompt_yn "Create GitHub remote?" "n"; then
    create_remote=true
    github_remote=$(prompt_text "GitHub repo name" "RonHadler/$project_name")
  fi
  echo ""

  # ── 5. GCP Project ────────────────────────────────────────
  local GCP_PROJECT_ID="" GCP_REGION="us-central1"
  local gcp_input
  gcp_input=$(prompt_text "GCP project ID (or 'skip')" "skip")
  if [ "$gcp_input" != "skip" ]; then
    GCP_PROJECT_ID="$gcp_input"
    GCP_REGION=$(prompt_text "GCP region" "us-central1")
  fi
  echo ""

  # ── 6. Create tasks.json ──────────────────────────────────
  local create_tasks=true
  if ! prompt_yn "Create tasks.json for Ralph Loop?" "y"; then
    create_tasks=false
  fi
  echo ""

  # ── Target Directory ───────────────────────────────────────
  local parent_dir target_dir
  parent_dir="$(dirname "$DEV_ENV_DIR")"
  target_dir="$parent_dir/$project_name"

  if [ -d "$target_dir" ]; then
    echo -e "${RED}Directory already exists: $target_dir${NC}"
    exit 1
  fi

  # ══════════════════════════════════════════════════════════
  # SCAFFOLDING
  # ══════════════════════════════════════════════════════════

  # Clean up temp files on exit/interrupt
  local _tmpfiles=()
  # shellcheck disable=SC2317  # trap callback is invoked indirectly
  _cleanup() { [ ${#_tmpfiles[@]} -gt 0 ] && rm -f "${_tmpfiles[@]}" 2>/dev/null || true; }
  trap _cleanup EXIT

  echo -e "${BOLD}Creating project: $project_name${NC}"
  echo -e "${DIM}Location: $target_dir${NC}"
  echo -e "${DIM}Stack: $selected_stack (${TEMPLATE_CHAIN[*]})${NC}"
  echo ""

  mkdir -p "$target_dir"
  mkdir -p "$target_dir/.github/workflows"

  # ── Shared locals for scaffolding sections ──────────────────
  local tjson dir_entry dest_dir stack dest_rel source_path
  local j try_stack seeded_len actual_skeleton sk
  local dest_key src_path source_file dest_file rel_path

  # ── A. Scaffold directories from template chain ────────────
  for stack in "${TEMPLATE_CHAIN[@]}"; do
    tjson="$TEMPLATES_DIR/$stack/template.json"
    while IFS= read -r dir_entry; do
      [ -z "$dir_entry" ] && continue
      dest_dir=$(resolve_scaffold_dest "$dir_entry" "$target_dir")
      mkdir -p "$dest_dir"
    done < <(json_extract_array "$tjson" "scaffold.directories")
  done
  echo -e "  ${GREEN}+${NC} Scaffold directories"

  # ── B. Python: create package root ─────────────────────────
  if is_python_stack; then
    mkdir -p "$target_dir/$META_PACKAGE_NAME"
  fi

  # ── C. Managed files (CI workflows, review config) ─────────
  collect_managed_files

  echo ""
  echo -e "${BOLD}Managed Files${NC} ${DIM}(CI workflows, review config)${NC}"
  if [ ${#MANAGED_FILES[@]} -eq 0 ]; then
    echo -e "  ${DIM}(no managed files in template chain)${NC}"
  fi

  for entry in "${MANAGED_FILES[@]}"; do
    stack="${entry%%:*}"
    dest_rel="${entry#*:}"

    # Resolve source: declaring stack first, then walk chain backwards
    source_path=$(resolve_workflow_source "$stack" "$dest_rel")
    if [ -z "$source_path" ] || [ ! -f "$source_path" ]; then
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
      echo -e "  ${YELLOW}~${NC} $dest_rel — template source not found"
      continue
    fi

    mkdir -p "$(dirname "$target_dir/$dest_rel")"
    cp "$source_path" "$target_dir/$dest_rel"
    apply_all_substitutions "$target_dir/$dest_rel"
    echo -e "  ${GREEN}+${NC} $dest_rel"
  done

  # ── D. Seeded files (CLAUDE.md, AGENTS.md, Makefile, etc.) ─
  collect_seeded_files

  echo ""
  echo -e "${BOLD}Seeded Files${NC} ${DIM}(project-owned after creation)${NC}"

  seeded_len=${#SEEDED_MAP_KEYS[@]}
  for ((i=0; i<seeded_len; i++)); do
    dest_rel="${SEEDED_MAP_KEYS[$i]}"
    stack="${SEEDED_MAP_VALUES[$i]}"

    # .gitignore handled separately by copy_gitignore
    [ "$dest_rel" = ".gitignore" ] && continue

    local dest_path
    dest_path="$target_dir/$dest_rel"

    # Check for skeleton (most specific layer wins)
    actual_skeleton=""
    for s in "${TEMPLATE_CHAIN[@]}"; do
      sk="$TEMPLATES_DIR/$s/skeletons/${dest_rel}.skeleton"
      if [ -f "$sk" ]; then
        actual_skeleton="$sk"
      fi
    done

    if [ -n "$actual_skeleton" ]; then
      # Assemble from skeleton + fragments
      local tmpfile
      tmpfile=$(mktemp)
      _tmpfiles+=("$tmpfile")
      assemble_file "$actual_skeleton" "$tmpfile"
      apply_all_substitutions "$tmpfile"
      mkdir -p "$(dirname "$dest_path")"
      cat "$tmpfile" > "$dest_path"
      rm -f "$tmpfile"
      echo -e "  ${GREEN}+${NC} $dest_rel (assembled)"
    else
      # Direct copy — try exact name, then .template suffix
      source_path="$TEMPLATES_DIR/$stack/$dest_rel"
      if [ ! -f "$source_path" ]; then
        source_path="$TEMPLATES_DIR/$stack/${dest_rel}.template"
      fi

      if [ -f "$source_path" ]; then
        mkdir -p "$(dirname "$dest_path")"
        cp "$source_path" "$dest_path"
        apply_all_substitutions "$dest_path"
        echo -e "  ${GREEN}+${NC} $dest_rel"
      else
        echo -e "  ${YELLOW}~${NC} $dest_rel — source not found in $stack/"
      fi
    fi
  done

  # ── E. Scaffold source files (coordinator.py, etc.) ────────
  echo ""
  echo -e "${BOLD}Scaffold Files${NC} ${DIM}(initial source code)${NC}"

  local has_scaffold_files=false
  for stack in "${TEMPLATE_CHAIN[@]}"; do
    tjson="$TEMPLATES_DIR/$stack/template.json"
    while IFS=$'\t' read -r dest_key src_path; do
      [ -z "$dest_key" ] && continue
      has_scaffold_files=true

      source_file="$TEMPLATES_DIR/$stack/$src_path"
      if [ ! -f "$source_file" ]; then
        echo -e "  ${YELLOW}~${NC} $dest_key — scaffold source not found: $src_path"
        continue
      fi

      dest_file=$(resolve_scaffold_dest "$dest_key" "$target_dir")
      mkdir -p "$(dirname "$dest_file")"
      cp "$source_file" "$dest_file"
      apply_all_substitutions "$dest_file"

      rel_path="${dest_file#"$target_dir/"}"
      echo -e "  ${GREEN}+${NC} $rel_path"
    done < <(extract_scaffold_files "$tjson")
  done
  if [ "$has_scaffold_files" = false ]; then
    echo -e "  ${DIM}(no scaffold files in template chain)${NC}"
  fi

  # ── F. Python: create __init__.py files ────────────────────
  if is_python_stack; then
    while IFS= read -r d; do
      touch "$d/__init__.py"
    done < <(find "$target_dir/$META_PACKAGE_NAME" -type d 2>/dev/null)
    if [ -d "$target_dir/tests" ]; then
      while IFS= read -r d; do
        touch "$d/__init__.py"
      done < <(find "$target_dir/tests" -type d 2>/dev/null)
    fi
    echo -e "  ${GREEN}+${NC} __init__.py files"
  fi

  # ── G. .gitignore (concatenated from chain) ────────────────
  copy_gitignore "$target_dir"
  if ! grep -qF '.sdlc/' "$target_dir/.gitignore" 2>/dev/null; then
    {
      echo ""
      echo "# SDLC pipeline"
      echo ".sdlc/"
    } >> "$target_dir/.gitignore"
  fi
  echo -e "  ${GREEN}+${NC} .gitignore (${#TEMPLATE_CHAIN[@]} layers)"

  # ── H. tasks.json (optional) ──────────────────────────────
  if [ "$create_tasks" = true ]; then
    local tasks_source=""
    for stack in "${TEMPLATE_CHAIN[@]}"; do
      if [ -f "$TEMPLATES_DIR/$stack/tasks.json" ]; then
        tasks_source="$TEMPLATES_DIR/$stack/tasks.json"
      fi
    done
    if [ -n "$tasks_source" ]; then
      cp "$tasks_source" "$target_dir/tasks.json"
      apply_all_substitutions "$target_dir/tasks.json"
      echo -e "  ${GREEN}+${NC} tasks.json"
    fi
  fi

  # ── I. README.md ──────────────────────────────────────────
  local quick_start_cmds
  case "$selected_stack" in
    python*)
      quick_start_cmds="# Install dependencies
uv sync

# Run tests
make test

# Start development server
make dev-serve

# Start stdio transport (for local MCP clients)
make dev-stdio"
      ;;
    go)
      quick_start_cmds="# Start development containers
make up

# Run tests
make test

# Open development shell
make shell"
      ;;
    node)
      quick_start_cmds="# Install dependencies
npm install

# Run tests
npm test

# Start development server
npm run dev"
      ;;
    rust)
      quick_start_cmds="# Build
cargo build

# Run tests
cargo test"
      ;;
    *)
      quick_start_cmds="# See Makefile for available commands
make help"
      ;;
  esac

  cat > "$target_dir/README.md" <<EOF
# $META_DISPLAY_NAME

$META_DESCRIPTION

## Quick Start

\`\`\`bash
$quick_start_cmds
\`\`\`

## Development

See [CLAUDE.md](CLAUDE.md) for development workflow and TDD requirements.
See [AGENTS.md](AGENTS.md) for architecture and project context.

## Deployment

\`\`\`bash
# Build Docker image
make build

# Deploy to Cloud Run (via GitHub Actions)
git push origin develop
\`\`\`
EOF
  echo -e "  ${GREEN}+${NC} README.md"

  # ── J. docs/current-tasks.md ──────────────────────────────
  cat > "$target_dir/docs/current-tasks.md" <<EOF
# $META_DISPLAY_NAME — Current Tasks

## Current Sprint Goal
Initial project setup and core implementation.

## In Progress
- None

## Up Next
- TASK-002: Implement first feature

## Completed
- TASK-001: Scaffold project structure

## Blocked
- None
EOF
  echo -e "  ${GREEN}+${NC} docs/current-tasks.md"

  echo ""

  # ══════════════════════════════════════════════════════════
  # POST-SCAFFOLD
  # ══════════════════════════════════════════════════════════

  cd "$target_dir" || exit 1

  # ── Install dependencies / generate lockfile ───────────────
  echo -e "${BOLD}Installing dependencies...${NC}"
  if [ -f "$target_dir/pyproject.toml" ]; then
    if command -v uv &>/dev/null; then
      if uv sync 2>&1 | tail -5; then
        echo -e "  ${GREEN}+${NC} Dependencies installed (uv sync)"
      else
        echo -e "  ${YELLOW}~${NC} uv sync failed — run manually"
      fi
    else
      echo -e "  ${YELLOW}~${NC} uv not found — run 'uv sync' manually"
    fi
  elif [ -f "$target_dir/package.json" ]; then
    if command -v npm &>/dev/null; then
      if npm install 2>&1 | tail -5; then
        echo -e "  ${GREEN}+${NC} Dependencies installed (npm install)"
      else
        echo -e "  ${YELLOW}~${NC} npm install failed — run manually"
      fi
    else
      echo -e "  ${YELLOW}~${NC} npm not found — run 'npm install' manually"
    fi
  elif [ -f "$target_dir/go.mod" ]; then
    if command -v go &>/dev/null; then
      if go mod tidy 2>&1 | tail -5; then
        echo -e "  ${GREEN}+${NC} Dependencies resolved (go mod tidy)"
      else
        echo -e "  ${YELLOW}~${NC} go mod tidy failed — run manually"
      fi
    else
      echo -e "  ${YELLOW}~${NC} go not found — run 'go mod tidy' manually"
    fi
  elif [ -f "$target_dir/Cargo.toml" ]; then
    if command -v cargo &>/dev/null; then
      if cargo generate-lockfile 2>&1 | tail -5; then
        echo -e "  ${GREEN}+${NC} Lockfile generated (cargo)"
      else
        echo -e "  ${YELLOW}~${NC} cargo generate-lockfile failed — run manually"
      fi
    else
      echo -e "  ${YELLOW}~${NC} cargo not found — generate Cargo.lock manually"
    fi
  fi
  echo ""

  # ── Run initial tests ─────────────────────────────────────
  echo -e "${BOLD}Running initial tests...${NC}"
  if [ -f "$target_dir/pyproject.toml" ] && command -v uv &>/dev/null; then
    if uv run pytest tests/ -v 2>&1 | tail -10; then
      echo -e "  ${GREEN}+${NC} Initial tests pass"
    else
      echo -e "  ${YELLOW}~${NC} Tests failed — check the output above"
    fi
  elif [ -f "$target_dir/package.json" ] && command -v npm &>/dev/null; then
    if npm test 2>&1 | tail -10; then
      echo -e "  ${GREEN}+${NC} Initial tests pass"
    else
      echo -e "  ${YELLOW}~${NC} Tests failed — check the output above"
    fi
  elif [ -f "$target_dir/go.mod" ] && command -v go &>/dev/null; then
    if go test ./... 2>&1 | tail -10; then
      echo -e "  ${GREEN}+${NC} Initial tests pass"
    else
      echo -e "  ${YELLOW}~${NC} Tests failed — check the output above"
    fi
  elif [ -f "$target_dir/Cargo.toml" ] && command -v cargo &>/dev/null; then
    if cargo test 2>&1 | tail -10; then
      echo -e "  ${GREEN}+${NC} Initial tests pass"
    else
      echo -e "  ${YELLOW}~${NC} Tests failed — check the output above"
    fi
  else
    echo -e "  ${DIM}-${NC} Skipping tests (tool not available)"
  fi
  echo ""

  # ── Git init ──────────────────────────────────────────────
  echo -e "${BOLD}Initializing git...${NC}"
  git init -q
  git checkout -b develop
  git add -A
  git commit -q -m "$(cat <<'COMMITMSG'
feat: scaffold project

Initial project structure created by rdi-dev-env scaffolder.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
COMMITMSG
)"

  # Create staging and main branches
  git branch staging
  git branch main
  echo -e "  ${GREEN}+${NC} Git initialized (develop/staging/main)"
  echo ""

  # ── GitHub Remote ──────────────────────────────────────────
  if [ "$create_remote" = true ] && command -v gh &>/dev/null; then
    echo -e "${BOLD}Creating GitHub remote...${NC}"
    if gh repo create "$github_remote" --private --source=. --push 2>&1 | tail -3; then
      echo -e "  ${GREEN}+${NC} GitHub remote created"
    else
      echo -e "  ${YELLOW}~${NC} GitHub remote creation failed — run manually"
    fi
    echo ""
  fi

  # ══════════════════════════════════════════════════════════
  # SUMMARY
  # ══════════════════════════════════════════════════════════
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}  Project Created: $project_name${NC}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${BOLD}Location:${NC}    $target_dir"
  echo -e "  ${BOLD}Stack:${NC}       $selected_stack (${TEMPLATE_CHAIN[*]})"
  echo -e "  ${BOLD}Package:${NC}     $META_PACKAGE_NAME"
  echo -e "  ${BOLD}Branches:${NC}    develop (default), staging, main"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo -e "  cd $target_dir"
  echo -e "  claude                     # Start Claude Code"

  case "$selected_stack" in
    python*)
      echo -e "  make dev-serve             # Start dev server" ;;
    go)
      echo -e "  make up                    # Start dev containers" ;;
    node)
      echo -e "  npm run dev                # Start dev server" ;;
    rust)
      echo -e "  cargo run                  # Run project" ;;
  esac
  echo ""
}

main "$@"
