#!/usr/bin/env bash

REGISTRY_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/packages.json"
COMMAND="$1"
PKG_NAME="$2"

if [ "$COMMAND" = "install" ]; then
    if [ -z "$PKG_NAME" ]; then
        echo "Error: Please specify a package name."
        exit 1
    fi

    echo "Searching for package '$PKG_NAME'..."
    SCRIPT_URL=$(curl -s "$REGISTRY_URL" | jq -r ".packages.\"$PKG_NAME\".url")

    if [ "$SCRIPT_URL" = "null" ] || [ -z "$SCRIPT_URL" ]; then
        echo "Error: Package '$PKG_NAME' does not exist in the registry."
        exit 1
    fi

    echo "Downloading and running installer..."
    bash <(curl -s "$SCRIPT_URL")
else
    echo "Usage: pkgman install <package-name>"
fi
