#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Template Downloader & Replacer Script
# =============================================================================
# Usage: ./script.sh -t <template-name> -p <prefix>
# =============================================================================

# -----------------------------
# Configuration
# -----------------------------
GITHUB_REPO="Spacelocust/devpod"
GITHUB_BRANCH="feat/scripts/bash"
TEMP_DIR=""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------
# Utility Functions
# -----------------------------
log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  case "$level" in
    INFO)  echo -e "${CYAN}[INFO]${NC}  $msg" ;;
    WARN)  echo -e "${YELLOW}[WARN]${NC}  $msg" ;;
    ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
    SUCCESS) echo -e "${GREEN}[✓]${NC}    $msg" ;;
    *) echo "$msg" ;;
  esac
}

section() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

die() {
  log ERROR "$*"
  cleanup 1
}

init_temp_dir() {
  TEMP_DIR="$(mktemp -d)"
  trap 'cleanup' EXIT INT TERM
  log INFO "Created temporary directory: $TEMP_DIR"
}

cleanup() {
  local code=${1:-$?}
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    log INFO "Cleaning up temporary files"
    rm -rf "$TEMP_DIR"
  fi
  exit "$code"
}

clone_repository() {
  local repo_dir="$TEMP_DIR/repo"
  local repo_url="https://github.com/$GITHUB_REPO.git"

  log INFO "Cloning repository: $GITHUB_REPO"
  log INFO "Branch: $GITHUB_BRANCH"

  if git clone --depth 1 --branch "$GITHUB_BRANCH" --single-branch "$repo_url" "$repo_dir" >/dev/null 2>&1; then
    log SUCCESS "Repository cloned successfully"
    return 0
  else
    die "Failed to clone repository: $repo_url"
  fi
}

copy_template_file() {
  local source_path="$1"
  local dest_path="$2"
  local repo_dir="$TEMP_DIR/repo"
  local full_source="$repo_dir/$source_path"

  if [[ -f "$full_source" ]]; then
    cp "$full_source" "$dest_path"
    log SUCCESS "Copied: $source_path"
    return 0
  else
    log WARN "File not found: $source_path"
    return 1
  fi
}

copy_template_directory() {
  local source_path="$1"
  local dest_path="$2"
  local repo_dir="$TEMP_DIR/repo"
  local full_source="$repo_dir/$source_path"

  if [[ -d "$full_source" ]]; then
    cp -r "$full_source" "$dest_path"
    log SUCCESS "Copied directory: $source_path"
    return 0
  else
    log WARN "Directory not found: $source_path"
    return 1
  fi
}

