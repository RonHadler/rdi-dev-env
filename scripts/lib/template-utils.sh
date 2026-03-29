#!/usr/bin/env bash
# template-utils.sh — Shared functions for rdi-dev-env scripts
#
# Source this file: source "$SCRIPT_DIR/lib/template-utils.sh"
#
# Provides:
#   json_extract_field   — Extract a string field from template.json
#   resolve_chain        — Walk extends chain → TEMPLATE_CHAIN array
#   detect_stack         — Auto-detect project type from manifest files
#   collect_managed_files — Collect managed files from template chain
#   collect_seeded_files  — Collect seeded files (later layers override)
#   assemble_file        — Skeleton + fragment composition
#   copy_gitignore       — Concatenate .gitignore from each layer
#   extract_metadata     — Polymorphic project metadata extraction

set -euo pipefail

# ── Configuration ────────────────────────────────────────────
# TEMPLATES_DIR must be set before sourcing this file.
# Typically: TEMPLATES_DIR="$(cd "$(dirname "$0")/../templates" && pwd)"

# Resolve python command (python3 on Linux/macOS, python on Windows/Git Bash)
# Verify the command actually works — Windows Store aliases pass command -v
# but fail to execute.
PYTHON_CMD=""
if command -v python3 &>/dev/null && python3 --version &>/dev/null; then
  PYTHON_CMD="python3"
elif command -v python &>/dev/null && python --version &>/dev/null; then
  PYTHON_CMD="python"
fi

if [ -z "$PYTHON_CMD" ]; then
  echo "Error: Python is required but not found (tried python3 and python)." >&2
  exit 1
fi

# ── Globals set by functions ─────────────────────────────────
# shellcheck disable=SC2034  # These globals are consumed by scripts that source this file
TEMPLATE_CHAIN=()       # Set by resolve_chain()
DETECTED_STACK=""       # Set by detect_stack()
MANAGED_FILES=()        # Set by collect_managed_files()
SEEDED_MAP_KEYS=()      # Set by collect_seeded_files()
SEEDED_MAP_VALUES=()    # Set by collect_seeded_files()

# Metadata set by extract_metadata()
# shellcheck disable=SC2034
META_PROJECT_NAME=""
META_DESCRIPTION=""
META_PACKAGE_NAME=""
META_DISPLAY_NAME=""
META_DEFAULT_BRANCH=""

# ── JSON Parsing ─────────────────────────────────────────────

# Extract a simple top-level field from a JSON file.
# Handles both quoted strings ("key": "value") and bare numbers ("key": 2).
# Does NOT work for nested objects or arrays.
# Usage: json_extract_field <file> <field_name>
json_extract_field() {
  local file="$1" field="$2"
  if [ ! -f "$file" ]; then
    echo ""
    return
  fi
  local line
  line=$(grep -m1 "\"$field\"[[:space:]]*:" "$file" 2>/dev/null || echo "")
  if [ -z "$line" ]; then
    echo ""
    return
  fi
  # Check for null
  if printf '%s' "$line" | grep -q "null"; then
    echo ""
    return
  fi
  # Try quoted value first: "field": "value"
  if printf '%s' "$line" | grep -q "\"$field\"[[:space:]]*:[[:space:]]*\""; then
    printf '%s' "$line" | sed 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
  else
    # Bare numeric value: "field": 2
    printf '%s' "$line" | sed 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/'
  fi
}

# Extract a JSON array of strings from a JSON file using python3.
# Usage: json_extract_array <file> <dot.path>
# Example: json_extract_array template.json "files.managed" → one item per line
json_extract_array() {
  local file="$1" path="$2"
  if [ ! -f "$file" ]; then
    return
  fi
  $PYTHON_CMD -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
obj = data
for key in sys.argv[2].split('.'):
    obj = obj.get(key, {}) if isinstance(obj, dict) else {}
if isinstance(obj, list):
    for item in obj:
        print(item)
" "$file" "$path" 2>/dev/null || true
}

