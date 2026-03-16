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
#   5. Symlinks scripts to ~/.local/bin/ as rdi-ralph-loop, rdi-new-project, etc.
#   6. Configures Claude Code hooks (PreCompact archiver, SessionStart reseeder)
#   7. Sets up global gitignore for .sdlc/conversations/
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
    ((SKIPPED++)) || true
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
      ((SKIPPED++)) || true
      return
    fi

    # Backup existing file
    local backup
    backup="${dest}.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$dest" "$backup"
    echo -e "  ${YELLOW}~${NC} $name — backed up to $(basename "$backup")"
    ((BACKED_UP++)) || true
  fi

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  # Create symlink
  ln -s "$src" "$dest"
  echo -e "  ${GREEN}+${NC} $name -> $dest"
  ((INSTALLED++)) || true
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
# 4. CLI scripts (symlinked to ~/.local/bin/)
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}CLI scripts${NC}"

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Map script files to their global command names
declare -A SCRIPT_MAP=(
  ["scripts/ralph-loop.sh"]="rdi-ralph-loop"
  ["scripts/new-project.sh"]="rdi-new-project"
  ["scripts/quality-gate.sh"]="rdi-quality-gate"
  ["scripts/usage-monitor.sh"]="rdi-usage-monitor"
  ["scripts/conversation-archiver.sh"]="rdi-conversation-archiver"
  ["scripts/context-reseeder.sh"]="rdi-context-reseeder"
)

for script in "${!SCRIPT_MAP[@]}"; do
  cmd_name="${SCRIPT_MAP[$script]}"
  src="$SCRIPT_DIR/$script"
  dest="$LOCAL_BIN/$cmd_name"
  if [ -f "$src" ]; then
    chmod +x "$src"
    link_file "$src" "$dest" "$cmd_name"
  fi
done

# Check if ~/.local/bin is on PATH
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
  echo ""
  echo -e "  ${YELLOW}Note:${NC} Add ~/.local/bin to your PATH:"
  echo -e "  ${DIM}echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc${NC}"
fi
echo ""

# ══════════════════════════════════════════════════════════════
# 5. Claude Code hooks (user-level settings.json)
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}Claude Code hooks${NC}"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Build the hooks config we want
HOOKS_CONFIG='{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"'"$LOCAL_BIN"'/rdi-conversation-archiver\"",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"'"$LOCAL_BIN"'/rdi-context-reseeder\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}'

# Merge hooks into existing settings.json (or create it)
if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq &>/dev/null; then
    # jq available — proper JSON merge
    tmp=$(mktemp)
    jq --argjson hooks "$(echo "$HOOKS_CONFIG" | jq '.hooks')" \
      '.hooks = ((.hooks // {}) + $hooks)' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo -e "  ${GREEN}+${NC} Hooks merged into $SETTINGS_FILE (via jq)"
    ((INSTALLED++)) || true
  elif command -v node &>/dev/null; then
    # Node available — use it for JSON merge
    # Convert Git Bash path to Windows path for Node
    win_settings=$(cygpath -w "$SETTINGS_FILE" 2>/dev/null || echo "$SETTINGS_FILE")
    hooks_json=$(echo "$HOOKS_CONFIG" | tr -d '\n')
    node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
      const hooks = JSON.parse(process.argv[2]);
      settings.hooks = { ...(settings.hooks || {}), ...hooks.hooks };
      fs.writeFileSync(process.argv[1], JSON.stringify(settings, null, 2) + '\n');
    " "$win_settings" "$hooks_json"
    echo -e "  ${GREEN}+${NC} Hooks merged into $SETTINGS_FILE (via node)"
    ((INSTALLED++)) || true
  else
    echo -e "  ${YELLOW}~${NC} Neither jq nor node found — hooks not configured (add manually)"
    ((SKIPPED++)) || true
  fi
else
  mkdir -p "$CLAUDE_DIR"
  echo "$HOOKS_CONFIG" > "$SETTINGS_FILE"
  echo -e "  ${GREEN}+${NC} Created $SETTINGS_FILE with hooks"
  ((INSTALLED++)) || true
fi
echo ""

# ══════════════════════════════════════════════════════════════
# 6. Global gitignore (.sdlc/conversations/)
# ══════════════════════════════════════════════════════════════
echo -e "${BOLD}Global gitignore${NC}"

GLOBAL_GITIGNORE="$HOME/.gitignore_global"

# Ensure file exists
touch "$GLOBAL_GITIGNORE"

# Add .sdlc/conversations/ if not already present
if ! grep -qF '.sdlc/conversations/' "$GLOBAL_GITIGNORE" 2>/dev/null; then
  echo "" >> "$GLOBAL_GITIGNORE"
  echo "# SDLC pipeline conversation archives (rdi-dev-env)" >> "$GLOBAL_GITIGNORE"
  echo ".sdlc/conversations/" >> "$GLOBAL_GITIGNORE"
  echo -e "  ${GREEN}+${NC} Added .sdlc/conversations/ to $GLOBAL_GITIGNORE"
  ((INSTALLED++)) || true
else
  echo -e "  ${DIM}-${NC} .sdlc/conversations/ already in $GLOBAL_GITIGNORE"
  ((SKIPPED++)) || true
fi

# Ensure git uses the global gitignore
current_excludes=$(git config --global core.excludesfile 2>/dev/null || echo "")
if [ "$current_excludes" != "$GLOBAL_GITIGNORE" ]; then
  git config --global core.excludesfile "$GLOBAL_GITIGNORE"
  echo -e "  ${GREEN}+${NC} Set git core.excludesfile to $GLOBAL_GITIGNORE"
  ((INSTALLED++)) || true
else
  echo -e "  ${DIM}-${NC} git core.excludesfile already set"
  ((SKIPPED++)) || true
fi
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
