#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Styling & Logger
###############################################################################

if [[ -t 1 ]]; then
  RESET="\033[0m"
  BOLD="\033[1m"
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
  BLUE="\033[34m"
else
  RESET="" BOLD="" RED="" GREEN="" YELLOW="" BLUE=""
fi

log() {
  local level="$1"; shift
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  local color
  case "$level" in
    INFO) color="$GREEN" ;;
    WARN) color="$YELLOW" ;;
    ERROR) color="$RED" ;;
    *) color="$RESET" ;;
  esac

  printf "%s %b[%s]%b %s\n" "$ts" "$BOLD$color" "$level" "$RESET" "$msg"
}

section() {
  printf "\n%b==> %s%b\n" "$BLUE$BOLD" "$1" "$RESET"
}

die() {
  log ERROR "$*"
  exit 1
}

###############################################################################
# GitHub Download Helpers (requires jq)
###############################################################################

download_file() {
  local remote_path="$1"
  local local_path="$2"
  local url="$GITHUB_RAW_URL/$remote_path"

  log INFO "Downloading $remote_path"
  mkdir -p "$(dirname "$local_path")"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$local_path" || die "Failed to download $remote_path"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$local_path" || die "Failed to download $remote_path"
  else
    die "curl or wget required"
  fi
}

download_directory() {
  local remote_dir="$1"
  local local_dir="$2"

  mkdir -p "$local_dir"

  local json
  if command -v curl >/dev/null 2>&1; then
    json=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/contents/$remote_dir?ref=$GITHUB_BRANCH") || return 1
  else
    json=$(wget -qO- "https://api.github.com/repos/$GITHUB_REPO/contents/$remote_dir?ref=$GITHUB_BRANCH") || return 1
  fi

  # Use jq to parse files and dirs reliably
  echo "$json" | jq -r '. | if type=="array" then .[] else . end | "\(.path) \(.type)"' |
  while IFS= read -r line; do
    local path type filename sub_local
    path=$(awk '{print $1}' <<<"$line")
    type=$(awk '{print $2}' <<<"$line")

    if [[ "$type" == "file" ]]; then
      filename="$(basename "$path")"
      download_file "$path" "$local_dir/$filename"
    elif [[ "$type" == "dir" ]]; then
      sub_local="$local_dir/$(basename "$path")"
      download_directory "$path" "$sub_local"
    fi
  done
}

###############################################################################
# Literal placeholder replacer
###############################################################################

literal_replace() {
  local input_file="$1"
  local output_file="$2"
  shift 2

  local tmp_file
  tmp_file="$(mktemp "${output_file}.XXXX")"
  cp "$input_file" "$tmp_file"

  while [[ $# -gt 0 ]]; do
    local placeholder="$1"
    local value="$2"
    shift 2

    # Escape sed delimiter |
    local esc_value
    esc_value=$(printf '%s' "$value" | sed 's/|/\\|/g')
    sed "s|$placeholder|$esc_value|g" "$tmp_file" > "$tmp_file.new"
    mv "$tmp_file.new" "$tmp_file"
  done

  mv "$tmp_file" "$output_file"
}
