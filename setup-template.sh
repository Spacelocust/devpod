#!/usr/bin/env sh

# Exit gracefully
trap cleanup SIGINT SIGTERM EXIT

# Exit on error
set -e

# GitHub repository configuration
GITHUB_REPO="Spacelocust/devpod"  # Change this to your repo
GITHUB_BRANCH="main"             # Change if using different branch
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

# Temporary directory
TEMP_DIR=""

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

# Usage function
usage() {
    echo "Usage: $0 -t <template-name> [-p <prefix>] [-n <network>]"
    echo ""
    echo "Options:"
    echo "  -t    Template name (required)"
    echo "  -p    Container prefix (default: template name)"
    echo "  -h    Show this help"
    echo ""
    echo "Example:"
    echo "  $0 -t strapi -p gcp"
    exit 1
}

# Download file from GitHub
download_file() {
    local remote_path="$1"
    local local_path="$2"
    local url="$GITHUB_RAW_URL/$remote_path"

    echo "  Downloading $remote_path..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$local_path" 2>/dev/null || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$local_path" 2>/dev/null || return 1
    else
        echo "Error: Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    return 0
}

# Download directory recursively from GitHub
download_directory() {
    local remote_dir="$1"
    local local_dir="$2"
    local api_url="https://api.github.com/repos/$GITHUB_REPO/contents/$remote_dir?ref=$GITHUB_BRANCH"

    echo "  Downloading $remote_dir/..."

    # Create local directory
    mkdir -p "$local_dir"

    # Get directory contents from GitHub API
    local contents
    if command -v curl >/dev/null 2>&1; then
        contents=$(curl -fsSL "$api_url" 2>/dev/null) || return 1
    elif command -v wget >/dev/null 2>&1; then
        contents=$(wget -qO- "$api_url" 2>/dev/null) || return 1
    fi

    # Parse JSON and download files (basic parsing without jq)
    echo "$contents" | grep -o '"path":"[^"]*"' | sed 's/"path":"//;s/"$//' | while read -r file_path; do
        echo "$contents" | grep -o '"type":"[^"]*","path":"'"$file_path"'"' | grep -q '"type":"file"' && {
            local filename=$(basename "$file_path")
            download_file "$file_path" "$local_dir/$filename"
        }
    done

    return 0
}

# Parse arguments
TEMPLATE_NAME=""
PREFIX=""
SHOW_HELP=false

while getopts "t:p:n:h" opt; do
    case $opt in
        t) TEMPLATE_NAME="$OPTARG" ;;
        p) PREFIX="$OPTARG" ;;
        h) SHOW_HELP=true ;;
        *) usage ;;
    esac
done

# Show help if requested
if [ "$SHOW_HELP" = true ] || [ $# -eq 0 ]; then
    usage
fi

# Validate required arguments
if [ -z "$TEMPLATE_NAME" ]; then
    echo "Error: Template name (-t) is required"
    usage
fi

# Set defaults
if [ -z "$PREFIX" ]; then
    echo "Error: Prefix (-p) is required"
    usage
fi

echo "Setting up template: $TEMPLATE_NAME"
echo "Container prefix: $PREFIX"
echo "Repository: $GITHUB_REPO"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"
echo ""

# Download replace-vars.sh script
echo "Downloading replacer script..."
download_file "replace-vars.sh" "$TEMP_DIR/replace-vars.sh" || {
    echo "Error: Failed to download replace-vars.sh"
    exit 1
}
chmod +x "$TEMP_DIR/replace-vars.sh"

# Download template files
echo "Downloading template files..."

# Download .devcontainer
download_directory "template/$TEMPLATE_NAME/.devcontainer" "$TEMP_DIR/.devcontainer" || {
    echo "Warning: Failed to download .devcontainer, skipping"
}

# Download scripts
download_directory "template/$TEMPLATE_NAME/scripts" "$TEMP_DIR/scripts" || {
    echo "Warning: Failed to download scripts, skipping"
}

# Download Dockerfile
download_file "template/$TEMPLATE_NAME/Dockerfile" "$TEMP_DIR/Dockerfile" || {
    echo "Warning: Failed to download Dockerfile, skipping"
}

# Download compose.yml
download_file "template/$TEMPLATE_NAME/compose.yml" "$TEMP_DIR/compose.yml" || {
    echo "Warning: Failed to download compose.yml, skipping"
}

# Download common Makefile
download_file "common/Makefile" "$TEMP_DIR/Makefile.template" || {
    echo "Warning: Failed to download Makefile, skipping"
}

echo ""
echo "Setting up local files..."

# Create .devpod directory
mkdir -p "./.devpod"

# Copy .devcontainer if exists
if [ -d "$TEMP_DIR/.devcontainer" ]; then
    echo "Copying .devcontainer..."
    cp -r "$TEMP_DIR/.devcontainer" "./.devpod/"
fi

# Copy scripts if exists
if [ -d "$TEMP_DIR/scripts" ]; then
    echo "Copying scripts..."
    cp -r "$TEMP_DIR/scripts" "./.devpod/"
fi

# Copy Dockerfile if exists
if [ -f "$TEMP_DIR/Dockerfile" ]; then
    echo "Copying Dockerfile..."
    cp "$TEMP_DIR/Dockerfile" "./.devpod/"
fi

# Process compose.yml if exists
if [ -f "$TEMP_DIR/compose.yml" ]; then
    echo "Processing compose.yml..."
    "$TEMP_DIR/replace-vars.sh" -f "$TEMP_DIR/compose.yml" \
        -p '(prefix)' -v "$PREFIX" \
        -o "./compose-devpod.yml"
    echo "✓ Created compose-devpod.yml"
fi

# Process Makefile if exists
if [ -f "$TEMP_DIR/Makefile.template" ]; then
    echo "Processing Makefile..."
    "$TEMP_DIR/replace-vars.sh" -f "$TEMP_DIR/Makefile.template" \
        -p '(prefix)' -v "$PREFIX" \
        -o "./Makefile"
    echo "✓ Created Makefile"
fi

echo ""
echo "✓ Template setup complete!"
echo ""
echo "Generated files:"
echo "  - .devpod/"
echo "  - compose-devpod.yml"
echo "  - Makefile"
echo ""
echo "Next steps:"
echo "  - Review the generated files"
echo "  - Run your workspace setup"
