#!/usr/bin/env sh
set -eu

usage() {
    cat <<EOF
Usage: $0 -f <file> [-p <placeholder> -v <value>]... [-o <output>]

Options:
  -f    Input file (required)
  -p    Placeholder (can be used multiple times)
  -v    Value (must follow each -p)
  -o    Output file (optional; defaults to overwriting input)
  -h    Show this help
EOF
    exit 1
}

# -------------------------
# Parse arguments
# -------------------------
FILE=""
OUTPUT=""
LAST_PLACEHOLDER=""
PLACEHOLDERS=""
VALUES=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f)
            FILE="$2"
            shift 2
            ;;
        -p)
            [ -z "$LAST_PLACEHOLDER" ] || { echo "Error: -p '$LAST_PLACEHOLDER' missing -v" >&2; exit 1; }
            LAST_PLACEHOLDER="$2"
            shift 2
            ;;
        -v)
            [ -n "$LAST_PLACEHOLDER" ] || { echo "Error: -v without preceding -p" >&2; exit 1; }
            PLACEHOLDERS="$PLACEHOLDERS
$LAST_PLACEHOLDER"
            VALUES="$VALUES
$2"
            LAST_PLACEHOLDER=""
            shift 2
            ;;
        -o)
            OUTPUT="$2"
            shift 2
            ;;
        -h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validation
[ -n "$FILE" ] || { echo "Error: -f is required" >&2; usage; }
[ -f "$FILE" ] || { echo "Error: File not found: $FILE" >&2; exit 1; }

[ -n "$PLACEHOLDERS" ] || { echo "Error: At least one -p/-v pair is required" >&2; exit 1; }
[ -z "$LAST_PLACEHOLDER" ] || { echo "Error: -p '$LAST_PLACEHOLDER' missing -v" >&2; exit 1; }

[ -z "$OUTPUT" ] && OUTPUT="$FILE"

# -------------------------
# Apply replacements
# -------------------------
TMP="$(mktemp "${OUTPUT}.XXXX")"
trap 'rm -f "$TMP"' EXIT

cp "$FILE" "$TMP"

# Loop over placeholder/value lists
# Convert multi-line variables to iterators
echo "$PLACEHOLDERS" | sed '/^$/d' | while IFS= read -r ph; do
    # get corresponding value
    value=$(echo "$VALUES" | sed '/^$/d' | sed -n "$(expr $(echo "$PLACEHOLDERS" | sed '/^$/d' | grep -n -F "$ph" | cut -d: -f1) )p")
    # Escape sed delimiter | in value
    esc_value=$(printf '%s' "$value" | sed 's/|/\\|/g')
    # Apply literal replacement
    sed "s|$ph|$esc_value|g" "$TMP" > "$TMP.new" && mv "$TMP.new" "$TMP"
done

mv "$TMP" "$OUTPUT"

echo "✓ Replacements complete: $OUTPUT"
