#!/bin/bash
set -e

REPO_RAW_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/cli.sh"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="pkgman"

echo "==> Installing $BINARY_NAME..."

# Check required dependencies
for cmd in curl jq git; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required dependency '$cmd' is not installed."
        echo "Please install '$cmd' using your system package manager and try again."
        exit 1
    fi
done

# Download the main CLI script
echo "==> Fetching $BINARY_NAME script from repository..."
TMP_FILE=$(mktemp)
curl -sL "$REPO_RAW_URL" -o "$TMP_FILE"

# Ensure the downloaded file is valid
if [ ! -s "$TMP_FILE" ]; then
    echo "Error: Failed to download $BINARY_NAME from $REPO_RAW_URL"
    rm -f "$TMP_FILE"
    exit 1
fi

# Move script to target destination with root permissions if required
echo "==> Installing executable to $INSTALL_DIR/$BINARY_NAME..."
if [ -w "$INSTALL_DIR" ]; then
    mv "$TMP_FILE" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
else
    sudo mv "$TMP_FILE" "$INSTALL_DIR/$BINARY_NAME"
    sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
fi

echo "==> Installation complete! You can now use '$BINARY_NAME'."
echo "Run '$BINARY_NAME help' to get started."
