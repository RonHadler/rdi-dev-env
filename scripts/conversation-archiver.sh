#!/bin/bash
#
# rdi-dev-env — Conversation Archiver (PreCompact Hook)
#
# Archives the full conversation JSONL before Claude Code auto-compacts,
# preserving context that would otherwise be lost.
#
# Hook trigger: PreCompact
# Input (stdin): JSON with transcript_path, session_id, cwd
# Output: none (archives file to .sdlc/conversations/)
#

set -uo pipefail

# Read hook input from stdin
input=$(cat)

# Parse fields using jq for safe JSON handling
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Validate required fields
if [ -z "$transcript_path" ] || [ -z "$cwd" ]; then
  echo "Missing required fields (transcript_path, cwd)" >&2
  exit 0  # Don't block compaction on archiver errors
fi

if [ ! -f "$transcript_path" ]; then
  echo "Transcript file not found: $transcript_path" >&2
  exit 0
fi

# Archive to project-local .sdlc/conversations/
archive_dir="${cwd}/.sdlc/conversations"
mkdir -p "$archive_dir"

timestamp=$(date '+%Y%m%d-%H%M%S')
session_prefix="${session_id:0:8}"
archive_file="${archive_dir}/${timestamp}-${session_prefix}.jsonl"

cp "$transcript_path" "$archive_file"

# Log stats
msg_count=$(grep -c '"role":"assistant"' "$archive_file" 2>/dev/null || true)
[ -z "$msg_count" ] && msg_count=0
user_count=$(grep -c '"role":"user"' "$archive_file" 2>/dev/null || true)
[ -z "$user_count" ] && user_count=0
file_size=$(wc -c < "$archive_file" 2>/dev/null | tr -d ' ')

echo "Archived conversation: ${msg_count} assistant + ${user_count} user messages (${file_size} bytes) -> ${archive_file}" >&2
exit 0
