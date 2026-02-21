#!/bin/bash
#
# rdi-dev-env — One-Command 3-Pane Development Launcher
#
# Creates a tmux session with:
#   Pane 1 (left, 50%):  Claude Code / main terminal
#   Pane 2 (top-right):  Quality Gate (continuous watch)
#   Pane 3 (bot-right):  Dev Server (auto-detected)
#
# Usage:
#   bash tmux-dev.sh [project-path] [session-name]
#
# Examples:
#   bash tmux-dev.sh /mnt/c/Dev/rdi-novusiq elevateai
#   bash tmux-dev.sh /mnt/c/Dev/rdi-argus-mcp argus
#   bash tmux-dev.sh .                           # current dir, auto-named
#

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────

PROJECT_PATH="${1:-.}"
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "Error: Directory '$1' not found."
  exit 1
}

# Session name: argument, or derive from directory name
SESSION_NAME="${2:-$(basename "$PROJECT_PATH")}"

# Sanitize session name (tmux doesn't like dots or colons)
SESSION_NAME="${SESSION_NAME//[.:]/-}"

# ── Colors ───────────────────────────────────────────────────

CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ── Check Dependencies ──────────────────────────────────────

if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is not installed. Install with: sudo apt install tmux"
  exit 1
fi

# ── Kill existing session if it exists ───────────────────────

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo -e "${DIM}Session '$SESSION_NAME' already exists. Attaching...${NC}"
  exec tmux attach-session -t "$SESSION_NAME"
fi

# ── Auto-detect project type and dev command ─────────────────

detect_dev_command() {
  local dir="$1"

  if [ -f "$dir/package.json" ]; then
    # Node.js project — check for common dev scripts
    if grep -q '"dev"' "$dir/package.json" 2>/dev/null; then
      echo "npm run dev"
    elif grep -q '"start"' "$dir/package.json" 2>/dev/null; then
      echo "npm start"
    else
      echo "echo 'No dev script found in package.json'"
    fi
  elif [ -f "$dir/Makefile" ]; then
    # Makefile project (Go, etc.)
    if grep -q '^dev:' "$dir/Makefile" 2>/dev/null; then
      echo "make dev"
    elif grep -q '^up:' "$dir/Makefile" 2>/dev/null; then
      echo "make up"
    elif grep -q '^dev-serve:' "$dir/Makefile" 2>/dev/null; then
      echo "make dev-serve"
    else
      echo "echo 'No dev/up target found in Makefile'"
    fi
  elif [ -f "$dir/pyproject.toml" ]; then
    # Python project with uv/poetry
    echo "echo 'Python project detected. Start dev server manually.'"
  elif [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/docker-compose.yaml" ]; then
    echo "docker compose up"
  else
    echo "echo 'Unknown project type. Start dev server manually.'"
  fi
}

# Auto-detect quality gate script location
detect_quality_gate() {
  local dir="$1"

  if [ -f "$dir/scripts/quality-gate.sh" ]; then
    # Project has its own quality gate — use it
    echo "bash scripts/quality-gate.sh"
  else
    # Fall back to rdi-dev-env generic quality gate
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -f "$script_dir/scripts/quality-gate.sh" ]; then
      echo "bash $script_dir/scripts/quality-gate.sh"
    else
      echo "echo 'No quality gate script found.'"
    fi
  fi
}

DEV_CMD=$(detect_dev_command "$PROJECT_PATH")
QG_CMD=$(detect_quality_gate "$PROJECT_PATH")

# ── Create tmux session ─────────────────────────────────────

echo -e "${CYAN}${BOLD}Creating tmux session: $SESSION_NAME${NC}"
echo -e "${DIM}  Project: $PROJECT_PATH${NC}"
echo -e "${DIM}  Dev cmd: $DEV_CMD${NC}"
echo -e "${DIM}  QG cmd:  $QG_CMD${NC}"
echo ""

# Create session with first pane (Pane 1: Claude Code)
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_PATH" -x "$(tput cols)" -y "$(tput lines)"

# Set pane title for Pane 1
tmux select-pane -t "$SESSION_NAME:1.1" -T "Claude Code"

# Split right to create Pane 2 (Quality Gate) — 50% width
tmux split-window -h -t "$SESSION_NAME:1.1" -c "$PROJECT_PATH" -p 50

# Set pane title for Pane 2
tmux select-pane -t "$SESSION_NAME:1.2" -T "Quality Gate"

# Split Pane 2 vertically to create Pane 3 (Dev Server)
tmux split-window -v -t "$SESSION_NAME:1.2" -c "$PROJECT_PATH" -p 50

# Set pane title for Pane 3
tmux select-pane -t "$SESSION_NAME:1.3" -T "Dev Server"

# ── Start processes ──────────────────────────────────────────

# Pane 2: Quality Gate
tmux send-keys -t "$SESSION_NAME:1.2" "$QG_CMD" Enter

# Pane 3: Dev Server
tmux send-keys -t "$SESSION_NAME:1.3" "$DEV_CMD" Enter

# ── Focus on Pane 1 (Claude Code) ───────────────────────────

tmux select-pane -t "$SESSION_NAME:1.1"

# ── Attach ───────────────────────────────────────────────────

echo -e "${GREEN}${BOLD}Session ready. Attaching...${NC}"
exec tmux attach-session -t "$SESSION_NAME"
