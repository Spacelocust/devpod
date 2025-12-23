#!/usr/bin/env sh

# Exit on error
set -e

# Usage function
usage() {
    echo "Usage: $0 -f <file> [-p <placeholder> -v <value>]... [-o <output>]"
    echo ""
    echo "Options:"
    echo "  -f    Input file to process (required)"
    echo "  -p    Placeholder to replace (can be used multiple times)"
    echo "  -v    Value to replace with (must follow each -p)"
    echo "  -o    Output file (optional, defaults to overwriting input file)"
    echo ""
    echo "Examples:"
    echo "  # Single replacement"
    echo "  $0 -f docker-compose.yml -p '{{container-prefix}}' -v 'myapp'"
    echo ""
    echo "  # Multiple replacements"
    echo "  $0 -f docker-compose.yml \\"
    echo "    -p '{{container-prefix}}' -v 'myapp' \\"
    echo "    -p '{{network-name}}' -v 'production'"
    echo ""
    echo "  # With output file"
    echo "  $0 -f template.yml \\"
    echo "    -p '{{prefix}}' -v 'app' \\"
    echo "    -p '{{env}}' -v 'prod' \\"
    echo "    -o docker-compose.prod.yml"
    exit 1
}

# Parse arguments
FILE=""
OUTPUT=""
SHOW_HELP=false
REPLACEMENTS=""
LAST_PLACEHOLDER=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f)
            FILE="$2"
            shift 2
            ;;
        -p)
            if [ -n "$LAST_PLACEHOLDER" ]; then
                echo "Error: Placeholder '$LAST_PLACEHOLDER' has no corresponding value"
                echo "Each -p must be followed by -v"
                usage
            fi
            LAST_PLACEHOLDER="$2"
            shift 2
            ;;
        -v)
            if [ -z "$LAST_PLACEHOLDER" ]; then
                echo "Error: Value provided without placeholder"
                echo "Each -v must be preceded by -p"
                usage
            fi
            # Store placeholder=value pair
            REPLACEMENTS="$REPLACEMENTS$LAST_PLACEHOLDER|||$2
"
            LAST_PLACEHOLDER=""
            shift 2
            ;;
        -o)
            OUTPUT="$2"
            shift 2
            ;;
        -h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
done

# Show help if requested or no arguments provided
if [ "$SHOW_HELP" = true ]; then
    usage
fi

# Check for unpaired placeholder
if [ -n "$LAST_PLACEHOLDER" ]; then
    echo "Error: Placeholder '$LAST_PLACEHOLDER' has no corresponding value"
    usage
fi

# Validate required arguments
if [ -z "$FILE" ]; then
    echo "Error: Input file (-f) is required"
    usage
fi

if [ -z "$REPLACEMENTS" ]; then
    echo "Error: At least one placeholder-value pair (-p/-v) is required"
    usage
fi

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

# Set output file (default to input file)
if [ -z "$OUTPUT" ]; then
    OUTPUT="$FILE"
fi

# Create temp file
TEMP_FILE="$OUTPUT.tmp"
cp "$FILE" "$TEMP_FILE"

# Process each replacement
echo "Processing replacements in $FILE..."
echo "$REPLACEMENTS" | while IFS='|||' read -r placeholder value; do
    if [ -n "$placeholder" ] && [ -n "$value" ]; then
        echo "  Replacing '$placeholder' with '$value'"

        # Escape special characters for sed
        ESCAPED_PLACEHOLDER=$(echo "$placeholder" | sed 's/[]\/$*.^[]/\\&/g')
        ESCAPED_VALUE=$(echo "$value" | sed 's/[\/&]/\\&/g')

        # Perform replacement
        sed "s/$ESCAPED_PLACEHOLDER/$ESCAPED_VALUE/g" "$TEMP_FILE" > "$TEMP_FILE.new"
        mv "$TEMP_FILE.new" "$TEMP_FILE"
    fi
done

# Move temp file to output
mv "$TEMP_FILE" "$OUTPUT"

echo "✓ All replacements complete: $OUTPUT"
