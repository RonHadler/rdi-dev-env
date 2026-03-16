#!/bin/bash
#
# rdi-dev-env — Context Reseeder (SessionStart Hook)
#
# After compaction, injects a summary of the pre-compaction conversation
# so context isn't lost.
#
# Hook trigger: SessionStart (matcher: compact)
# Input (stdin): JSON with transcript_path, session_id, cwd
# Output (stdout): JSON with hookSpecificOutput.additionalContext
#

set -uo pipefail

# Read hook input from stdin
input=$(cat)

# Parse cwd using jq for safe JSON handling
cwd=$(echo "$input" | jq -r '.cwd // empty')

if [ -z "$cwd" ]; then
  exit 0
fi

archive_dir="${cwd}/.sdlc/conversations"

# Find most recent archive
latest=$(ls -t "$archive_dir"/*.jsonl 2>/dev/null | head -1)
if [ -z "$latest" ]; then
  exit 0  # No archive, nothing to reseed
fi

# Extract key context from the archive

# Recent user messages (last 15, truncated)
user_msgs=""
while IFS= read -r line; do
  text=$(echo "$line" | jq -r '.text // empty' 2>/dev/null)
  if [ -n "$text" ]; then
    # Truncate long messages
    truncated="${text:0:200}"
    user_msgs="$(printf '%s- %s\n' "$user_msgs" "$truncated")"
  fi
done < <(grep '"role":"user"' "$latest" 2>/dev/null | tail -15)

# Files that were written/edited
files_touched=$(grep -o '"file_path":"[^"]*"' "$latest" 2>/dev/null | sort -u | cut -d'"' -f4)

# Task references
task_refs=$(grep -o 'TASK-[0-9]*' "$latest" 2>/dev/null | sort -u)

# Build context summary
summary="## Pre-Compaction Context (auto-recovered)

### Recent user requests:
${user_msgs}
### Files modified this session:
${files_touched:-None detected}

### Tasks referenced:
${task_refs:-None}

Full archive: ${latest}"

# Return as additionalContext using jq for safe JSON encoding
jq -n --arg ctx "$summary" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
