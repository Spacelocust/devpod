#!/usr/bin/env sh
set -eu

###############################################################################
# Styling & Logger (POSIX)
###############################################################################

# Enable colors only if stdout is a terminal
if [ -t 1 ]; then
  RESET="$(printf '\033[0m')"
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  RED="$(printf '\033[31m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  BLUE="$(printf '\033[34m')"
  CYAN="$(printf '\033[36m')"
else
  RESET=""; BOLD=""; DIM=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

SCRIPT_NAME="$(basename "$0")"
#LOG_DIR="./logs"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
#LOG_FILE="$LOG_DIR/${SCRIPT_NAME}_${TIMESTAMP}.log"

#mkdir -p "$LOG_DIR"

log() {
  level="$1"; shift
  msg="$*"
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  case "$level" in
    INFO)  color="$GREEN" ;;
    WARN)  color="$YELLOW" ;;
    ERROR) color="$RED" ;;
    *)     color="$RESET" ;;
  esac

  printf "%s %s[%s]%s %s\n" \
    "$ts" "$color$BOLD" "$level" "$RESET" "$msg"

  # printf "%s [%s] %s\n" "$ts" "$level" "$msg" >> "$LOG_FILE"
}

section() {
  printf "\n%s%s==> %s%s\n" "$BLUE" "$BOLD" "$1" "$RESET"
}

die() {
  log ERROR "$*"
  exit 1
}

###############################################################################
# Cleanup
###############################################################################

TEMP_DIR=""

cleanup() {
  code=$?
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    log INFO "Cleaning up temporary files"
    rm -rf "$TEMP_DIR"
    log INFO "Cleanup complete"
  fi
  exit "$code"
}

trap cleanup INT TERM EXIT

###############################################################################
# GitHub configuration
###############################################################################

GITHUB_REPO="Spacelocust/devpod"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

###############################################################################
# Usage
###############################################################################

usage() {
  cat <<EOF
Usage: $0 -t <template-name> -p <prefix>

Options:
  -t    Template name (required)
  -p    Container prefix (required)
  -h    Show this help

Example:
  $0 -t strapi -p gcp
EOF
  exit 1
}

###############################################################################
# Download helpers
###############################################################################

download_file() {
  remote_path="$1"
  local_path="$2"
  url="$GITHUB_RAW_URL/$remote_path"

  log INFO "Downloading $remote_path"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$local_path" || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$local_path" || return 1
  else
    die "curl or wget is required"
  fi
}

download_directory() {
    remote_dir="$1"
    local_dir="$2"

    mkdir -p "$local_dir"

    # Fetch JSON using GitHub API
    if command -v curl >/dev/null 2>&1; then
        json=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/contents/$remote_dir?ref=$GITHUB_BRANCH") || return 1
    else
        json=$(wget -qO- "https://api.github.com/repos/$GITHUB_REPO/contents/$remote_dir?ref=$GITHUB_BRANCH") || return 1
    fi

    # Loop over all items using jq
    echo "$json" | jq -r '. | if type=="array" then .[] else . end | "\(.path) \(.type)"' | while IFS= read -r line; do
        path=$(printf '%s' "$line" | awk '{print $1}')
        type=$(printf '%s' "$line" | awk '{print $2}')

        if [ "$type" = "file" ]; then
            filename="$(basename "$path")"
            download_file "$path" "$local_dir/$filename"
        elif [ "$type" = "dir" ]; then
            sub_local="$local_dir/$(basename "$path")"
            download_directory "$path" "$sub_local"
        fi
    done
}

###############################################################################
# Argument parsing
###############################################################################

TEMPLATE_NAME=""
PREFIX=""

while getopts "t:p:h" opt; do
  case "$opt" in
    t) TEMPLATE_NAME="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

[ -n "$TEMPLATE_NAME" ] || die "Template name (-t) is required"
[ -n "$PREFIX" ] || die "Prefix (-p) is required"

###############################################################################
# Execution
###############################################################################

section "Configuration"
log INFO "Template: $TEMPLATE_NAME"
log INFO "Prefix: $PREFIX"
log INFO "Repository: $GITHUB_REPO"

TEMP_DIR="$(mktemp -d)"
log INFO "Temporary directory: $TEMP_DIR"

section "Downloading files"

download_file "replacer.sh" "$TEMP_DIR/replacer.sh" || die "Failed to download replacer.sh"
chmod +x "$TEMP_DIR/replacer.sh"

download_directory "template/$TEMPLATE_NAME/.devcontainer" "$TEMP_DIR/.devcontainer" || log WARN ".devcontainer missing"
download_directory "template/$TEMPLATE_NAME/scripts" "$TEMP_DIR/scripts" || log WARN "scripts missing"
download_file "template/$TEMPLATE_NAME/Dockerfile" "$TEMP_DIR/Dockerfile" || log WARN "Dockerfile missing"
download_file "template/$TEMPLATE_NAME/compose.yml" "$TEMP_DIR/compose.yml" || log WARN "compose.yml missing"
download_file "common/Makefile" "$TEMP_DIR/Makefile.template" || log WARN "Makefile missing"

section "Setting up local files"

mkdir -p "./.devpod"

if [ -f "$TEMP_DIR/.devcontainer/devcontainer.json" ]; then
  "$TEMP_DIR/replacer.sh" -f "$TEMP_DIR/.devcontainer/devcontainer.json" \
    -p '(prefix)' -v "$PREFIX"
  log INFO "Updated devcontainer.json"
fi

if [ -f "$TEMP_DIR/scripts/up.sh" ]; then
  "$TEMP_DIR/replacer.sh" -f "$TEMP_DIR/scripts/up.sh" \
    -p '(prefix)' -v "$PREFIX"
  log INFO "Updated up.sh"
fi

if [ -f "$TEMP_DIR/compose.yml" ]; then
  "$TEMP_DIR/replacer.sh" -f "$TEMP_DIR/compose.yml" \
    -p '(prefix)' -v "$PREFIX" \
    -o "./compose-devpod.yml"
  log INFO "Created compose-devpod.yml"
fi

if [ -f "$TEMP_DIR/Makefile.template" ]; then
  "$TEMP_DIR/replacer.sh" -f "$TEMP_DIR/Makefile.template" \
    -p '(prefix)' -v "$PREFIX" \
    -o "./Makefile"
  log INFO "Created Makefile"
fi

[ -d "$TEMP_DIR/.devcontainer" ] && cp -r "$TEMP_DIR/.devcontainer" "./.devpod/"
[ -d "$TEMP_DIR/scripts" ] && cp -r "$TEMP_DIR/scripts" "./.devpod/"
[ -f "$TEMP_DIR/Dockerfile" ] && cp "$TEMP_DIR/Dockerfile" "./.devpod/"

section "Done"
log INFO "Template setup complete 🎉"

log INFO "Generated:"
log INFO "  .devpod/"
log INFO "  compose-devpod.yml"
log INFO "  Makefile"
