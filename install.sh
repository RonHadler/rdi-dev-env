#!/bin/bash
#
# rdi-dev-env — Installation Script
#
# Symlinks development environment configs, Claude Code commands,
# and Agent Skills to their correct locations.
#
# Usage:
#   cd /path/to/rdi-dev-env
#   bash install.sh
#
# What it does:
#   1. Backs up existing ~/.tmux.conf (if any)
#   2. Symlinks tmux/tmux.conf -> ~/.tmux.conf
#   3. Symlinks commands/*.md -> ~/.claude/commands/
#   4. Symlinks skills/*/ -> ~/.claude/skills/
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
CLAUDE_DIR="$HOME/.claude"

echo -e "${CYAN}${BOLD}rdi-dev-env installer${NC}"
echo -e "${DIM}Source: $SCRIPT_DIR${NC}"
echo ""

INSTALLED=0
SKIPPED=0
BACKED_UP=0

# ── Helper: create symlink with backup ───────────────────────
link_file() {
  local src="$1"
  local dest="$2"
  local name="$3"

  if [ ! -e "$src" ]; then
    echo -e "  ${RED}x${NC} $name — source not found: $src"
    ((SKIPPED++))
    return
  fi

  # If destination exists and is not a symlink to our source
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local current_target=""
    if [ -L "$dest" ]; then
      current_target="$(readlink -f "$dest" 2>/dev/null || readlink "$dest")"
    fi

    local src_resolved
    src_resolved="$(readlink -f "$src" 2>/dev/null || echo "$src")"

    if [ "$current_target" = "$src_resolved" ]; then
      echo -e "  ${DIM}-${NC} $name — already linked"
      ((SKIPPED++))
      return
    fi

    # Backup existing file
    local backup="${dest}.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$dest" "$backup"
    echo -e "  ${YELLOW}~${NC} $name — backed up to $(basename "$backup")"
    ((BACKED_UP++))
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  # Create symlink
  ln -s "$src" "$dest"
  echo -e "  ${GREEN}+${NC} $name -> $dest"
  ((INSTALLED++))
}

# ══════════════════════════════════════════════════════════════
# 1. tmux config
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}tmux${NC}"
link_file "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf" "tmux.conf"
echo ""

# ══════════════════════════════════════════════════════════════
# 2. Claude Code commands
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}Claude Code commands${NC}"
mkdir -p "$CLAUDE_DIR/commands"

for cmd_file in "$SCRIPT_DIR"/commands/*.md; do
  if [ -f "$cmd_file" ]; then
    local_name="$(basename "$cmd_file")"
    link_file "$cmd_file" "$CLAUDE_DIR/commands/$local_name" "$local_name"
  fi
done
echo ""

# ══════════════════════════════════════════════════════════════
# 3. Claude Code skills
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}Claude Code skills${NC}"
mkdir -p "$CLAUDE_DIR/skills"

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
  if [ -d "$skill_dir" ]; then
    skill_name="$(basename "$skill_dir")"
    link_file "$skill_dir" "$CLAUDE_DIR/skills/$skill_name" "$skill_name/"
  fi
done
echo ""

# ══════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}Summary${NC}"
echo -e "  ${GREEN}Installed:${NC} $INSTALLED"
echo -e "  ${DIM}Skipped:${NC}   $SKIPPED (already linked)"
echo -e "  ${YELLOW}Backed up:${NC} $BACKED_UP"
echo ""

if [ $INSTALLED -gt 0 ]; then
  echo -e "${GREEN}${BOLD}Done!${NC} Symlinks created successfully."
else
  echo -e "${DIM}Nothing to install — everything is up to date.${NC}"
fi

# Remind about tmux reload if tmux config was installed
if [ -L "$HOME/.tmux.conf" ]; then
  echo ""
  echo -e "${DIM}Tip: If tmux is running, reload config with:${NC}"
  echo -e "${DIM}  tmux source-file ~/.tmux.conf${NC}"
fi
