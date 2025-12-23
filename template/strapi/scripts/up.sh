#!/usr/bin/env sh
# Exit gracefully
trap "exit" SIGINT
trap "exit" SIGTERM

# Parse command line arguments
RECREATE=false
for arg in "$@"; do
    case $arg in
        --recreate)
            RECREATE=true
            shift
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Create or check network
echo "Checking network for workspace..."
if docker network inspect (prefix)-network >/dev/null 2>&1; then
    echo "✓ Network (prefix)-network already exists"
else
    echo "Creating network (prefix)-network..."
    docker network create (prefix)-network
    echo "✓ Network (prefix)-network created"
fi

# Set devpod flags based on recreate parameter
DEVPOD_FLAGS=""
if [ "$RECREATE" = true ]; then
    echo "Recreating strapi workspace (containers will be rebuilt)..."
    DEVPOD_FLAGS="--recreate"
else
    echo "Starting strapi workspace..."
fi

devpod up . --devcontainer-path ./devpod/.devcontainer/devcontainer.json --id (prefix)-strapi $DEVPOD_FLAGS

echo "✓ Workspace setup complete"