# Extract the detect rule from template.json as a parseable string.
# Returns: "always", "file_exists:<path>", or "file_contains:<path>:<pattern>"
# Usage: json_extract_detect <template.json>
json_extract_detect() {
  local file="$1"
  $PYTHON_CMD -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
d = data.get('detect', {})
if d.get('always'):
    print('always')
elif 'file_exists' in d:
    print('file_exists:' + d['file_exists'])
elif 'file_contains' in d:
    fc = d['file_contains']
    print('file_contains:' + fc['path'] + ':' + fc['pattern'])
else:
    print('unknown')
" "$file" 2>/dev/null || echo "unknown"
}

# ── Template Chain Resolution ────────────────────────────────

# Walk the extends chain from a stack name to produce an ordered list.
# Sets TEMPLATE_CHAIN=("base" "python" "python-fastmcp")
# Usage: resolve_chain <stack_name>
resolve_chain() {
  local stack="$1"
  TEMPLATE_CHAIN=()
  local chain=()
  local current="$stack"

  while [ -n "$current" ]; do
    chain=("$current" "${chain[@]}")
    local tjson="$TEMPLATES_DIR/$current/template.json"
    if [ ! -f "$tjson" ]; then
      echo "Error: template.json not found for stack '$current' at $tjson" >&2
      return 1
    fi
    current=$(json_extract_field "$tjson" "extends")
  done

  TEMPLATE_CHAIN=("${chain[@]}")
}

# ── Stack Detection ──────────────────────────────────────────

