#!/bin/bash
#
# rdi-dev-env — Smart Project Scaffolder
#
# Interactive script to create new projects from templates.
# Currently supports: Python/FastMCP
# Future: Next.js, Go
#
# Usage:
#   new-project.sh
#
# Dependencies: git, uv (for Python), sed, jq
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

# ── Paths ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ENV_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$DEV_ENV_DIR/templates"

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

to_snake_case() {
  echo "$1" | sed 's/[- ]/_/g'
}

to_upper_snake_case() {
  echo "$1" | sed 's/[- ]/_/g' | tr '[:lower:]' '[:upper:]'
}

# ── Dependency Check ─────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in git sed; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}Missing required dependencies: ${missing[*]}${NC}"
    exit 1
  fi
}

# ── Template Substitution ────────────────────────────────────
substitute_markers() {
  local file="$1"

  # Skip binary files
  if file "$file" | grep -q "binary"; then
    return
  fi

  # Escape pipe characters in user inputs to avoid breaking sed delimiter
  local safe_description="${PROJECT_DESCRIPTION//|/\\|}"
  local safe_display_name="${PROJECT_DISPLAY_NAME//|/\\|}"
  local safe_project_name="${PROJECT_NAME//|/\\|}"
  local safe_gcp_project="${GCP_PROJECT_ID//|/\\|}"
  local safe_gcp_region="${GCP_REGION//|/\\|}"

  sed -i.bak \
    -e "s|<!-- CUSTOMIZE: Project Name -->|$safe_display_name|g" \
    -e "s|<!-- CUSTOMIZE: project-name -->|$safe_project_name|g" \
    -e "s|<!-- CUSTOMIZE: package_name -->|$PACKAGE_NAME|g" \
    -e "s|<!-- CUSTOMIZE: PACKAGE_NAME -->|$UPPER_PACKAGE_NAME|g" \
    -e "s|<!-- CUSTOMIZE: description -->|$safe_description|g" \
    -e "s|<!-- CUSTOMIZE: date -->|$(date +%Y-%m-%d)|g" \
    -e "s|<!-- CUSTOMIZE: GCP project ID -->|$safe_gcp_project|g" \
    -e "s|<!-- CUSTOMIZE: GCP region -->|$safe_gcp_region|g" \
    "$file" && rm -f "${file}.bak"
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

check_deps

echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  RDI Project Scaffolder${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""

# ── 1. Project Name ──────────────────────────────────────────
PROJECT_NAME=$(prompt_text "Project name (e.g., rdi-my-mcp)")
if [ -z "$PROJECT_NAME" ]; then
  echo -e "${RED}Project name is required${NC}"
  exit 1
fi

PACKAGE_NAME=$(to_snake_case "$PROJECT_NAME")
UPPER_PACKAGE_NAME=$(to_upper_snake_case "$PROJECT_NAME")
# Generate display name: rdi-my-mcp -> Rdi My Mcp
PROJECT_DISPLAY_NAME=$(echo "$PROJECT_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')

echo ""

# ── 2. Stack Type ────────────────────────────────────────────
STACK_CHOICE=$(prompt_choice "Stack type:" "Python/FastMCP" "Next.js (coming soon)" "Go (coming soon)")

case $STACK_CHOICE in
  1) STACK="python-fastmcp" ;;
  2) echo -e "${YELLOW}Next.js scaffolding is not yet available.${NC}"; exit 0 ;;
  3) echo -e "${YELLOW}Go scaffolding is not yet available.${NC}"; exit 0 ;;
  *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

TEMPLATE_DIR="$TEMPLATES_DIR/$STACK"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo -e "${RED}Template not found: $TEMPLATE_DIR${NC}"
  exit 1
fi

echo ""

# ── 3. Description ───────────────────────────────────────────
PROJECT_DESCRIPTION=$(prompt_text "Brief project description" "A FastMCP server for...")
echo ""