literal_replace() {
  local input_file="$1"
  local output_file="$2"
  local pattern="$3"
  local replacement="$4"

  if [[ ! -f "$input_file" ]]; then
    log WARN "Input file not found: $input_file"
    return 1
  fi

  log INFO "Replacing '$pattern' → '$replacement' in $(basename "$input_file")"

  # Escape special characters for sed
  local escaped_pattern
  local escaped_replacement
  escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[[\.*^$()+?{|]/\\&/g')
  escaped_replacement=$(printf '%s\n' "$replacement" | sed 's/[\/&]/\\&/g')

  sed "s/$escaped_pattern/$escaped_replacement/g" "$input_file" > "$output_file"
  log SUCCESS "Created: $output_file"
}

# -----------------------------
# Argument Parsing
# -----------------------------
TEMPLATE_NAME=""
PREFIX=""

usage() {
  cat <<EOF
Usage: $0 -t <template-name> -p <prefix>

Options:
  -t <template-name>  Template to use (e.g., nodejs, python, react)
  -p <prefix>         Prefix for replacements (e.g., myproject)
  -h                  Show this help message

Example:
  $0 -t nodejs -p myapp

The script will:
  1. Download template files from GitHub
  2. Replace (prefix) placeholder with your prefix
  3. Set up project structure in current directory

EOF
  exit 1
}

while getopts "t:p:h" opt; do
  case "$opt" in
    t) TEMPLATE_NAME="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

[[ -n "$TEMPLATE_NAME" ]] || die "Template name (-t) is required. Use -h for help."
[[ -n "$PREFIX" ]] || die "Prefix (-p) is required. Use -h for help."

# Validate prefix
if ! [[ "$PREFIX" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  die "Prefix must contain only alphanumeric characters, dashes, and underscores"
fi

# -----------------------------
# Main Execution
# -----------------------------
init_temp_dir

section "Configuration"
log INFO "Template: $TEMPLATE_NAME"
log INFO "Prefix: $PREFIX"
log INFO "Repository: $GITHUB_REPO"
log INFO "Branch: $GITHUB_BRANCH"

section "Cloning Repository"

clone_repository

section "Copying Template Files"

REPO_DIR="$TEMP_DIR/repo"

# Copy template-specific files
copy_template_directory "templates/$TEMPLATE_NAME/.devcontainer" "$TEMP_DIR/.devcontainer"
copy_template_directory "templates/$TEMPLATE_NAME/scripts" "$TEMP_DIR/scripts"
copy_template_file "templates/$TEMPLATE_NAME/Dockerfile" "$TEMP_DIR/Dockerfile"
copy_template_file "templates/$TEMPLATE_NAME/compose.yml" "$TEMP_DIR/compose.yml"
copy_template_file "templates/$TEMPLATE_NAME/README.md" "$TEMP_DIR/README.md"
copy_template_file "templates/$TEMPLATE_NAME/.gitignore" "$TEMP_DIR/.gitignore"

# Copy common files
copy_template_file "common/Makefile" "$TEMP_DIR/Makefile.template"
copy_template_file "common/.editorconfig" "$TEMP_DIR/.editorconfig"

section "Processing and Replacing Patterns"

# Create output directories
mkdir -p ./.devpod
mkdir -p ./scripts

# Process files with pattern replacement
if [[ -f "$TEMP_DIR/compose.yml" ]]; then
  literal_replace "$TEMP_DIR/compose.yml" "./compose-devpod.yml" "(prefix)" "$PREFIX"
fi

if [[ -f "$TEMP_DIR/Makefile.template" ]]; then
  literal_replace "$TEMP_DIR/Makefile.template" "./Makefile" "(prefix)" "$PREFIX"
fi

if [[ -f "$TEMP_DIR/Dockerfile" ]]; then
  literal_replace "$TEMP_DIR/Dockerfile" "./.devpod/Dockerfile" "(prefix)" "$PREFIX"
fi

if [[ -f "$TEMP_DIR/README.md" ]]; then
  literal_replace "$TEMP_DIR/README.md" "./README.md" "(prefix)" "$PREFIX"
fi

# Copy directories
if [[ -d "$TEMP_DIR/.devcontainer" ]]; then
  cp -r "$TEMP_DIR/.devcontainer" ./.devpod/
  log SUCCESS "Copied: .devcontainer → .devpod/"
fi

if [[ -d "$TEMP_DIR/scripts" ]]; then
  cp -r "$TEMP_DIR/scripts" ./.devpod/
  log SUCCESS "Copied: scripts → .devpod/"
fi

# Copy other files
[[ -f "$TEMP_DIR/.gitignore" ]] && cp "$TEMP_DIR/.gitignore" ./ && log SUCCESS "Copied: .gitignore"
[[ -f "$TEMP_DIR/.editorconfig" ]] && cp "$TEMP_DIR/.editorconfig" ./ && log SUCCESS "Copied: .editorconfig"

section "Setup Complete! 🎉"

log SUCCESS "Template '$TEMPLATE_NAME' has been set up with prefix '$PREFIX'"
echo ""
log INFO "Generated files and directories:"
log INFO "  📁 .devpod/"
log INFO "  📁 scripts/"
log INFO "  📄 compose-devpod.yml"
log INFO "  📄 Makefile"
log INFO "  📄 README.md"
log INFO "  📄 .gitignore"
echo ""
log INFO "Next steps:"
log INFO "  1. Review the generated files"
log INFO "  2. Run 'make help' to see available commands"
log INFO "  3. Start developing! 🚀"
echo ""
