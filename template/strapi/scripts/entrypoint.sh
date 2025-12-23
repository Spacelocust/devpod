#!/usr/bin/env sh

# Exit gracefully
trap "exit" SIGINT
trap "exit" SIGTERM

echo "Installing dependencies"

npm install

echo "Building application"

npm run build

echo "Container ready"

tail -f /dev/null