# Auto-detect project type from manifest files in a project directory.
# Checks most specific stacks first (higher layer numbers).
# Sets DETECTED_STACK to the most specific matching stack name.
# Usage: detect_stack <project_dir>
detect_stack() {
  local project_dir="$1"
  DETECTED_STACK=""

  # Collect all stacks with their layer numbers
  # Use tab delimiter to avoid conflicts with colons in Windows paths
  local stack_entries=()
  for tjson in "$TEMPLATES_DIR"/*/template.json; do
    [ -f "$tjson" ] || continue
    local name
    name=$(json_extract_field "$tjson" "name")
    local layer
    layer=$(json_extract_field "$tjson" "layer")
    stack_entries+=("${layer:-0}	$name	$tjson")
  done

  # Sort by layer descending (most specific first)
  local sorted
  # No templates found — nothing to detect
  [ ${#stack_entries[@]} -eq 0 ] && return 0

  sorted=$(printf '%s\n' "${stack_entries[@]}" | sort -t$'\t' -k1 -rn)

  # Evaluate each detect rule
  while IFS=$'\t' read -r layer name tjson; do

    local detect_rule
    detect_rule=$(json_extract_detect "$tjson")

    case "$detect_rule" in
      always)
        # Base always matches, but we want the most specific
        if [ -z "$DETECTED_STACK" ]; then
          DETECTED_STACK="$name"
        fi
        ;;
      file_exists:*)
        local check_file
        check_file="${detect_rule#file_exists:}"
        if [ -f "$project_dir/$check_file" ]; then
          DETECTED_STACK="$name"
          return 0
        fi
        ;;
      file_contains:*)
        local check_path check_pattern
        local detect_args="${detect_rule#file_contains:}"
        check_path="${detect_args%%:*}"
        check_pattern="${detect_args#*:}"
        if [ -f "$project_dir/$check_path" ] && grep -qE -e "$check_pattern" -- "$project_dir/$check_path" 2>/dev/null; then
          DETECTED_STACK="$name"
          return 0
        fi
        ;;
    esac
  done <<< "$sorted"
}

# ── File Collection ──────────────────────────────────────────

# Collect all managed files from the template chain.
# Each entry is "stack_name:dest_path" so callers know which layer provides it.
# Requires TEMPLATE_CHAIN to be set (call resolve_chain first).
# Sets MANAGED_FILES array.
# Usage: collect_managed_files
collect_managed_files() {
  MANAGED_FILES=()
  for stack in "${TEMPLATE_CHAIN[@]}"; do
    local tjson="$TEMPLATES_DIR/$stack/template.json"
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      MANAGED_FILES+=("$stack:$entry")
    done < <(json_extract_array "$tjson" "files.managed")
  done
}

# Collect seeded files from the template chain.
# Later layers override earlier ones for same-named files.
# Uses parallel arrays instead of associative arrays for bash 3 compat.
# Sets SEEDED_MAP_KEYS and SEEDED_MAP_VALUES arrays.
# Usage: collect_seeded_files
collect_seeded_files() {
  SEEDED_MAP_KEYS=()
  SEEDED_MAP_VALUES=()

  for stack in "${TEMPLATE_CHAIN[@]}"; do
    local tjson="$TEMPLATES_DIR/$stack/template.json"
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      # Check if key already exists; if so, override its value
      local found=false
      local keys_len=${#SEEDED_MAP_KEYS[@]}
      for ((i=0; i<keys_len; i++)); do
        if [ "${SEEDED_MAP_KEYS[$i]}" = "$entry" ]; then
          SEEDED_MAP_VALUES[$i]="$stack"
          found=true
          break
        fi
      done
      if [ "$found" = false ]; then
        SEEDED_MAP_KEYS+=("$entry")
        SEEDED_MAP_VALUES+=("$stack")
      fi
    done < <(json_extract_array "$tjson" "files.seeded")
  done
}

# ── Fragment Assembly ────────────────────────────────────────

# Assemble a document from a skeleton file and fragment files.
# Reads the skeleton, finds <!-- FRAGMENT: name --> markers, and replaces
# each with the content of the matching fragment file. Later layers in
# the template chain override earlier ones for same-named fragments.
#
# Usage: assemble_file <skeleton_file> <output_file>
# Requires TEMPLATE_CHAIN to be set.
assemble_file() {
  local skeleton="$1" output="$2"

  if [ ! -f "$skeleton" ]; then
    echo "Warning: skeleton not found: $skeleton" >&2
    return 1
  fi

  # Build fragment map: walk chain, later layers override
  # Parallel arrays for fragment name → file path
  local frag_names=()
  local frag_paths=()

  for stack in "${TEMPLATE_CHAIN[@]}"; do
    local frag_dir="$TEMPLATES_DIR/$stack/fragments"
    [ -d "$frag_dir" ] || continue
    for frag_file in "$frag_dir"/*.md; do
      [ -f "$frag_file" ] || continue
      local frag_name
      frag_name=$(basename "$frag_file" .md)
      # Check if already exists; override if so
      local found=false
      local names_len=${#frag_names[@]}
      for ((i=0; i<names_len; i++)); do
        if [ "${frag_names[$i]}" = "$frag_name" ]; then
          frag_paths[$i]="$frag_file"
          found=true
          break
        fi
      done
      if [ "$found" = false ]; then
        frag_names+=("$frag_name")
        frag_paths+=("$frag_file")
      fi
    done
  done

  # Process skeleton: replace FRAGMENT markers with content
  local temp_output
  temp_output=$(mktemp)

  while IFS= read -r line || [ -n "$line" ]; do
    # Check for <!-- FRAGMENT: name --> pattern
    if printf '%s' "$line" | grep -q '<!-- FRAGMENT:'; then
      local marker_name
      marker_name=$(printf '%s' "$line" | sed 's/.*<!-- FRAGMENT: \([^ ]*\) -->.*/\1/')

      # Find fragment in map
      local found=false
      local names_len=${#frag_names[@]}
      for ((i=0; i<names_len; i++)); do
        if [ "${frag_names[$i]}" = "$marker_name" ]; then
          cat "${frag_paths[$i]}" >> "$temp_output"
          found=true
          break
        fi
      done

      if [ "$found" = false ]; then
        # Leave marker as-is if fragment not found
        printf '%s\n' "$line" >> "$temp_output"
      fi
    else
      printf '%s\n' "$line" >> "$temp_output"
    fi
  done < "$skeleton"

  mv "$temp_output" "$output"
}

# ── .gitignore Concatenation ─────────────────────────────────

# Concatenate .gitignore files from each layer in the template chain.
# WARNING: This truncates the target .gitignore and rebuilds it from templates.
# Only use during new project scaffolding, NOT during refresh (which should
# preserve project-specific exclusions).
# Usage: copy_gitignore <target_dir>
# Requires TEMPLATE_CHAIN to be set.
copy_gitignore() {
  local target="$1"
  > "$target/.gitignore"
  for stack in "${TEMPLATE_CHAIN[@]}"; do
    local gi="$TEMPLATES_DIR/$stack/.gitignore"
    if [ -f "$gi" ]; then
      cat "$gi" >> "$target/.gitignore"
      printf "\n" >> "$target/.gitignore"
    fi
  done
}

# ── Metadata Extraction ──────────────────────────────────────

# Extract project metadata from the appropriate manifest file.
# Detects project type and reads name, description, package name.
# Sets META_* globals.
# Usage: extract_metadata <project_dir>
extract_metadata() {
  local project_dir="$1"
  META_PROJECT_NAME=""
  META_DESCRIPTION=""
  META_PACKAGE_NAME=""
  META_DISPLAY_NAME=""
  META_DEFAULT_BRANCH=""

  # Detect default branch
  META_DEFAULT_BRANCH=$(cd "$project_dir" && git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "")
  if [ -z "$META_DEFAULT_BRANCH" ]; then
    META_DEFAULT_BRANCH=$(cd "$project_dir" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")
  fi

  if [ -f "$project_dir/pyproject.toml" ]; then
    _extract_python_metadata "$project_dir"
  elif [ -f "$project_dir/package.json" ]; then
    _extract_node_metadata "$project_dir"
  elif [ -f "$project_dir/go.mod" ]; then
    _extract_go_metadata "$project_dir"
  elif [ -f "$project_dir/Cargo.toml" ]; then
    _extract_rust_metadata "$project_dir"
  fi

  # Derive display name from project name if not set
  if [ -z "$META_DISPLAY_NAME" ] && [ -n "$META_PROJECT_NAME" ]; then
    META_DISPLAY_NAME=$($PYTHON_CMD -c "import sys; print(sys.argv[1].replace('-', ' ').title())" "$META_PROJECT_NAME")
  fi
}

_extract_python_metadata() {
  local dir="$1"
  local result
  result=$($PYTHON_CMD -c "
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib
with open(sys.argv[1], 'rb') as f:
    data = tomllib.load(f)
proj = data.get('project', {})
name = proj.get('name', '')
desc = proj.get('description', '')
pkg = name.replace('-', '_')
print(name)
print(desc)
print(pkg)
" "$dir/pyproject.toml" 2>/dev/null) || return 0

  META_PROJECT_NAME=$(echo "$result" | sed -n '1p')
  META_DESCRIPTION=$(echo "$result" | sed -n '2p')
  META_PACKAGE_NAME=$(echo "$result" | sed -n '3p')
}

_extract_node_metadata() {
  local dir="$1"
  if ! command -v node &>/dev/null; then
    echo "Warning: node not found — cannot extract package.json metadata" >&2
    return 0
  fi
  local result
  result=$(node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
console.log(pkg.name || '');
console.log(pkg.description || '');
console.log((pkg.name || '').replace(/-/g, '_'));
" "$dir/package.json" 2>/dev/null) || return 0

  META_PROJECT_NAME=$(echo "$result" | sed -n '1p')
  META_DESCRIPTION=$(echo "$result" | sed -n '2p')
  META_PACKAGE_NAME=$(echo "$result" | sed -n '3p')
}

_extract_go_metadata() {
  local dir="$1"
  # go.mod: first line is "module github.com/user/project-name"
  local mod_line
  mod_line=$(grep -m1 '^module ' "$dir/go.mod" 2>/dev/null || echo "")
  if [ -n "$mod_line" ]; then
    local full_module="${mod_line#module }"
    META_PROJECT_NAME=$(basename "$full_module")
    META_PACKAGE_NAME=$(echo "$META_PROJECT_NAME" | sed 's/-/_/g')
  fi
  META_DESCRIPTION=""
}

_extract_rust_metadata() {
  local dir="$1"
  # Simple TOML parsing for name and description
  META_PROJECT_NAME=$(grep -m1 '^name' "$dir/Cargo.toml" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "")
  META_DESCRIPTION=$(grep -m1 '^description' "$dir/Cargo.toml" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "")
  META_PACKAGE_NAME=$(echo "$META_PROJECT_NAME" | sed 's/-/_/g')
}

# ── Template Marker Substitution ─────────────────────────────

# Apply <!-- CUSTOMIZE: marker --> substitutions to a file.
# Uses the META_* globals and any additional vars passed.
# Usage: substitute_markers <file> [extra_var=value ...]
substitute_markers() {
  local file="$1"
  shift

  [ -f "$file" ] || return 0

  # Escape sed special characters in values
  # Escape only characters special to sed with | delimiter: backslash, ampersand, pipe
  _sed_escape() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

  local project_name; project_name=$(_sed_escape "$META_PROJECT_NAME")
  local description; description=$(_sed_escape "$META_DESCRIPTION")
  local package_name; package_name=$(_sed_escape "$META_PACKAGE_NAME")
  local display_name; display_name=$(_sed_escape "$META_DISPLAY_NAME")
  local upper_package; upper_package=$(_sed_escape "$(echo "$META_PACKAGE_NAME" | tr '[:lower:]' '[:upper:]')")
  local default_branch; default_branch=$(_sed_escape "$META_DEFAULT_BRANCH")
  local today; today=$(date +%Y-%m-%d)

  sed -i.bak \
    -e "s|<!-- CUSTOMIZE: Project Name -->|$display_name|g" \
    -e "s|<!-- CUSTOMIZE: project-name -->|$project_name|g" \
    -e "s|<!-- CUSTOMIZE: package_name -->|$package_name|g" \
    -e "s|<!-- CUSTOMIZE: PACKAGE_NAME -->|$upper_package|g" \
    -e "s|<!-- CUSTOMIZE: description -->|$description|g" \
    -e "s|<!-- CUSTOMIZE: date -->|$today|g" \
    -e "s|<!-- CUSTOMIZE: default_branch -->|$default_branch|g" \
    "$file"
  rm -f "${file}.bak"

  # Apply any extra key=value substitutions
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    val=$(_sed_escape "$val")
    sed -i.bak "s|<!-- CUSTOMIZE: $key -->|$val|g" "$file"
    rm -f "${file}.bak"
  done
}

# ── Resolve Workflow Source Path ──────────────────────────────

# Given a managed file destination path and the stack that owns it,
# resolve the source path in the templates directory.
# Usage: resolve_workflow_source <stack> <dest_path>
# Example: resolve_workflow_source "python" ".github/workflows/lint-python.yml"
#   → templates/python/workflows/lint-python.yml
resolve_workflow_source() {
  local stack="$1" dest="$2"
  local basename
  basename=$(basename "$dest")

  # Workflows live in <stack>/workflows/
  local source="$TEMPLATES_DIR/$stack/workflows/$basename"
  if [ -f "$source" ]; then
    echo "$source"
    return
  fi

  # Dependabot lives in <stack>/workflows/dependabot.yml but dest is .github/dependabot.yml
  if [ "$basename" = "dependabot.yml" ]; then
    source="$TEMPLATES_DIR/$stack/workflows/dependabot.yml"
    if [ -f "$source" ]; then
      echo "$source"
      return
    fi
  fi

  echo ""
}