# ── 4. GitHub Remote ─────────────────────────────────────────
GITHUB_REMOTE=""
CREATE_REMOTE=false
if prompt_yn "Create GitHub remote?" "n"; then
  CREATE_REMOTE=true
  GITHUB_REMOTE=$(prompt_text "GitHub repo name" "RonHadler/$PROJECT_NAME")
fi
echo ""

# ── 5. GitHub Actions ────────────────────────────────────────
SELECTED_WORKFLOWS=("ci" "security" "gemini-code-review")
echo -e "${BOLD}GitHub Actions workflows:${NC}"
echo -e "  Default: ${CYAN}ci, security, gemini-code-review${NC}"
echo -e "  Available: ci, security, gemini-code-review, gemini-on-demand, deploy-cloudrun, stale, dependabot"
EXTRA_WORKFLOWS=$(prompt_text "Additional workflows (comma-separated, or Enter for defaults)" "")
if [ -n "$EXTRA_WORKFLOWS" ]; then
  IFS=',' read -ra extras <<< "$EXTRA_WORKFLOWS"
  for w in "${extras[@]}"; do
    w=$(echo "$w" | xargs)  # trim whitespace
    SELECTED_WORKFLOWS+=("$w")
  done
fi
echo ""

# ── 6. GCP Project ──────────────────────────────────────────
GCP_PROJECT_ID=""
GCP_REGION="us-central1"
GCP_INPUT=$(prompt_text "GCP project ID (or 'skip')" "skip")
if [ "$GCP_INPUT" != "skip" ]; then
  GCP_PROJECT_ID="$GCP_INPUT"
  GCP_REGION=$(prompt_text "GCP region" "us-central1")
fi
echo ""

# ── 7. Create tasks.json ────────────────────────────────────
CREATE_TASKS=true
if ! prompt_yn "Create tasks.json for Ralph Loop?" "y"; then
  CREATE_TASKS=false
fi
echo ""

# ── Target Directory ─────────────────────────────────────────
# Default to parent of rdi-dev-env (typically C:\Dev)
PARENT_DIR="$(dirname "$DEV_ENV_DIR")"
TARGET_DIR="$PARENT_DIR/$PROJECT_NAME"

if [ -d "$TARGET_DIR" ]; then
  echo -e "${RED}Directory already exists: $TARGET_DIR${NC}"
  exit 1
fi

# ══════════════════════════════════════════════════════════════
# SCAFFOLDING
# ══════════════════════════════════════════════════════════════

echo -e "${BOLD}Creating project: $PROJECT_NAME${NC}"
echo -e "${DIM}Location: $TARGET_DIR${NC}"
echo ""

# ── Create directory structure ───────────────────────────────
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/$PACKAGE_NAME/models"
mkdir -p "$TARGET_DIR/$PACKAGE_NAME/tools"
mkdir -p "$TARGET_DIR/tests/tools"
mkdir -p "$TARGET_DIR/docs/adr"
mkdir -p "$TARGET_DIR/docs/stories"
mkdir -p "$TARGET_DIR/docs/requirements"
mkdir -p "$TARGET_DIR/.github/workflows"

# ── Copy and customize templates ─────────────────────────────

# Root files from python-fastmcp template
for file in CLAUDE.md AGENTS.md GEMINI.md pyproject.toml Makefile Dockerfile .gitignore .env.example; do
  if [ -f "$TEMPLATE_DIR/$file" ]; then
    cp "$TEMPLATE_DIR/$file" "$TARGET_DIR/$file"
    substitute_markers "$TARGET_DIR/$file"
    echo -e "  ${GREEN}+${NC} $file"
  fi
done

# tasks.json (optional)
if [ "$CREATE_TASKS" = true ] && [ -f "$TEMPLATE_DIR/tasks.json" ]; then
  cp "$TEMPLATE_DIR/tasks.json" "$TARGET_DIR/tasks.json"
  substitute_markers "$TARGET_DIR/tasks.json"
  echo -e "  ${GREEN}+${NC} tasks.json"
