#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Source reusable functions
# -----------------------------
GITHUB_REPO="Spacelocust/devpod"
GITHUB_BRANCH="feat/scripts/bash"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"


TEMP_DIR=""

init_temp_dir() {
  TEMP_DIR="$(mktemp -d)"
  trap cleanup EXIT INT TERM
}

cleanup() {
  local code=${1:-$?}
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    log INFO "Cleaning up temporary files"
    rm -rf "$TEMP_DIR"
    log INFO "Cleanup complete"
  fi
  exit "$code"
}

init_temp_dir

# Download utils.sh into TEMP_DIR
download_file "utils.sh" "$TEMP_DIR/utils.sh"
. "$TEMP_DIR/utils.sh"

# -----------------------------
# Argument parsing
# -----------------------------
TEMPLATE_NAME=""
PREFIX=""

usage() {
  cat <<EOF
Usage: $0 -t <template-name> -p <prefix>
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

[[ -n "$TEMPLATE_NAME" ]] || die "Template name (-t) is required"
[[ -n "$PREFIX" ]] || die "Prefix (-p) is required"

# -----------------------------
# Execution
# -----------------------------
section "Configuration"
log INFO "Template: $TEMPLATE_NAME"
log INFO "Prefix: $PREFIX"

section "Downloading files"
download_file "replacer.sh" "$TEMP_DIR/replacer.sh"
chmod +x "$TEMP_DIR/replacer.sh"

download_directory "template/$TEMPLATE_NAME/.devcontainer" "$TEMP_DIR/.devcontainer" || log WARN ".devcontainer missing"
download_directory "template/$TEMPLATE_NAME/scripts" "$TEMP_DIR/scripts" || log WARN "scripts missing"
download_file "template/$TEMPLATE_NAME/Dockerfile" "$TEMP_DIR/Dockerfile" || log WARN "Dockerfile missing"
download_file "template/$TEMPLATE_NAME/compose.yml" "$TEMP_DIR/compose.yml" || log WARN "compose.yml missing"
download_file "common/Makefile" "$TEMP_DIR/Makefile.template" || log WARN "Makefile missing"

section "Processing files"

mkdir -p ./.devpod

# Example replacements
[ -f "$TEMP_DIR/compose.yml" ] && literal_replace "$TEMP_DIR/compose.yml" "./compose-devpod.yml" "(prefix)" "$PREFIX"
[ -f "$TEMP_DIR/Makefile.template" ] && literal_replace "$TEMP_DIR/Makefile.template" "./Makefile" "(prefix)" "$PREFIX"

[ -d "$TEMP_DIR/.devcontainer" ] && cp -r "$TEMP_DIR/.devcontainer" ./.devpod/
[ -d "$TEMP_DIR/scripts" ] && cp -r "$TEMP_DIR/scripts" ./.devpod/
[ -f "$TEMP_DIR/Dockerfile" ] && cp "$TEMP_DIR/Dockerfile" ./.devpod/

section "Done"
log INFO "Template setup complete 🎉"

log INFO "Generated:"
log INFO "  .devpod/"
log INFO "  compose-devpod.yml"
log INFO "  Makefile"
