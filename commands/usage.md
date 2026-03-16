---
name: usage
description: Show Claude Max subscription usage budget and status
allowed-tools:
  - Bash(*)
  - Read
---

Check the current Claude Max subscription usage budget by running the usage monitor script.

1. Run: `bash "$HOME/.local/bin/rdi-usage-monitor" status`
2. If the script is not found, try the source location: `bash "$(find /c/Dev/rdi-dev-env/scripts -name 'usage-monitor.sh' 2>/dev/null | head -1)" status`
3. If neither is found, explain that the usage monitor needs to be installed from rdi-dev-env (`bash install.sh`) and show the manual calculation approach:
   - Count files: `find ~/.claude/projects -name '*.jsonl' -mmin -300`
   - Count assistant messages: `grep -c '"role":"assistant"' <file>`
4. Present the results clearly with the budget status
5. If status is LOW or CRITICAL, warn about pausing autonomous work