fi

# Scaffold source files into package directory
for file in coordinator.py config.py server.py __main__.py; do
  if [ -f "$TEMPLATE_DIR/scaffold/$file" ]; then
    cp "$TEMPLATE_DIR/scaffold/$file" "$TARGET_DIR/$PACKAGE_NAME/$file"
    substitute_markers "$TARGET_DIR/$PACKAGE_NAME/$file"
    echo -e "  ${GREEN}+${NC} $PACKAGE_NAME/$file"
  fi
done

# __init__.py files
touch "$TARGET_DIR/$PACKAGE_NAME/__init__.py"
touch "$TARGET_DIR/$PACKAGE_NAME/models/__init__.py"
touch "$TARGET_DIR/$PACKAGE_NAME/tools/__init__.py"
touch "$TARGET_DIR/tests/__init__.py"
touch "$TARGET_DIR/tests/tools/__init__.py"
echo -e "  ${GREEN}+${NC} __init__.py files"

# Test files from scaffold
for file in conftest.py test_coordinator.py; do
  if [ -f "$TEMPLATE_DIR/scaffold/tests/$file" ]; then
    cp "$TEMPLATE_DIR/scaffold/tests/$file" "$TARGET_DIR/tests/$file"
    substitute_markers "$TARGET_DIR/tests/$file"
    echo -e "  ${GREEN}+${NC} tests/$file"
  fi
done

# ── GitHub Actions workflows ─────────────────────────────────
WORKFLOWS_DIR="$TEMPLATES_DIR/github-workflows"
for workflow in "${SELECTED_WORKFLOWS[@]}"; do
  workflow_file="$workflow.yml"
  if [ "$workflow" = "dependabot" ]; then
    # Dependabot goes in .github/ not .github/workflows/
    if [ -f "$WORKFLOWS_DIR/dependabot.yml" ]; then
      cp "$WORKFLOWS_DIR/dependabot.yml" "$TARGET_DIR/.github/dependabot.yml"
      echo -e "  ${GREEN}+${NC} .github/dependabot.yml"
    fi
  elif [ -f "$WORKFLOWS_DIR/$workflow_file" ]; then
    cp "$WORKFLOWS_DIR/$workflow_file" "$TARGET_DIR/.github/workflows/$workflow_file"
    echo -e "  ${GREEN}+${NC} .github/workflows/$workflow_file"
  else
    echo -e "  ${YELLOW}~${NC} Workflow not found: $workflow_file"
  fi
done

# ── Docs ─────────────────────────────────────────────────────
cat > "$TARGET_DIR/docs/current-tasks.md" <<EOF
# $PROJECT_DISPLAY_NAME — Current Tasks

## Current Sprint Goal
Initial project setup and core tool implementation.

## In Progress
- None

## Up Next
- TASK-002: Add health check tool and /health custom route

## Completed
- TASK-001: Scaffold project structure

## Blocked
- None
EOF
echo -e "  ${GREEN}+${NC} docs/current-tasks.md"

cat > "$TARGET_DIR/docs/adr/adr-001-fastmcp-architecture.md" <<EOF
# ADR-001: FastMCP 3.x Architecture

## Status
Accepted

## Context
$PROJECT_DISPLAY_NAME needs an MCP server framework. FastMCP 3.x provides a mature, async-first framework with decorator-based tool registration, Pydantic integration, and built-in transport support (streamable-http, stdio, SSE).

