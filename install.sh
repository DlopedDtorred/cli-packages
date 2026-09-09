#!/usr/bin/env bash
set -e

INSTALL_DIR="/usr/local/bin"
CLI_NAME="pkgman" # O el nombre que quieras para tu comando
REPO_RAW_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/cli.sh"

echo "Installing $CLI_NAME..."

# Descargar el cli.sh principal y guardarlo en el directorio de binarios del sistema
sudo curl -sL "$REPO_RAW_URL" -o "$INSTALL_DIR/$CLI_NAME"

# Darle permisos de ejecución
sudo chmod +x "$INSTALL_DIR/$CLI_NAME"

echo "✨ Successfully installed! You can now use '$CLI_NAME' from anywhere."
echo "Try running: $CLI_NAME install <package-name>"