## Decision
Use FastMCP 3.x with the coordinator singleton pattern:
- \`coordinator.py\` — FastMCP singleton instance
- \`config.py\` — Pydantic BaseSettings singleton
- \`server.py\` — Entry point (dotenv → import tools → mcp.run())
- \`tools/\` — One file per domain, \`@mcp.tool()\` decorators

## Consequences
- **Positive:** Consistent with rdi-poe-mcp, familiar pattern, testable, async-native
- **Negative:** Tied to FastMCP 3.x API, singleton pattern limits test isolation (use monkeypatch)
EOF
echo -e "  ${GREEN}+${NC} docs/adr/adr-001-fastmcp-architecture.md"

# ── README.md ────────────────────────────────────────────────
cat > "$TARGET_DIR/README.md" <<EOF
# $PROJECT_DISPLAY_NAME

$PROJECT_DESCRIPTION

## Quick Start

\`\`\`bash
# Install dependencies
uv sync

# Run tests
make test

# Start development server
make dev-serve

# Start stdio transport (for local MCP clients)
make dev-stdio
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

echo ""

# ══════════════════════════════════════════════════════════════
# POST-SCAFFOLD
# ══════════════════════════════════════════════════════════════

cd "$TARGET_DIR" || exit 1

# ── Ensure .sdlc/ is in .gitignore (all stacks) ─────────────
if [ -f "$TARGET_DIR/.gitignore" ]; then
  if ! grep -qF '.sdlc/' "$TARGET_DIR/.gitignore" 2>/dev/null; then
    echo "" >> "$TARGET_DIR/.gitignore"
    echo "# SDLC pipeline" >> "$TARGET_DIR/.gitignore"
    echo ".sdlc/" >> "$TARGET_DIR/.gitignore"
    echo -e "  ${GREEN}+${NC} Added .sdlc/ to .gitignore"
  fi
fi

# ── Install dependencies ─────────────────────────────────────
echo -e "${BOLD}Installing dependencies...${NC}"
if command -v uv &>/dev/null; then
  uv sync 2>&1 | tail -5
  echo -e "  ${GREEN}+${NC} Dependencies installed"
else
  echo -e "  ${YELLOW}~${NC} uv not found — run 'uv sync' manually"
fi
echo ""

# ── Verify tests pass ───────────────────────────────────────
echo -e "${BOLD}Running initial tests...${NC}"
if command -v uv &>/dev/null; then
  if uv run pytest tests/ -v 2>&1 | tail -10; then
    echo -e "  ${GREEN}+${NC} Initial tests pass"
  else
    echo -e "  ${YELLOW}~${NC} Tests failed — check the output above"
  fi
else
  echo -e "  ${DIM}-${NC} Skipping tests (uv not available)"
fi
echo ""

# ── Git init ─────────────────────────────────────────────────
echo -e "${BOLD}Initializing git...${NC}"
git init -q
git checkout -b develop
git add -A
git commit -q -m "feat: scaffold $PROJECT_NAME

Initial project structure created by rdi-dev-env scaffolder.
Stack: Python/FastMCP 3.x

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# Create staging and main branches
git branch staging
git branch main
echo -e "  ${GREEN}+${NC} Git initialized (develop/staging/main)"
echo ""

# ── GitHub Remote ────────────────────────────────────────────
if [ "$CREATE_REMOTE" = true ] && command -v gh &>/dev/null; then
  echo -e "${BOLD}Creating GitHub remote...${NC}"
  gh repo create "$GITHUB_REMOTE" --private --source=. --push 2>&1 | tail -3
  echo -e "  ${GREEN}+${NC} GitHub remote created"
  echo ""
fi

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Project Created: $PROJECT_NAME${NC}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC}    $TARGET_DIR"
echo -e "  ${BOLD}Stack:${NC}       Python/FastMCP 3.x"
echo -e "  ${BOLD}Package:${NC}     $PACKAGE_NAME"
echo -e "  ${BOLD}Branches:${NC}    develop (default), staging, main"
if [ "$CREATE_TASKS" = true ]; then
  echo -e "  ${BOLD}Tasks:${NC}       tasks.json (4 tasks, 1 pre-completed)"
fi
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo -e "  cd $TARGET_DIR"
echo -e "  claude                     # Start Claude Code"
echo -e "  make dev-serve             # Start dev server"
echo -e "  ralph-loop.sh --once       # Run next task autonomously"
echo ""
